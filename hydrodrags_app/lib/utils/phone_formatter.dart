import 'package:flutter/services.dart';

/// Utility class for phone number formatting and validation
class PhoneFormatter {
  /// Format phone number as (XXX) XXX-XXXX
  /// Accepts digits only and formats to US phone format
  static String formatPhoneNumber(String input) {
    // Remove all non-digit characters
    final digitsOnly = input.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) return '';
    
    // Format based on length
    if (digitsOnly.length <= 3) {
      return '($digitsOnly';
    } else if (digitsOnly.length <= 6) {
      return '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3)}';
    } else {
      final areaCode = digitsOnly.substring(0, 3);
      final firstPart = digitsOnly.substring(3, 6);
      final secondPart = digitsOnly.substring(6, digitsOnly.length > 10 ? 10 : digitsOnly.length);
      return '($areaCode) $firstPart-$secondPart';
    }
  }

  /// Validate phone number format
  /// Returns null if valid, error message if invalid
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    
    // Remove all non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's a valid length (10 digits for US, allow up to 15 for international)
    if (digitsOnly.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    
    if (digitsOnly.length > 15) {
      return 'Phone number is too long';
    }
    
    // For US numbers, should be exactly 10 digits
    if (digitsOnly.length == 10) {
      // Check if area code starts with 0 or 1 (invalid)
      if (digitsOnly[0] == '0' || digitsOnly[0] == '1') {
        return 'Invalid area code';
      }
    }
    
    return null; // Valid
  }

  /// Get digits only from formatted phone number
  static String getDigitsOnly(String formattedPhone) {
    return formattedPhone.replaceAll(RegExp(r'[^\d]'), '');
  }
}

/// Text input formatter for phone numbers
/// Formats as user types: (XXX) XXX-XXXX
class PhoneNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;
    
    // If backspace and text is getting shorter, allow it
    if (newText.length < oldValue.text.length) {
      return newValue;
    }
    
    // Remove all non-digits
    final digitsOnly = newText.replaceAll(RegExp(r'[^\d]'), '');
    
    // Limit to 10 digits for US numbers
    if (digitsOnly.length > 10) {
      return oldValue;
    }
    
    // Format the phone number
    final formatted = PhoneFormatter.formatPhoneNumber(digitsOnly);
    
    // Calculate cursor position
    int cursorPosition = formatted.length;
    
    // If user is typing in the middle, try to maintain relative position
    if (oldValue.selection.baseOffset < oldValue.text.length) {
      final oldDigits = PhoneFormatter.getDigitsOnly(oldValue.text);
      final newDigits = PhoneFormatter.getDigitsOnly(formatted);
      final digitDiff = newDigits.length - oldDigits.length;
      
      if (digitDiff > 0) {
        // User added digits, move cursor forward accounting for formatting
        final oldFormattedLength = oldValue.text.length;
        final newFormattedLength = formatted.length;
        final lengthDiff = newFormattedLength - oldFormattedLength;
        cursorPosition = (oldValue.selection.baseOffset + lengthDiff).clamp(0, formatted.length);
      }
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}
