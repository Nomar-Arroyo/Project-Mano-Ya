import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/billing_repository.dart';
import '../domain/billable_job.dart';
import '../domain/charge.dart';

/// Repositorio de cobros persistentes; usa datos demo solo sin Supabase.
final billingRepositoryProvider = Provider<BillingRepository>(
  (ref) => BillingRepository(),
);

final billableJobsProvider = FutureProvider.autoDispose<List<BillableJob>>((
  ref,
) async {
  return ref.read(billingRepositoryProvider).listBillableJobs();
});

/// Lista de solicitudes de cobro.
final chargesListProvider = FutureProvider.autoDispose<List<Charge>>((
  ref,
) async {
  return ref.read(billingRepositoryProvider).list();
});

/// Detalle de una solicitud de cobro por id.
final chargeByIdProvider = FutureProvider.autoDispose.family<Charge?, String>((
  ref,
  id,
) async {
  return ref.read(billingRepositoryProvider).getById(id);
});
