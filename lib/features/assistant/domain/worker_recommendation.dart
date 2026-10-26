import '../../workers/domain/worker.dart';

class WorkerRecommendation {
  final Worker worker;
  final String reason;

  const WorkerRecommendation({required this.worker, required this.reason});

  factory WorkerRecommendation.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('La recomendación no tiene un formato válido.');
    }

    final id = _requiredString(value, 'id');
    final name = _requiredString(value, 'name');
    final category = _requiredString(value, 'category');
    final city = _requiredString(value, 'city');
    final reason = _requiredString(value, 'reason');
    final status = value['status'] == 'available'
        ? WorkerStatus.available
        : WorkerStatus.busy;

    return WorkerRecommendation(
      worker: Worker(
        id: id,
        name: name,
        category: category,
        subcategory: _string(value, 'subcategory'),
        city: city,
        identityVerified: false,
        workGuaranteed: false,
        status: status,
        rating: _number(value, 'rating'),
        reviewsCount: _integer(value, 'reviews_count'),
        avatarUrl: _nullableString(value, 'avatar_url'),
        phone: _nullableString(value, 'phone'),
        bio: _nullableString(value, 'bio'),
      ),
      reason: reason,
    );
  }
}

class WorkerRecommendationResult {
  final bool clarificationRequired;
  final String? question;
  final String? message;
  final String? category;
  final String? subcategory;
  final List<WorkerRecommendation> recommendations;

  const WorkerRecommendationResult({
    required this.clarificationRequired,
    required this.recommendations,
    this.question,
    this.message,
    this.category,
    this.subcategory,
  });

  factory WorkerRecommendationResult.fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['ok'] != true) {
      final message = value is Map<String, dynamic>
          ? _string(value, 'error')
          : '';
      throw FormatException(
        message.isNotEmpty
            ? message
            : 'El servicio devolvió una respuesta no válida.',
      );
    }

    final rawRecommendations = value['recommendations'];
    if (rawRecommendations is! List) {
      throw const FormatException('No se recibieron recomendaciones válidas.');
    }

    return WorkerRecommendationResult(
      clarificationRequired: value['clarification_required'] == true,
      question: _nullableString(value, 'question'),
      message: _nullableString(value, 'message'),
      category: _nullableString(value, 'category'),
      subcategory: _nullableString(value, 'subcategory'),
      recommendations: rawRecommendations
          .map(WorkerRecommendation.fromJson)
          .toList(growable: false),
    );
  }
}

String _requiredString(Map<String, dynamic> value, String key) {
  final result = _string(value, key);
  if (result.isEmpty) {
    throw FormatException('Falta el dato requerido: $key.');
  }
  return result;
}

String _string(Map<String, dynamic> value, String key) {
  final item = value[key];
  return item is String ? item.trim() : '';
}

String? _nullableString(Map<String, dynamic> value, String key) {
  final result = _string(value, key);
  return result.isEmpty ? null : result;
}

double _number(Map<String, dynamic> value, String key) {
  final item = value[key];
  return item is num ? item.toDouble() : 0;
}

int _integer(Map<String, dynamic> value, String key) {
  final item = value[key];
  return item is num ? item.toInt() : 0;
}
