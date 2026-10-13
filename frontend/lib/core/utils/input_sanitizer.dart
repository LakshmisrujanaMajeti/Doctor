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
}
