enum DemoPaymentStatus { pending, paid }

class DemoPaymentSplit {
  static const int commissionPercent = 15;

  final int totalMinor;
  final int platformFeeMinor;
  final int workerNetMinor;

  const DemoPaymentSplit({
    required this.totalMinor,
    required this.platformFeeMinor,
    required this.workerNetMinor,
  });

  factory DemoPaymentSplit.calculate(int totalMinor) {
    if (totalMinor <= 0) {
      throw ArgumentError.value(totalMinor, 'totalMinor', 'Debe ser positivo');
    }

    final feeMinor = (totalMinor * commissionPercent + 50) ~/ 100;
    return DemoPaymentSplit(
      totalMinor: totalMinor,
      platformFeeMinor: feeMinor,
      workerNetMinor: totalMinor - feeMinor,
    );
  }
}

class DemoPayment {
  final String id;
  final String concept;
  final String workerName;
  final String workerEmail;
  final String workerBank;
  final String workerPhone;
  final String workerDocument;
  final String clientName;
  final String clientEmail;
  final DemoPaymentSplit split;
  final DemoPaymentStatus status;
  final DateTime createdAt;
  final String? simulationBank;
  final String? simulationReference;
  final DateTime? simulationCompletedAt;
  final DateTime? paidAt;
  final String? paymentReference;

  const DemoPayment({
    required this.id,
    required this.concept,
    required this.workerName,
    required this.workerEmail,
    required this.workerBank,
    required this.workerPhone,
    required this.workerDocument,
    required this.clientName,
    required this.clientEmail,
    required this.split,
    required this.status,
    required this.createdAt,
    this.simulationBank,
    this.simulationReference,
    this.simulationCompletedAt,
    this.paidAt,
    this.paymentReference,
  });

  DemoPayment copyWith({
    DemoPaymentStatus? status,
    String? simulationBank,
    String? simulationReference,
    DateTime? simulationCompletedAt,
    DateTime? paidAt,
    String? paymentReference,
  }) {
    return DemoPayment(
      id: id,
      concept: concept,
      workerName: workerName,
      workerEmail: workerEmail,
      workerBank: workerBank,
      workerPhone: workerPhone,
      workerDocument: workerDocument,
      clientName: clientName,
      clientEmail: clientEmail,
      split: split,
      status: status ?? this.status,
      createdAt: createdAt,
      simulationBank: simulationBank ?? this.simulationBank,
      simulationReference: simulationReference ?? this.simulationReference,
      simulationCompletedAt:
          simulationCompletedAt ?? this.simulationCompletedAt,
      paidAt: paidAt ?? this.paidAt,
      paymentReference: paymentReference ?? this.paymentReference,
    );
  }
}
