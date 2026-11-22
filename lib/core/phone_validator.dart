/// Phone Number Validation and Normalization Utility
///
/// Enforces E.164 international phone number format:
/// - Format: +[country code][subscriber number]
/// - Max length: 15 digits (excluding '+')
/// - Total max chars: 20 (with '+' and minimal formatting)
///
/// Example valid numbers:
/// - +12345678901234 (E.164 pure)
/// - +1 555-123-4567 (formatted)
/// - +254712345678 (Kenya)
/// - +86 138 0013 8000 (China)
library;

class PhoneValidator {
  /// Validates and normalizes a phone number to E.164 format
  ///
  /// Returns normalized phone number or null if invalid
  ///
  /// Rules:
  /// - Must start with '+' or be added
  /// - 7-15 digits after country code
  /// - Remove excess formatting: () - spaces (except single spaces)
  /// - Reject extensions (x123, ext 456)
  /// - Max 20 chars to fit database VARCHAR(20)
  static String? normalize(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) return null;

    String input = phoneNumber.trim();

    // Reject numbers with extensions
    if (input.toLowerCase().contains('x') ||
        input.toLowerCase().contains('ext')) {
      return null; // Invalid: has extension
    }

    // Remove formatting characters (but keep + and digits)
    String digitsOnly = input.replaceAll(RegExp(r'[^\d+]'), '');

    // Ensure starts with '+'
    if (!digitsOnly.startsWith('+')) {
      // If no country code, can't normalize reliably
      return null; // Invalid: no country code
    }

    // Check digit count (1-15 digits after '+')
    int digitCount = digitsOnly.substring(1).length;
    if (digitCount < 7 || digitCount > 15) {
      return null; // Invalid: wrong digit count
    }

    // Normalize to E.164 pure format (no formatting)
    String normalized = digitsOnly;

    // Ensure fits in VARCHAR(20) - pure E.164 should be max 16 chars
    if (normalized.length > 20) {
      return null; // Invalid: too long even after normalization
    }

    return normalized;
  }

  /// Validates if a phone number is in acceptable format
  /// (doesn't normalize, just checks)
  static bool isValid(String? phoneNumber) {
    return normalize(phoneNumber) != null;
  }

  /// Formats phone number for display (adds spacing for readability)
  /// E.g., "+12345678901" -> "+1 234 567 8901"
  static String formatForDisplay(String e164Number) {
    if (!e164Number.startsWith('+')) return e164Number;

    String digits = e164Number.substring(1);

    if (digits.length <= 3) {
      return e164Number; // Too short to format
    }

    // Simple formatting: +CC DDD DDD DDDD
    StringBuffer formatted = StringBuffer('+');

    // Country code (1-3 digits)
    if (digits.length >= 10) {
      // Assume 1-digit country code for 10+ digit numbers
      formatted.write('${digits[0]} ');
      digits = digits.substring(1);
    } else if (digits.length >= 9) {
      // Assume 2-digit country code
      formatted.write('${digits.substring(0, 2)} ');
      digits = digits.substring(2);
    } else {
      // Assume 3-digit country code
      formatted.write('${digits.substring(0, 3)} ');
      digits = digits.substring(3);
    }

    // Format remaining digits in groups of 3-4
    while (digits.isNotEmpty) {
      if (digits.length <= 4) {
        formatted.write(digits);
        break;
      }
      formatted.write('${digits.substring(0, 3)} ');
      digits = digits.substring(3);
    }

    return formatted.toString().trim();
  }

  /// Extracts country code from E.164 number
  /// Returns null if can't determine
  static String? getCountryCode(String e164Number) {
    if (!e164Number.startsWith('+')) return null;

    String digits = e164Number.substring(1);

    // Common country codes
    if (digits.startsWith('1')) return '1'; // US/Canada
    if (digits.startsWith('7')) return '7'; // Russia
    if (digits.startsWith('20')) return '20'; // Egypt
    if (digits.startsWith('27')) return '27'; // South Africa
    if (digits.startsWith('254')) return '254'; // Kenya
    if (digits.startsWith('86')) return '86'; // China

    // Default: assume 1-3 digit country code
    if (digits.length >= 3) {
      return digits.substring(0, 3);
    }

    return digits;
  }

  /// Returns human-readable validation error message
  static String? getValidationError(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return 'Phone number is required';
    }

    String input = phoneNumber.trim();

    // Check for extensions
    if (input.toLowerCase().contains('x') ||
        input.toLowerCase().contains('ext')) {
      return 'Extensions (x123, ext) are not allowed';
    }

    // Check for country code
    String digitsOnly = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (!digitsOnly.startsWith('+')) {
      return 'Phone number must start with country code (+)';
    }

    // Check digit count
    int digitCount = digitsOnly.substring(1).length;
    if (digitCount < 7) {
      return 'Phone number is too short (min 7 digits)';
    }
    if (digitCount > 15) {
      return 'Phone number is too long (max 15 digits)';
    }

    // Check total length
    if (digitsOnly.length > 20) {
      return 'Phone number exceeds maximum length';
    }

    return null; // Valid
  }
}
