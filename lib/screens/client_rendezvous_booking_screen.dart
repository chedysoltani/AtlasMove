import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/network/http_client.dart';
import '../models/rendezvous_models.dart';
import '../services/rendezvous_service.dart';

class _ServiceItem {
  final String id;
  final String name;
  const _ServiceItem({required this.id, required this.name});
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
  static const _navyLight = Color(0xFF1E293B);
  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFF8C5A);
  static const _bg = Color(0xFFF8F9FB);
  static const _cardBg = Colors.white;
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF9BA3B4);
  static const _border = Color(0xFFE8ECF0);

  // ─── State ───────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  List<_ServiceItem> _services = [];
  _ServiceItem? _selectedService;
  bool _loadingServices = true;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int _durationMinutes = 60;

  bool _isSubmitting = false;
  String? _error;

  final List<int> _durations = [30, 60, 90, 120];

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

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

    _fetchServices();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _addressCtrl.dispose();
    _detailsCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchServices() async {
    try {
      final response = await HttpClient.get('/services');
      if (response.isSuccess) {
        List<dynamic> rawList = [];
        final json = response.json;
        final outer = json['data'];
        if (outer is List) {
          rawList = outer;
        } else if (outer is Map<String, dynamic>) {
          final inner = outer['data'];
          if (inner is List) rawList = inner;
        }
        if (mounted) {
          setState(() {
            _services = rawList
                .where((j) => j is Map && (j['is_active'] ?? true) == true)
                .map((j) => _ServiceItem(
                      id: j['id']?.toString() ?? '',
                      name: j['name']?.toString() ?? 'Service',
                    ))
                .toList();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showSnack('Veuillez sélectionner une date');
      return;
    }
    if (_selectedTime == null) {
      _showSnack('Veuillez sélectionner une heure');
      return;
    }
    if (_selectedService == null) {
      _showSnack('Veuillez sélectionner un service');
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

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final rdv = await RendezvousService.bookRendezvous(
        serviceId: _selectedService!.id,
        scheduledAt: scheduledAt,
        durationMinutes: _durationMinutes,
        details: _detailsCtrl.text.trim().isEmpty ? null : _detailsCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        latitude: lat,
        longitude: lng,
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
                  color: const Color(0xFF22C55E).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 34),
              ),
              const SizedBox(height: 16),
              Text(
                'Réservation confirmée !',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _confirmRow(Icons.local_taxi_rounded, 'Service', rdv.serviceName),
              const SizedBox(height: 10),
              _confirmRow(
                Icons.calendar_today_rounded,
                'Date',
                DateFormat('dd MMM yyyy à HH:mm', 'fr').format(rdv.scheduledAt),
              ),
              const SizedBox(height: 10),
              _confirmRow(Icons.timer_rounded, 'Durée', '${rdv.durationMinutes} min'),
              const SizedBox(height: 10),
              _confirmRow(Icons.location_on_rounded, 'Adresse', rdv.address),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_orange, _orangeLight],
                    ),
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
                      'Parfait !',
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
                              _sectionLabel('Service', Icons.local_taxi_rounded),
                              const SizedBox(height: 10),
                              _serviceDropdown(),
                              const SizedBox(height: 22),
                              _sectionLabel('Date & Heure', Icons.event_rounded),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(child: _dateTile()),
                                const SizedBox(width: 12),
                                Expanded(child: _timeTile()),
                              ]),
                              const SizedBox(height: 22),
                              _sectionLabel('Durée', Icons.timer_rounded),
                              const SizedBox(height: 10),
                              _durationSelector(),
                              const SizedBox(height: 22),
                              _sectionLabel('Adresse du rendez-vous', Icons.location_on_rounded),
                              const SizedBox(height: 10),
                              _addressField(),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(
                                  child: _coordField(_latCtrl, 'Latitude', '36.8065'),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _coordField(_lngCtrl, 'Longitude', '10.1815'),
                                ),
                              ]),
                              const SizedBox(height: 22),
                              _sectionLabel('Instructions (optionnel)', Icons.notes_rounded),
                              const SizedBox(height: 10),
                              _detailsField(),
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

  Widget _buildHero() {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 150,
        child: Stack(
          children: [
            // Decorative ring
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
            // Content
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
                        child: const Icon(
                          Icons.event_available_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nouveau Rendez-vous',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Réservez votre course à l\'avance',
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
            'Chargement des services...',
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

  // ─── Service dropdown ────────────────────────────────────────────

  Widget _serviceDropdown() {
    if (_services.isEmpty) {
      return _card(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _textSecondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_taxi_rounded, color: _textSecondary, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Aucun service disponible',
              style: GoogleFonts.poppins(fontSize: 14, color: _textSecondary),
            ),
          ],
        ),
      );
    }

    return _card(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_taxi_rounded, color: _orange, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<_ServiceItem>(
              isExpanded: true,
              underline: const SizedBox(),
              value: _selectedService,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textSecondary),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
              items: _services
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedService = v),
            ),
          ),
        ],
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
                    : 'Date',
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
              hasTime ? _selectedTime!.format(context) : 'Heure',
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

  // ─── Duration selector ───────────────────────────────────────────

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
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _navy.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
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

  // ─── Text fields ─────────────────────────────────────────────────

  Widget _addressField() {
    return TextFormField(
      controller: _addressCtrl,
      style: GoogleFonts.poppins(fontSize: 14, color: _textPrimary),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Adresse requise' : null,
      maxLines: 2,
      decoration: _inputDeco('Adresse complète', Icons.location_on_rounded),
    );
  }

  Widget _coordField(TextEditingController ctrl, String label, String hint) {
    return TextFormField(
      controller: ctrl,
      style: GoogleFonts.poppins(fontSize: 13, color: _textPrimary),
      keyboardType:
          const TextInputType.numberWithOptions(signed: true, decimal: true),
      decoration: _inputDeco(label, Icons.my_location_rounded)
          .copyWith(hintText: hint),
    );
  }

  Widget _detailsField() {
    return TextFormField(
      controller: _detailsCtrl,
      style: GoogleFonts.poppins(fontSize: 14, color: _textPrimary),
      maxLines: 3,
      decoration: _inputDeco(
        'Ex: Articles fragiles, appelez à l\'arrivée…',
        Icons.notes_rounded,
      ),
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
                    'Envoi en cours...',
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
                    'Confirmer la réservation',
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
