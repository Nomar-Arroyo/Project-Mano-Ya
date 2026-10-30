import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/core/utils/validators.dart';

void main() {
  group('Validators.phone', () {
    test('accepts supported Venezuelan mobile numbers', () {
      for (final prefix in ['412', '414', '416', '422', '424', '426']) {
        expect(Validators.phone('$prefix 123 4567'), isNull);
      }
    });

    test('accepts local and international country-code formats', () {
      expect(Validators.phone('0412 123 4567'), isNull);
      expect(Validators.phone('+58 412 123 4567'), isNull);
    });

    test('rejects invalid prefixes and incomplete numbers', () {
      expect(Validators.phone('413 123 4567'), isNotNull);
      expect(Validators.phone('412 123 456'), isNotNull);
      expect(Validators.phone('212 123 4567'), isNotNull);
    });

    test('requires a phone number', () {
      expect(Validators.phone(''), 'Ingresa tu teléfono');
    });
  });

  group('Validators.emailCode', () {
    test('acepta códigos de 6 a 10 dígitos', () {
      expect(Validators.emailCode('123456'), isNull);
      expect(Validators.emailCode('12345678'), isNull);
      expect(Validators.emailCode('0123456789'), isNull);
    });

    test('rechaza códigos cortos, largos o con letras', () {
      expect(Validators.emailCode(''), 'Ingresa el código');
      expect(Validators.emailCode('12345'), isNotNull);
      expect(Validators.emailCode('12345678901'), isNotNull);
      expect(Validators.emailCode('12a45678'), isNotNull);
    });
  });
}
