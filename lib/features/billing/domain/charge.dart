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

  factory Installment.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    if (amount is! num) {
      throw const FormatException('El monto de la cuota no es válido.');
    }
    if (json['paid'] is! bool) {
      throw const FormatException('El estado de la cuota no es válido.');
    }
    return Installment(
      id: _requiredString(json, 'id'),
      label: _requiredString(json, 'label'),
      amount: amount.toDouble(),
      dueDate: DateTime.parse(_requiredString(json, 'due_date')),
      paid: json['paid'] as bool,
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('El campo "$key" de la cuota no es válido.');
    }
    return value;
  }

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
  final String? jobId;
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
    this.jobId,
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

  factory Charge.fromJson(Map<String, dynamic> json) {
    final installmentsJson = json['installments'];
    if (installmentsJson is! List) {
      throw const FormatException('El cobro no incluye una lista de cuotas.');
    }
    final statusValue = json['status'];
    final ChargeStatus? status = switch (statusValue) {
      'pending' => ChargeStatus.pending,
      'client_notified' => ChargeStatus.clientNotified,
      'paid' => ChargeStatus.paid,
      _ => null,
    };
    if (status == null) {
      throw FormatException('El estado del cobro "$statusValue" no es válido.');
    }
    final totalValue = json['total'];
    if (totalValue is! num) {
      throw const FormatException('El monto del cobro no es válido.');
    }

    return Charge(
      id: _requiredString(json, 'id'),
      jobId: json['job_id'] as String?,
      concept: _requiredString(json, 'concept'),
      workerName: _requiredString(json, 'worker_name'),
      clientName: _requiredString(json, 'client_name'),
      clientEmail: json['client_email'] as String?,
      total: totalValue.toDouble(),
      bankInfo: _requiredString(json, 'bank_info'),
      createdAt: DateTime.parse(_requiredString(json, 'created_at')),
      status: status,
      installments: installmentsJson
          .map(
            (value) =>
                Installment.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList(),
      receiptPath: json['receipt_path'] as String?,
      paidAt: json['paid_at'] == null
          ? null
          : DateTime.parse(json['paid_at'] as String),
    );
  }

  String get databaseStatus => switch (status) {
    ChargeStatus.pending => 'pending',
    ChargeStatus.clientNotified => 'client_notified',
    ChargeStatus.paid => 'paid',
  };

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('El campo "$key" del cobro no es válido.');
    }
    return value;
  }

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
    bool clearPaidAt = false,
  }) {
    return Charge(
      id: id,
      jobId: jobId,
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
      paidAt: clearPaidAt ? null : paidAt ?? this.paidAt,
    );
  }
}
