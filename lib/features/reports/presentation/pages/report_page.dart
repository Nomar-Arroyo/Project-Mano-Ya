import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../domain/report.dart';
import '../report_provider.dart';

/// Pantalla para enviar un reporte sobre un trabajador o un servicio.
///
/// El reporte se guarda siempre en la base de datos de Supabase y, si hay un
/// webhook de n8n configurado, se envía la notificación al equipo de soporte.
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key, this.targetUserId, this.targetName, this.jobId});

  /// Usuario al que se refiere el reporte (trabajador).
  final String? targetUserId;

  /// Nombre del trabajador reportado.
  final String? targetName;

  /// Servicio relacionado con el reporte.
  final String? jobId;

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  ReportCategory _category = ReportCategory.calidad;
  ReportSeverity _severity = ReportSeverity.normal;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = ref.read(authStateProvider);
    final messenger = ScaffoldMessenger.of(context);

    final ok = await ref
        .read(reportControllerProvider.notifier)
        .submit(
          reporterId: auth.userId ?? '',
          reporterName: auth.displayName ?? '',
          reporterEmail: auth.email ?? '',
          targetUserId: widget.targetUserId,
          targetName: widget.targetName ?? 'Sin especificar',
          jobId: widget.jobId,
          category: _category,
          reason: _reasonCtrl.text.trim(),
          details: _detailsCtrl.text.trim(),
          severity: _severity,
        );

    if (!mounted) return;
    final message =
        ref.read(reportControllerProvider).message ??
        'Reporte enviado correctamente';

    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: ManoYaColors.success),
      );
      context.pop();
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: ManoYaColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(reportControllerProvider);
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(title: const Text('Enviar reporte')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.targetName != null) ...[
                  Card(
                    color: surface,
                    child: ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Reporte sobre'),
                      subtitle: Text(widget.targetName!),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                const Text(
                  'Motivo del reporte',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ReportCategory.values.map((category) {
                    final selected = category == _category;
                    return ChoiceChip(
                      label: Text(category.label),
                      selected: selected,
                      onSelected: submission.loading
                          ? null
                          : (_) => setState(() => _category = category),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Urgencia',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<ReportSeverity>(
                  segments: ReportSeverity.values
                      .map(
                        (severity) => ButtonSegment<ReportSeverity>(
                          value: severity,
                          label: Text(severity.label),
                        ),
                      )
                      .toList(),
                  selected: {_severity},
                  onSelectionChanged: submission.loading
                      ? null
                      : (selection) =>
                            setState(() => _severity = selection.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _reasonCtrl,
                  label: 'Asunto',
                  hint: 'Resume en una línea lo que pasó',
                  prefixIcon: Icons.title,
                  enabled: !submission.loading,
                  validator: (value) {
                    if (value == null || value.trim().length < 5) {
                      return 'Describe el motivo (mínimo 5 caracteres)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _detailsCtrl,
                  label: 'Detalle',
                  hint: 'Describe qué ocurrió, fechas y datos de contacto',
                  prefixIcon: Icons.notes,
                  maxLines: 5,
                  enabled: !submission.loading,
                  validator: (value) {
                    if (value == null || value.trim().length < 10) {
                      return 'Cuéntanos con más detalle (mínimo 10 caracteres)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Enviar reporte',
                  icon: Icons.send,
                  loading: submission.loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Tu reporte se guarda de forma confidencial. El equipo de '
                  'soporte lo revisa y te responde por correo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ManoYaColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
