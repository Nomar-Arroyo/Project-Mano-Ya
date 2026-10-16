import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// Representa una zona/ciudad devuelta por el autocompletado.
/// Guarda el nombre legible y las coordenadas para calcular cercanía.
class Place {
  final String displayName;
  final double latitude;
  final double longitude;

  const Place({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}

/// Servicio de geolocalización.
///
/// Usa la API pública de OpenStreetMap (Nominatim) para autocompletar
/// zonas/ciudades del usuario y utiliza la fórmula de Haversine para
/// estimar la distancia entre el usuario y los trabajadores cercanos.
///
/// Si la petición falla (sin internet, límite de uso de la API, etc.)
/// se recurre a un catálogo local para no romper la experiencia.
class MapsService {
  static const String _nominatimBase =
      'https://nominatim.openstreetmap.org/search';

  /// Zonas de respaldo para modo offline / demo (Valle del Cauca y capitales).
  static const List<Place> _fallbackPlaces = [
    Place(
      displayName: 'Cali, Valle del Cauca, Colombia',
      latitude: 3.4516,
      longitude: -76.5320,
    ),
    Place(
      displayName: 'Palmira, Valle del Cauca, Colombia',
      latitude: 3.5394,
      longitude: -76.3036,
    ),
    Place(
      displayName: 'Buenaventura, Valle del Cauca, Colombia',
      latitude: 3.8801,
      longitude: -77.0312,
    ),
    Place(
      displayName: 'Bogotá, Colombia',
      latitude: 4.7110,
      longitude: -74.0721,
    ),
    Place(
      displayName: 'Medellín, Antioquia, Colombia',
      latitude: 6.2442,
      longitude: -75.5812,
    ),
  ];

  /// Autocompleta zonas/ciudades a partir de un texto escrito por el usuario.
  /// Devuelve como máximo 5 resultados (restricción de Nominatim).
  static Future<List<Place>> autocomplete(String query) async {
    final text = query.trim();
    if (text.length < 3) return const [];

    try {
      final uri = Uri.parse(_nominatimBase).replace(
        queryParameters: {
          'q': text,
          'format': 'json',
          'addressdetails': '1',
          'limit': '5',
          'countrycodes': 'co',
        },
      );
      final res = await http
          .get(
            uri,
            headers: {
              // Nominatim exige un User-Agent identificable.
              'User-Agent': 'ManoYaApp/1.0 (contacto@manoya.app)',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List<dynamic>;
        final places = data.map((item) {
          final map = item as Map<String, dynamic>;
          return Place(
            displayName: map['display_name'] as String? ?? text,
            latitude: double.tryParse(map['lat']?.toString() ?? '') ?? 0,
            longitude: double.tryParse(map['lon']?.toString() ?? '') ?? 0,
          );
        }).toList();
        if (places.isNotEmpty) return places;
      }
    } catch (_) {
      // Silencioso: caemos al respaldo local.
    }

    // Respaldo local si no hay conexión o la API no responde.
    final lower = text.toLowerCase();
    return _fallbackPlaces
        .where((p) => p.displayName.toLowerCase().contains(lower))
        .toList();
  }

  /// Calcula la distancia aproximada en kilómetros entre dos coordenadas
  /// usando la fórmula de Haversine.
  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0;
    double toRadians(double degrees) => degrees * (math.pi / 180.0);

    final dLat = toRadians(lat2 - lat1);
    final dLon = toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRadians(lat1)) *
            math.cos(toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }
}
