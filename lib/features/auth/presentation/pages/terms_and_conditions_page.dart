import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/app_spacing.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  static const _infractions = [
    _Infraction(
      detected: 'Abandono o paralización injustificada de la labor',
      qualification: 'Incumplimiento contractual civil',
      legalBasis: 'Arts. 1.167 y 1.630 del Código Civil',
      sanction: 'Suspensión temporal de cuenta (15 a 30 días) o rescisión definitiva de perfil.',
    ),
    _Infraction(
      detected: 'Falsificación o adulteración de comprobantes de pago (Pago Móvil / Transferencia)',
      qualification: 'Delito de Estafa',
      legalBasis: 'Artículo 462 del Código Penal venezolano',
      sanction: 'Expulsión inmediata y permanente, con remisión de logs técnicos y evidencias al Ministerio Público / CICPC.',
    ),
    _Infraction(
      detected: 'Coacción, amenazas o cobros extorsivos forzados',
      qualification: 'Delito de Extorsión',
      legalBasis: 'Ley Contra el Secuestro y la Extorsión',
      sanction: 'Bloqueo definitivo de cuenta y formulación inmediata de la denuncia penal respectiva.',
    ),
    _Infraction(
      detected: 'Retención indebida de herramientas o bienes ajenos',
      qualification: 'Apropiación Indebida',
      legalBasis: 'Arts. 466 y 468 del Código Penal',
      sanction: 'Inhabilitación de perfil y entrega formal del historial y datos a la parte afectada.',
    ),
    _Infraction(
      detected:
          'Mora deliberada o negativa injustificada de pago por el Cliente',
      qualification: 'Mora civil en el pago del precio pactado',
      legalBasis: 'Art. 1.264 del Código Civil',
      sanction: 'Inhabilitación preventiva para publicar nuevas ofertas o contratar personal.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ManoYaColors.background,
      appBar: AppBar(title: const Text('Términos y condiciones')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          return SelectionArea(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? AppSpacing.sm : AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
              children: [
                _DocumentPage(
                  compact: compact,
                  children: [
                    const _DocumentHeading(),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionHeading(
                      number: '1',
                      title: 'NATURALEZA CIVIL DEL VÍNCULO Y PRIMACÍA DE LA REALIDAD',
                    ),
                    const _LegalParagraph(
                      heading: 'Objeto Contractual',
                      text: 'Los servicios convenidos a través de la plataforma Mano Ya corresponden exclusivamente a contratos de obra y arrendamiento de servicios de carácter eminentemente civil, regulados por los Artículos 1.629 y 1.630 del Código Civil venezolano.',
                    ),
                    const _LegalParagraph(
                      heading: 'Ausencia de Relación Laboral',
                      text: 'Mano Ya actúa únicamente en condición de intermediario y facilitador tecnológico. La plataforma no ostenta facultades patronales, de supervisión técnica, mando ni subordinación laboral bajo la Ley Orgánica del Trabajo, los Trabajadores y las Trabajadoras (LOTTT).',
                    ),
                    const _LegalParagraph(
                      heading: 'Autonomía Operativa (Art. 22 LOTTT)',
                      text: 'El Trabajador o Prestador Independiente goza de total autonomía técnico-operativa: fija autónomamente sus tarifas, suministra sus propios medios, herramientas e instrumentos de labor, pacta sus horarios y administra libremente su disponibilidad en la aplicación móvil (Disponible / En descanso).',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionHeading(
                      number: '2',
                      title: 'VALIDEZ PROBATORIA Y MENSAJES DE DATOS',
                    ),
                    const _LegalParagraph(
                      heading: 'Consentimiento Electrónico Vinculante',
                      text: 'De conformidad con lo previsto en los Artículos 4 y 6 de la Ley sobre Mensajes de Datos y Firmas Electrónicas, la aceptación de este instrumento efectuada mediante la marcación de la casilla de verificación (checkbox) durante el registro, aparejada a los metadatos de auditoría (dirección IP, identificador único user_id y estampa de tiempo inmutable), reviste pleno valor probatorio y fuerza legal obligatoria entre las partes.',
                    ),
                    const _LegalParagraph(
                      heading: 'Eficacia Probatoria de Registros Digitales',
                      text: 'Los comprobantes de transferencia bancaria o Pago Móvil adjuntados en la plataforma, al igual que los registros de hitos y avances almacenados en la base de datos, poseen total equivalencia funcional y eficacia probatoria frente a instrumentos físicos escritos.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionHeading(
                      number: '3',
                      title:
                          'DINÁMICA OPERATIVA DE PAGOS Y CUOTAS / HITOS (MVP)',
                    ),
                    const _LegalParagraph(
                      heading: 'Cobro Descentralizado',
                      text: 'Mano Ya no realiza intermediación financiera, captación bancaria directa ni custodia de fondos (no actúa como pasarela retenedora). La conclusión de cada servicio constituye una potestad técnica exclusiva del Trabajador mediante la activación voluntaria del comando "Pago Recibido / Trabajo Pagado", previa constatación personal del dinero en sus cuentas bancarias.',
                    ),
                    const _LegalParagraph(
                      heading: 'Proyectos Superiores a \$800 USD',
                      text: 'Todo presupuesto convenido que exceda dicha cuantía se fraccionará obligatoriamente en hitos o cuotas periódicas de avance. El servicio mantendrá el estado pendiente hasta que la totalidad de los hitos cuente con la confirmación expresa de cobro por parte del Trabajador.',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _PageFooter(page: 1),
                  ],
                ),
                SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
                _DocumentPage(
                  compact: compact,
                  children: [
                    const _ContinuationHeading(),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionHeading(
                      number: '4',
                      title: 'CÓDIGO DE CONDUCTA Y RÉGIMEN SANCIONATORIO',
                    ),
                    const Text(
                      'Régimen disciplinario y tipificación de infracciones aplicable con efecto inmediato a usuarios clientes y prestadores dentro de la plataforma:',
                      style: TextStyle(
                        color: ManoYaColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _InfractionTable(
                      infractions: _infractions,
                      compact: compact,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionHeading(
                      number: '5',
                      title: 'CIBERSEGURIDAD, PRIVACIDAD Y PRINCIPIO DE NO REPUDIO',
                    ),
                    const Text(
                      'En estricto cumplimiento de la Ley Especial contra los Delitos Informáticos, la plataforma implementa autenticación robusta mediante tokens criptográficos JWT y políticas de aislamiento de datos Row Level Security (RLS) a nivel de base de datos PostgreSQL. En virtud de ello, ningún usuario registrado podrá desconocer válidamente compromisos, cotizaciones o transacciones ejecutadas bajo sus credenciales autenticadas.',
                      style: TextStyle(
                        color: ManoYaColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionHeading(
                      number: '6',
                      title: 'MEDIACIÓN INTERNA Y FUERO JURISDICCIONAL',
                    ),
                    const Text(
                      'Para dirimir cualquier controversia derivada de la ejecución del servicio o la verificación de pagos, las Partes convienen someterse preferentemente a la mediación del equipo de soporte de Mano Ya. En caso de no alcanzarse un acuerdo satisfactorio, las Partes se someten expresamente a la jurisdicción de los tribunales civiles y mercantiles competentes correspondientes al domicilio donde se ejecutó fácticamente la labor dentro del territorio de la República Bolivariana de Venezuela.',
                      style: TextStyle(
                        color: ManoYaColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _PageFooter(page: 2),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DocumentPage extends StatelessWidget {
  const _DocumentPage({required this.compact, required this.children});

  final bool compact;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ManoYaColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ManoYaColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentHeading extends StatelessWidget {
  const _DocumentHeading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INSTRUMENTO JURÍDICO VINCULANTE',
          style: theme.textTheme.labelLarge?.copyWith(
            color: ManoYaColors.primary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'CONTRATO DE TÉRMINOS Y CONDICIONES DE USO, POLÍTICA DE PRIVACIDAD Y RÉGIMEN DISCIPLINARIO',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: ManoYaColors.textPrimary,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: const [
            _MetadataChip(label: 'Plataforma Digital', value: 'Mano Ya'),
            _MetadataChip(
              label: 'Jurisdicción',
              value: 'Rep. Bolivariana de Venezuela',
            ),
            _MetadataChip(label: 'Vigencia', value: '2026'),
            _MetadataChip(label: 'Versión', value: '1.0 (MVP Operativo)'),
          ],
        ),
      ],
    );
  }
}

class _ContinuationHeading extends StatelessWidget {
  const _ContinuationHeading();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.description_outlined, color: ManoYaColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Mano Ya · Instrumento Legal y Regulatorio',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: ManoYaColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: ManoYaColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ManoYaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ManoYaColors.muted,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: ManoYaColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ManoYaColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: ManoYaColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: ManoYaColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalParagraph extends StatelessWidget {
  const _LegalParagraph({required this.heading, required this.text});

  final String heading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$heading:',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: ManoYaColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: ManoYaColors.textSecondary, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _Infraction {
  const _Infraction({
    required this.detected,
    required this.qualification,
    required this.legalBasis,
    required this.sanction,
  });

  final String detected;
  final String qualification;
  final String legalBasis;
  final String sanction;
}

const _infractionHeaders = [
  'INFRACCIÓN DETECTADA',
  'CALIFICACIÓN JURÍDICA',
  'FUNDAMENTO LEGAL',
  'SANCIÓN EN PLATAFORMA',
];

class _InfractionTable extends StatelessWidget {
  const _InfractionTable({required this.infractions, required this.compact});

  final List<_Infraction> infractions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          for (final (index, infraction) in infractions.indexed)
            _InfractionCard(number: index + 1, infraction: infraction),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: ManoYaColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              ManoYaColors.primary.withValues(alpha: 0.08),
            ),
            dataRowMinHeight: 76,
            dataRowMaxHeight: 132,
            columnSpacing: AppSpacing.md,
            dataTextStyle: const TextStyle(color: ManoYaColors.textPrimary),
            columns: [
              for (final header in _infractionHeaders)
                DataColumn(
                  label: SizedBox(
                    width: 190,
                    child: Text(
                      header,
                      style: const TextStyle(
                        color: ManoYaColors.primaryDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
            rows: [
              for (final infraction in infractions)
                DataRow(
                  cells: [
                    _dataCell(infraction.detected),
                    _dataCell(infraction.qualification),
                    _dataCell(infraction.legalBasis),
                    _dataCell(infraction.sanction),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  DataCell _dataCell(String value) => DataCell(
    SizedBox(
      width: 190,
      child: Text(
        value,
        style: const TextStyle(color: ManoYaColors.textPrimary, height: 1.35),
      ),
    ),
  );
}

class _InfractionCard extends StatelessWidget {
  const _InfractionCard({required this.number, required this.infraction});

  final int number;
  final _Infraction infraction;

  @override
  Widget build(BuildContext context) {
    final values = [
      infraction.detected,
      infraction.qualification,
      infraction.legalBasis,
      infraction.sanction,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: ManoYaColors.surface,
        border: Border.all(color: ManoYaColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: ManoYaColors.primary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: Text(
              'Infracción $number',
              style: const TextStyle(
                color: ManoYaColors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (var index = 0; index < _infractionHeaders.length; index++)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 124,
                    child: Text(
                      _infractionHeaders[index],
                      style: const TextStyle(
                        color: ManoYaColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      values[index],
                      style: const TextStyle(
                        color: ManoYaColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PageFooter extends StatelessWidget {
  const _PageFooter({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final footerText = Text(
          'Mano Ya · Instrumento Legal y Regulatorio',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: ManoYaColors.muted),
        );
        final pageText = Text(
          'Página $page de 2',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ManoYaColors.muted,
            fontWeight: FontWeight.w700,
          ),
        );

        if (constraints.maxWidth < 520) {
          return Column(
            children: [
              const Divider(height: 1, color: ManoYaColors.border),
              const SizedBox(height: AppSpacing.sm),
              footerText,
              const SizedBox(height: AppSpacing.xs),
              pageText,
            ],
          );
        }

        return Row(
          children: [
            const Expanded(
              child: Divider(height: 1, color: ManoYaColors.border),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: footerText,
            ),
            pageText,
          ],
        );
      },
    );
  }
}
