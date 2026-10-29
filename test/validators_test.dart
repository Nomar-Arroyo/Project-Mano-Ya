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
}
