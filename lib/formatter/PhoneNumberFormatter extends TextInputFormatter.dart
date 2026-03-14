import 'package:flutter/services.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('261')) {
      digits = digits.substring(3);
    }

    String formatted = "+261 ";

    if (digits.length > 2) {
      formatted += digits.substring(0, 2);
    } else {
      formatted += digits;
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    if (digits.length > 4) {
      formatted += " ${digits.substring(2, 4)}";
    } else if (digits.length > 2) {
      formatted += " ${digits.substring(2)}";
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    if (digits.length > 7) {
      formatted += " ${digits.substring(4, 7)}";
    } else if (digits.length > 4) {
      formatted += " ${digits.substring(4)}";
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    if (digits.length > 7) {
      formatted += " ${digits.substring(7)}";
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
