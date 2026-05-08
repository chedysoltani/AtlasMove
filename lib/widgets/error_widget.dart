import 'package:flutter/material.dart';
import '../providers/map_provider.dart';

class CustomErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final String? retryText;

  const CustomErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.retryText = 'Réessayer',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(retryText!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LocationErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;
  final MapStatus status;

  const LocationErrorWidget({
    super.key,
    required this.message,
    required this.status,
    this.onRetry,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getIcon(),
                  size: 48,
                  color: _getIconColor(),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _getSubMessage(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onRetry != null) ...[
                      ElevatedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (onOpenSettings != null)
                      OutlinedButton.icon(
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.settings),
                        label: const Text('Paramètres'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (status) {
      case MapStatus.permissionDenied:
        return Icons.location_disabled;
      case MapStatus.locationDisabled:
        return Icons.gps_off;
      default:
        return Icons.error_outline;
    }
  }

  Color _getIconColor() {
    switch (status) {
      case MapStatus.permissionDenied:
        return Colors.orange[400]!;
      case MapStatus.locationDisabled:
        return Colors.red[400]!;
      default:
        return Colors.red[400]!;
    }
  }

  String _getSubMessage() {
    switch (status) {
      case MapStatus.permissionDenied:
        return 'Accordez la permission de localisation dans les paramètres de votre appareil';
      case MapStatus.locationDisabled:
        return 'Activez le service de localisation (GPS) dans les paramètres de votre appareil';
      default:
        return 'Vérifiez votre connexion et réessayez';
    }
  }
}

