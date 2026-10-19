import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/auth_state.dart';
import '../repositories/auth_repository.dart';

export '../../../core/network/dio_client.dart' show dioClientProvider;

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AuthRepository(dioClient);
});

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    Future.microtask(() => checkCurrentUser());
    return const AuthState();
  }

  Future<void> checkCurrentUser() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _repository.getCurrentUser();
      if (user != null) {
        state = state.copyWith(isAuthenticated: true, user: user, isLoading: false);
      } else {
        state = state.copyWith(isAuthenticated: false, isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isAuthenticated: false, isLoading: false);
    }
  }

  Future<bool> login(String identifier, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.login(identifier, password);
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> registerPatient({
    required String fullName,
    required String phone,
    String? email,
    required String password,
    String gender = 'MALE',
    int? ageYears,
    String? bloodGroup,
    String? address,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.registerPatient(
        fullName: fullName,
        phone: phone,
        email: email,
        password: password,
        gender: gender,
        ageYears: ageYears,
        bloodGroup: bloodGroup,
        address: address,
      );
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> registerStaff({
    required String fullName,
    required String email,
    required String password,
    required String roleName,
    String? phone,
    Map<String, dynamic>? roleMetadata,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.registerStaff(
        fullName: fullName,
        email: email,
        password: password,
        roleName: roleName,
        phone: phone,
        roleMetadata: roleMetadata,
      );
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<String?> forgotPassword(String identifier) async {
    return await requestPasswordResetOtp(identifier);
  }

  Future<String?> requestPasswordResetOtp(String identifier) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final code = await _repository.requestPasswordResetOtp(identifier);
      state = state.copyWith(isLoading: false);
      return code;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return null;
    }
  }

  Future<bool> resetPasswordWithOtp({
    required String identifier,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.resetPasswordWithOtp(
        identifier: identifier,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.resetPassword(token, newPassword);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<String?> sendOtp(String identifier, {String purpose = 'login'}) async {
    try {
      return await _repository.sendOtp(identifier, purpose: purpose);
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return null;
    }
  }

  Future<bool> verifyOtp(String identifier, String otp, {String purpose = 'login'}) async {
    try {
      await _repository.verifyOtp(identifier, otp, purpose: purpose);
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void setSimulatedUser(UserModel simulatedUser) {
    state = state.copyWith(
      isAuthenticated: true,
      user: simulatedUser,
      isLoading: false,
      errorMessage: null,
    );
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
