import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/network/http_client.dart';
import '../models/rendezvous_models.dart';
import '../services/rendezvous_service.dart';
import '../utils/app_theme.dart';

// Simple service item used in the dropdown
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
    extends State<ClientRendezvousBookingScreen> {
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

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  @override
  void dispose() {
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
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement services: $e');
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primaryColor),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      _showError('Veuillez sélectionner une date');
      return;
    }
    if (_selectedTime == null) {
      _showError('Veuillez sélectionner une heure');
      return;
    }
    if (_selectedService == null) {
      _showError('Veuillez sélectionner un service');
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
        details: _detailsCtrl.text.trim().isEmpty
            ? null
            : _detailsCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        latitude: lat,
        longitude: lng,
      );

      if (mounted) {
        _showSuccessDialog(rdv);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  void _showSuccessDialog(Rendezvous rdv) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: AppTheme.successColor, size: 28),
          SizedBox(width: 10),
          Text('Réservation confirmée'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service : ${rdv.serviceName}'),
            const SizedBox(height: 6),
            Text(
              'Date : ${DateFormat('dd MMM yyyy à HH:mm', 'fr').format(rdv.scheduledAt)}',
            ),
            const SizedBox(height: 6),
            Text('Durée : ${rdv.durationMinutes} min'),
            const SizedBox(height: 6),
            Text('Adresse : ${rdv.address}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Nouveau Rendez-vous'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loadingServices
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _sectionLabel('Service'),
                  const SizedBox(height: 8),
                  _serviceDropdown(),
                  const SizedBox(height: 20),
                  _sectionLabel('Date & Heure'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _dateTile()),
                    const SizedBox(width: 12),
                    Expanded(child: _timeTile()),
                  ]),
                  const SizedBox(height: 20),
                  _sectionLabel('Durée'),
                  const SizedBox(height: 8),
                  _durationSelector(),
                  const SizedBox(height: 20),
                  _sectionLabel('Adresse du rendez-vous'),
                  const SizedBox(height: 8),
                  _addressField(),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _coordField(_latCtrl, 'Latitude', '36.8065')),
                    const SizedBox(width: 12),
                    Expanded(child: _coordField(_lngCtrl, 'Longitude', '10.1815')),
                  ]),
                  const SizedBox(height: 20),
                  _sectionLabel('Instructions spéciales (optionnel)'),
                  const SizedBox(height: 8),
                  _detailsField(),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Confirmer la réservation',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      );

  Widget _serviceDropdown() {
    if (_services.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text(
          'Aucun service disponible',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButton<_ServiceItem>(
        isExpanded: true,
        underline: const SizedBox(),
        value: _selectedService,
        items: _services
            .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
            .toList(),
        onChanged: (v) => setState(() => _selectedService = v),
      ),
    );
  }

  Widget _dateTile() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedDate != null
                  ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                  : 'Choisir la date',
              style: TextStyle(
                color: _selectedDate != null
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _timeTile() {
    return GestureDetector(
      onTap: _pickTime,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(children: [
          const Icon(Icons.access_time, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            _selectedTime != null
                ? _selectedTime!.format(context)
                : 'Choisir l\'heure',
            style: TextStyle(
              color: _selectedTime != null
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _durationSelector() {
    return Row(
      children: _durations.map((d) {
        final selected = _durationMinutes == d;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => setState(() => _durationMinutes = d),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryColor
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppTheme.primaryColor
                      : Colors.grey.shade200,
                ),
              ),
              child: Text(
                '${d}min',
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _addressField() {
    return TextFormField(
      controller: _addressCtrl,
      decoration: _inputDeco('Adresse complète', Icons.location_on),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Adresse requise' : null,
      maxLines: 2,
    );
  }

  Widget _coordField(
      TextEditingController ctrl, String label, String hint) {
    return TextFormField(
      controller: ctrl,
      decoration: _inputDeco(label, Icons.my_location).copyWith(hintText: hint),
      keyboardType:
          const TextInputType.numberWithOptions(signed: true, decimal: true),
    );
  }

  Widget _detailsField() {
    return TextFormField(
      controller: _detailsCtrl,
      decoration: _inputDeco(
        'Ex: Articles fragiles, appelez à l\'arrivée…',
        Icons.notes,
      ),
      maxLines: 3,
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: AppTheme.primaryColor, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
    );
  }
}
