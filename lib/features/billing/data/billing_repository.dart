import 'package:uuid/uuid.dart';

import '../domain/charge.dart';

/// Repositorio de cobros (datos en memoria hasta integrar Supabase).
///
/// Mantiene la lista de solicitudes de cobro durante la sesión y expone las
/// operaciones del flujo de pago: crear, notificar pago (cliente) y confirmar
/// pago recibido (trabajador), además del manejo de cuotas/hitos.
class BillingRepository {
  final List<Charge> _charges = _seed();

  /// Lista todas las solicitudes de cobro (más recientes primero).
  Future<List<Charge>> list() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final copy = List<Charge>.from(_charges);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  /// Busca un cobro por su id.
  Future<Charge?> getById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    for (final charge in _charges) {
      if (charge.id == id) return charge;
    }
    return null;
  }

  /// Crea una nueva solicitud de cobro con su plan de cuotas.
  Future<Charge> create({
    required String concept,
    required String workerName,
    required String clientName,
    required double total,
    required String bankInfo,
    String? clientEmail,
    int installmentCount = 1,
    int spacingDays = 30,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now();
    final charge = Charge(
      id: const Uuid().v4().substring(0, 8),
      concept: concept,
      workerName: workerName,
      clientName: clientName,
      clientEmail: clientEmail,
      total: total,
      bankInfo: bankInfo,
      createdAt: now,
      status: ChargeStatus.pending,
      installments: _buildInstallments(
        total: total,
        count: installmentCount,
        spacingDays: spacingDays,
        start: now,
      ),
    );
    _charges.add(charge);
    return charge;
  }

  /// El cliente notifica que realizó el pago.
  Future<Charge> notifyPayment(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _update(id, (charge) {
      return charge.copyWith(status: ChargeStatus.clientNotified);
    });
  }

  /// El trabajador confirma el pago recibido. Marca todas las cuotas como
  /// pagadas y deja el trabajo en estado "Pagado / Completado".
  Future<Charge> confirmPayment(String id, {String? receiptPath}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _update(id, (charge) {
      final paidInstallments = charge.installments
          .map((i) => i.copyWith(paid: true))
          .toList();
      return charge.copyWith(
        status: ChargeStatus.paid,
        installments: paidInstallments,
        receiptPath: receiptPath,
        paidAt: DateTime.now(),
      );
    });
  }

  /// Reemplaza un cobro en memoria aplicando la transformación indicada.
  Charge _update(String id, Charge Function(Charge) transform) {
    final index = _charges.indexWhere((c) => c.id == id);
    if (index == -1) {
      throw StateError('Cobro no encontrado: $id');
    }
    final updated = transform(_charges[index]);
    _charges[index] = updated;
    return updated;
  }

  /// Divide el monto total en cuotas/hitos equitativos. La última cuota
  /// absorbe el redondeo para que la suma coincida con el total.
  List<Installment> _buildInstallments({
    required double total,
    required int count,
    required int spacingDays,
    required DateTime start,
  }) {
    if (count <= 1) {
      return [
        Installment(
          id: 'cuota-1',
          label: 'Pago único',
          amount: total,
          dueDate: start,
        ),
      ];
    }

    final base = double.parse((total / count).toStringAsFixed(2));
    final installments = <Installment>[];
    double accumulated = 0;

    for (var i = 0; i < count; i++) {
      // La última cuota se ajusta para cuadrar el total exacto.
      final amount = (i == count - 1)
          ? double.parse((total - accumulated).toStringAsFixed(2))
          : base;
      accumulated += amount;
      installments.add(
        Installment(
          id: 'cuota-${i + 1}',
          label: 'Cuota ${i + 1}',
          amount: amount,
          dueDate: start.add(Duration(days: spacingDays * i)),
        ),
      );
    }
    return installments;
  }

  /// Datos de ejemplo para el MVP.
  static List<Charge> _seed() {
    final now = DateTime.now();
    return [
      Charge(
        id: 'demo0001',
        concept: 'Remodelación de baño completo',
        workerName: 'Carlos Ramírez',
        clientName: 'Laura Gómez',
        clientEmail: 'laura.gomez@example.com',
        total: 1200,
        bankInfo:
            'Banco de Venezuela · Ahorros ****1234\nPago móvil: 0412-1112233',
        createdAt: now.subtract(const Duration(days: 20)),
        status: ChargeStatus.clientNotified,
        installments: [
          Installment(
            id: 'cuota-1',
            label: 'Anticipo',
            amount: 300,
            dueDate: now.subtract(const Duration(days: 20)),
            paid: true,
          ),
          Installment(
            id: 'cuota-2',
            label: 'Cuota 2',
            amount: 300,
            dueDate: now.subtract(const Duration(days: 5)),
            paid: true,
          ),
          Installment(
            id: 'cuota-3',
            label: 'Cuota 3',
            amount: 300,
            dueDate: now.add(const Duration(days: 10)),
          ),
          Installment(
            id: 'cuota-4',
            label: 'Cuota final',
            amount: 300,
            dueDate: now.add(const Duration(days: 25)),
          ),
        ],
      ),
      Charge(
        id: 'demo0002',
        concept: 'Reparación de instalación eléctrica',
        workerName: 'Luis Pérez',
        clientName: 'Mario Díaz',
        clientEmail: 'mario.diaz@example.com',
        total: 350,
        bankInfo: 'Pago móvil: 0412-3334455',
        createdAt: now.subtract(const Duration(days: 2)),
        status: ChargeStatus.pending,
        installments: [
          Installment(
            id: 'cuota-1',
            label: 'Pago único',
            amount: 350,
            dueDate: now.add(const Duration(days: 3)),
          ),
        ],
      ),
      Charge(
        id: 'demo0003',
        concept: 'Pintura y acabado de sala',
        workerName: 'Luis Pérez',
        clientName: 'Gabriela Torres',
        clientEmail: 'gabriela.torres@example.com',
        total: 240,
        bankInfo: 'Pago móvil: 0412-5556677',
        createdAt: now.subtract(const Duration(days: 8)),
        status: ChargeStatus.paid,
        installments: [
          Installment(
            id: 'cuota-1',
            label: 'Pago único',
            amount: 240,
            dueDate: now.subtract(const Duration(days: 8)),
            paid: true,
          ),
        ],
        paidAt: now.subtract(const Duration(days: 6)),
      ),
    ];
  }
}
