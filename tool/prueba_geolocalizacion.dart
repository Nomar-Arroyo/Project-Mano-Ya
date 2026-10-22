// Prueba manual del servicio de geolocalizacion contra Nominatim.
// Se ejecuta con: dart run tool/prueba_geolocalizacion.dart
import 'package:mano_ya/core/services/maps_service.dart';

Future<void> main() async {
  const consultas = [
    'Caracas',
    'Maracay',
    'Valencia',
    'Bogota',
    'Medellin',
    'Cali',
    'Los Palos Grandes',
    'Petare',
  ];

  for (final q in consultas) {
    final lugares = await MapsService.autocomplete(q);
    print('\n"$q" -> ${lugares.length} sugerencia(s)');
    for (final p in lugares.take(3)) {
      final esVe = p.displayName.contains('Venezuela');
      print('   ${esVe ? "[VE]" : "[!!]"} ${p.displayName}');
      print('        lat=${p.latitude} lon=${p.longitude}');
    }
    await Future.delayed(const Duration(milliseconds: 1200));
  }

  // Distancia Caracas - Maracay (debe ser ~140 km por carretera, ~120 en linea recta).
  final d = MapsService.distanceKm(10.4806, -66.9036, 10.2469, -67.5958);
  print('\nDistancia Caracas-Maracay (linea recta): ${d.toStringAsFixed(1)} km');
}
