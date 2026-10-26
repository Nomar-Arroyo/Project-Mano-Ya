import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/features/assistant/domain/worker_recommendation.dart';
import 'package:mano_ya/features/workers/domain/worker.dart';

void main() {
  group('WorkerRecommendationResult', () {
    test('lee recomendaciones reales y sus motivos', () {
      final result = WorkerRecommendationResult.fromJson({
        'ok': true,
        'clarification_required': false,
        'category': 'Mantenimiento',
        'subcategory': 'Plomería',
        'recommendations': [
          {
            'id': 'worker-listing-1',
            'name': 'María Pérez',
            'category': 'Mantenimiento',
            'subcategory': 'Plomería',
            'city': 'Caracas',
            'phone': '+584121234567',
            'avatar_url': null,
            'bio': 'Reparación de tuberías',
            'rating': 4.8,
            'reviews_count': 12,
            'status': 'available',
            'reason': 'Coincide con Plomería y figura disponible.',
          },
        ],
      });

      expect(result.clarificationRequired, isFalse);
      expect(result.category, 'Mantenimiento');
      expect(result.recommendations, hasLength(1));
      expect(result.recommendations.single.reason, contains('disponible'));
      expect(
        result.recommendations.single.worker.status,
        WorkerStatus.available,
      );
      expect(result.recommendations.single.worker.rating, 4.8);
      expect(result.recommendations.single.worker.identityVerified, isFalse);
      expect(result.recommendations.single.worker.workGuaranteed, isFalse);
    });

    test('conserva la pregunta de aclaración sin inventar recomendaciones', () {
      final result = WorkerRecommendationResult.fromJson({
        'ok': true,
        'clarification_required': true,
        'question': '¿Qué tipo de reparación necesitas?',
        'recommendations': [],
      });

      expect(result.clarificationRequired, isTrue);
      expect(result.question, '¿Qué tipo de reparación necesitas?');
      expect(result.recommendations, isEmpty);
    });

    test('rechaza una respuesta malformada', () {
      expect(
        () => WorkerRecommendationResult.fromJson({
          'ok': true,
          'clarification_required': false,
          'recommendations': [
            {'name': 'Registro incompleto'},
          ],
        }),
        throwsFormatException,
      );
    });
  });
}
