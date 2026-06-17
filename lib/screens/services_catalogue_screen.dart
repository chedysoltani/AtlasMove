import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/service_models.dart';
import '../services/service_api.dart';
import '../services/location_service.dart';
import '../providers/services_provider.dart';
import '../core/storage/token_storage.dart';
import '../utils/app_theme.dart';

class ServicesCatalogueScreen extends ConsumerStatefulWidget {
  const ServicesCatalogueScreen({super.key});

  @override
  ConsumerState<ServicesCatalogueScreen> createState() =>
      _ServicesCatalogueScreenState();
}

class _ServicesCatalogueScreenState
    extends ConsumerState<ServicesCatalogueScreen> {
  static const _orange = Color(0xFFFF6B35);
  static const _bg = Color(0xFFF8F8F8);
  bool _initialized = false;
  final Set<int> _expanded = {};

  Future<void> _fetchWithGps(CatalogueNotifier notifier) async {
    try {
      final pos = await LocationService().getCurrentPosition();
      notifier.fetchCatalogue(latitude: pos?.latitude, longitude: pos?.longitude);
    } catch (_) {
      notifier.fetchCatalogue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(catalogueProvider);
    final notifier = ref.read(catalogueProvider.notifier);

    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchWithGps(notifier));
      _initialized = true;
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(notifier),
      body: catalogueAsync.when(
        loading: _loadingState,
        error: (e, _) => _errorState(e.toString(), notifier),
        data: (catalogue) => _buildCatalogue(context, catalogue),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  AppBar _buildAppBar(CatalogueNotifier notifier) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: Text(
        'services.catalogue'.tr(),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _fetchWithGps(notifier);
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.refresh_rounded, color: _orange, size: 20),
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(context, '/services_assignments');
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.history_rounded, color: _orange, size: 20),
          ),
        ),
      ],
    );
  }

  // ─── Catalogue list ───────────────────────────────────────────────────────

  Widget _buildCatalogue(BuildContext context, ServiceCatalogue catalogue) {
    final categories = catalogue.data;

    if (categories.isEmpty) {
      return _emptyState();
    }

    return RefreshIndicator(
      color: _orange,
      onRefresh: () => _fetchWithGps(ref.read(catalogueProvider.notifier)),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: categories.length,
        itemBuilder: (context, index) =>
            _categoryCard(context, categories[index], index),
      ),
    );
  }

  Widget _categoryCard(
    BuildContext context,
    ServiceCategoryWithServices category,
    int index,
  ) {
    final isOpen = _expanded.contains(index);
    final services = category.services;
    final icon = _categoryIcon(category.name);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          if (isOpen) {
            _expanded.remove(index);
          } else {
            _expanded.add(index);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // ─ Header row ─
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: _orange, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${services.length} service${services.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isOpen ? _orange : Colors.grey.shade400,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            // ─ Services list ─
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: isOpen
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: services.isEmpty
                  ? _emptyCategory()
                  : Column(
                      children: [
                        Container(height: 1, color: Colors.grey.shade50),
                        ...services.asMap().entries.map((e) =>
                            _serviceItem(context, e.value, e.key, services.length)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceItem(
      BuildContext context, Service service, int index, int total) {
    final isLast = index == total - 1;
    final hasImage = service.imageUrl != null && service.imageUrl!.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ─ Image / fallback icon ─
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasImage
                    ? Image.network(
                        service.imageUrl!,
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _serviceFallbackIcon(service),
                      )
                    : _serviceFallbackIcon(service),
              ),
              const SizedBox(width: 12),

              // ─ Info ─
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    if (service.basePrice != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${service.basePrice!.toStringAsFixed(2)} ${service.currency ?? 'EUR'}'
                        '${service.pricePerKm != null ? ' + ${service.pricePerKm!.toStringAsFixed(2)} ${service.currency ?? 'EUR'}/km' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _smallBadge(_pricingLabel(service.pricingModel),
                            const Color(0xFF3B82F6)),
                        if (service.requiresDocument) ...[
                          const SizedBox(width: 5),
                          _smallBadge('Doc', Colors.orange.shade700),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ─ Accept button + badge ─
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _smallBadge(service.transportType, _orange),
                  const SizedBox(height: 8),
                  _miniAcceptBtn(
                    active: service.isActive,
                    onTap: () => _showAssignmentBottomSheet(context, service),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 1, color: Colors.grey.shade100),
          ),
      ],
    );
  }

  Widget _serviceFallbackIcon(Service service) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: service.isActive
            ? _orange.withOpacity(0.08)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _categoryIcon(service.name),
        size: 28,
        color: service.isActive ? _orange : Colors.grey.shade400,
      ),
    );
  }

  String _pricingLabel(String model) {
    switch (model.toLowerCase()) {
      case 'combined': return 'Combiné';
      case 'per_km': return '/km';
      case 'fixed': return 'Fixe';
      case 'hourly': return '/heure';
      default: return model;
    }
  }

  Widget _smallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _miniAcceptBtn({required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: active
          ? () {
              HapticFeedback.lightImpact();
              onTap();
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF22C55E) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'services.join'.tr(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _emptyCategory() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Text(
        'services.no_category_services'.tr(),
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade400,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  // ─── States ───────────────────────────────────────────────────────────────

  Widget _loadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: _orange),
          const SizedBox(height: 16),
          Text(
            'services.loading_catalogue'.tr(),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.category_outlined, size: 40, color: _orange),
          ),
          const SizedBox(height: 16),
          Text(
            'services.catalogue_empty'.tr(),
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(
            'services.no_categories'.tr(),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String error, CatalogueNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.error_outline_rounded,
                  size: 36, color: Colors.red.shade400),
            ),
            const SizedBox(height: 14),
            Text(
              'services.load_error'.tr(),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => notifier.fetchCatalogue(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'common.retry'.tr(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Icon mapping ─────────────────────────────────────────────────────────

  IconData _categoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('taxi') || n.contains('course')) return Icons.local_taxi_rounded;
    if (n.contains('vtc') || n.contains('chauffeur') || n.contains('premium')) return Icons.star_rounded;
    if (n.contains('moto')) return Icons.motorcycle_rounded;
    if (n.contains('livraison') || n.contains('coursier') || n.contains('delivery')) return Icons.delivery_dining_rounded;
    if (n.contains('van') || n.contains('camionnette')) return Icons.airport_shuttle_rounded;
    if (n.contains('bus') || n.contains('minibus') || n.contains('louage')) return Icons.directions_bus_rounded;
    if (n.contains('camion') || n.contains('truck') || n.contains('fourgon')) return Icons.local_shipping_rounded;
    if (n.contains('velo') || n.contains('bicycle')) return Icons.pedal_bike_rounded;
    if (n.contains('luxe') || n.contains('luxury') || n.contains('vip')) return Icons.star_rounded;
    if (n.contains('aeroport') || n.contains('airport')) return Icons.flight_land_rounded;
    if (n.contains('scolaire') || n.contains('school')) return Icons.school_rounded;
    if (n.contains('ambulance') || n.contains('medical')) return Icons.emergency_rounded;
    if (n.contains('demenag') || n.contains('moving')) return Icons.move_to_inbox_rounded;
    if (n.contains('frigo') || n.contains('frigorif')) return Icons.ac_unit_rounded;
    return Icons.category_rounded;
  }

  // ─── Bottom Sheet ─────────────────────────────────────────────────────────

  void _showAssignmentBottomSheet(BuildContext context, Service service) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignmentSheet(service: service),
    );
  }
}

