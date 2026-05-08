import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_models.dart';
import '../providers/assignments_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';

class ServicesAssignmentsScreen extends ConsumerStatefulWidget {
  const ServicesAssignmentsScreen({super.key});

  @override
  ConsumerState<ServicesAssignmentsScreen> createState() => _ServicesAssignmentsScreenState();
}

class _ServicesAssignmentsScreenState extends ConsumerState<ServicesAssignmentsScreen> {
  @override
  void initState() {
    super.initState();
    // Charger les données au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(assignmentsProvider.notifier).refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final assignmentsState = ref.watch(assignmentsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mes Affectations',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
            onPressed: () {
              ref.read(assignmentsProvider.notifier).refreshAll();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(assignmentsProvider.notifier).refreshAll();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Assignement Actuel
              _buildCurrentAssignmentSection(assignmentsState),
              
              const SizedBox(height: 24),
              
              // Section Historique
              _buildHistorySection(assignmentsState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentAssignmentSection(AssignmentsState state) {
    if (state.isLoadingCurrent) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (state.currentAssignment == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              const Text(
                'Aucun assignement actif',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'pour le moment',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final assignment = state.currentAssignment!;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getServiceIcon(assignment.serviceId),
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Assignement Actuel',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        assignment.serviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(assignment.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(assignment.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(assignment.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAssignmentDetails(assignment),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(AssignmentsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historique des assignements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        
        if (state.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (state.error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[400], size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Erreur de chargement',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.error!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: 'Réessayer',
                    onPressed: () {
                      ref.read(assignmentsProvider.notifier).clearError();
                      ref.read(assignmentsProvider.notifier).refreshAll();
                    },
                    height: 36,
                  ),
                ],
              ),
            ),
          )
        else if (state.history.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Aucun historique',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vous n\'avez pas encore d\'assignements',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...state.history.map((assignment) => _buildAssignmentCard(assignment)).toList(),
      ],
    );
  }

  Widget _buildAssignmentCard(ServiceAssignment assignment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getServiceIcon(assignment.serviceId),
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.serviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Assigné le ${_formatDate(assignment.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(assignment.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(assignment.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(assignment.status),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentDetails(ServiceAssignment assignment) {
    return Column(
      children: [
        _buildDetailRow('Service', assignment.serviceName),
        _buildDetailRow('Catégorie', _getCategoryName(assignment.serviceId)),
        _buildDetailRow('Date d\'assignement', _formatDate(assignment.createdAt)),
        _buildDetailRow('Statut', _getStatusText(assignment.status)),
        if (assignment.documentUrl != null && assignment.documentUrl!.isNotEmpty)
          _buildDetailRow('Document', 'Document fourni'),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getServiceIcon(String serviceId) {
    // Icon basé sur le type de service
    if (serviceId.contains('taxi')) return Icons.local_taxi;
    if (serviceId.contains('delivery')) return Icons.delivery_dining;
    if (serviceId.contains('transport')) return Icons.directions_car;
    return Icons.assignment;
  }

  String _getCategoryName(String serviceId) {
    // Catégorie basée sur le service
    if (serviceId.contains('taxi')) return 'Transport';
    if (serviceId.contains('delivery')) return 'Livraison';
    return 'Service';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'En attente';
      case 'approved':
        return 'Approuvé';
      case 'rejected':
        return 'Rejeté';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
