import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class PostalOfficeInfo {
  final String officeName;
  final String district;
  final String state;
  final String pincode;

  const PostalOfficeInfo({
    required this.officeName,
    required this.district,
    required this.state,
    required this.pincode,
  });

  factory PostalOfficeInfo.fromJson(Map<String, dynamic> json, String pincode) {
    return PostalOfficeInfo(
      officeName: json['Name'] as String? ?? '',
      district: json['District'] as String? ?? '',
      state: json['State'] as String? ?? '',
      pincode: pincode,
    );
  }
}

class PostalLookupResult {
  final bool isSuccess;
  final String? message;
  final List<PostalOfficeInfo> offices;
  final String? suggestedDistrict;
  final String? suggestedState;

  const PostalLookupResult({
    required this.isSuccess,
    this.message,
    this.offices = const [],
    this.suggestedDistrict,
    this.suggestedState,
  });
}

class PostalPincodeService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ),
  );

  // In-memory cache for ultra-fast instant repeated lookups
  static final Map<String, PostalLookupResult> _cache = {};

  /// Validate Indian 6-digit PIN code format (1st digit 1-9, exactly 6 numeric digits).
  static bool isValidIndianPincode(String? pincode) {
    if (pincode == null) return false;
    final clean = pincode.trim();
    final regex = RegExp(r'^[1-9][0-9]{5}$');
    return regex.hasMatch(clean);
  }

  /// Format validation error message if invalid.
  static String? validatePincodeFormat(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final clean = value.trim();
    if (clean.length != 6) {
      return 'PIN code must be exactly 6 numeric digits';
    }
    if (clean.startsWith('0')) {
      return 'Indian PIN code cannot start with 0';
    }
    if (!RegExp(r'^\d+$').hasMatch(clean)) {
      return 'PIN code must contain digits only';
    }
    return null;
  }

  /// Lookup post offices, district, and state using India Post API with offline fallback.
  static Future<PostalLookupResult> lookupPincode(String pincode) async {
    final clean = pincode.trim();
    if (!isValidIndianPincode(clean)) {
      return const PostalLookupResult(
        isSuccess: false,
        message: 'Invalid 6-digit PIN code format.',
      );
    }

    if (_cache.containsKey(clean)) {
      return _cache[clean]!;
    }

    // 1. Try public postal API
    try {
      final res = await _dio.get('https://api.postalpincode.in/pincode/$clean');
      if (res.statusCode == 200 && res.data is List && (res.data as List).isNotEmpty) {
        final firstBlock = res.data[0] as Map<String, dynamic>;
        final status = firstBlock['Status'] as String? ?? '';

        if (status.toLowerCase() == 'success') {
          final postOffices = firstBlock['PostOffice'] as List<dynamic>? ?? [];
          final offices = postOffices
              .map((p) => PostalOfficeInfo.fromJson(p as Map<String, dynamic>, clean))
              .toList();

          if (offices.isNotEmpty) {
            final result = PostalLookupResult(
              isSuccess: true,
              offices: offices,
              suggestedDistrict: offices.first.district,
              suggestedState: offices.first.state,
              message: 'Found ${offices.length} post office(s) in ${offices.first.district}, ${offices.first.state}.',
            );
            _cache[clean] = result;
            return result;
          }
        }
      }
    } catch (e) {
      debugPrint('ℹ️ [PINCODE LOOKUP] Online lookup failed: $e, checking offline directory...');
    }

    // 2. Offline directory fallback for hospital local & regional areas (Puducherry & surrounding districts)
    final offlineMatch = _lookupOfflineDirectory(clean);
    if (offlineMatch != null) {
      _cache[clean] = offlineMatch;
      return offlineMatch;
    }

    // 3. Graceful fallback preserving user input
    return const PostalLookupResult(
      isSuccess: false,
      message: 'PIN code service currently offline. You may enter City and State manually.',
    );
  }

  static PostalLookupResult? _lookupOfflineDirectory(String pin) {
    // Puducherry local hospital region (SMVMCH located at Kalitheerthalkuppam / Madagadipet 605107)
    final localMap = <String, Map<String, String>>{
      '605107': {'district': 'Puducherry', 'state': 'Puducherry', 'office': 'Madagadipet SO'},
      '605001': {'district': 'Puducherry', 'state': 'Puducherry', 'office': 'Puducherry HO'},
      '605002': {'district': 'Puducherry', 'state': 'Puducherry', 'office': 'Nellithope SO'},
      '605003': {'district': 'Puducherry', 'state': 'Puducherry', 'office': 'Muthialpet SO'},
      '605004': {'district': 'Puducherry', 'state': 'Puducherry', 'office': 'Mudaliarpet SO'},
      '605005': {'district': 'Puducherry', 'state': 'Puducherry', 'office': 'Villianur SO'},
      '605006': {'district': 'Puducherry', 'state': 'Puducherry', 'office': 'Lawspet SO'},
      '605007': {'district': 'Puducherry', 'state': 'Puducherry', 'office': 'Reddiarpalayam SO'},
      '605008': {'district': 'Puducherry', 'state': 'Puducherry', 'office': 'Ariyankuppam SO'},
      '605009': {'district': 'Puducherry', 'state': 'Puducherry', 'office': 'Bahour SO'},
      '605102': {'district': 'Puducherry', 'state': 'Puducherry', 'office': 'Korkadu SO'},
      '605106': {'district': 'Puducherry', 'state': 'Puducherry', 'office': 'Thirubuvanai SO'},
      '605110': {'district': 'Puducherry', 'state': 'Puducherry', 'office': 'Sedurapet SO'},
      '605602': {'district': 'Viluppuram', 'state': 'Tamil Nadu', 'office': 'Viluppuram HO'},
      '607001': {'district': 'Cuddalore', 'state': 'Tamil Nadu', 'office': 'Cuddalore HO'},
      '600001': {'district': 'Chennai', 'state': 'Tamil Nadu', 'office': 'Chennai GPO'},
      '600028': {'district': 'Chennai', 'state': 'Tamil Nadu', 'office': 'R A Puram SO'},
      '500001': {'district': 'Hyderabad', 'state': 'Telangana', 'office': 'Hyderabad GPO'},
      '500081': {'district': 'Hyderabad', 'state': 'Telangana', 'office': 'Madhapur SO'},
      '560001': {'district': 'Bengaluru', 'state': 'Karnataka', 'office': 'Bengaluru GPO'},
      '400001': {'district': 'Mumbai', 'state': 'Maharashtra', 'office': 'Mumbai GPO'},
      '110001': {'district': 'Central Delhi', 'state': 'Delhi', 'office': 'New Delhi GPO'},
    };

    if (localMap.containsKey(pin)) {
      final item = localMap[pin]!;
      final office = PostalOfficeInfo(
        officeName: item['office']!,
        district: item['district']!,
        state: item['state']!,
        pincode: pin,
      );
      return PostalLookupResult(
        isSuccess: true,
        offices: [office],
        suggestedDistrict: item['district'],
        suggestedState: item['state'],
        message: 'Verified via regional directory: ${item['district']}, ${item['state']}.',
      );
    }
    return null;
  }
}
