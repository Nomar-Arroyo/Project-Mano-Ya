/// Estados posibles de una solicitud de cobro.
enum ChargeStatus {
  /// El trabajador envió el cobro; el cliente aún no notifica el pago.
  pending,

  /// El cliente notificó el pago; falta que el trabajador lo confirme.
  clientNotified,

  /// El trabajador confirmó el pago: trabajo pagado / completado.
  paid,
}

/// Cuota o hito del pago. Los proyectos grandes (> $800) pueden dividirse
/// en varias cuotas, cada una con su estado (pagada / pendiente).
class Installment {
  final String id;
  final String label;
  final double amount;
  final DateTime dueDate;
  final bool paid;

  const Installment({
    required this.id,
    required this.label,
    required this.amount,
    required this.dueDate,
    this.paid = false,
  });

  Installment copyWith({bool? paid}) => Installment(
    id: id,
    label: label,
    amount: amount,
    dueDate: dueDate,
    paid: paid ?? this.paid,
  );
}

/// Solicitud de cobro que el trabajador envía al cliente con los datos de
/// pago (banco/pago móvil), el monto total y el desglose de cuotas.
class Charge {
  final String id;
  final String concept;
  final String workerName;
  final String clientName;

  /// Correo del cliente para enviarle el recibo/reporte de pago.
  final String? clientEmail;
  final double total;
  final String bankInfo;
  final DateTime createdAt;
  final ChargeStatus status;
  final List<Installment> installments;

  /// Ruta del recibo PDF generado al confirmar el pago.
  final String? receiptPath;

  /// Fecha en que el trabajador confirmó el pago.
  final DateTime? paidAt;

  const Charge({
    required this.id,
    required this.concept,
    required this.workerName,
    required this.clientName,
    required this.total,
    required this.bankInfo,
    required this.createdAt,
    required this.status,
    this.clientEmail,
    this.installments = const [],
    this.receiptPath,
    this.paidAt,
  });

  /// Monto ya pagado (suma de cuotas pagadas).
  double get paidAmount =>
      installments.where((i) => i.paid).fold(0.0, (sum, i) => sum + i.amount);

  /// Monto pendiente por pagar.
  double get pendingAmount => total - paidAmount;

  /// Indica si el cobro está dividido en cuotas/hitos.
  bool get hasInstallments => installments.isNotEmpty;

  /// Etiqueta legible del estado para mostrar en la interfaz.
  String get statusLabel {
    switch (status) {
      case ChargeStatus.pending:
        return 'Pendiente de pago';
      case ChargeStatus.clientNotified:
        return 'Pago notificado por el cliente';
      case ChargeStatus.paid:
        return 'Trabajo Pagado / Completado';
    }
  }

  /// Devuelve una copia con los campos indicados actualizados.
  Charge copyWith({
    ChargeStatus? status,
    List<Installment>? installments,
    String? receiptPath,
    DateTime? paidAt,
    String? clientEmail,
  }) {
    return Charge(
      id: id,
      concept: concept,
      workerName: workerName,
      clientName: clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      total: total,
      bankInfo: bankInfo,
      createdAt: createdAt,
      status: status ?? this.status,
      installments: installments ?? this.installments,
      receiptPath: receiptPath ?? this.receiptPath,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}
