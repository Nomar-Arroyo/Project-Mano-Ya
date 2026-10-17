import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Separador con la etiqueta "o" centrada, para alternativas de autenticación.
class OrDivider extends StatelessWidget {
  final String label;

  const OrDivider({super.key, this.label = 'o'});

  @override
  Widget build(BuildContext context) {
    final color = ManoYaColors.muted.withValues(alpha: 0.4);
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label,
            style: const TextStyle(color: ManoYaColors.muted, fontSize: 13),
          ),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}
