import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';

class AuthState {
  final User? currentUser;
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final bool sessionRestoreFailed;

  AuthState({
    this.currentUser,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.sessionRestoreFailed = false,
  });

  AuthState copyWith({
    User? currentUser,
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? sessionRestoreFailed,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      sessionRestoreFailed: sessionRestoreFailed ?? this.sessionRestoreFailed,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final StorageService _storageService;

  AuthNotifier(this._apiService, this._storageService) : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    await loadCurrentUser();
    state = state.copyWith(isLoading: false);
  }

  Future<void> loadCurrentUser() async {
    state = state.copyWith(isLoading: true, clearError: true, sessionRestoreFailed: false);
    final token = await _storageService.getToken();
    if (token == null) {
      state = AuthState(isAuthenticated: false, isLoading: false);
      return;
    }

    final result = await _apiService.getCurrentUser(token);
    if (result['success'] == true) {
      state = AuthState(
        currentUser: result['user'],
        isAuthenticated: true,
        isLoading: false,
      );
    } else if (result['unauthorized'] == true) {
      await _storageService.deleteToken();
      state = AuthState(isAuthenticated: false, isLoading: false);
    } else {
      state = state.copyWith(
        isLoading: false,
        sessionRestoreFailed: true,
        error: 'Impossible de vérifier votre session. Réessayez lorsque la connexion sera rétablie.',
      );
    }
  }

  Future<void> refreshProfile() async {
    final userId = state.currentUser?.id;
    final token = await _storageService.getToken();
    if (token == null || userId == null) return;
    final result = await _apiService.getCurrentUser(token);
    if (result['success'] == true && state.currentUser?.id == userId) {
      state = state.copyWith(currentUser: result['user'] as User);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _apiService.login(email: email, password: password);

    if (result['success'] == true) {
      final token = result['token'] as String;
      final user = result['user'] as User;

      await _storageService.saveToken(token);

      state = AuthState(
        currentUser: user,
        isAuthenticated: true,
        isLoading: false,
      );
      
      // Process any pending notification after successful login
      // Note: We need a BuildContext to navigate, so this will be handled in the login page
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result['message'] as String?,
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _apiService.register(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      role: role,
    );

    if (result['success'] == true) {
      final token = result['token'] as String;
      final user = result['user'] as User;

      await _storageService.saveToken(token);

      state = AuthState(
        currentUser: user,
        isAuthenticated: true,
        isLoading: false,
      );
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: result['message'] as String?,
      );
      return false;
    }
  }

  Future<void> logout() async {
    // Drop the authenticated socket so no stale token stays connected.
    await ChatService().disconnect();
    await _storageService.deleteToken();
    state = AuthState(isAuthenticated: false, isLoading: false);
  }

  Future<bool> updateProfile({
    required String fullName,
    String? phone,
    String? city,
    String? wilaya,
  }) async {
    if (state.currentUser == null) return false;

    final token = await _storageService.getToken();
    if (token == null) return false;

    final result = await _apiService.updateProfile(
      token: token,
      fullName: fullName,
      phone: phone,
      city: city,
      wilaya: wilaya,
    );

    if (result['success'] == true) {
      final updatedProfile = result['profile'] as UserProfile;
      state = state.copyWith(
        currentUser: User(
          id: state.currentUser!.id,
          email: state.currentUser!.email,
          role: state.currentUser!.role,
          profile: updatedProfile,
        ),
      );
      return true;
    }

    return false;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ApiService(), StorageService());
});
