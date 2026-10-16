enum WorkerStatus { available, busy }

class Worker {
  final String id;
  final String name;
  final String category;
  final String subcategory;
  final String city;
  final bool identityVerified;
  final bool workGuaranteed;
  final WorkerStatus status;
  final bool availableToday;
  final double rating;
  final int reviewsCount;
  final String? avatarUrl;
  final String? phone;
  final String? bio;

  /// Coordenadas de la zona del trabajador (para calcular cercanía).
  final double? latitude;
  final double? longitude;

  const Worker({
    required this.id,
    required this.name,
    required this.category,
    required this.city,
    required this.identityVerified,
    required this.workGuaranteed,
    required this.status,
    this.subcategory = '',
    this.availableToday = true,
    this.rating = 0,
    this.reviewsCount = 0,
    this.avatarUrl,
    this.phone,
    this.bio,
    this.latitude,
    this.longitude,
  });

  bool get isAvailable => status == WorkerStatus.available;
}
