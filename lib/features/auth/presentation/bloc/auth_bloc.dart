import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/core/config/app_config.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/core/router/app_router.dart';
import 'package:orderpulse_flutter/features/auth/domain/auth_repository.dart';
import 'package:orderpulse_flutter/features/auth/domain/merchant_profile.dart';

/// Switches DI environment scope cleanly between Demo and Live backends.
abstract interface class EnvironmentConfigurator {
  AppConfig get currentConfig;
  Future<void> activateEnvironment(AppConfig config);
}

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class AuthSessionRestoreRequested extends AuthEvent {
  const AuthSessionRestoreRequested();
}

final class AuthDemoSignInRequested extends AuthEvent {
  const AuthDemoSignInRequested();
}

final class AuthLiveSignInRequested extends AuthEvent {
  const AuthLiveSignInRequested({
    required this.email,
    required this.password,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
  });

  final String email;
  final String password;
  final String apiBaseUrl;
  final String wsBaseUrl;

  @override
  List<Object?> get props => [email, password, apiBaseUrl, wsBaseUrl];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

final class AuthSessionExpiredReceived extends AuthEvent {
  const AuthSessionExpiredReceived();
}

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthAuthenticating extends AuthState {
  const AuthAuthenticating();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.merchant);

  final MerchantProfile merchant;

  @override
  List<Object?> get props => [merchant];
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({
    this.errorMessage,
    this.sessionExpired = false,
  });

  final String? errorMessage;
  final bool sessionExpired;

  @override
  List<Object?> get props => [errorMessage, sessionExpired];
}

/// Manages merchant authentication lifecycle and synchronizes [AuthSessionGate].
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required EnvironmentConfigurator environmentConfigurator,
    required AuthRepository Function() authRepositoryProvider,
    required AuthSessionGate authGate,
  })  : _environmentConfigurator = environmentConfigurator,
        _authRepositoryProvider = authRepositoryProvider,
        _authGate = authGate,
        super(const AuthInitial()) {
    on<AuthSessionRestoreRequested>(_onRestoreRequested);
    on<AuthDemoSignInRequested>(_onDemoSignInRequested);
    on<AuthLiveSignInRequested>(_onLiveSignInRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpiredReceived>(_onSessionExpired);
  }

  final EnvironmentConfigurator _environmentConfigurator;
  final AuthRepository Function() _authRepositoryProvider;
  final AuthSessionGate _authGate;

  Future<void> _onRestoreRequested(
    AuthSessionRestoreRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthAuthenticating());
    final result = await _authRepositoryProvider().restoreSession();
    switch (result) {
      case Success<MerchantProfile>(:final value):
        _authGate.setAuthenticated(true);
        emit(AuthAuthenticated(value));
      case Err<MerchantProfile>():
        _authGate.setAuthenticated(false);
        emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onDemoSignInRequested(
    AuthDemoSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthAuthenticating());
    final targetConfig = _environmentConfigurator.currentConfig.copyWith(
      environment: AppEnvironment.demo,
    );
    await _environmentConfigurator.activateEnvironment(targetConfig);

    final result = await _authRepositoryProvider().signIn(
      email: 'merchant@orderpulse.demo',
      password: 'demo-session-password',
    );

    switch (result) {
      case Success<MerchantProfile>(:final value):
        _authGate.setAuthenticated(true);
        emit(AuthAuthenticated(value));
      case Err<MerchantProfile>(:final failure):
        _authGate.setAuthenticated(false);
        emit(AuthUnauthenticated(errorMessage: failure.message));
    }
  }

  Future<void> _onLiveSignInRequested(
    AuthLiveSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    final trimmedEmail = event.email.trim();
    if (trimmedEmail.isEmpty || event.password.isEmpty) {
      emit(
        const AuthUnauthenticated(
          errorMessage: 'Please enter both merchant email and password.',
        ),
      );
      return;
    }
    final trimmedApi = event.apiBaseUrl.trim();
    final trimmedWs = event.wsBaseUrl.trim();
    if (trimmedApi.isEmpty || trimmedWs.isEmpty) {
      emit(
        const AuthUnauthenticated(
          errorMessage: 'API and WebSocket URLs are required for Live Server mode.',
        ),
      );
      return;
    }

    emit(const AuthAuthenticating());
    final targetConfig = AppConfig(
      environment: AppEnvironment.live,
      apiBaseUrl: trimmedApi,
      wsBaseUrl: trimmedWs,
    );
    await _environmentConfigurator.activateEnvironment(targetConfig);

    final result = await _authRepositoryProvider().signIn(
      email: trimmedEmail,
      password: event.password,
    );

    switch (result) {
      case Success<MerchantProfile>(:final value):
        _authGate.setAuthenticated(true);
        emit(AuthAuthenticated(value));
      case Err<MerchantProfile>(:final failure):
        _authGate.setAuthenticated(false);
        emit(AuthUnauthenticated(errorMessage: failure.message));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepositoryProvider().signOut();
    _authGate.setAuthenticated(false);
    emit(const AuthUnauthenticated());
  }

  Future<void> _onSessionExpired(
    AuthSessionExpiredReceived event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthUnauthenticated &&
        (state as AuthUnauthenticated).sessionExpired) {
      return;
    }
    _authGate.setAuthenticated(false);
    emit(
      const AuthUnauthenticated(
        sessionExpired: true,
        errorMessage: 'Your session expired. Please sign in again.',
      ),
    );
  }
}
