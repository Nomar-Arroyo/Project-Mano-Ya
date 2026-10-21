/// Modelo de dominio del perfil extendido del trabajador.
///
/// Agrupa la información que el mega-prompt define para el rol Trabajador:
/// identidad, portafolio express, datos de cobro y estado de disponibilidad.
library;

/// Fotografía de un trabajo previo que forma parte del portafolio express.
///
/// El megaprompt limita el portafolio a entre 3 y 5 fotos; esa regla se aplica
/// en la capa de presentación, aquí solo se modela la información.
class PortfolioItem {
  /// Identificador único de la foto dentro del portafolio.
  final String id;

  /// URL pública de la imagen (Supabase Storage) o ruta local en modo mock.
  final String imageUrl;

  /// Texto corto que describe el trabajo realizado.
  final String caption;

  /// Posición dentro de la galería (0 = primera foto).
  final int position;

  const PortfolioItem({
    required this.id,
    required this.imageUrl,
    this.caption = '',
    this.position = 0,
  });

  /// Copia inmutable con los campos indicados.
  PortfolioItem copyWith({
    String? id,
    String? imageUrl,
    String? caption,
    int? position,
  }) {
    return PortfolioItem(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
      position: position ?? this.position,
    );
  }

  /// Convierte el modelo a un mapa JSON (para Supabase).
  Map<String, dynamic> toJson() => {
    'id': id,
    'image_url': imageUrl,
    'caption': caption,
    'position': position,
  };

  /// Construye el modelo a partir de una fila de Supabase.
  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    return PortfolioItem(
      id: json['id']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Datos financieros del trabajador: dónde y cómo recibe el dinero.
///
/// Corresponde al punto 4 del perfil del trabajador en el mega-prompt
/// ("Configuración de cuentas bancarias o métodos de pago preferidos").
class PayoutInfo {
  /// Método de pago elegido (Nequi, Daviplata, transferencia bancaria, etc.).
  final String method;

  /// Nombre del titular de la cuenta.
  final String accountHolder;

  /// Número de cuenta o teléfono asociado al método de pago.
  final String accountNumber;

  /// Banco de la cuenta (opcional, solo para transferencias).
  final String? bankName;

  const PayoutInfo({
    this.method = '',
    this.accountHolder = '',
    this.accountNumber = '',
    this.bankName,
  });

  /// Datos vacíos (el trabajador aún no ha configurado su cobro).
  static const PayoutInfo empty = PayoutInfo();

  /// Indica si ya hay información de cobro suficiente para cobrar.
  bool get isConfigured =>
      method.trim().isNotEmpty && accountNumber.trim().isNotEmpty;

  /// Copia inmutable con los campos indicados.
  PayoutInfo copyWith({
    String? method,
    String? accountHolder,
    String? accountNumber,
    String? bankName,
  }) {
    return PayoutInfo(
      method: method ?? this.method,
      accountHolder: accountHolder ?? this.accountHolder,
      accountNumber: accountNumber ?? this.accountNumber,
      bankName: bankName ?? this.bankName,
    );
  }

  /// Convierte el modelo a un mapa JSON (para Supabase).
  Map<String, dynamic> toJson() => {
    'payout_method': method,
    'payout_account_holder': accountHolder,
    'payout_account_number': accountNumber,
    'payout_bank_name': bankName,
  };

  /// Construye el modelo a partir de una fila de Supabase.
  factory PayoutInfo.fromJson(Map<String, dynamic> json) {
    return PayoutInfo(
      method: json['payout_method']?.toString() ?? '',
      accountHolder: json['payout_account_holder']?.toString() ?? '',
      accountNumber: json['payout_account_number']?.toString() ?? '',
      bankName: json['payout_bank_name']?.toString(),
    );
  }
}

/// Perfil completo del trabajador con los datos extendidos del mega-prompt.
class WorkerProfile {
  /// Id del usuario propietario del perfil.
  final String ownerId;

  /// Nombre completo mostrado en la app.
  final String displayName;

  /// Teléfono de contacto.
  final String? phone;

  /// Zona o ciudad donde opera.
  final String? city;

  /// URL de la foto de perfil.
  final String? avatarUrl;

  /// Bio o presentación breve de su experiencia.
  final String bio;

  /// Oficio principal (categoría del catálogo).
  final String category;

  /// Fotografías del portafolio express.
  final List<PortfolioItem> portfolio;

  /// Datos de cobro configurados.
  final PayoutInfo payout;

  /// Indica si el trabajador está disponible hoy.
  final bool availableToday;

  /// Identidad verificada por el equipo de Mano Ya.
  final bool identityVerified;

  /// Calificación promedio recibida.
  final double rating;

  /// Cantidad de reseñas recibidas.
  final int reviewsCount;

  const WorkerProfile({
    required this.ownerId,
    this.displayName = '',
    this.phone,
    this.city,
    this.avatarUrl,
    this.bio = '',
    this.category = '',
    this.portfolio = const [],
    this.payout = PayoutInfo.empty,
    this.availableToday = true,
    this.identityVerified = false,
    this.rating = 0,
    this.reviewsCount = 0,
  });

  /// Indica si el portafolio ya tiene al menos tres fotos (mínimo del prompt).
  bool get hasMinimumPortfolio => portfolio.length >= 3;

  /// Indica si el portafolio alcanzó el máximo de cinco fotos.
  bool get hasMaximumPortfolio => portfolio.length >= 5;

  /// Copia inmutable con los campos indicados.
  WorkerProfile copyWith({
    String? ownerId,
    String? displayName,
    String? phone,
    String? city,
    String? avatarUrl,
    String? bio,
    String? category,
    List<PortfolioItem>? portfolio,
    PayoutInfo? payout,
    bool? availableToday,
    bool? identityVerified,
    double? rating,
    int? reviewsCount,
  }) {
    return WorkerProfile(
      ownerId: ownerId ?? this.ownerId,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      category: category ?? this.category,
      portfolio: portfolio ?? this.portfolio,
      payout: payout ?? this.payout,
      availableToday: availableToday ?? this.availableToday,
      identityVerified: identityVerified ?? this.identityVerified,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
    );
  }

  /// Convierte el modelo a un mapa JSON (para Supabase).
  Map<String, dynamic> toJson() => {
    'id': ownerId,
    'full_name': displayName,
    'phone': phone,
    'city': city,
    'avatar_url': avatarUrl,
    'bio': bio,
    'category': category,
    'available_today': availableToday,
    ...payout.toJson(),
  };

  /// Construye el modelo a partir de una fila de Supabase.
  factory WorkerProfile.fromJson(Map<String, dynamic> json) {
    return WorkerProfile(
      ownerId: json['id']?.toString() ?? '',
      displayName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      city: json['city']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      bio: json['bio']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      availableToday: json['available_today'] as bool? ?? true,
      identityVerified: json['identity_verified'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewsCount: (json['reviews_count'] as num?)?.toInt() ?? 0,
      payout: PayoutInfo.fromJson(json),
    );
  }
}
