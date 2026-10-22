import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

/// Representa una zona/ciudad devuelta por el autocompletado.
/// Guarda el nombre legible y las coordenadas para calcular cercanÃ­a.
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

/// Servicio de geolocalizaciÃ³n.
///
/// Usa la API pÃºblica de OpenStreetMap (Nominatim) para autocompletar
/// zonas/ciudades del usuario y utiliza la fÃ³rmula de Haversine para
/// estimar la distancia entre el usuario y los trabajadores cercanos.
///
/// Las consultas estÃ¡n limitadas a Venezuela (`countrycodes=ve`): el
/// servicio solo ofrece direcciones del paÃ­s, de modo que nunca aparecen
/// sugerencias de otros paÃ­ses.
///
/// Si la peticiÃ³n falla (sin internet, lÃ­mite de uso de la API, etc.)
/// se recurre a un catÃ¡logo local para no romper la experiencia.
class MapsService {
  static const String _nominatimBase =
      'https://nominatim.openstreetmap.org/search';

  /// CÃ³digo de paÃ­s de Venezuela para filtrar las respuestas de Nominatim.
  static const String countryCode = 've';

  /// Cantidad mÃ¡xima de sugerencias que se muestran al usuario.
  static const int maxSuggestions = 5;

  /// Zonas de respaldo para modo offline / demo (Venezuela).
  static const List<Place> _fallbackPlaces = [
    Place(
      displayName: 'Caracas, Distrito Capital, Venezuela',
      latitude: 10.4806,
      longitude: -66.9036,
    ),
    Place(
      displayName: 'Maracay, Aragua, Venezuela',
      latitude: 10.2469,
      longitude: -67.5958,
    ),
    Place(
      displayName: 'Valencia, Carabobo, Venezuela',
      latitude: 10.1620,
      longitude: -68.0077,
    ),
    Place(
      displayName: 'Barquisimeto, Lara, Venezuela',
      latitude: 10.0670,
      longitude: -69.3170,
    ),
    Place(
      displayName: 'Maracaibo, Zulia, Venezuela',
      latitude: 10.6427,
      longitude: -71.6125,
    ),
    Place(
      displayName: 'MÃ©rida, MÃ©rida, Venezuela',
      latitude: 8.5936,
      longitude: -71.1431,
    ),
  ];

  /// Autocompleta zonas/ciudades a partir de un texto escrito por el usuario.
  ///
  /// Devuelve como mÃ¡ximo 5 sugerencias, todas de Venezuela.
  static Future<List<Place>> autocomplete(String query) async {
    final text = query.trim();
    if (text.length < 3) return const [];

    try {
      final uri = Uri.parse(_nominatimBase).replace(
        queryParameters: {
          'q': text,
          'format': 'json',
          'addressdetails': '1',
          // Se piden mÃ¡s resultados de los necesarios porque despuÃ©s se
          // filtran los que no son localidades (calles y comercios).
          'limit': '15',
          // Solo Venezuela: nunca se muestran direcciones de otros paÃ­ses.
          'countrycodes': countryCode,
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
        final places = <Place>[];
        for (final item in data) {
          if (places.length >= maxSuggestions) break;
          final map = item as Map<String, dynamic>;
          // Doble filtro: se descarta cualquier resultado que no sea de
          // Venezuela, aunque Nominatim devuelva algo inesperado.
          if (!isInCountryPlace(map)) continue;
          // Y un tercero: solo interesan las localidades, no las calles,
          // los comercios ni los puntos de interÃ©s.
          if (!isLocalityPlace(map)) continue;
          places.add(
            Place(
              displayName: map['display_name'] as String? ?? text,
              latitude: double.tryParse(map['lat']?.toString() ?? '') ?? 0,
              longitude: double.tryParse(map['lon']?.toString() ?? '') ?? 0,
            ),
          );
        }
        if (places.isNotEmpty) return places;
      }
    } catch (_) {
      // Silencioso: caemos al respaldo local.
    }

    // Respaldo local si no hay conexiÃ³n o la API no responde.
    final lower = text.toLowerCase();
    return _fallbackPlaces
        .where((p) => p.displayName.toLowerCase().contains(lower))
        .toList();
  }

  /// Tipos de lugar que se consideran una ciudad, pueblo o zona habitable.
  ///
  /// Nominatim devuelve muchos resultados que son calles, comercios o
  /// puntos de interÃ©s (por ejemplo "Calle Cali" en Caracas). Solo se
  /// aceptan las localidades para que el autocompletado muestre sitios
  /// donde realmente se puede contratar el servicio.
  static const Set<String> _localityTypes = {
    'city',
    'town',
    'village',
    'hamlet',
    'locality',
    'suburb',
    'neighbourhood',
    'city_district',
    'borough',
    'municipality',
    'county',
    'state',
    'administrative',
  };

  /// Indica si el resultado corresponde a una localidad habitada.
  static bool isLocalityPlace(Map<String, dynamic> map) {
    final type = map['type']?.toString().toLowerCase() ?? '';
    if (type.isEmpty) return false;
    return _localityTypes.contains(type);
  }

  /// Indica si el resultado de Nominatim pertenece a Venezuela.
  ///
  /// Se usa el cÃ³digo de paÃ­s que devuelve la API y, si no viene, se revisa
  /// que el nombre mostrado mencione Venezuela.
  static bool isInCountryPlace(Map<String, dynamic> map) {
    final address = map['address'];
    if (address is Map<String, dynamic>) {
      final code = address['country_code']?.toString().toLowerCase() ?? '';
      if (code.isNotEmpty) return code == countryCode;
    }
    final display = map['display_name']?.toString().toLowerCase() ?? '';
    return display.contains('venezuela');
  }

  /// Calcula la distancia aproximada en kilÃ³metros entre dos coordenadas
  /// usando la fÃ³rmula de Haversine.
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
