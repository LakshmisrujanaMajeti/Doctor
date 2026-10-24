import 'package:flutter_test/flutter_test.dart';
import 'package:opd_connect/core/utils/field_validators.dart';
import 'package:flutter/services.dart';

void main() {
  group('FieldValidators.validatePersonName', () {
    test('accepts valid English names with spaces, hyphens, apostrophes, and initials', () {
      expect(FieldValidators.validatePersonName('Ravi Kumar', fieldName: 'Name'), isNull);
      expect(FieldValidators.validatePersonName("O'Connor", fieldName: 'Name'), isNull);
      expect(FieldValidators.validatePersonName('Mary-Jane', fieldName: 'Name'), isNull);
      expect(FieldValidators.validatePersonName('M. K. Gandhi', fieldName: 'Name'), isNull);
      expect(FieldValidators.validatePersonName('Dr. John Doe', fieldName: 'Name'), isNull);
      expect(FieldValidators.validatePersonName('Anand', fieldName: 'Name'), isNull);
    });

    test('accepts valid Tamil Unicode names', () {
      expect(FieldValidators.validatePersonName('இரா. குமார்', fieldName: 'Name'), isNull);
      expect(FieldValidators.validatePersonName('கார்த்திக் சுந்தரம்', fieldName: 'Name'), isNull);
      expect(FieldValidators.validatePersonName('செல்வி மா', fieldName: 'Name'), isNull);
    });

    test('rejects numbers, symbols, and malformed inputs', () {
      expect(FieldValidators.validatePersonName('Ravi123', fieldName: 'Name'), contains('cannot contain numbers'));
      expect(FieldValidators.validatePersonName('John@Hospital', fieldName: 'Name'), contains('letters, spaces, hyphens'));
      expect(FieldValidators.validatePersonName('@@@', fieldName: 'Name'), contains('letters, spaces, hyphens'));
      expect(FieldValidators.validatePersonName('<script>', fieldName: 'Name'), contains('letters, spaces, hyphens'));
    });

    test('validates required vs optional empty / whitespace', () {
      expect(FieldValidators.validatePersonName('', fieldName: 'Name', isRequired: true), contains('is required'));
      expect(FieldValidators.validatePersonName('   ', fieldName: 'Name', isRequired: true), contains('is required'));
      expect(FieldValidators.validatePersonName('', fieldName: 'Name', isRequired: false), isNull);
      expect(FieldValidators.validatePersonName(null, fieldName: 'Name', isRequired: false), isNull);
    });
  });

  group('FieldValidators.validateIndianPhone', () {
    test('accepts valid 10-digit Indian mobile numbers starting 6-9', () {
      expect(FieldValidators.validateIndianPhone('9876543210'), isNull);
      expect(FieldValidators.validateIndianPhone('+919876543210'), isNull);
      expect(FieldValidators.validateIndianPhone('09876543210'), isNull);
      expect(FieldValidators.validateIndianPhone('8123456789'), isNull);
      expect(FieldValidators.validateIndianPhone('7012345678'), isNull);
      expect(FieldValidators.validateIndianPhone('6381234567'), isNull);
    });

    test('rejects numbers not starting with 6-9 or invalid lengths', () {
      expect(FieldValidators.validateIndianPhone('1234567890'), contains('starts with 6-9'));
      expect(FieldValidators.validateIndianPhone('5234567890'), contains('starts with 6-9'));
      expect(FieldValidators.validateIndianPhone('98765'), contains('10 digits'));
      expect(FieldValidators.validateIndianPhone('987654321012'), contains('10 digits'));
      expect(FieldValidators.validateIndianPhone('abcdefghij'), contains('must contain only numbers'));
    });

    test('handles optional and required correctly', () {
      expect(FieldValidators.validateIndianPhone('', isRequired: true), contains('is required'));
      expect(FieldValidators.validateIndianPhone('', isRequired: false), isNull);
      expect(FieldValidators.validateIndianPhone(null, isRequired: false), isNull);
    });
  });

  group('FieldValidators.validatePinCode', () {
    test('accepts valid 6-digit Indian PIN codes', () {
      expect(FieldValidators.validatePinCode('605001'), isNull);
      expect(FieldValidators.validatePinCode('600028'), isNull);
      expect(FieldValidators.validatePinCode('110001'), isNull);
    });

    test('rejects invalid PIN codes', () {
      expect(FieldValidators.validatePinCode('012345'), contains('cannot start with 0'));
      expect(FieldValidators.validatePinCode('60500'), contains('must be exactly 6 digits'));
      expect(FieldValidators.validatePinCode('6050012'), contains('must be exactly 6 digits'));
      expect(FieldValidators.validatePinCode('605 01'), contains('digits only'));
      expect(FieldValidators.validatePinCode('60500A'), contains('digits only'));
    });

    test('handles optional vs required', () {
      expect(FieldValidators.validatePinCode('', isRequired: true), contains('is required'));
      expect(FieldValidators.validatePinCode('', isRequired: false), isNull);
    });
  });

  group('FieldValidators.validateEmail', () {
    test('accepts valid email formats', () {
      expect(FieldValidators.validateEmail('user@hospital.org'), isNull);
      expect(FieldValidators.validateEmail('doctor.kumar@smvmch.ac.in'), isNull);
      expect(FieldValidators.validateEmail('patient+care@sub.domain.co'), isNull);
    });

    test('rejects malformed email addresses', () {
      expect(FieldValidators.validateEmail('notanemail'), contains('Enter a valid Email address'));
      expect(FieldValidators.validateEmail('user@'), contains('Enter a valid Email address'));
      expect(FieldValidators.validateEmail('@domain.com'), contains('Enter a valid Email address'));
    });
  });

  group('FieldValidators.validateAge & validateAgeMonths', () {
    test('accepts valid age in years 0-130', () {
      expect(FieldValidators.validateAge('0'), isNull);
      expect(FieldValidators.validateAge('35'), isNull);
      expect(FieldValidators.validateAge('120'), isNull);
    });

    test('rejects out of range or non-integer years', () {
      expect(FieldValidators.validateAge('-1'), contains('between 0 and 130'));
      expect(FieldValidators.validateAge('135'), contains('between 0 and 130'));
      expect(FieldValidators.validateAge('35.5'), contains('whole number'));
      expect(FieldValidators.validateAge('abc'), contains('whole number'));
    });

    test('validates months 0-11', () {
      expect(FieldValidators.validateAgeMonths('0'), isNull);
      expect(FieldValidators.validateAgeMonths('11'), isNull);
      expect(FieldValidators.validateAgeMonths('12'), contains('between 0 and 11'));
      expect(FieldValidators.validateAgeMonths('-1'), contains('between 0 and 11'));
    });
  });

  group('FieldValidators Vital Signs', () {
    test('systolic blood pressure (40 - 280 mmHg)', () {
      expect(FieldValidators.validateSystolicBp('120'), isNull);
      expect(FieldValidators.validateSystolicBp('35'), contains('between 40 and 280'));
      expect(FieldValidators.validateSystolicBp('290'), contains('between 40 and 280'));
    });

    test('diastolic blood pressure (20 - 180 mmHg)', () {
      expect(FieldValidators.validateDiastolicBp('80'), isNull);
      expect(FieldValidators.validateDiastolicBp('15'), contains('between 20 and 180'));
      expect(FieldValidators.validateDiastolicBp('190'), contains('between 20 and 180'));
      expect(FieldValidators.validateDiastolicBp('120', systolicBp: 110), contains('must be less than Systolic'));
    });

    test('pulse rate (25 - 250 bpm)', () {
      expect(FieldValidators.validatePulseRate('72'), isNull);
      expect(FieldValidators.validatePulseRate('20'), contains('between 25 and 250'));
      expect(FieldValidators.validatePulseRate('260'), contains('between 25 and 250'));
    });

    test('temperature (90.0 - 110.0 °F)', () {
      expect(FieldValidators.validateTemperature('98.6'), isNull);
      expect(FieldValidators.validateTemperature('102.4'), isNull);
      expect(FieldValidators.validateTemperature('88.0'), contains('between 90.0°F and 110.0°F'));
      expect(FieldValidators.validateTemperature('112.0'), contains('between 90.0°F and 110.0°F'));
    });

    test('oxygen saturation SpO2 (50 - 100 %)', () {
      expect(FieldValidators.validateSpO2('98'), isNull);
      expect(FieldValidators.validateSpO2('100'), isNull);
      expect(FieldValidators.validateSpO2('48'), contains('between 50% and 100%'));
      expect(FieldValidators.validateSpO2('105'), contains('between 50% and 100%'));
    });

    test('height (20.0 - 260.0 cm) and weight (0.5 - 350.0 kg)', () {
      expect(FieldValidators.validateHeight('172.5'), isNull);
      expect(FieldValidators.validateHeight('15'), contains('between 20.0 and 260.0'));
      expect(FieldValidators.validateWeight('68.4'), isNull);
      expect(FieldValidators.validateWeight('0.2'), contains('between 0.5 and 350.0'));
    });
  });

  group('FieldValidators Pharmacy and Billing', () {
    test('price validation', () {
      expect(FieldValidators.validatePrice('150.00'), isNull);
      expect(FieldValidators.validatePrice('0'), isNull);
      expect(FieldValidators.validatePrice('-10'), contains('cannot be negative'));
    });

    test('quantity validation', () {
      expect(FieldValidators.validateQuantity('10'), isNull);
      expect(FieldValidators.validateQuantity('0'), contains('between 1 and'));
      expect(FieldValidators.validateQuantity('-5'), contains('between 1 and'));
    });

    test('expiry date validation', () {
      final futureDate = DateTime.now().add(const Duration(days: 180));
      final pastDate = DateTime.now().subtract(const Duration(days: 30));
      expect(FieldValidators.validateExpiryDate(futureDate), isNull);
      expect(FieldValidators.validateExpiryDate(pastDate), contains('must be in the future'));
      expect(FieldValidators.validateExpiryDate(null), contains('Expiry date is required'));
    });

    test('batch number validation', () {
      expect(FieldValidators.validateBatchNumber('BATCH123-A'), isNull);
      expect(FieldValidators.validateBatchNumber('B/001'), isNull);
      expect(FieldValidators.validateBatchNumber('B@123!'), contains('letters, numbers, hyphens, and slashes'));
    });
  });

  group('PersonNameInputFormatter', () {
    test('rejects digits and unsupported symbols while preserving allowed characters', () {
      final formatter = PersonNameInputFormatter();
      const oldValue = TextEditingValue(text: 'Ravi');
      const invalidValue = TextEditingValue(
        text: 'Ravi1',
        selection: TextSelection.collapsed(offset: 5),
      );
      final rejectedResult = formatter.formatEditUpdate(oldValue, invalidValue);
      expect(rejectedResult.text, equals('Ravi'));

      const validNewValue = TextEditingValue(
        text: 'Ravi Kumar',
        selection: TextSelection.collapsed(offset: 10),
      );
      final acceptedResult = formatter.formatEditUpdate(oldValue, validNewValue);
      expect(acceptedResult.text, equals('Ravi Kumar'));
    });

    test('preserves Tamil Unicode characters', () {
      final formatter = PersonNameInputFormatter();
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(
        text: 'இரா. குமார்',
        selection: TextSelection.collapsed(offset: 11),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, equals('இரா. குமார்'));
    });
  });
}
