import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../shared/models/user_role.dart';

/// Selector de rol (Cliente / Trabajador) con tarjetas seleccionables.
///
/// Reemplaza al `SegmentedButton` por una presentación más clara e
/// inclusiva en móvil y web.
class RoleSelector extends StatelessWidget {
  final UserRole value;
  final ValueChanged<UserRole> onChanged;
  final bool enabled;

  const RoleSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleTile(
            icon: Icons.person_outline,
            title: 'Cliente',
            subtitle: 'Busco un oficio',
            selected: value == UserRole.client,
            enabled: enabled,
            onTap: () => onChanged(UserRole.client),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _RoleTile(
            icon: Icons.handyman_outlined,
            title: 'Trabajador',
            subtitle: 'Ofrezco mis servicios',
            selected: value == UserRole.worker,
            enabled: enabled,
            onTap: () => onChanged(UserRole.worker),
          ),
        ),
      ],
    );
  }
}

class _RoleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _RoleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? ManoYaColors.primary : ManoYaColors.muted;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: selected
                ? ManoYaColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? ManoYaColors.primary : ManoYaColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: color,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? ManoYaColors.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: ManoYaColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
