import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../domain/demo_payment.dart';

final paymentsDemoRepositoryProvider = Provider<PaymentsDemoRepository>(
  (ref) => PaymentsDemoRepository(),
);

class PaymentsDemoRepository {
  PaymentsDemoRepository()
    : _payments = [
        _payment(
          id: 'demo-pending-001',
          concept: 'Reparación de instalación eléctrica',
          workerName: 'Luis Pérez',
          workerEmail: 'luis.perez@ejemplo.demo',
          workerBank: 'Banco de Venezuela',
          workerPhone: '0000000000',
          workerDocument: 'V-00.000.001',
          clientName: 'Mario Díaz',
          clientEmail: 'mario.diaz@ejemplo.demo',
          amountMinor: 35000,
        ),
        _payment(
          id: 'demo-pending-002',
          concept: 'Instalación de aire acondicionado',
          workerName: 'Ana Castillo',
          workerEmail: 'ana.castillo@ejemplo.demo',
          workerBank: 'Banco Mercantil',
          workerPhone: '0000000000',
          workerDocument: 'V-00.000.002',
          clientName: 'Sofía Herrera',
          clientEmail: 'sofia.herrera@ejemplo.demo',
          amountMinor: 68000,
        ),
        _payment(
          id: 'demo-pending-003',
          concept: 'Mantenimiento de tuberías',
          workerName: 'José Ramírez',
          workerEmail: 'jose.ramirez@ejemplo.demo',
          workerBank: 'Banco Provincial',
          workerPhone: '0000000000',
          workerDocument: 'V-00.000.003',
          clientName: 'Valentina Rojas',
          clientEmail: 'valentina.rojas@ejemplo.demo',
          amountMinor: 22500,
        ),
      ];

  final List<DemoPayment> _payments;

  List<DemoPayment> get payments => List.unmodifiable(_payments);

  DemoPayment? getById(String id) {
    for (final payment in _payments) {
      if (payment.id == id) return payment;
    }
    return null;
  }

  DemoPayment markAsPaid(String id) {
    final index = _payments.indexWhere((payment) => payment.id == id);
    if (index == -1) {
      throw StateError('Pago de prueba no encontrado: $id');
    }

    final payment = _payments[index];
    if (payment.status != DemoPaymentStatus.pending) {
      throw StateError('Este pago de prueba ya fue procesado.');
    }
    if (payment.simulationCompletedAt == null ||
        payment.simulationReference == null) {
      throw StateError('Primero completa el pago móvil de prueba.');
    }

    final paidPayment = payment.copyWith(
      status: DemoPaymentStatus.paid,
      paidAt: DateTime.now(),
      paymentReference: payment.simulationReference,
    );
    _payments[index] = paidPayment;
    return paidPayment;
  }

  DemoPayment completePaymentSimulation(String id, {required String bank}) {
    final index = _payments.indexWhere((payment) => payment.id == id);
    if (index == -1) {
      throw StateError('Pago de prueba no encontrado: $id');
    }
    final payment = _payments[index];
    if (payment.status != DemoPaymentStatus.pending) {
      throw StateError('Este pago de prueba ya fue procesado.');
    }
    if (payment.simulationCompletedAt != null) {
      throw StateError('El pago móvil de prueba ya fue completado.');
    }
    if (bank.trim().isEmpty) {
      throw ArgumentError.value(bank, 'bank', 'Selecciona un banco de origen');
    }

    final completedPayment = payment.copyWith(
      simulationBank: bank,
      simulationReference: 'DEMO-${const Uuid().v4().substring(0, 8)}',
      simulationCompletedAt: DateTime.now(),
    );
    _payments[index] = completedPayment;
    return completedPayment;
  }

  static DemoPayment _payment({
    required String id,
    required String concept,
    required String workerName,
    required String workerEmail,
    required String workerBank,
    required String workerPhone,
    required String workerDocument,
    required String clientName,
    required String clientEmail,
    required int amountMinor,
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
      split: DemoPaymentSplit.calculate(amountMinor),
      status: DemoPaymentStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    );
  }
}
