import 'package:flutter/services.dart';

/// Comprehensive Hospital OPD Field-Specific Validators and Input Formatters.
/// Strictly enforces data quality, culturally valid names, Indian telecom standards,
/// clinical measurement ranges, and ISO/RFC specifications without generic blankets.
class FieldValidators {
  // Regex supporting English alphabets, Tamil Unicode script (\u0B80-\u0BFF),
  // spaces, hyphens, apostrophes, and periods for initials.
  // Rejects digits (0-9), emojis, and unrelated special symbols.
  static final RegExp _personNameRegex = RegExp(
    r"^[a-zA-Z\u0B80-\u0BFF]+([ '\-\.]+[a-zA-Z\u0B80-\u0BFF]+)*\.?$",
  );

  /// Validates person names (Patient, Parent/Spouse, Doctor, Guardian, Emergency Contact)
  static String? validatePersonName(
    String? value, {
    bool isRequired = true,
    String fieldName = 'Name',
    int minLength = 2,
    int maxLength = 100,
  }) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return '$fieldName is required';
      return null;
    }

    final trimmed = value.trim();

    if (trimmed.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }

    if (trimmed.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters';
    }

    // Explicit check for numeric digits
    if (RegExp(r'\d').hasMatch(trimmed)) {
      return '$fieldName cannot contain numbers';
    }

    // Check for emojis or illegal symbols
    if (!_personNameRegex.hasMatch(trimmed)) {
      return 'Enter a valid $fieldName (letters, spaces, hyphens, or apostrophes only)';
    }

    return null;
  }

  /// Extracts the standard 10-digit Indian phone number
  static String extract10Digits(String? input) {
    if (input == null) return '';
    String clean = input.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (clean.startsWith('+91')) {
      clean = clean.substring(3);
    } else if (clean.length == 12 && clean.startsWith('91')) {
      clean = clean.substring(2);
    } else if (clean.length == 11 && clean.startsWith('0')) {
      clean = clean.substring(1);
    }
    return clean;
  }

  /// Validates Indian 10-digit mobile phone numbers
  static String? validateIndianPhone(
    String? value, {
    bool isRequired = true,
    String fieldName = 'Mobile number',
  }) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return '$fieldName is required';
      return null;
    }

    final clean = extract10Digits(value);

    // Reject non-numeric characters without silently stripping them
    if (!RegExp(r'^\d+$').hasMatch(clean)) {
      return '$fieldName must contain only numbers';
    }

    if (clean.length != 10) {
      return '$fieldName must contain exactly 10 digits';
    }

    // Indian mobile numbers typically start with 6, 7, 8, or 9
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) {
      return 'Enter a valid 10-digit Indian $fieldName (starts with 6-9)';
    }

    return null;
  }

  /// Validates Indian Postal PIN codes (exactly 6 digits, 100000 - 999999)
  static String? validatePinCode(
    String? value, {
    bool isRequired = true,
    String fieldName = 'PIN code',
  }) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return '$fieldName is required';
      return null;
    }

    final clean = value.trim();

    if (RegExp(r'\D').hasMatch(clean)) {
      return '$fieldName must contain digits only';
    }

    if (clean.length != 6) {
      return '$fieldName must be exactly 6 digits';
    }

    if (clean.startsWith('0')) {
      return '$fieldName cannot start with 0';
    }

    return null;
  }

  /// Validates standard email address
  static String? validateEmail(
    String? value, {
    bool isRequired = false,
    String fieldName = 'Email address',
  }) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return '$fieldName is required';
      return null;
    }

    final clean = value.trim();
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    if (!emailRegex.hasMatch(clean)) {
      return 'Enter a valid $fieldName (e.g. name@domain.com)';
    }

    return null;
  }

  /// Validates age in years (0 - 130)
  static String? validateAge(
    String? value, {
    bool isRequired = true,
    int min = 0,
    int max = 130,
    String fieldName = 'Age',
  }) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return '$fieldName is required';
      return null;
    }

    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return '$fieldName must be a valid whole number';
    }

    if (parsed < min || parsed > max) {
      return 'Enter a valid $fieldName between $min and $max years';
    }

    return null;
  }

  /// Validates age in months (0 - 11) for infants
  static String? validateAgeMonths(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0 || parsed > 11) {
      return 'Months must be between 0 and 11';
    }
    return null;
  }

  /// Validates Date of Birth and optionally cross-checks with Age
  static String? validateDateOfBirth(
    DateTime? dob, {
    bool isRequired = false,
    int? ageToCrossCheck,
  }) {
    if (dob == null) {
      if (isRequired) return 'Date of birth is required';
      return null;
    }

    final now = DateTime.now();
    if (dob.isAfter(now)) {
      return 'Date of birth cannot be in the future';
    }

    final calculatedYears = now.year - dob.year - ((now.month < dob.month || (now.month == dob.month && now.day < dob.day)) ? 1 : 0);

    if (calculatedYears > 130) {
      return 'Date of birth exceeds maximum valid age (130 years)';
    }

    if (ageToCrossCheck != null) {
      // Allow +/- 1 year tolerance for birthday timing
      if ((calculatedYears - ageToCrossCheck).abs() > 1) {
        return 'Date of birth does not match entered age ($ageToCrossCheck years)';
      }
    }

    return null;
  }

  /// Validates residential address (multilingual English/Tamil, numbers, punctuation)
  static String? validateAddress(
    String? value, {
    bool isRequired = true,
    String fieldName = 'Address',
    int minLength = 3,
    int maxLength = 250,
  }) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return '$fieldName is required';
      return null;
    }

    final clean = value.trim();

    if (clean.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }

    if (clean.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters';
    }

    // Check for malicious script tags or null bytes
    if (RegExp(r'<[^>]*>|[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]').hasMatch(clean)) {
      return '$fieldName contains invalid formatting';
    }

    return null;
  }

  // ==========================================
  // CLINICAL & VITAL SIGNS VALIDATION
  // ==========================================

  /// Systolic Blood Pressure (mmHg): 40 - 280
  static String? validateSystolicBp(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Systolic BP is required';
      return null;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Enter a numeric systolic value';
    if (parsed < 40 || parsed > 280) {
      return 'Systolic BP must be between 40 and 280 mmHg';
    }
    return null;
  }

  /// Diastolic Blood Pressure (mmHg): 20 - 180, cross-checks systolic > diastolic
  static String? validateDiastolicBp(
    String? value, {
    bool isRequired = false,
    int? systolicBp,
  }) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Diastolic BP is required';
      return null;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Enter a numeric diastolic value';
    if (parsed < 20 || parsed > 180) {
      return 'Diastolic BP must be between 20 and 180 mmHg';
    }
    if (systolicBp != null && parsed >= systolicBp) {
      return 'Diastolic ($parsed) must be less than Systolic ($systolicBp)';
    }
    return null;
  }

  /// Pulse Rate (bpm): 25 - 250
  static String? validatePulseRate(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Pulse rate is required';
      return null;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Enter a numeric pulse rate';
    if (parsed < 25 || parsed > 250) {
      return 'Pulse rate must be between 25 and 250 bpm';
    }
    return null;
  }

  /// Temperature (°F: 90.0 - 110.0, or °C: 32.0 - 43.0)
  static String? validateTemperature(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Temperature is required';
      return null;
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a valid numeric temperature';
    if (parsed < 90.0 || parsed > 110.0) {
      return 'Temperature must be between 90.0°F and 110.0°F';
    }
    return null;
  }

  /// SpO2 Oxygen Saturation (%): 50 - 100
  static String? validateSpO2(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'SpO2 is required';
      return null;
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a numeric SpO2 value';
    if (parsed < 50.0 || parsed > 100.0) {
      return 'SpO2 must be between 50% and 100%';
    }
    return null;
  }

  /// Respiratory Rate (breaths/min): 6 - 80
  static String? validateRespiratoryRate(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Respiratory rate is required';
      return null;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Enter a numeric respiratory rate';
    if (parsed < 6 || parsed > 80) {
      return 'Respiratory rate must be between 6 and 80 breaths/min';
    }
    return null;
  }

  /// Height in cm: 20.0 - 260.0
  static String? validateHeight(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Height is required';
      return null;
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a numeric height in cm';
    if (parsed < 20.0 || parsed > 260.0) {
      return 'Height must be between 20.0 and 260.0 cm';
    }
    return null;
  }

  /// Weight in kg: 0.5 - 350.0
  static String? validateWeight(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Weight is required';
      return null;
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a numeric weight in kg';
    if (parsed < 0.5 || parsed > 350.0) {
      return 'Weight must be between 0.5 and 350.0 kg';
    }
    return null;
  }

  /// Blood Glucose (mg/dL): 20 - 800
  static String? validateBloodGlucose(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Blood glucose is required';
      return null;
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a numeric glucose value';
    if (parsed < 20.0 || parsed > 800.0) {
      return 'Blood glucose must be between 20 and 800 mg/dL';
    }
    return null;
  }

  // ==========================================
  // PHARMACY, BILLING & NUMERIC FIELDS
  // ==========================================

  /// Validates positive integer quantity (> 0)
  static String? validateQuantity(
    String? value, {
    bool isRequired = true,
    int min = 1,
    int max = 100000,
    String fieldName = 'Quantity',
  }) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return '$fieldName is required';
      return null;
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return '$fieldName must be an integer';
    if (parsed < min || parsed > max) {
      return '$fieldName must be between $min and $max';
    }
    return null;
  }

  /// Validates monetary prices & fees (>= 0.00, up to 2 decimal places)
  static String? validatePrice(
    String? value, {
    bool isRequired = true,
    double min = 0.0,
    double max = 1000000.0,
    String fieldName = 'Price',
  }) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return '$fieldName is required';
      return null;
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'Enter a valid numeric $fieldName';
    if (parsed < min) return '$fieldName cannot be negative';
    if (parsed > max) return '$fieldName exceeds maximum allowed amount';
    return null;
  }

  /// Validates future expiry date (YYYY-MM-DD or DateTime)
  static String? validateExpiryDate(DateTime? expiryDate) {
    if (expiryDate == null) return 'Expiry date is required';
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (!expiryDate.isAfter(todayDate)) {
      return 'Expiry date must be in the future';
    }
    return null;
  }

  /// Validates batch number (2 - 30 alphanumeric characters, hyphens, slashes)
  static String? validateBatchNumber(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Batch number is required';
      return null;
    }
    final clean = value.trim();
    if (clean.length < 2 || clean.length > 30) {
      return 'Batch number must be between 2 and 30 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9\-_/]+$').hasMatch(clean)) {
      return 'Batch number can only contain letters, numbers, hyphens, and slashes';
    }
    return null;
  }

  /// Validates department code (2 - 8 uppercase alphanumeric)
  static String? validateDepartmentCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Department code is required';
    }
    final clean = value.trim();
    if (clean.length < 2 || clean.length > 8) {
      return 'Department code must be 2 to 8 characters';
    }
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(clean)) {
      return 'Department code must be uppercase letters and numbers only';
    }
    return null;
  }
}

/// Level 1 Input Formatter: Allows English letters, Tamil Unicode (\u0B80-\u0BFF),
/// spaces, hyphens, apostrophes, and periods for initials. Rejects digits and symbols.
class PersonNameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    // Reject updates containing characters that are not letters (English or Tamil), spaces, dots, hyphens, or apostrophes
    if (RegExp(r'[^a-zA-Z\u0B80-\u0BFF\s\-\.\x27]').hasMatch(newValue.text)) {
      return oldValue;
    }
    return newValue;
  }
}

/// Level 1 Input Formatter: Formats decimal numbers with max 2 decimal places
class DecimalInputFormatter extends TextInputFormatter {
  final int decimalRange;

  DecimalInputFormatter({this.decimalRange = 2});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Reject non-numeric (except 1 dot)
    if (!RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)) {
      return oldValue;
    }

    if (newValue.text.contains('.')) {
      final parts = newValue.text.split('.');
      if (parts.length > 1 && parts[1].length > decimalRange) {
        return oldValue;
      }
    }

    return newValue;
  }
}