// ─── Assignment Bottom Sheet ──────────────────────────────────────────────────

class _AssignmentSheet extends ConsumerStatefulWidget {
  final Service service;
  const _AssignmentSheet({required this.service});

  @override
  ConsumerState<_AssignmentSheet> createState() => _AssignmentSheetState();
}

class _AssignmentSheetState extends ConsumerState<_AssignmentSheet> {
  static const _orange = Color(0xFFFF6B35);
  static const _green = Color(0xFF22C55E);
  bool _isLoading = false;
  String? _documentUrl;

  bool get _canConfirm =>
      widget.service.isActive &&
      (!widget.service.requiresDocument || _documentUrl != null);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ─ Service image header ─
          _buildServiceHeader(),
          if (widget.service.description != null) ...[
            const SizedBox(height: 12),
            Text(
              widget.service.description!,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600, height: 1.5),
            ),
          ],
          if (widget.service.requiresDocument) ...[
            const SizedBox(height: 20),
            Text(
              'services.doc_required'.tr(),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDocument,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: _documentUrl != null
                      ? _green.withOpacity(0.07)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _documentUrl != null
                        ? _green.withOpacity(0.4)
                        : Colors.grey.shade200,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _documentUrl != null
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      color: _documentUrl != null
                          ? _green
                          : Colors.grey.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _documentUrl != null
                          ? 'services.doc_uploaded'.tr()
                          : 'services.doc_tap_upload'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _documentUrl != null
                            ? _green
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!widget.service.isActive) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Colors.red.shade600, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'services.service_unavailable_now'.tr(),
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'common.cancel'.tr(),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: (_isLoading || !_canConfirm) ? null : _assignToService,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: _canConfirm
                          ? const LinearGradient(
                              colors: [Color(0xFFFF6B35), Color(0xFFFF8A65)],
                            )
                          : null,
                      color: _canConfirm ? null : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            'services.confirm_mission'.tr(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceHeader() {
    final service = widget.service;
    final hasImage = service.imageUrl != null && service.imageUrl!.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Image ou icône
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: hasImage
              ? Image.network(
                  service.imageUrl!,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackBox(),
                )
              : _fallbackBox(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'services.join_mission'.tr(),
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                service.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              if (service.basePrice != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${service.basePrice!.toStringAsFixed(2)} ${service.currency ?? 'EUR'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (service.pricePerKm != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '+ ${service.pricePerKm!.toStringAsFixed(2)}/km',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _fallbackBox() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: _orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.work_outline_rounded, color: _orange, size: 32),
    );
  }

  Future<void> _pickDocument() async {
    try {
      final file = await ServiceApi.pickDocument();
      if (file != null) {
        setState(() => _isLoading = true);
        final token = await TokenStorage.getAccessToken() ?? '';
        final url = await ServiceApi.uploadDocument(token: token, file: file);
        setState(() {
          _documentUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _assignToService() async {
    setState(() => _isLoading = true);
    try {
      final token = await TokenStorage.getAccessToken() ?? '';
      await ServiceApi.assignToService(
        token: token,
        serviceId: widget.service.id,
        documentUrl: _documentUrl,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('services.mission_accepted'.tr()),
          backgroundColor: const Color(0xFF22C55E),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
