import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/service_models.dart';
import '../services/service_api.dart';
import '../providers/services_provider.dart';
import '../core/storage/token_storage.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  static const _orange = Color(0xFFFF6B35);
  static const _bg = Color(0xFFF8F8F8);
  final ScrollController _scrollController = ScrollController();
  String? _activeFilter;

  final List<Map<String, dynamic>> _filters = [
    {'label': 'Tous', 'value': null, 'icon': Icons.apps_rounded},
    {'label': 'Taxi', 'value': 'taxi', 'icon': Icons.local_taxi_rounded},
    {'label': 'VTC', 'value': 'vtc', 'icon': Icons.directions_car_rounded},
    {'label': 'Moto', 'value': 'moto', 'icon': Icons.motorcycle_rounded},
    {'label': 'Livraison', 'value': 'livraison', 'icon': Icons.delivery_dining_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(servicesProvider.notifier).fetchServices(reset: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(servicesProvider.notifier).fetchServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(servicesProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildFilterBar(),
            Expanded(child: _buildBody(state)),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'services.title'.tr(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Trouvez votre mission idéale',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          _iconBtn(
            Icons.category_rounded,
            onTap: () => Navigator.pushNamed(context, '/services_catalogue'),
          ),
          const SizedBox(width: 8),
          _iconBtn(
            Icons.history_rounded,
            onTap: () => Navigator.pushNamed(context, '/services_assignments'),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: _orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: _orange, size: 20),
      ),
    );
  }

  // ─── Filters ─────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((f) {
            final isActive = _activeFilter == f['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _activeFilter = f['value'] as String?);
                  ref
                      .read(servicesProvider.notifier)
                      .setTransportTypeFilter(f['value'] as String?);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive ? _orange : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        f['icon'] as IconData,
                        size: 14,
                        color: isActive ? Colors.white : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        f['label'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody(ServicesState state) {
    if (state.isLoading && state.services.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _orange),
      );
    }

    if (state.error != null && state.services.isEmpty) {
      return _errorState(state.error!);
    }

    if (state.services.isEmpty) {
      return _emptyState();
    }

    return RefreshIndicator(
      color: _orange,
      onRefresh: () => ref.read(servicesProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: state.services.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.services.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                  child: CircularProgressIndicator(color: _orange, strokeWidth: 2)),
            );
          }
          return _serviceCard(context, state.services[index]);
        },
      ),
    );
  }

  Widget _serviceCard(BuildContext context, Service service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _serviceIcon(service.transportType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              service.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          _typeBadge(service.transportType),
                        ],
                      ),
                      if (service.category?.name != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          service.category!.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (service.description != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          service.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: Colors.grey.shade50,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
            child: Row(
              children: [
                _pricingBadge(service.pricingModel),
                if (service.requiresDocument) ...[
                  const SizedBox(width: 6),
                  _docBadge(),
                ],
                if (!service.isActive) ...[
                  const SizedBox(width: 6),
                  _inactiveBadge(),
                ],
                const Spacer(),
                if (service.basePrice != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      '${service.basePrice!.toStringAsFixed(2)} ${service.currency}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                _acceptBtn(
                  active: service.isActive,
                  onTap: () => _showAssignmentBottomSheet(context, service),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceIcon(String transportType) {
    final type = transportType.toLowerCase();
    IconData icon;
    if (type.contains('taxi')) {
      icon = Icons.local_taxi_rounded;
    } else if (type.contains('moto')) {
      icon = Icons.motorcycle_rounded;
    } else if (type.contains('livraison') || type.contains('delivery')) {
      icon = Icons.delivery_dining_rounded;
    } else if (type.contains('vtc') || type.contains('voiture')) {
      icon = Icons.directions_car_rounded;
    } else if (type.contains('van')) {
      icon = Icons.airport_shuttle_rounded;
    } else {
      icon = Icons.work_outline_rounded;
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: _orange, size: 22),
    );
  }

  Widget _typeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: _orange,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _pricingBadge(String model) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        model.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Color(0xFF3B82F6),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _docBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined,
              size: 10, color: Colors.orange.shade700),
          const SizedBox(width: 3),
          Text(
            'Doc requis',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inactiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block_rounded, size: 10, color: Colors.red.shade600),
          const SizedBox(width: 3),
          Text(
            'Indisponible',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _acceptBtn({required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: active ? () { HapticFeedback.lightImpact(); onTap(); } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF22C55E) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Accepter',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  // ─── States ───────────────────────────────────────────────────────────────

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
            child: const Icon(Icons.work_off_outlined, size: 40, color: _orange),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucun service disponible',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(
            'Revenez plus tard ou modifiez les filtres',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded,
                  size: 36, color: Colors.red.shade400),
            ),
            const SizedBox(height: 14),
            Text(
              'common.error'.tr(),
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
              onTap: () => ref.read(servicesProvider.notifier).refresh(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _orange,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Réessayer',
                  style: TextStyle(
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
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.work_outline_rounded,
                    color: _orange, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rejoindre la mission',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      widget.service.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.service.basePrice != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.service.basePrice!.toStringAsFixed(2)} ${widget.service.currency}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (widget.service.description != null) ...[
            const SizedBox(height: 14),
            Text(
              widget.service.description!,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.5),
            ),
          ],
          if (widget.service.requiresDocument) ...[
            const SizedBox(height: 20),
            const Text(
              'Document requis',
              style: TextStyle(
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
                      color: _documentUrl != null ? _green : Colors.grey.shade400,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _documentUrl != null
                          ? 'Document téléchargé'
                          : 'Appuyez pour télécharger',
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
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _useTestDocument,
                  icon: const Icon(Icons.bug_report_rounded, size: 15),
                  label: const Text('DEV — Document de test'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
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
                    'Ce service est actuellement indisponible',
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
                    child: const Text(
                      'Annuler',
                      style: TextStyle(
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
                  onTap: (_isLoading || !widget.service.isActive ||
                          (widget.service.requiresDocument &&
                              _documentUrl == null))
                      ? null
                      : _assignToService,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: (widget.service.isActive &&
                              (!widget.service.requiresDocument ||
                                  _documentUrl != null))
                          ? const LinearGradient(
                              colors: [Color(0xFFFF6B35), Color(0xFFFF8A65)],
                            )
                          : null,
                      color: (widget.service.isActive &&
                              (!widget.service.requiresDocument ||
                                  _documentUrl != null))
                          ? null
                          : Colors.grey.shade300,
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
                        : const Text(
                            'Confirmer la mission',
                            style: TextStyle(
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _useTestDocument() async {
    // En dev : on simule un document uploadé sans appel réseau
    setState(() {
      _documentUrl = 'https://test.atla.business/dev/test_document.png';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('DEV: Document de test chargé ✓'),
          backgroundColor: Color(0xFF7C3AED),
          duration: Duration(seconds: 2),
        ),
      );
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
        await _showAssignmentPendingDialog(context);
        if (mounted) Navigator.of(context).pop();
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

  Future<void> _showAssignmentPendingDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded,
                    color: Color(0xFFF59E0B), size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Demande envoyée !',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1F36)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Text(
                'Votre demande d\'assignement a bien été enregistrée.\n\n'
                'L\'administrateur doit approuver cette assignation '
                'avant que vous puissiez commencer les missions.\n\n'
                'Vous serez notifié dès que votre demande sera acceptée.',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                    height: 1.6),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Compris',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
