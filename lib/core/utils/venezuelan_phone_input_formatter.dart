import 'package:flutter/services.dart';

/// Formatea números móviles venezolanos como `412 123 4567`.
///
/// El código de país `+58` se muestra por separado en el campo.
class VenezuelanPhoneInputFormatter extends TextInputFormatter {
  const VenezuelanPhoneInputFormatter();

  static String formatNational(String value) {
    var digits = _digitsOnly(value);
    if (digits.startsWith('58') && digits.length >= 12) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) digits = digits.substring(1);
    return _formatDigits(_limitDigits(digits));
  }

  static String formatInternational(String value) {
    final nationalNumber = formatNational(value);
    return nationalNumber.isEmpty ? '' : '+58 $nationalNumber';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }

    final sourceDigits = _digitsOnly(newValue.text);
    var digits = sourceDigits;
    if (digits.startsWith('58') && digits.length >= 12) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0') && digits.length > 1) {
      digits = digits.substring(1);
    }
    digits = _limitDigits(digits);

    final formatted = _formatDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: _formattedOffset(
          _nationalDigitsBeforeCursor(
            newValue.text,
            sourceDigits,
            newValue.selection.baseOffset,
          ),
          digits.length,
        ),
        extentOffset: _formattedOffset(
          _nationalDigitsBeforeCursor(
            newValue.text,
            sourceDigits,
            newValue.selection.extentOffset,
          ),
          digits.length,
        ),
      ),
    );
  }

  static String _digitsOnly(String value) =>
      value.replaceAll(RegExp(r'[^0-9]'), '');

  static String _limitDigits(String digits) =>
      digits.length > 10 ? digits.substring(0, 10) : digits;

  static String _formatDigits(String digits) {
    if (digits.length <= 3) return digits;
    if (digits.length <= 6) {
      return '${digits.substring(0, 3)} ${digits.substring(3)}';
    }
    return '${digits.substring(0, 3)} '
        '${digits.substring(3, 6)} '
        '${digits.substring(6)}';
  }

  static int _nationalDigitsBeforeCursor(
    String sourceText,
    String sourceDigits,
    int cursor,
  ) {
    if (cursor < 0) return 0;
    final digitsBeforeCursor = _digitsOnly(
      sourceText.substring(0, cursor.clamp(0, sourceText.length).toInt()),
    ).length;
    var normalizedCount = digitsBeforeCursor;
    if (sourceDigits.startsWith('58') && sourceDigits.length >= 12) {
      normalizedCount = (normalizedCount - 2).clamp(0, 10);
    } else if (sourceDigits.startsWith('0') && sourceDigits.length > 1) {
      normalizedCount = (normalizedCount - 1).clamp(0, 10);
    }
    return normalizedCount;
  }

  static int _formattedOffset(int digitCount, int maxDigits) {
    final count = digitCount.clamp(0, maxDigits).toInt();
    if (count <= 3) return count;
    if (count <= 6) return count + 1;
    return count + 2;
  }
}
