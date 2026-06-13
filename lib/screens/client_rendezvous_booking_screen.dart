import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import '../core/network/http_client.dart';
import '../models/rendezvous_models.dart';
import '../models/service_models.dart';
import '../services/rendezvous_service.dart';
import '../utils/fare_calculator.dart';

// Full service data needed to show pricing card + detect delivery type
class _ServiceData {
  final String id;
  final String name;
  final String transportType;
  final String pricingModel;
  final double? basePrice;
  final double? pricePerKm;
  final double? pricePerMinute;
  final double? minimumFare;
  final String currency;

  const _ServiceData({
    required this.id,
    required this.name,
    required this.transportType,
    required this.pricingModel,
    this.basePrice,
    this.pricePerKm,
    this.pricePerMinute,
    this.minimumFare,
    this.currency = 'TND',
  });

  bool get isDelivery =>
      TransportTypeConstants.deliverySlugs.contains(transportType);

  bool get isHourly => pricingModel == 'hourly';
  bool get isFixed => pricingModel == 'fixed';
}

class ClientRendezvousBookingScreen extends StatefulWidget {
  const ClientRendezvousBookingScreen({super.key});

  @override
  State<ClientRendezvousBookingScreen> createState() =>
      _ClientRendezvousBookingScreenState();
}

