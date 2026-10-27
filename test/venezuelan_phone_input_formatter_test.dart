import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mano_ya/core/utils/venezuelan_phone_input_formatter.dart';

void main() {
  group('VenezuelanPhoneInputFormatter', () {
    const formatter = VenezuelanPhoneInputFormatter();

    test('formats national mobile numbers with spaces', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(
          text: '4121234567',
          selection: TextSelection.collapsed(offset: 10),
        ),
      );

      expect(result.text, '412 123 4567');
      expect(result.selection.extentOffset, result.text.length);
    });

    test('accepts a pasted local number with its trunk zero', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(
          text: '0412-123-4567',
          selection: TextSelection.collapsed(offset: 13),
        ),
      );

      expect(result.text, '412 123 4567');
    });

    test('accepts a pasted international number', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(
          text: '+58 412 123 4567',
          selection: TextSelection.collapsed(offset: 16),
        ),
      );

      expect(result.text, '412 123 4567');
      expect(
        VenezuelanPhoneInputFormatter.formatInternational(result.text),
        '+58 412 123 4567',
      );
    });

    test('limits the national number to ten digits', () {
      final result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(
          text: '412123456789',
          selection: TextSelection.collapsed(offset: 12),
        ),
      );

      expect(result.text, '412 123 4567');
    });

    test('formats existing numbers for display and storage', () {
      expect(
        VenezuelanPhoneInputFormatter.formatNational('+58 0412 123 4567'),
        '412 123 4567',
      );
      expect(
        VenezuelanPhoneInputFormatter.formatInternational('04121234567'),
        '+58 412 123 4567',
      );
      expect(VenezuelanPhoneInputFormatter.formatInternational(''), '');
    });
  });
}
