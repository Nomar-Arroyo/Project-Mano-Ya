import '../../../../core/services/supabase_service.dart';
import '../domain/worker_recommendation.dart';

class RecommendationRepository {
  Future<WorkerRecommendationResult> recommend({
    required String description,
    String? city,
  }) async {
    final client = SupabaseService.client;
    if (client == null || client.auth.currentSession == null) {
      throw StateError(
        'Inicia sesión para buscar recomendaciones de trabajadores.',
      );
    }

    final response = await client.functions.invoke(
      'recommend-workers',
      body: {
        'description': description.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      },
    );
    return WorkerRecommendationResult.fromJson(response.data);
  }
}
