/// Hospital OPD Input Sanitizer
/// Ensures clean data sanitization, XSS mitigation, and safe normalization across all forms.
class InputSanitizer {
  /// Strip null characters, HTML tags, leading/trailing spaces, and control characters
  static String sanitizeText(String? input, {int? maxLength}) {
    if (input == null) return '';
    var cleaned = input
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '') // remove control chars
        .replaceAll(RegExp(r'<[^>]*>'), '') // strip HTML/XML tags
        .trim();
    if (maxLength != null && cleaned.length > maxLength) {
      cleaned = cleaned.substring(0, maxLength);
    }
    return cleaned;
  }

  /// Sanitize phone numbers to international format (+ and digits only)
  static String sanitizePhone(String? input) {
    if (input == null) return '';
    final trimmed = input.trim();
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    return hasPlus ? '+$digits' : digits;
  }

  /// Sanitize email address (lowercase, trim, alphanumeric with standard email symbols)
  static String sanitizeEmail(String? input) {
    if (input == null) return '';
    return input.trim().toLowerCase().replaceAll(RegExp(r'[^\w\.\+\-\@]'), '');
  }

  /// Sanitize UHID identifier (uppercase, hyphen, alphanumeric)
  static String sanitizeUhid(String? input) {
    if (input == null) return '';
    return input.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
  }

  /// Sanitize search queries and remove SQL/injection escape characters
  static String sanitizeSearchQuery(String? input) {
    if (input == null) return '';
    return input.trim().replaceAll(RegExp(r'[<>\x22\x27;\\]'), '');
  }

  /// Sanitize clinical notes and treatment descriptions
  static String sanitizeClinicalNotes(String? input) {
    if (input == null) return '';
    return input
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>', caseSensitive: false), '')
        .trim();
  }

  /// Validate standard email format (e.g. name@domain.com)
  static bool isValidEmail(String? input) {
    if (input == null || input.trim().isEmpty) return false;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(input.trim());
  }

  /// Validate email field with custom requirement flag and field name
  static String? validateEmail(String? input, {bool isRequired = true, String? fieldName}) {
    final label = fieldName ?? 'Email address';
    if (input == null || input.trim().isEmpty) {
      if (isRequired) return '$label is required';
      return null;
    }
    if (!isValidEmail(input)) {
      return 'Enter a valid $label (e.g. name@domain.com)';
    }
    return null;
  }

  /// Extract 10-digit phone number, stripping country code (+91, 91, 0, +1) and non-numeric characters
  static String extract10DigitPhone(String? input) {
    if (input == null) return '';
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && (digits.startsWith('0') || digits.startsWith('1'))) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// Check whether phone contains exactly 10 digits
  static bool isValid10DigitPhone(String? input) {
    if (input == null) return false;
    final digits = extract10DigitPhone(input);
    return RegExp(r'^\d{10}$').hasMatch(digits);
  }

  /// Validate phone number to ensure exactly 10 digits
  static String? validate10DigitPhone(String? input, {bool isRequired = true, String? fieldName}) {
    final label = fieldName ?? 'Phone number';
    if (input == null || input.trim().isEmpty) {
      if (isRequired) return '$label is required';
      return null;
    }
    if (!isValid10DigitPhone(input)) {
      return '$label must be exactly 10 digits';
    }
    return null;
  }

  /// Validate strong password:
  /// - At least 8 characters
  /// - At least 1 uppercase letter (A-Z)
  /// - At least 1 lowercase letter (a-z)
  /// - At least 1 digit (0-9)
  /// - At least 1 special character (!@#$%^&*...)
  static String? validateStrongPassword(String? input) {
    if (input == null || input.isEmpty) {
      return 'Password is required';
    }
    if (input.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'[A-Z]').hasMatch(input)) {
      return 'Password must contain at least one uppercase letter (A-Z)';
    }
    if (!RegExp(r'[a-z]').hasMatch(input)) {
      return 'Password must contain at least one lowercase letter (a-z)';
    }
    if (!RegExp(r'[0-9]').hasMatch(input)) {
      return 'Password must contain at least one number (0-9)';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;~`]').hasMatch(input)) {
      return 'Password must contain at least one special character (!@#\$%^&*)';
    }
    return null;
  }
}

