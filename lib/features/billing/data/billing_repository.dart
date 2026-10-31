import 'package:uuid/uuid.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/billable_job.dart';
import '../domain/charge.dart';

class BillingRepository {
  final List<Charge> _charges = _seed();

  static const _billableStatuses = {'accepted', 'in_progress', 'completed'};

  static const _demoJobs = [
    BillableJob(
      id: 'demo-job-1',
      title: 'Reparación de baño',
      clientId: 'demo-client-1',
      clientName: 'Cliente de demostración',
      workerId: 'demo-worker-1',
      workerName: 'Trabajador de demostración',
      price: 1200,
      status: 'in_progress',
    ),
  ];

  Future<List<Charge>> list() async {
    final client = SupabaseService.client;
    if (client != null) {
      if (client.auth.currentUser == null) {
        throw StateError('Inicia sesión para consultar tus cobros.');
      }
      final rows = await client
          .from('charges')
          .select('*, installments(*)')
          .order('created_at', ascending: false);
      return rows
          .map((row) => Charge.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    }

    await Future.delayed(const Duration(milliseconds: 300));
    final copy = List<Charge>.from(_charges);
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }

  Future<List<BillableJob>> listBillableJobs() async {
    final client = SupabaseService.client;
    if (client == null) return _demoJobs;
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Inicia sesión para seleccionar un trabajo.');
    }

    final rows = await client
        .from('jobs')
        .select(
          'id,title,client_id,client_name,worker_id,worker_name,price,status',
        )
        .eq('worker_id', user.id)
        .order('created_at', ascending: false);
    return rows
        .map((row) => BillableJob.fromJson(Map<String, dynamic>.from(row)))
        .where((job) => _billableStatuses.contains(job.status))
        .toList();
  }

  Future<Charge?> getById(String id) async {
    final client = SupabaseService.client;
    if (client != null) {
      if (client.auth.currentUser == null) {
        throw StateError('Inicia sesión para consultar este cobro.');
      }
      final row = await client
          .from('charges')
          .select('*, installments(*)')
          .eq('id', id)
          .maybeSingle();
      return row == null
          ? null
          : Charge.fromJson(Map<String, dynamic>.from(row));
    }

    await Future.delayed(const Duration(milliseconds: 200));
    for (final charge in _charges) {
      if (charge.id == id) return charge;
    }
    return null;
  }

  Future<Charge> create({
    required String jobId,
    required String concept,
    required double total,
    required String bankInfo,
    int installmentCount = 1,
    int spacingDays = 30,
  }) async {
    final client = SupabaseService.client;
    if (client != null) {
      if (client.auth.currentUser == null) {
        throw StateError('Inicia sesión para crear una solicitud de cobro.');
      }
      final id = await client.rpc(
        'create_charge_with_installments',
        params: {
          'p_job_id': jobId,
          'p_concept': concept.trim(),
          'p_total': total,
          'p_bank_info': bankInfo.trim(),
          'p_installment_count': installmentCount,
          'p_spacing_days': spacingDays,
        },
      );
      if (id is! String || id.isEmpty) {
        throw const FormatException(
          'Supabase no devolvió el identificador del cobro.',
        );
      }
      final charge = await getById(id);
      if (charge == null) {
        throw StateError('No se pudo volver a leer el cobro recién creado.');
      }
      return charge;
    }

    await Future.delayed(const Duration(milliseconds: 400));
    final job = _demoJobs.where((item) => item.id == jobId);
    if (job.isEmpty) {
      throw StateError('Selecciona un trabajo válido para crear el cobro.');
    }
    final now = DateTime.now();
    final charge = Charge(
      id: const Uuid().v4().substring(0, 8),
      jobId: jobId,
      concept: concept,
      workerName: job.first.workerName,
      clientName: job.first.clientName,
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

  Future<Charge> notifyPayment(String id) async {
    final client = SupabaseService.client;
    if (client != null) {
      if (client.auth.currentUser == null) {
        throw StateError('Inicia sesión para notificar el pago.');
      }
      await client.rpc('notify_charge_payment', params: {'p_charge_id': id});
      final updated = await getById(id);
      if (updated == null) {
        throw StateError('No se pudo volver a leer el cobro actualizado.');
      }
      return updated;
    }

    await Future.delayed(const Duration(milliseconds: 300));
    return _update(id, (charge) {
      if (charge.status != ChargeStatus.pending || charge.pendingAmount <= 0) {
        throw StateError('Este cobro no está pendiente de notificación.');
      }
      return charge.copyWith(status: ChargeStatus.clientNotified);
    });
  }

  Future<Charge> confirmPayment(String id) async {
    final client = SupabaseService.client;
    if (client != null) {
      if (client.auth.currentUser == null) {
        throw StateError('Inicia sesión para confirmar el pago recibido.');
      }
      await client.rpc('confirm_charge_payment', params: {'p_charge_id': id});
      final updated = await getById(id);
      if (updated == null) {
        throw StateError('No se pudo volver a leer el cobro actualizado.');
      }
      return updated;
    }

    await Future.delayed(const Duration(milliseconds: 400));
    return _update(id, (charge) {
      if (charge.status != ChargeStatus.clientNotified) {
        throw StateError('El cliente aún no ha reportado el pago.');
      }
      final nextIndex = charge.installments.indexWhere((item) => !item.paid);
      if (nextIndex == -1) {
        throw StateError('No quedan cuotas pendientes por confirmar.');
      }
      final paidInstallments = List<Installment>.from(charge.installments);
      paidInstallments[nextIndex] = paidInstallments[nextIndex].copyWith(
        paid: true,
      );
      final completed = paidInstallments.every((item) => item.paid);
      return charge.copyWith(
        status: completed ? ChargeStatus.paid : ChargeStatus.pending,
        installments: paidInstallments,
        paidAt: completed ? DateTime.now() : null,
        clearPaidAt: !completed,
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
