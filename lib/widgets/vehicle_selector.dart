import 'package:flutter/material.dart';
import '../models/user.dart';
import '../utils/app_theme.dart';

class VehicleSelector extends StatelessWidget {
  final VehicleType? selectedVehicle;
  final ValueChanged<VehicleType> onVehicleChanged;

  const VehicleSelector({
    super.key,
    this.selectedVehicle,
    required this.onVehicleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de véhicule',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Column(
            children: VehicleType.values.map((vehicle) {
              final isSelected = selectedVehicle == vehicle;
              return Column(
                children: [
                  InkWell(
                    onTap: () => onVehicleChanged(vehicle),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getVehicleIcon(vehicle),
                              color: isSelected ? AppTheme.textWhite : Colors.grey.shade600,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vehicle.displayName,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? AppTheme.primaryColor : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getVehicleDescription(vehicle),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Radio<VehicleType>(
                            value: vehicle,
                            groupValue: selectedVehicle,
                            onChanged: (value) => onVehicleChanged(vehicle),
                            activeColor: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (vehicle != VehicleType.values.last) _buildDivider(),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFFE0E0E0),
    );
  }

  IconData _getVehicleIcon(VehicleType vehicle) {
    switch (vehicle) {
      case VehicleType.car:
        return Icons.directions_car;
      case VehicleType.motorcycle:
        return Icons.motorcycle;
      case VehicleType.truck:
        return Icons.local_shipping;
      case VehicleType.van:
        return Icons.airport_shuttle;
    }
  }

  String _getVehicleDescription(VehicleType vehicle) {
    switch (vehicle) {
      case VehicleType.car:
        return 'Idéal pour les courses rapides';
      case VehicleType.motorcycle:
        return 'Parfait pour les livraisons urgentes';
      case VehicleType.truck:
        return 'Pour les gros volumes et meubles';
      case VehicleType.van:
        return 'Pour les livraisons moyennes';
    }
  }
}