class _ClientRendezvousBookingScreenState
    extends State<ClientRendezvousBookingScreen>
    with SingleTickerProviderStateMixin {
  // ─── Colors ──────────────────────────────────────────────────────
  static const _navy = Color(0xFF0F172A);
  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFF8C5A);
  static const _bg = Color(0xFFF8F9FB);
  static const _cardBg = Colors.white;
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF9BA3B4);
  static const _border = Color(0xFFE8ECF0);
  static const _green = Color(0xFF22C55E);

  // ─── State ───────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // Standard address (used for RDV services or as pickup for delivery)
  final _addressCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  // Delivery-specific fields
  final _destAddressCtrl = TextEditingController();
  final _destLatCtrl = TextEditingController();
  final _destLngCtrl = TextEditingController();
  final _cargoDescCtrl = TextEditingController();

  String? _selectedCargoSize; // 'small' | 'medium' | 'large' | 'extra_large'
  double? _selectedCargoWeightKg;
  bool _isFragile = false;

  List<_ServiceData> _services = [];
  _ServiceData? _selectedService;
  bool _loadingServices = true;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _durationMinutes = 60; // for standard RDV
  int _durationHours = 1;    // for hourly services

  bool _isSubmitting = false;
  String? _error;

  // Fare estimate (computed from fields when both addresses are set)
  double? _estimatedFare;
  double? _estimatedDistanceKm;

  final List<int> _durations = [30, 60, 90, 120];
  final List<int> _hourOptions = [1, 2, 4, 8, 12];
  final List<String> _cargoSizes = ['small', 'medium', 'large', 'extra_large'];
  final List<double> _weightOptions = [5, 20, 100, 500, 1000];

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ─── Computed ────────────────────────────────────────────────────
  bool get _isDelivery => _selectedService?.isDelivery ?? false;
  bool get _isHourly => _selectedService?.isHourly ?? false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    _fetchServicesWithLocation();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _addressCtrl.dispose();
    _detailsCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _destAddressCtrl.dispose();
    _destLatCtrl.dispose();
    _destLngCtrl.dispose();
    _cargoDescCtrl.dispose();
    super.dispose();
  }

  // ─── Services loading ─────────────────────────────────────────────
  Future<void> _fetchServicesWithLocation() async {
    double? latitude;
    double? longitude;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 5),
        );
        latitude = pos.latitude;
        longitude = pos.longitude;
      }
    } catch (_) {
      // GPS unavailable — proceed without coordinates (backend returns default zone)
    }
    await _fetchServices(latitude: latitude, longitude: longitude);
  }

  Future<void> _fetchServices({double? latitude, double? longitude}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (latitude != null) queryParams['latitude'] = latitude.toString();
      if (longitude != null) queryParams['longitude'] = longitude.toString();
      final params = queryParams.isEmpty ? null : queryParams;

      // HttpClient throws on 4xx — use try/catch for each fallback
      HttpResponse? response;
      for (final path in ['/m/services', '/m/services/catalogue', '/services/catalogue', '/services']) {
        try {
          response = await HttpClient.get(path, queryParams: params);
          break;
        } catch (_) {
          continue;
        }
      }
      if (response == null || !response.isSuccess) {
        if (mounted) setState(() => _loadingServices = false);
        return;
      }
      {
        final json = response.json;
        final outer = json['data'];

        // Unwrap nested envelope: { data: { message, data: [...] } }
        List<dynamic> rawList = [];
        if (outer is List) {
          rawList = outer;
        } else if (outer is Map<String, dynamic>) {
          final inner = outer['data'];
          if (inner is List) rawList = inner;
        }

        // rawList may be either:
        //  A) a flat list of service objects  → id, name, pricing_model, base_price, …
        //  B) a catalogue of categories       → id, name, transport_type, services: [...]
        // Detect by checking if the first item has a 'services' array.
        final isCatalogue = rawList.isNotEmpty &&
            rawList.first is Map &&
            (rawList.first as Map)['services'] is List;

        final List<_ServiceData> parsed = [];

        if (isCatalogue) {
          // Flatten: iterate categories, then services inside each
          for (final cat in rawList) {
            if (cat is! Map<String, dynamic>) continue;
            final categoryTransportType = cat['transport_type']?.toString() ?? '';
            final services = cat['services'];
            if (services is! List) continue;
            for (final svc in services) {
              if (svc is! Map<String, dynamic>) continue;
              if ((svc['is_active'] ?? true) == false) continue;
              // transport_type lives on the category for catalogue responses
              final transportType = svc['transport_type']?.toString().isNotEmpty == true
                  ? svc['transport_type'].toString()
                  : categoryTransportType;
              parsed.add(_ServiceData(
                id: svc['id']?.toString() ?? '',
                name: svc['name']?.toString() ?? 'Service',
                transportType: transportType,
                pricingModel: svc['pricing_model']?.toString() ?? 'combined',
                basePrice: double.tryParse(svc['base_price']?.toString() ?? ''),
                pricePerKm: double.tryParse(svc['price_per_km']?.toString() ?? ''),
                pricePerMinute: double.tryParse(svc['price_per_minute']?.toString() ?? ''),
                minimumFare: double.tryParse(svc['minimum_fare']?.toString() ?? ''),
                currency: svc['currency']?.toString() ?? 'TND',
              ));
            }
          }
        } else {
          // Flat list of services (from /m/services or /services)
          for (final svc in rawList) {
            if (svc is! Map<String, dynamic>) continue;
            if ((svc['is_active'] ?? true) == false) continue;
            final cat = svc['category'];
            final transportType = (cat is Map)
                ? (cat['transport_type']?.toString() ?? '')
                : (svc['transport_type']?.toString() ?? '');
            parsed.add(_ServiceData(
              id: svc['id']?.toString() ?? '',
              name: svc['name']?.toString() ?? 'Service',
              transportType: transportType,
              pricingModel: svc['pricing_model']?.toString() ?? 'combined',
              basePrice: double.tryParse(svc['base_price']?.toString() ?? ''),
              pricePerKm: double.tryParse(svc['price_per_km']?.toString() ?? ''),
              pricePerMinute: double.tryParse(svc['price_per_minute']?.toString() ?? ''),
              minimumFare: double.tryParse(svc['minimum_fare']?.toString() ?? ''),
              currency: svc['currency']?.toString() ?? 'TND',
            ));
          }
        }

        if (mounted) {
          setState(() {
            _services = parsed;
            if (_services.isNotEmpty) _selectedService = _services.first;
            _loadingServices = false;
          });
          _animCtrl.forward();
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement services: $e');
      if (mounted) {
        setState(() => _loadingServices = false);
        _animCtrl.forward();
      }
    }
  }

  // ─── Fare estimation ─────────────────────────────────────────────
  void _recalculateFare() {
    final svc = _selectedService;
    if (svc == null) return;

    double distKm = 0;
    double durMin = _isHourly
        ? _durationHours * 60.0
        : _durationMinutes.toDouble();

    if (_isDelivery) {
      final lat1 = double.tryParse(_latCtrl.text.trim());
      final lng1 = double.tryParse(_lngCtrl.text.trim());
      final lat2 = double.tryParse(_destLatCtrl.text.trim());
      final lng2 = double.tryParse(_destLngCtrl.text.trim());
      if (lat1 != null && lng1 != null && lat2 != null && lng2 != null) {
        distKm = FareCalculator.distanceKm(lat1, lng1, lat2, lng2);
        if (!_isHourly) {
          durMin = FareCalculator.estimatedDurationMin(distKm);
        }
      }
    }

    final fare = FareCalculator.calculateFare(
      pricingModel: svc.pricingModel,
      distanceKm: distKm,
      durationMin: durMin,
      basePrice: svc.basePrice ?? 0,
      pricePerKm: svc.pricePerKm ?? 0,
      pricePerMinute: svc.pricePerMinute ?? 0,
      minimumFare: svc.minimumFare ?? 0,
    );

    setState(() {
      _estimatedDistanceKm = distKm > 0 ? distKm : null;
      _estimatedFare = fare > 0 ? fare : null;
    });
  }

  // ─── Date / Time pickers ─────────────────────────────────────────
  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _orange),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: _orange),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    HapticFeedback.lightImpact();
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _orange),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: _orange),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ─── Submit ───────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showSnack('rdv.date'.tr());
      return;
    }
    if (_selectedTime == null) {
      _showSnack('rdv.time'.tr());
      return;
    }
    if (_selectedService == null) {
      _showSnack('services.title'.tr());
      return;
    }
    if (_isDelivery && _destAddressCtrl.text.trim().isEmpty) {
      _showSnack('Adresse de livraison requise');
      return;
    }
    if (_isDelivery && _cargoDescCtrl.text.trim().isEmpty) {
      _showSnack('Description du colis requise');
      return;
    }

    final scheduledAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final lat = double.tryParse(_latCtrl.text.trim()) ?? 0.0;
    final lng = double.tryParse(_lngCtrl.text.trim()) ?? 0.0;
    final durMin = _isHourly
        ? _durationHours * 60
        : _durationMinutes;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // Recalculate one last time to ensure estimates are up to date
      _recalculateFare();

      // Determine the fare to send: hourly → computed from hours, delivery → from distance estimate
      double? fareToSend;
      if (_isHourly && _selectedService != null) {
        final f = FareCalculator.calculateFare(
          pricingModel: _selectedService!.pricingModel,
          distanceKm: 0,
          durationMin: _durationHours * 60.0,
          basePrice: _selectedService!.basePrice ?? 0,
          pricePerKm: _selectedService!.pricePerKm ?? 0,
          pricePerMinute: _selectedService!.pricePerMinute ?? 0,
          minimumFare: _selectedService!.minimumFare ?? 0,
        );
        fareToSend = f > 0 ? f : null;
      } else if (_estimatedFare != null && _estimatedFare! > 0) {
        fareToSend = _estimatedFare;
      }

      final rdv = await RendezvousService.bookRendezvous(
        serviceId: _selectedService!.id,
        scheduledAt: scheduledAt,
        durationMinutes: durMin,
        details: _detailsCtrl.text.trim().isEmpty
            ? null
            : _detailsCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        latitude: lat,
        longitude: lng,
        destinationAddress: _isDelivery
            ? _destAddressCtrl.text.trim()
            : null,
        destinationLatitude: _isDelivery
            ? double.tryParse(_destLatCtrl.text.trim())
            : null,
        destinationLongitude: _isDelivery
            ? double.tryParse(_destLngCtrl.text.trim())
            : null,
        cargoDescription: _isDelivery
            ? _cargoDescCtrl.text.trim()
            : null,
        cargoWeightKg: _isDelivery ? _selectedCargoWeightKg : null,
        cargoSize: _isDelivery ? _selectedCargoSize : null,
        isFragile: _isDelivery ? _isFragile : null,
        estimatedFare: fareToSend,
        estimatedDistanceKm: _estimatedDistanceKm != null && _estimatedDistanceKm! > 0
            ? _estimatedDistanceKm
            : null,
      );
      if (mounted) _showSuccessDialog(rdv);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: _navy,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccessDialog(Rendezvous rdv) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: _cardBg,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: _green, size: 34),
              ),
              const SizedBox(height: 16),
              Text(
                'rdv.confirmed'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _confirmRow(
                rdv.isDelivery ? Icons.local_shipping_rounded : Icons.local_taxi_rounded,
                'services.title'.tr(),
                rdv.serviceName,
              ),
              const SizedBox(height: 10),
              _confirmRow(
                Icons.calendar_today_rounded,
                'rdv.date'.tr(),
                DateFormat('dd MMM yyyy à HH:mm', 'fr').format(rdv.scheduledAt),
              ),
              const SizedBox(height: 10),
              _confirmRow(Icons.location_on_rounded, 'rdv.address'.tr(), rdv.address),
              if (rdv.isDelivery && rdv.destinationAddress != null) ...[
                const SizedBox(height: 10),
                _confirmRow(
                  Icons.flag_rounded,
                  'Livraison',
                  rdv.destinationAddress!,
                ),
              ],
              if (rdv.estimatedFare != null) ...[
                const SizedBox(height: 10),
                _confirmRow(
                  Icons.payments_rounded,
                  'Tarif estimé',
                  FareCalculator.formatFare(
                    rdv.estimatedFare!,
                    _selectedService?.currency ?? 'TND',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_orange, _orangeLight]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _orange.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'common.confirm'.tr(),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _confirmRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _orange, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: _textSecondary, fontWeight: FontWeight.w500)),
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: _textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Column(
        children: [
          _buildHero(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: _loadingServices
                  ? _buildLoader()
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                            children: [
                              // ── Service selector ──────────────────
                              _sectionLabel('services.title'.tr(), Icons.apps_rounded),
                              const SizedBox(height: 10),
                              _serviceSelector(),

                              // ── Pricing card (always shown when service is selected)
                              if (_selectedService != null) ...[
                                const SizedBox(height: 12),
                                _ServicePricingCard(service: _selectedService!),
                              ],

                              const SizedBox(height: 22),

                              // ── Date & Time ───────────────────────
                              _sectionLabel('rdv.date'.tr(), Icons.event_rounded),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(child: _dateTile()),
                                const SizedBox(width: 12),
                                Expanded(child: _timeTile()),
                              ]),

                              const SizedBox(height: 22),

                              // ── Duration / Hours ──────────────────
                              if (_isHourly) ...[
                                _sectionLabel('Durée de la prestation', Icons.timer_rounded),
                                const SizedBox(height: 10),
                                _hourSelector(),
                              ] else if (!_isDelivery) ...[
                                _sectionLabel('rdv.details'.tr(), Icons.timer_rounded),
                                const SizedBox(height: 10),
                                _durationSelector(),
                              ],

                              const SizedBox(height: 22),

                              // ── Address section ───────────────────
                              _sectionLabel(
                                _isDelivery ? 'Adresse de collecte' : 'rdv.address'.tr(),
                                Icons.location_on_rounded,
                              ),
                              const SizedBox(height: 10),
                              _addressField(
                                _addressCtrl,
                                _isDelivery ? 'Adresse de collecte (départ)' : 'rdv.address'.tr(),
                                Icons.location_on_rounded,
                                required: true,
                                onChanged: (_) => _recalculateFare(),
                              ),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: _coordField(
                                  _latCtrl, 'Latitude', '36.8065',
                                  onChanged: (_) => _recalculateFare(),
                                )),
                                const SizedBox(width: 12),
                                Expanded(child: _coordField(
                                  _lngCtrl, 'Longitude', '10.1815',
                                  onChanged: (_) => _recalculateFare(),
                                )),
                              ]),

                              // ── Delivery destination ──────────────
                              if (_isDelivery) ...[
                                const SizedBox(height: 22),
                                _sectionLabel('Adresse de livraison', Icons.flag_rounded),
                                const SizedBox(height: 10),
                                _addressField(
                                  _destAddressCtrl,
                                  'Adresse de livraison (destination)',
                                  Icons.flag_rounded,
                                  required: true,
                                  onChanged: (_) => _recalculateFare(),
                                ),
                                const SizedBox(height: 12),
                                Row(children: [
                                  Expanded(child: _coordField(
                                    _destLatCtrl, 'Latitude dest.', '36.9',
                                    onChanged: (_) => _recalculateFare(),
                                  )),
                                  const SizedBox(width: 12),
                                  Expanded(child: _coordField(
                                    _destLngCtrl, 'Longitude dest.', '10.3',
                                    onChanged: (_) => _recalculateFare(),
                                  )),
                                ]),

                                // ── Fare estimate banner ──────────────
                                if (_estimatedFare != null) ...[
                                  const SizedBox(height: 12),
                                  _FareEstimateBanner(
                                    distanceKm: _estimatedDistanceKm,
                                    fare: _estimatedFare!,
                                    currency: _selectedService?.currency ?? 'TND',
                                  ),
                                ],

                                const SizedBox(height: 22),

                                // ── Cargo details ─────────────────────
                                _sectionLabel('Détails du colis / cargo', Icons.inventory_2_rounded),
                                const SizedBox(height: 10),
                                _addressField(
                                  _cargoDescCtrl,
                                  'Description de la marchandise',
                                  Icons.description_rounded,
                                  required: true,
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                _weightSelector(),
                                const SizedBox(height: 12),
                                _cargoSizeSelector(),
                                const SizedBox(height: 12),
                                _fragileToggle(),
                              ],

                              // ── Fare estimate for hourly (no address needed)
                              if (_isHourly && _selectedService != null) ...[
                                const SizedBox(height: 12),
                                _FareEstimateBanner(
                                  distanceKm: null,
                                  fare: FareCalculator.calculateFare(
                                    pricingModel: _selectedService!.pricingModel,
                                    distanceKm: 0,
                                    durationMin: _durationHours * 60.0,
                                    basePrice: _selectedService!.basePrice ?? 0,
                                    pricePerKm: _selectedService!.pricePerKm ?? 0,
                                    pricePerMinute: _selectedService!.pricePerMinute ?? 0,
                                    minimumFare: _selectedService!.minimumFare ?? 0,
                                  ),
                                  currency: _selectedService!.currency,
                                  label: 'Tarif estimé pour $_durationHours h',
                                ),
                              ],

                              const SizedBox(height: 22),

                              // ── Notes ─────────────────────────────
                              _sectionLabel('rdv.details'.tr(), Icons.notes_rounded),
                              const SizedBox(height: 10),
                              _addressField(
                                _detailsCtrl,
                                'rdv.details'.tr(),
                                Icons.notes_rounded,
                                maxLines: 3,
                              ),

                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFEF4444).withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline_rounded,
                                          color: Color(0xFFEF4444), size: 18),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            color: const Color(0xFFEF4444),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              _submitButton(),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hero ─────────────────────────────────────────────────────────

  Widget _buildHero() {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 150,
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                    width: 28,
                  ),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -30,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.04),
                    width: 20,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_orange, _orangeLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _orange.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isDelivery
                              ? Icons.local_shipping_rounded
                              : Icons.event_available_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isDelivery
                                ? 'Commander une livraison'
                                : 'rdv.book'.tr(),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _isDelivery
                                ? 'Remplissez les détails de votre envoi'
                                : 'rdv.title'.tr(),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: _orange,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'common.loading'.tr(),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section label ────────────────────────────────────────────────

  Widget _sectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _orange),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textSecondary,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  // ─── Service selector ────────────────────────────────────────────

  Widget _serviceSelector() {
    if (_services.isEmpty) {
      return _card(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _textSecondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.apps_rounded, color: _textSecondary, size: 20),
            ),
            const SizedBox(width: 12),
            Text('services.no_services'.tr(),
                style: GoogleFonts.poppins(fontSize: 14, color: _textSecondary)),
          ],
        ),
      );
    }

    final svc = _selectedService;
    return GestureDetector(
      onTap: _showServicePicker,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _orange.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _orange.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_orange, _orangeLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _orange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                serviceIconFor(svc?.transportType ?? ''),
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: svc == null
                  ? Text('Sélectionner un service',
                      style: GoogleFonts.poppins(fontSize: 14, color: _textSecondary))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          svc.name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _servicePriceLine(svc),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _navy.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Changer',
                      style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _navy)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: _navy, size: 15),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _servicePriceLine(_ServiceData svc) {
    final c = svc.currency;
    switch (svc.pricingModel) {
      case 'fixed':
        return svc.basePrice != null
            ? 'Prix fixe : ${svc.basePrice!.toStringAsFixed(3)} $c'
            : 'Prix fixe';
      case 'distance':
        final base = (svc.basePrice != null && svc.basePrice! > 0)
            ? '${svc.basePrice!.toStringAsFixed(3)} $c + '
            : '';
        final km = svc.pricePerKm != null
            ? '${svc.pricePerKm!.toStringAsFixed(3)} $c/km'
            : '';
        return '$base$km';
      case 'hourly':
        return svc.pricePerMinute != null
            ? '${(svc.pricePerMinute! * 60).toStringAsFixed(3)} $c / heure'
            : 'Prix horaire';
      default:
        final base = svc.basePrice != null
            ? '${svc.basePrice!.toStringAsFixed(3)} $c'
            : '';
        final km = svc.pricePerKm != null
            ? ' + ${svc.pricePerKm!.toStringAsFixed(3)}/km'
            : '';
        return '$base$km';
    }
  }

  void _showServicePicker() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.apps_rounded, color: _orange, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Choisir un service',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _border.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 16, color: _textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: _border),
              // List
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: _services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final svc = _services[i];
                    final isSelected = _selectedService?.id == svc.id;
                    return _ServicePickerTile(
                      service: svc,
                      isSelected: isSelected,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedService = svc;
                          _estimatedFare = null;
                          _estimatedDistanceKm = null;
                        });
                        _recalculateFare();
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Date / Time tiles ───────────────────────────────────────────

  Widget _dateTile() {
    final hasDate = _selectedDate != null;
    return GestureDetector(
      onTap: _pickDate,
      child: _card(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: hasDate ? _orange.withOpacity(0.12) : _border,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 15,
                color: hasDate ? _orange : _textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasDate
                    ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                    : 'rdv.date'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
                  color: hasDate ? _textPrimary : _textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeTile() {
    final hasTime = _selectedTime != null;
    return GestureDetector(
      onTap: _pickTime,
      child: _card(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: hasTime ? _orange.withOpacity(0.12) : _border,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.access_time_rounded,
                size: 15,
                color: hasTime ? _orange : _textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              hasTime ? _selectedTime!.format(context) : 'rdv.time'.tr(),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: hasTime ? FontWeight.w600 : FontWeight.normal,
                color: hasTime ? _textPrimary : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Duration selector (minutes — for standard RDV) ───────────────

  Widget _durationSelector() {
    return Row(
      children: _durations.map((d) {
        final selected = _durationMinutes == d;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: d != _durations.last ? 10 : 0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _durationMinutes = d);
                _recalculateFare();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? _navy : _cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? _navy : _border,
                    width: selected ? 0 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$d',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : _textPrimary,
                      ),
                    ),
                    Text(
                      'min',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: selected
                            ? Colors.white.withOpacity(0.7)
                            : _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Hour selector (for hourly services) ─────────────────────────

  Widget _hourSelector() {
    return Row(
      children: _hourOptions.map((h) {
        final selected = _durationHours == h;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: h != _hourOptions.last ? 8 : 0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _durationHours = h);
                _recalculateFare();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? _navy : _cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? _navy : _border,
                    width: selected ? 0 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$h',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : _textPrimary,
                      ),
                    ),
                    Text(
                      'h',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: selected
                            ? Colors.white.withOpacity(0.7)
                            : _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Cargo weight selector ────────────────────────────────────────

  Widget _weightSelector() {
    final labels = ['< 5 kg', '5-20 kg', '20-100 kg', '100-500 kg', '500+ kg'];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Poids estimé',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_weightOptions.length, (i) {
              final w = _weightOptions[i];
              final selected = _selectedCargoWeightKg == w;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCargoWeightKg = w);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _navy : _cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? _navy : _border),
                  ),
                  child: Text(
                    labels[i],
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : _textPrimary,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── Cargo size selector ──────────────────────────────────────────

  Widget _cargoSizeSelector() {
    final labels = {
      'small': 'Petit',
      'medium': 'Moyen',
      'large': 'Grand',
      'extra_large': 'Très grand',
    };
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Taille du colis',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: _textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: _cargoSizes.map((size) {
              final selected = _selectedCargoSize == size;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: size != _cargoSizes.last ? 8 : 0),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCargoSize = size);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? _orange : _cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: selected ? _orange : _border),
                      ),
                      child: Text(
                        labels[size]!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : _textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Fragile toggle ───────────────────────────────────────────────

  Widget _fragileToggle() {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _isFragile
                  ? const Color(0xFFEF4444).withOpacity(0.1)
                  : _border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: _isFragile
                  ? const Color(0xFFEF4444)
                  : _textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Colis fragile',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary)),
                Text('Manipulation avec précaution',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: _textSecondary)),
              ],
            ),
          ),
          Switch(
            value: _isFragile,
            activeColor: _orange,
            onChanged: (v) => setState(() => _isFragile = v),
          ),
        ],
      ),
    );
  }

  // ─── Text fields ─────────────────────────────────────────────────

  Widget _addressField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool required = false,
    int maxLines = 2,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: ctrl,
      style: GoogleFonts.poppins(fontSize: 14, color: _textPrimary),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? hint : null
          : null,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: _inputDeco(hint, icon),
    );
  }

  Widget _coordField(
    TextEditingController ctrl,
    String label,
    String hint, {
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: ctrl,
      style: GoogleFonts.poppins(fontSize: 13, color: _textPrimary),
      keyboardType:
          const TextInputType.numberWithOptions(signed: true, decimal: true),
      onChanged: onChanged,
      decoration: _inputDeco(label, Icons.my_location_rounded)
          .copyWith(hintText: hint),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _orange, size: 16),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      filled: true,
      fillColor: _cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _orange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  // ─── Submit button ───────────────────────────────────────────────

  Widget _submitButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: _isSubmitting
            ? null
            : const LinearGradient(
                colors: [_orange, _orangeLight],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        color: _isSubmitting ? _border : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isSubmitting
            ? []
            : [
                BoxShadow(
                  color: _orange.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          minimumSize: const Size(double.infinity, 54),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'common.loading'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textSecondary,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'common.confirm'.tr(),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── Card wrapper ────────────────────────────────────────────────

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}

// ─── Service Pricing Card ─────────────────────────────────────────────────────

class _ServicePricingCard extends StatelessWidget {
  final _ServiceData service;

  const _ServicePricingCard({required this.service});

  static const _orange = Color(0xFFFF6B35);
  static const _navy = Color(0xFF0F172A);
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF9BA3B4);

  @override
  Widget build(BuildContext context) {
    final currency = service.currency;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _navy.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  FareCalculator.pricingModelBadge(service.pricingModel),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _orange,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  FareCalculator.pricingModelLabel(service.pricingModel),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(color: Color(0xFFE8ECF0), height: 1),
          const SizedBox(height: 10),

          // Pricing rows — shown only when value is non-zero
          if (service.basePrice != null && service.basePrice! > 0)
            _priceRow(
              'Prix de base',
              '${service.basePrice!.toStringAsFixed(3)} $currency',
            ),
          if (service.pricePerKm != null && service.pricePerKm! > 0) ...[
            const SizedBox(height: 6),
            _priceRow(
              'Par kilomètre',
              '${service.pricePerKm!.toStringAsFixed(3)} $currency/km',
              highlight: true,
            ),
          ],
          if (service.pricePerMinute != null &&
              service.pricePerMinute! > 0 &&
              service.pricingModel != 'distance') ...[
            const SizedBox(height: 6),
            _priceRow(
              service.pricingModel == 'hourly'
                  ? 'Par heure'
                  : 'Par minute',
              service.pricingModel == 'hourly'
                  ? '${(service.pricePerMinute! * 60).toStringAsFixed(3)} $currency/h'
                  : '${service.pricePerMinute!.toStringAsFixed(3)} $currency/min',
            ),
          ],
          if (service.minimumFare != null && service.minimumFare! > 0) ...[
            const SizedBox(height: 6),
            _priceRow(
              'Minimum garanti',
              '${service.minimumFare!.toStringAsFixed(3)} $currency',
              color: _orange,
            ),
          ],

          // Example calculation for combined/distance
          if ((service.pricingModel == 'combined' ||
                  service.pricingModel == 'distance') &&
              service.pricePerKm != null &&
              service.pricePerKm! > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _orange.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 13, color: _orange),
                  const SizedBox(width: 6),
                  Text(
                    'Exemple 10 km ≈ ${FareCalculator.formatFare(
                      FareCalculator.calculateFare(
                        pricingModel: service.pricingModel,
                        distanceKm: 10,
                        durationMin: FareCalculator.estimatedDurationMin(10),
                        basePrice: service.basePrice ?? 0,
                        pricePerKm: service.pricePerKm ?? 0,
                        pricePerMinute: service.pricePerMinute ?? 0,
                        minimumFare: service.minimumFare ?? 0,
                      ),
                      currency,
                    )}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: _orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Fixed price note
          if (service.isFixed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 13, color: Color(0xFF22C55E)),
                  const SizedBox(width: 6),
                  Text(
                    'Prix forfaitaire — pas de surprises',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF22C55E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value,
      {bool highlight = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: _textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            color: color ?? _textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Fare Estimate Banner ─────────────────────────────────────────────────────

class _FareEstimateBanner extends StatelessWidget {
  final double? distanceKm;
  final double fare;
  final String currency;
  final String? label;

  const _FareEstimateBanner({
    required this.distanceKm,
    required this.fare,
    required this.currency,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.payments_rounded,
                color: Color(0xFFFF6B35), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label ??
                      (distanceKm != null
                          ? 'Distance estimée : ${distanceKm!.toStringAsFixed(1)} km'
                          : 'Tarif estimé'),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                Text(
                  FareCalculator.formatFare(fare, currency),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Estimatif',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Service icon helper ──────────────────────────────────────────────────────

IconData serviceIconFor(String transportType) {
  final t = transportType.toLowerCase();
  if (t.contains('ambulance')) return Icons.emergency_rounded;
  if (t.contains('helicoptere')) return Icons.flight_rounded;
  if (t.contains('aeroport')) return Icons.flight_land_rounded;
  if (t.contains('yacht') || t.contains('vedette') || t.contains('nautique') || t.contains('ferry')) {
    return Icons.directions_boat_rounded;
  }
  if (t.contains('tracteur') || t.contains('agricole')) return Icons.agriculture_rounded;
  if (t.contains('chariot') || t.contains('elevateur')) return Icons.warehouse_rounded;
  if (t.contains('engins')) return Icons.precision_manufacturing_rounded;
  if (t.contains('grue')) return Icons.construction_rounded;
  if (t.contains('benne')) return Icons.construction_rounded;
  if (t.contains('frigo')) return Icons.ac_unit_rounded;
  if (t.contains('citerne')) return Icons.water_drop_rounded;
  if (t.contains('demenagement')) return Icons.move_to_inbox_rounded;
  if (t.contains('toupie')) return Icons.rotate_right_rounded;
  if (t.contains('semi') || t.contains('remorque') || t.contains('camion_20') || t.contains('camion_10')) {
    return Icons.local_shipping_rounded;
  }
  if (t.contains('camion') || t.contains('porteur') || t.contains('fourgon') || t.contains('plateau')) {
    return Icons.local_shipping_rounded;
  }
  if (t.contains('camionnette') || t.contains('pickup') || t.contains('van')) {
    return Icons.airport_shuttle_rounded;
  }
  if (t.contains('bus') || t.contains('minibus') || t.contains('scolaire') || t.contains('charter')) {
    return Icons.directions_bus_rounded;
  }
  if (t.contains('velo')) return Icons.pedal_bike_rounded;
  if (t.contains('tuk') || t.contains('tricycle')) return Icons.electric_rickshaw_rounded;
  if (t.contains('moto')) return Icons.two_wheeler_rounded;
  if (t.contains('colis') || t.contains('livraison') || t.contains('coursier')) {
    return Icons.inventory_2_rounded;
  }
  if (t.contains('covoiturage')) return Icons.people_alt_rounded;
  if (t.contains('luxe') || t.contains('premium') || t.contains('vtc')) {
    return Icons.directions_car_filled_rounded;
  }
  if (t.contains('taxi') || t.contains('voiture')) return Icons.local_taxi_rounded;
  return Icons.directions_car_rounded;
}

// ─── Service Picker Tile ──────────────────────────────────────────────────────

class _ServicePickerTile extends StatelessWidget {
  final _ServiceData service;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServicePickerTile({
    required this.service,
    required this.isSelected,
    required this.onTap,
  });

  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFF8C5A);
  static const _navy = Color(0xFF0F172A);
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF9BA3B4);
  static const _border = Color(0xFFE8ECF0);

  String get _priceLine {
    final c = service.currency;
    switch (service.pricingModel) {
      case 'fixed':
        return service.basePrice != null
            ? 'Prix fixe · ${service.basePrice!.toStringAsFixed(3)} $c'
            : 'Prix fixe';
      case 'distance':
        final base = (service.basePrice != null && service.basePrice! > 0)
            ? '${service.basePrice!.toStringAsFixed(3)} $c + '
            : '';
        final km = service.pricePerKm != null
            ? '${service.pricePerKm!.toStringAsFixed(3)} $c/km'
            : '';
        return '$base$km';
      case 'hourly':
        return service.pricePerMinute != null
            ? '${(service.pricePerMinute! * 60).toStringAsFixed(3)} $c / heure'
            : 'Prix horaire';
      default:
        final base = service.basePrice != null
            ? '${service.basePrice!.toStringAsFixed(3)} $c'
            : '';
        final km = service.pricePerKm != null
            ? ' + ${service.pricePerKm!.toStringAsFixed(3)}/km'
            : '';
        return '$base$km';
    }
  }

  String get _modelLabel {
    switch (service.pricingModel) {
      case 'fixed':    return 'Fixe';
      case 'distance': return 'Au km';
      case 'hourly':   return 'À l\'h';
      default:         return 'Combiné';
    }
  }

  Color get _modelColor {
    switch (service.pricingModel) {
      case 'fixed':    return const Color(0xFF22C55E);
      case 'distance': return const Color(0xFF3B82F6);
      case 'hourly':   return const Color(0xFF8B5CF6);
      default:         return _orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = serviceIconFor(service.transportType);
    final isDelivery = service.isDelivery;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _orange.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _orange : _border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _orange.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [_orange, _orangeLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : _textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service.name,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? _navy : _textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDelivery) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _navy.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'LIVR.',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _priceLine,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isSelected ? _orange : _textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Pricing model badge + check
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _modelColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _modelLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _modelColor,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(height: 6),
                  const Icon(Icons.check_circle_rounded, color: _orange, size: 18),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
