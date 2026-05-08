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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Mes Affectations',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/services');
            },
            icon: const Icon(Icons.list, color: Colors.black),
          ),
        ],
      ),
      body: Column(
        children: [
          // Current Assignment Card
          _buildCurrentAssignmentCard(currentAssignmentAsync),
          
          // Assignments List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => await ref.read(assignmentsProvider.notifier).refresh(),
              child: _buildAssignmentsList(assignmentsState),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentAssignmentCard(AsyncValue<ServiceAssignment?> currentAssignmentAsync) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: currentAssignmentAsync.when(
        loading: () => Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade600),
                const SizedBox(height: 4),
                Text(
                  'Erreur de chargement',
                  style: TextStyle(color: Colors.red.shade600),
                ),
              ],
            ),
          ),
        ),
        data: (assignment) => assignment != null
            ? _buildActiveAssignmentCard(assignment)
            : _buildNoAssignmentCard(),
      ),
    );
  }

  Widget _buildActiveAssignmentCard(ServiceAssignment assignment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ACTIF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.star, color: Colors.white, size: 20),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Text(
            assignment.serviceName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 4),
          
          Text(
            'Affecté le ${_formatDate(assignment.createdAt)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Voir détails',
                  onPressed: () => _showAssignmentDetails(assignment),
                  type: ButtonType.outline,
                  height: 36,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: 'Annuler',
                  onPressed: () => _showCancelConfirmation(assignment),
                  height: 36,
                  type: ButtonType.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoAssignmentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 32,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'Aucune affectation active',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Explorez les services disponibles',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'Voir les services',
            onPressed: () {
              Navigator.pushNamed(context, '/services');
            },
            height: 36,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsList(AssignmentsState state) {
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Réessayer',
              onPressed: () => ref.read(assignmentsProvider.notifier).refresh(),
            ),
          ],
        ),
      );
    }

    if (state.assignments.isEmpty && !state.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Aucun historique',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vous n\'avez aucune affectation passée',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: state.assignments.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.assignments.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final assignment = state.assignments[index];
        return _buildAssignmentCard(assignment);
      },
    );
  }

  Widget _buildAssignmentCard(ServiceAssignment assignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.serviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Demande le ${_formatDate(assignment.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(assignment.status),
              ],
            ),
            
            if (assignment.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        assignment.rejectionReason!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                CustomButton(
                  text: 'Détails',
                  onPressed: () => _showAssignmentDetails(assignment),
                  type: ButtonType.outline,
                  height: 32,
                ),
                if (assignment.isPending) ...[
                  const SizedBox(width: 8),
                  CustomButton(
                    text: 'Annuler',
                    onPressed: () => _showCancelConfirmation(assignment),
                    height: 32,
                    type: ButtonType.secondary,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    
    switch (status) {
      case 'PENDING':
        color = Colors.orange;
        text = 'EN ATTENTE';
        break;
      case 'APPROVED':
        color = Colors.green;
        text = 'APPROUVÉ';
        break;
      case 'REJECTED':
        color = Colors.red;
        text = 'REJETÉ';
        break;
      default:
        color = Colors.grey;
        text = status.toUpperCase();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showAssignmentDetails(ServiceAssignment assignment) {
    showDialog(
      context: context,
      builder: (context) => _AssignmentDetailsDialog(assignment: assignment),
    );
  }

  void _showCancelConfirmation(ServiceAssignment assignment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler l\'affectation'),
        content: Text(
          'Êtes-vous sûr de vouloir annuler votre affectation à ${assignment.serviceName} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(assignmentsProvider.notifier).cancelAssignment(assignment.id);
              
              // Refresh current assignment
              ref.invalidate(currentAssignmentProvider);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Affectation annulée avec succès'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
  }
}

class _AssignmentDetailsDialog extends StatelessWidget {
  final ServiceAssignment assignment;

  const _AssignmentDetailsDialog({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(assignment.serviceName),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('ID', assignment.id),
            _buildDetailRow('Statut', assignment.status),
            _buildDetailRow('Date de demande', _formatFullDate(assignment.createdAt)),
            if (assignment.approvedAt != null)
              _buildDetailRow('Date d\'approbation', _formatFullDate(assignment.approvedAt!)),
            if (assignment.rejectedAt != null)
              _buildDetailRow('Date de rejet', _formatFullDate(assignment.rejectedAt!)),
            if (assignment.rejectionReason != null)
              _buildDetailRow('Raison du rejet', assignment.rejectionReason!),
            if (assignment.documentUrl != null)
              _buildDetailRow('Document', 'Document téléchargé'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
