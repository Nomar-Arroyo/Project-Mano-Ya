/// Modelo de dominio de una dirección/zona guardada por el cliente.
///
/// Corresponde al punto 2 del perfil del cliente en el mega-prompt
/// ("Zonas / Direcciones Guardadas") y se alimenta del autocompletado
/// geolocalizado que ya ofrece la app.
library;

/// Dirección guardada con su etiqueta y coordenadas.
class SavedAddress {
  /// Identificador único de la dirección.
  final String id;

  /// Etiqueta corta que el usuario asigna ("Casa", "Oficina", "Bodega"...).
  final String label;

  /// Dirección legible completa.
  final String address;

  /// Latitud de la dirección.
  final double latitude;

  /// Longitud de la dirección.
  final double longitude;

  /// Indica si es la dirección principal del cliente.
  final bool isPrimary;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.isPrimary = false,
  });

  /// Copia inmutable con los campos indicados.
  SavedAddress copyWith({
    String? id,
    String? label,
    String? address,
    double? latitude,
    double? longitude,
    bool? isPrimary,
  }) {
    return SavedAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  /// Convierte el modelo a un mapa JSON (para Supabase).
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'is_primary': isPrimary,
  };

  /// Construye el modelo a partir de una fila de Supabase.
  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}
