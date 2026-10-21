import 'package:flutter_test/flutter_test.dart';
import 'package:opd_connect/core/utils/input_sanitizer.dart';
import 'package:opd_connect/core/network/dio_client.dart';

void main() {
  group('InputSanitizer Tests', () {
    test('sanitizeText strips HTML tags and control characters', () {
      const dirty = '<script>alert("xss")</script>Hello\x00\x08 World<b>!</b> ';
      final clean = InputSanitizer.sanitizeText(dirty);
      expect(clean, 'alert("xss")Hello World!');
    });

    test('sanitizeText trims and enforces maxLength', () {
      const input = '   Supercalifragilisticexpialidocious   ';
      final clean = InputSanitizer.sanitizeText(input, maxLength: 10);
      expect(clean, 'Supercalif');
    });

    test('sanitizePhone standardizes numbers', () {
      expect(InputSanitizer.sanitizePhone(' +91 (987) 654-3210 '), '+919876543210');
      expect(InputSanitizer.sanitizePhone(' 9876543210 '), '9876543210');
    });

    test('sanitizeEmail cleans and lowercases', () {
      expect(InputSanitizer.sanitizeEmail(' User.Doctor+Test@Hospital.Org '), 'user.doctor+test@hospital.org');
    });

    test('sanitizeUhid standardizes UHID string', () {
      expect(InputSanitizer.sanitizeUhid(' uhid-2026-9901 '), 'UHID-2026-9901');
    });

    test('sanitizeSearchQuery strips SQL and script injection symbols', () {
      expect(InputSanitizer.sanitizeSearchQuery("SELECT * FROM users WHERE '1'='1'; <script>"), 'SELECT * FROM users WHERE 1=1 script');
    });

    test('sanitizeClinicalNotes strips script blocks and control characters', () {
      const notes = '<script>malicious()</script>Patient presented with acute fever\x00 and cough.';
      final clean = InputSanitizer.sanitizeClinicalNotes(notes);
      expect(clean, 'Patient presented with acute fever and cough.');
    });
  });

  group('DioClient Cache Tests', () {
    test('DioClient clearCache operates without errors', () {
      DioClient.clearCache();
      DioClient.invalidatePath('/catalogue');
    });
  });
}
