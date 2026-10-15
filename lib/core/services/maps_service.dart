// Google Maps Places / Nominatim mock
class MapsService {
  static Future<List<String>> autocompleteCity(String query) async {
    if (query.isEmpty) return [];
    return [
      'Cali, Valle',
      'Palmira, Valle',
      'Buenaventura, Valle',
    ].where((c) => c.toLowerCase().contains(query.toLowerCase())).toList();
  }
}
