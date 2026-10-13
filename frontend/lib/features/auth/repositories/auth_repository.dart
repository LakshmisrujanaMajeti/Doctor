import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/auth_state.dart';

class AuthRepository {
  final DioClient _dioClient;

  AuthRepository(this._dioClient);

  Future<UserModel> login(String identifier, String password) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.login,
        data: {'identifier': identifier, 'password': password},
      );

      if (response.data['status'] == 'success') {
        final data = response.data['data'];
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

        await DioClient.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          role: user.roleName,
        );

        return user;
      } else {
        throw Exception(response.data['message'] ?? 'Login failed');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] as String?;
        if (msg != null && msg.isNotEmpty) {
          throw Exception(msg);
        }
      }
      throw Exception('Network error connecting to hospital server. Please try again.');
    }
  }

  Future<UserModel> registerPatient({
    required String fullName,
    required String phone,
    String? email,
    required String password,
    String gender = 'MALE',
    int? ageYears,
    String? bloodGroup,
    String? address,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.registerPatient,
        data: {
          'full_name': fullName,
          'phone': phone,
          if (email != null && email.isNotEmpty) 'email': email,
          'password': password,
          'gender': gender,
          if (ageYears != null) 'age_years': ageYears,
          if (bloodGroup != null) 'blood_group': bloodGroup,
          if (address != null) 'address': address,
        },
      );

      if (response.data['status'] == 'success') {
        final data = response.data['data'];
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;
        final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

        await DioClient.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          role: user.roleName,
        );

        return user;
      } else {
        throw Exception(response.data['message'] ?? 'Registration failed');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] as String?;
        if (msg != null && msg.isNotEmpty) {
          throw Exception(msg);
        }
      }
      throw Exception('Registration error. Please check your information and try again.');
    }
  }

  Future<String> forgotPassword(String identifier) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.forgotPassword,
        data: {'identifier': identifier},
      );

      if (response.data['status'] == 'success') {
        return response.data['message'] as String? ?? 'Recovery email dispatched';
      } else {
        throw Exception(response.data['message'] ?? 'Password reset request failed');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] as String?;
        if (msg != null && msg.isNotEmpty) {
          throw Exception(msg);
        }
      }
      throw Exception('Could not process password recovery. Please try again.');
    }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.resetPassword,
        data: {'token': token, 'new_password': newPassword},
      );

      if (response.data['status'] != 'success') {
        throw Exception(response.data['message'] ?? 'Password reset failed');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] as String?;
        if (msg != null && msg.isNotEmpty) {
          throw Exception(msg);
        }
      }
      throw Exception('Password reset failed. Token may be invalid or expired.');
    }
  }

  Future<String> sendOtp(String identifier, {String purpose = 'login'}) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.sendOtp,
        data: {'identifier': identifier, 'purpose': purpose},
      );

      if (response.data['status'] == 'success') {
        return response.data['message'] as String? ?? 'OTP sent';
      } else {
        throw Exception(response.data['message'] ?? 'Failed to send OTP');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] as String?;
        if (msg != null && msg.isNotEmpty) {
          throw Exception(msg);
        }
      }
      throw Exception('Unable to send OTP. Real SMS service is required.');
    }
  }

  Future<void> verifyOtp(String identifier, String otp, {String purpose = 'login'}) async {
    try {
      final response = await _dioClient.dio.post(
        ApiEndpoints.verifyOtp,
        data: {'identifier': identifier, 'otp': otp, 'purpose': purpose},
      );

      if (response.data['status'] != 'success') {
        throw Exception(response.data['message'] ?? 'OTP verification failed');
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response?.data['message'] as String?;
        if (msg != null && msg.isNotEmpty) {
          throw Exception(msg);
        }
      }
      throw Exception('OTP verification failed. Please try again.');
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final token = await DioClient.getAccessToken();
      if (token == null || token.isEmpty) return null;

      final res = await _dioClient.dio.get(ApiEndpoints.me);
      if (res.data['status'] == 'success') {
        return UserModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<void> logout() async {
    try {
      final refreshToken = await SecureStorageService.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _dioClient.dio.post(
          ApiEndpoints.logout,
          data: {'refresh_token': refreshToken},
        );
      }
    } catch (_) {
      // Continue to clear local tokens even if network fails
    } finally {
      await DioClient.clearTokens();
    }
  }
}
