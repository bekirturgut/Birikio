import 'package:flutter/services.dart';

/// Turkish money input: groups whole digits while keeping an optional comma
/// and up to two decimal digits. The caret follows the edited digit.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  String _format(String value) {
    final cleaned = value
        .replaceAll('.', '')
        .replaceAll(RegExp(r'[^0-9,]'), '');
    final comma = cleaned.indexOf(',');
    final whole = (comma < 0 ? cleaned : cleaned.substring(0, comma));
    final decimal = comma < 0
        ? ''
        : cleaned.substring(comma + 1).replaceAll(',', '');
    final digits = whole.isEmpty && comma >= 0 ? '0' : whole;
    final groups = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return comma < 0
        ? groups
        : '$groups,${decimal.substring(0, decimal.length.clamp(0, 2))}';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = _format(newValue.text);
    final caret = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final before = _format(newValue.text.substring(0, caret));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: before.length.clamp(0, formatted.length),
      ),
    );
  }
}
