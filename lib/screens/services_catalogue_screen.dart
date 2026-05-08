import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../models/service_models.dart';
import '../services/service_api.dart';
import '../providers/services_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';

class ServicesCatalogueScreen extends ConsumerStatefulWidget {
  const ServicesCatalogueScreen({super.key});

  @override
  ConsumerState<ServicesCatalogueScreen> createState() => _ServicesCatalogueScreenState();
}

class _ServicesCatalogueScreenState extends ConsumerState<ServicesCatalogueScreen> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(catalogueProvider);
    final catalogueNotifier = ref.read(catalogueProvider.notifier);

    // Rafraîchir les données une seule fois au chargement
    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        catalogueNotifier.fetchCatalogue();
      });
      _initialized = true;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Catalogue des Services',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () => catalogueNotifier.fetchCatalogue(),
          ),
        ],
      ),
      body: catalogueAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Réessayer',
                onPressed: () => catalogueNotifier.fetchCatalogue(),
              ),
            ],
          ),
        ),
        data: (catalogue) => _buildCatalogue(context, catalogue),
      ),
    );
  }

  Widget _buildCatalogue(BuildContext context, ServiceCatalogue catalogue) {
    final categories = catalogue.data;
    
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Aucune catégorie disponible',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final services = category.services;
        
        return _buildCategorySection(context, category, services);
      },
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    ServiceCategoryWithServices category,
    List<Service> services,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getCategoryIcon(category.name),
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          title: Text(
            category.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          subtitle: services.isEmpty
              ? null
              : Text(
                  '${services.length} service${services.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
          trailing: Icon(
            Icons.expand_more,
            color: Colors.grey.shade600,
          ),
          children: services.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Aucun service dans cette catégorie',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ]
              : services.map((service) => _buildServiceItem(context, service)).toList(),
        ),
      ),
    );
  }

  Widget _buildServiceItem(BuildContext context, Service service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
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
                      service.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    if (service.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        service.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      service.transportType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      service.pricingModel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              if (service.requiresDocument) ...[
                Icon(Icons.description, size: 12, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Text(
                  'Document requis',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              
              if (!service.isActive) ...[
                Icon(Icons.warning, size: 12, color: Colors.red.shade700),
                const SizedBox(width: 4),
                Text(
                  'Indisponible',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              
              if (service.basePrice != null) ...[
                const Spacer(),
                Text(
                  '${service.basePrice!.toStringAsFixed(2)} ${service.currency}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              
              CustomButton(
                text: "S'affecter",
                onPressed: service.isActive 
                    ? () => _showAssignmentDialog(context, service)
                    : null,
                height: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    
    if (name.contains('taxi') || name.contains('transport')) {
      return Icons.local_taxi;
    } else if (name.contains('livraison') || name.contains('delivery')) {
      return Icons.delivery_dining;
    } else if (name.contains('moto') || name.contains('moto')) {
      return Icons.motorcycle;
    } else if (name.contains('van') || name.contains('camion')) {
      return Icons.local_shipping;
    } else if (name.contains('course') || name.contains('ride')) {
      return Icons.directions_car;
    } else if (name.contains('urgence') || name.contains('emergency')) {
      return Icons.emergency;
    } else if (name.contains('premium') || name.contains('luxury')) {
      return Icons.star;
    } else {
      return Icons.category;
    }
  }

  void _showAssignmentDialog(BuildContext context, Service service) {
    showDialog(
      context: context,
      builder: (context) => _AssignmentDialog(service: service),
    );
  }
}

class _AssignmentDialog extends ConsumerStatefulWidget {
  final Service service;

  const _AssignmentDialog({required this.service});

  @override
  ConsumerState<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends ConsumerState<_AssignmentDialog> {
  bool _isLoading = false;
  String? _documentUrl;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("S'affecter à ${widget.service.name}"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.service.description ?? 'Service de ${widget.service.category?.name ?? ''}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          
          const SizedBox(height: 16),
          
          if (widget.service.requiresDocument) ...[
            Text(
              'Document requis',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _documentUrl != null 
                          ? 'Document téléchargé' 
                          : 'Aucun document sélectionné',
                      style: TextStyle(
                        color: _documentUrl != null 
                            ? Colors.green.shade700 
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _pickDocument,
                  icon: const Icon(Icons.upload_file),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          
          if (!widget.service.isActive) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ce service est actuellement indisponible',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: (_isLoading || (!widget.service.isActive)) ? null : _assignToService,
          child: _isLoading 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirmer'),
        ),
      ],
    );
  }

  Future<void> _pickDocument() async {
    try {
      final file = await ServiceApi.pickDocument();
      if (file != null) {
        setState(() => _isLoading = true);
        
        final token = provider_pkg.Provider.of<AuthProvider>(context, listen: false).token ?? '';
        final url = await ServiceApi.uploadDocument(token: token, file: file);
        
        setState(() {
          _documentUrl = url;
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document téléchargé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignToService() async {
    print('DEBUG: CATALOGUE - Début de l\'affectation');
    print('DEBUG: CATALOGUE - Service: ${widget.service.name} (ID: ${widget.service.id})');
    print('DEBUG: CATALOGUE - Requires document: ${widget.service.requiresDocument}');
    print('DEBUG: CATALOGUE - Document URL: $_documentUrl');
    
    if (widget.service.requiresDocument && _documentUrl == null) {
      print('DEBUG: CATALOGUE - Document requis mais non fourni');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez télécharger un document'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('DEBUG: CATALOGUE - Récupération du token...');
      final token = provider_pkg.Provider.of<AuthProvider>(context, listen: false).token ?? '';
      print('DEBUG: CATALOGUE - Token récupéré: ${token.isNotEmpty ? "présent (${token.length} chars)" : "vide"}');
      
      print('DEBUG: CATALOGUE - Appel de ServiceApi.assignToService...');
      await ServiceApi.assignToService(
        token: token,
        serviceId: widget.service.id,
        documentUrl: _documentUrl,
      );
      print('DEBUG: CATALOGUE - Affectation réussie');

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande envoyée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('DEBUG: CATALOGUE - Erreur lors de l\'affectation: $e');
      print('DEBUG: CATALOGUE - Type d\'erreur: ${e.runtimeType}');
      print('DEBUG: CATALOGUE - Stack trace: ${StackTrace.current}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
      print('DEBUG: CATALOGUE - Fin de l\'affectation (isLoading = false)');
    }
  }
}
