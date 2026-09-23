import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../shared/models/user_model.dart';
import '../../../core/network/api_client.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool otpSent;
  final bool requiresFaceEnrollment;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.otpSent = false,
    this.requiresFaceEnrollment = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? otpSent,
    bool? requiresFaceEnrollment,
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      otpSent: otpSent ?? this.otpSent,
      requiresFaceEnrollment: requiresFaceEnrollment ?? this.requiresFaceEnrollment,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(AuthState());

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void resetOtpState() {
    state = state.copyWith(otpSent: false, requiresFaceEnrollment: false, clearError: true);
  }

  Future<bool> requestOtp(String phone, UserRole role) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _apiClient.dio.post('/auth/request-otp', data: {
        'phone': phone,
        'role': role.name,
      });
      state = state.copyWith(isLoading: false, otpSent: true);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Failed to send OTP. Please check phone number.';
      state = state.copyWith(isLoading: false, error: msg.toString());
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String phone,
    required String otp,
    required UserRole role,
    String? fullName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiClient.dio.post('/auth/verify-otp', data: {
        'phone': phone,
        'otp': otp,
        'role': role.name,
        'full_name': fullName,
      });
      final user = UserModel.fromJson(response.data);
      _apiClient.setToken(user.token);

      if (user.requiresFaceEnrollment) {
        state = state.copyWith(
          user: user,
          isLoading: false,
          requiresFaceEnrollment: true,
        );
      } else {
        state = state.copyWith(
          user: user,
          isLoading: false,
          requiresFaceEnrollment: false,
        );
      }
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Invalid verification code.';
      state = state.copyWith(isLoading: false, error: msg.toString());
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> enrollWorkerFace({
    required String phone,
    required String faceImageBase64,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiClient.dio.post('/auth/worker/enroll-face', data: {
        'phone': phone,
        'face_image_base64': faceImageBase64,
      });
      final updatedUser = UserModel.fromJson(response.data);
      _apiClient.setToken(updatedUser.token);
      state = state.copyWith(
        user: updatedUser,
        isLoading: false,
        requiresFaceEnrollment: false,
      );
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Face enrollment failed. Please try again.';
      state = state.copyWith(isLoading: false, error: msg.toString());
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> loginAdmin({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _apiClient.dio.post('/auth/admin/login', data: {
        'email': email,
        'password': password,
      });
      final user = UserModel.fromJson(response.data);
      _apiClient.setToken(user.token);
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Invalid admin credentials.';
      state = state.copyWith(isLoading: false, error: msg.toString());
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void switchRoleForDemo(UserRole role) {
    final demoUser = UserModel(
      id: role == UserRole.ADMIN ? 99 : (role == UserRole.WORKER ? 42 : 1),
      workerId: role == UserRole.WORKER ? 1 : null,
      fullName: role == UserRole.ADMIN
          ? 'Municipal Commissioner'
          : (role == UserRole.WORKER ? 'Worker Ramesh' : 'Citizen Priya'),
      phone: '+919876543210',
      email: role == UserRole.ADMIN ? 'admin@municipal.gov.in' : null,
      role: role,
      token: 'demo-token',
      requiresFaceEnrollment: false,
      isActive: true,
    );
    state = state.copyWith(user: demoUser, requiresFaceEnrollment: false, clearError: true);
  }

  void logout() {
    _apiClient.setToken(null);
    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});
