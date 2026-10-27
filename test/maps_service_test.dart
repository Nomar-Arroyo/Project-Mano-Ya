import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/core/services/maps_service.dart';

void main() {
  group('MapsService.isLocalityPlace', () {
    test('acepta las localidades habitadas', () {
      const tipos = [
        'city',
        'town',
        'village',
        'hamlet',
        'locality',
        'suburb',
        'neighbourhood',
        'quarter',
        'residential',
        'district',
        'parish',
        'state_district',
        'municipality',
        'state',
      ];

      for (final tipo in tipos) {
        expect(
          MapsService.isLocalityPlace({'type': tipo}),
          isTrue,
          reason: 'El tipo "$tipo" debe aceptarse como localidad',
        );
      }
    });

    test('descarta calles, comercios y puntos de interes', () {
      const tipos = ['road', 'house', 'shop', 'cafe', 'amenity', 'building'];

      for (final tipo in tipos) {
        expect(
          MapsService.isLocalityPlace({'type': tipo}),
          isFalse,
          reason: 'El tipo "$tipo" no debe aceptarse como localidad',
        );
      }
    });

    test('descarta resultados sin tipo', () {
      expect(
        MapsService.isLocalityPlace({'display_name': 'Calle XYZ'}),
        isFalse,
      );
    });
  });

  group('MapsService.isInCountryPlace', () {
    test('acepta resultados de Venezuela por el codigo de pais', () {
      final map = {
        'address': {'country_code': 've'},
        'display_name': 'Los Palos, Bolivar, Venezuela',
      };

      expect(MapsService.isInCountryPlace(map), isTrue);
    });

    test('descarta resultados de otro pais', () {
      final map = {
        'address': {'country_code': 'co'},
        'display_name': 'Medellin, Antioquia, Colombia',
      };

      expect(MapsService.isInCountryPlace(map), isFalse);
    });

    test('usa el nombre mostrado cuando no viene el codigo de pais', () {
      expect(
        MapsService.isInCountryPlace({
          'display_name': 'Los Palos, Bolivar, Venezuela',
        }),
        isTrue,
      );
      expect(
        MapsService.isInCountryPlace({'display_name': 'Cali, Colombia'}),
        isFalse,
      );
    });
  });

  group('MapsService.distanceKm', () {
    test('calcula la distancia entre Caracas y Valencia', () {
      final km = MapsService.distanceKm(10.4806, -66.9036, 10.1620, -68.0077);

      expect(km, greaterThan(100));
      expect(km, lessThan(140));
    });

    test('devuelve cero para el mismo punto', () {
      expect(MapsService.distanceKm(10.4806, -66.9036, 10.4806, -66.9036), 0);
    });
  });
}
