import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/user.dart';
import '../utils/app_theme.dart';

class RoleSelector extends StatelessWidget {
  final UserRole selectedRole;
  final ValueChanged<UserRole> onRoleChanged;

  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'auth.i_am_a'.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildRoleOption(
            context,
            UserRole.client,
            'auth.client'.tr(),
            'auth.client_desc'.tr(),
            Icons.person,
          ),
          _buildDivider(),
          _buildRoleOption(
            context,
            UserRole.delivery,
            'signup.driver_badge'.tr(),
            'auth.driver_desc'.tr(),
            Icons.local_shipping,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOption(
    BuildContext context,
    UserRole role,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = selectedRole == role;

    return InkWell(
      onTap: () => onRoleChanged(role),
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
                icon,
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
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppTheme.primaryColor : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Radio<UserRole>(
              value: role,
              groupValue: selectedRole,
              onChanged: (value) => onRoleChanged(role),
              activeColor: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFFE0E0E0),
    );
  }
}
