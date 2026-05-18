import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';

class NotificationSheet extends StatefulWidget {
  const NotificationSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationSheet(),
    );
  }

  static void showInAppBanner(BuildContext context, NotificationItem item) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 350),
            tween: Tween(begin: -80.0, end: 0.0),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      if (entry.mounted) {
                        entry.remove();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    // Auto-remove after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  final NotificationService _notificationService = NotificationService();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshNotifications();
  }

  Future<void> _refreshNotifications() async {
    if (mounted) {
      setState(() {
        _isRefreshing = true;
      });
    }
    await _notificationService.fetchNotifications();
    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return "À l'instant";
    } else if (difference.inMinutes < 60) {
      return "Il y a ${difference.inMinutes} min";
    } else if (difference.inHours < 24) {
      return "Il y a ${difference.inHours} h";
    } else if (difference.inDays < 7) {
      return "Il y a ${difference.inDays} j";
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  Color _getPriorityBgColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Colors.grey.shade100;
      case NotificationPriority.medium:
        return AppTheme.primaryColor.withOpacity(0.08);
      case NotificationPriority.high:
        return Colors.amber.shade50;
      case NotificationPriority.urgent:
        return AppTheme.errorColor.withOpacity(0.08);
    }
  }

  Color _getPriorityBorderColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Colors.grey.shade300;
      case NotificationPriority.medium:
        return AppTheme.primaryColor.withOpacity(0.2);
      case NotificationPriority.high:
        return Colors.amber.shade300;
      case NotificationPriority.urgent:
        return AppTheme.errorColor.withOpacity(0.2);
    }
  }

  Color _getPriorityTextColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Colors.grey.shade600;
      case NotificationPriority.medium:
        return AppTheme.primaryColor;
      case NotificationPriority.high:
        return Colors.amber.shade800;
      case NotificationPriority.urgent:
        return AppTheme.errorColor;
    }
  }

  String _getPriorityLabel(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return 'INFO';
      case NotificationPriority.medium:
        return 'MOYEN';
      case NotificationPriority.high:
        return 'IMPORTANT';
      case NotificationPriority.urgent:
        return 'URGENT';
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.trip:
        return Icons.directions_car_rounded;
      case NotificationType.account:
        return Icons.person_rounded;
      case NotificationType.auth:
        return Icons.security_rounded;
      case NotificationType.message:
        return Icons.chat_bubble_outline_rounded;
      case NotificationType.alert:
        return Icons.warning_amber_rounded;
      case NotificationType.system:
      case NotificationType.other:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.trip:
        return AppTheme.primaryColor;
      case NotificationType.account:
        return AppTheme.successColor;
      case NotificationType.auth:
        return const Color(0xFF3F51B5); // Indigo
      case NotificationType.message:
        return const Color(0xFF03A9F4); // Blue
      case NotificationType.alert:
        return AppTheme.errorColor;
      case NotificationType.system:
      case NotificationType.other:
        return AppTheme.secondaryColor;
    }
  }

  void _handleNotificationTap(NotificationItem notification) {
    // Marquer comme lu
    if (notification.status == NotificationStatus.unread) {
      _notificationService.markAsRead(notification.id);
    }
    
    // Fermer le sheet
    Navigator.pop(context);
    
    // Suivre le deep link
    _navigateDeepLink(notification.actionUrl);
  }

  void _navigateDeepLink(String? actionUrl) {
    if (actionUrl == null || actionUrl.isEmpty) return;

    final path = actionUrl.toLowerCase().trim();

    if (path.contains('/trips/') && path.contains('/offers')) {
      final parts = path.split('/');
      final tripsIndex = parts.indexOf('trips');
      if (tripsIndex != -1 && tripsIndex + 1 < parts.length) {
        final tripId = parts[tripsIndex + 1];
        Navigator.pushNamed(context, '/create_ride', arguments: {'tripId': tripId});
        return;
      }
    }

    if (path.contains('/client_trip_history') || path.contains('/trips/')) {
      Navigator.pushNamed(context, '/client_trip_history');
    } else if (path.contains('/profile')) {
      Navigator.pushNamed(context, '/profile');
    } else if (path.contains('/create_ride')) {
      Navigator.pushNamed(context, '/create_ride');
    } else if (path.contains('/client_rewards')) {
      Navigator.pushNamed(context, '/client_rewards');
    } else if (path.contains('/cards')) {
      Navigator.pushNamed(context, '/cards');
    } else if (path.contains('/payment_history')) {
      Navigator.pushNamed(context, '/payment_history');
    } else if (path.contains('/driver_dashboard')) {
      Navigator.pushNamed(context, '/driver_dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _notificationService,
      builder: (context, _) {
        final notifications = _notificationService.notifications;
        final unreadCount = _notificationService.unreadCount;

        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Bottom Sheet pill indicator
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),

              // Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.secondaryColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          unreadCount > 0
                              ? '$unreadCount nouvelle${unreadCount > 1 ? "s" : ""}'
                              : 'À jour',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: unreadCount > 0 ? AppTheme.primaryColor : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    
                    if (unreadCount > 0)
                      TextButton.icon(
                        onPressed: () => _notificationService.markAllAsRead(),
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text(
                          'Tout marquer lu',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),

              // List of Notifications
              Expanded(
                child: _isRefreshing && notifications.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _refreshNotifications,
                        color: AppTheme.primaryColor,
                        child: notifications.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                                itemCount: notifications.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final notification = notifications[index];
                                  return _buildNotificationCard(notification);
                                },
                              ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    final isUnread = notification.status == NotificationStatus.unread;

    return InkWell(
      onTap: () => _handleNotificationTap(notification),
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread ? AppTheme.primaryColor.withOpacity(0.02) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread 
                ? AppTheme.primaryColor.withOpacity(0.15) 
                : Colors.grey.shade200,
            width: isUnread ? 1.5 : 1,
          ),
          boxShadow: isUnread ? [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.015),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getTypeColor(notification.type).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getTypeIcon(notification.type),
                size: 20,
                color: _getTypeColor(notification.type),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Priority Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getPriorityBgColor(notification.priority),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getPriorityBorderColor(notification.priority),
                          ),
                        ),
                        child: Text(
                          _getPriorityLabel(notification.priority),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _getPriorityTextColor(notification.priority),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      
                      // Time
                      Text(
                        _formatTime(notification.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Title
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Message
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: isUnread ? Colors.grey.shade800 : Colors.grey.shade600,
                      fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),

                  // Action Button
                  if (notification.actionUrl != null && notification.actionLabel != null) ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (isUnread) {
                          _notificationService.markAsRead(notification.id);
                        }
                        Navigator.pop(context);
                        _navigateDeepLink(notification.actionUrl);
                      },
                      icon: const Icon(Icons.arrow_right_alt_rounded, size: 16),
                      label: Text(
                        notification.actionLabel!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Unread pulsating indicator
            if (isUnread) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_off_outlined,
                  size: 54,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Aucune notification',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.secondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vous recevrez des alertes instantanées sur vos courses, transactions et actualités ici.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
