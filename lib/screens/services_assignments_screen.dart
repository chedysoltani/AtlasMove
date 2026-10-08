import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/service_models.dart';
import '../providers/assignments_provider.dart';
import '../utils/app_theme.dart';

class ServicesAssignmentsScreen extends ConsumerStatefulWidget {
  const ServicesAssignmentsScreen({super.key});

  @override
  ConsumerState<ServicesAssignmentsScreen> createState() =>
      _ServicesAssignmentsScreenState();
}

class _ServicesAssignmentsScreenState
    extends ConsumerState<ServicesAssignmentsScreen> {
  static const _orange = Color(0xFFFF6B35);
  static const _bg = Color(0xFFF8F8F8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assignmentsProvider.notifier).refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assignmentsProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(state),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
        color: _orange,
        onRefresh: () async => ref.read(assignmentsProvider.notifier).refreshAll(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentSection(state),
                  _buildHistorySection(state),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  AppBar _buildAppBar(AssignmentsState state) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.black, size: 20),
      ),
      title: Text(
        'services.assignments'.tr(),
        style: TextStyle(
          color: Colors.black,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () => ref.read(assignmentsProvider.notifier).refreshAll(),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.refresh_rounded, color: _orange, size: 20),
          ),
        ),
      ],
    );
  }

  // ─── Mission active ──────────────────────────────────────────────────────

  Widget _buildCurrentSection(AssignmentsState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('services_extra.active_mission'.tr()),
          const SizedBox(height: 12),
          if (state.isLoadingCurrent)
            _shimmerCard(height: 140)
          else if (state.currentAssignment == null)
            _emptyCurrentCard()
          else
            _activeAssignmentCard(state.currentAssignment!),
        ],
      ),
    );
  }

  Widget _activeAssignmentCard(ServiceAssignment assignment) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8A65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _orange.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.work_outline_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'services.assignments'.tr(),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      assignment.serviceName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadgeWhite(assignment.status),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          _detailRowWhite(
              Icons.category_outlined, 'support.category'.tr(), 'services_extra.service'.tr()),
          const SizedBox(height: 10),
          _detailRowWhite(
              Icons.calendar_today_outlined,
              'services_extra.assignment_date'.tr(),
              _formatDate(assignment.createdAt)),
          const SizedBox(height: 10),
          _detailRowWhite(
              Icons.info_outline_rounded,
              'payment.status'.tr(),
              _getStatusLabel(assignment.status)),
          if (assignment.documentUrl != null &&
              assignment.documentUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailRowWhite(
                Icons.description_outlined, 'services_extra.document'.tr(), 'services_extra.provided'.tr()),
          ],
        ],
      ),
    );
  }

  Widget _emptyCurrentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_outlined,
                color: _orange, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            'services_extra.no_active_mission'.tr(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'services_extra.explore_catalogue'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ─── Historique ──────────────────────────────────────────────────────────

  Widget _buildHistorySection(AssignmentsState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('services.history'.tr()),
              if (state.history.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${state.history.length}',
                    style: const TextStyle(
                      color: _orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (state.isLoading)
            ...List.generate(3, (_) => _shimmerCard(height: 80))
          else if (state.error != null)
            _errorCard(state.error!)
          else if (state.history.isEmpty)
            _emptyHistoryCard()
          else
            ...state.history.map(_historyCard).toList(),
        ],
      ),
    );
  }

  Widget _historyCard(ServiceAssignment assignment) {
    final color = _getStatusColor(assignment.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 68,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                bottomLeft: Radius.circular(14),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getStatusIcon(assignment.status),
                color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.serviceName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'services.assigned_on'.tr(namedArgs: {'date': _formatDate(assignment.createdAt)}),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusBadgeColored(assignment.status),
          const SizedBox(width: 14),
        ],
      ),
    );
  }

  Widget _emptyHistoryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(
            'services_extra.no_history'.tr(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red.shade400, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: () {
              ref.read(assignmentsProvider.notifier).clearError();
              ref.read(assignmentsProvider.notifier).refreshAll();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'common.retry'.tr(),
                style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Helpers UI ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _detailRowWhite(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 15),
        const SizedBox(width: 8),
        Text(
          '$label  ',
          style: const TextStyle(
              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w400),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statusBadgeWhite(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Text(
        _getStatusLabel(status),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _statusBadgeColored(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _shimmerCard({required double height}) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  // ─── Data helpers ────────────────────────────────────────────────────────

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFF9800);
      case 'approved':
      case 'active':
        return const Color(0xFF4CAF50);
      case 'rejected':
        return const Color(0xFFD32F2F);
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'approved':
      case 'active':
        return Icons.check_circle_outline_rounded;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'cancelled':
        return Icons.remove_circle_outline_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'common.pending'.tr();
      case 'approved':
        return 'common.approved'.tr();
      case 'active':
        return 'common.active'.tr();
      case 'rejected':
        return 'common.rejected'.tr();
      case 'cancelled':
        return 'common.cancelled'.tr();
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
