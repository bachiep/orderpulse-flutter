import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orderpulse_flutter/core/config/app_config.dart';
import 'package:orderpulse_flutter/core/error/failures.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/core/router/app_router.dart';
import 'package:orderpulse_flutter/features/auth/domain/auth_repository.dart';
import 'package:orderpulse_flutter/features/auth/domain/merchant_profile.dart';
import 'package:orderpulse_flutter/features/auth/presentation/bloc/auth_bloc.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockEnvironmentConfigurator extends Mock
    implements EnvironmentConfigurator {}

void main() {
  late _MockAuthRepository authRepository;
  late _MockEnvironmentConfigurator environmentConfigurator;
  late AuthSessionGate authGate;

  const sampleMerchant = MerchantProfile(
    id: 'm-1',
    merchantName: 'OrderPulse Kitchen - Demo',
    branchName: 'District 1 Flagship',
    email: 'merchant@orderpulse.demo',
  );

  setUpAll(() {
    registerFallbackValue(
      const AppConfig(
        environment: AppEnvironment.demo,
        apiBaseUrl: 'http://10.0.2.2:8301',
        wsBaseUrl: 'ws://10.0.2.2:8301/ws/orders',
      ),
    );
  });

  setUp(() {
    authRepository = _MockAuthRepository();
    environmentConfigurator = _MockEnvironmentConfigurator();
    authGate = AuthSessionGate();

    when(() => environmentConfigurator.currentConfig).thenReturn(
      const AppConfig(
        environment: AppEnvironment.demo,
        apiBaseUrl: 'http://10.0.2.2:8301',
        wsBaseUrl: 'ws://10.0.2.2:8301/ws/orders',
      ),
    );
    when(() => environmentConfigurator.activateEnvironment(any()))
        .thenAnswer((_) async {});
  });

  tearDown(() {
    authGate.dispose();
  });

  group('AuthBloc', () {
    blocTest<AuthBloc, AuthState>(
      'emits [AuthAuthenticating, AuthAuthenticated] on Demo sign-in',
      build: () {
        when(
          () => authRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => const Success(sampleMerchant));

        return AuthBloc(
          environmentConfigurator: environmentConfigurator,
          authRepositoryProvider: () => authRepository,
          authGate: authGate,
        );
      },
      act: (bloc) => bloc.add(const AuthDemoSignInRequested()),
      expect: () => const [
        AuthAuthenticating(),
        AuthAuthenticated(sampleMerchant),
      ],
      verify: (_) {
        expect(authGate.isAuthenticated, isTrue);
        verify(
          () => environmentConfigurator.activateEnvironment(
            any(
              that: isA<AppConfig>().having(
                (c) => c.environment,
                'environment',
                AppEnvironment.demo,
              ),
            ),
          ),
        ).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'activates live environment and emits AuthUnauthenticated on invalid credentials',
      build: () {
        when(
          () => authRepository.signIn(
            email: 'cashier@merchant.vn',
            password: 'wrong',
          ),
        ).thenAnswer(
          (_) async => const Err(UnauthorizedFailure('Invalid credentials.')),
        );

        return AuthBloc(
          environmentConfigurator: environmentConfigurator,
          authRepositoryProvider: () => authRepository,
          authGate: authGate,
        );
      },
      act: (bloc) => bloc.add(
        const AuthLiveSignInRequested(
          email: 'cashier@merchant.vn',
          password: 'wrong',
          apiBaseUrl: 'http://10.0.2.2:8301',
          wsBaseUrl: 'ws://10.0.2.2:8301/ws/orders',
        ),
      ),
      expect: () => const [
        AuthAuthenticating(),
        AuthUnauthenticated(errorMessage: 'Invalid credentials.'),
      ],
      verify: (_) {
        expect(authGate.isAuthenticated, isFalse);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits AuthUnauthenticated with sessionExpired=true when session expires',
      build: () {
        authGate.setAuthenticated(true);
        return AuthBloc(
          environmentConfigurator: environmentConfigurator,
          authRepositoryProvider: () => authRepository,
          authGate: authGate,
        );
      },
      act: (bloc) => bloc.add(const AuthSessionExpiredReceived()),
      expect: () => const [
        AuthUnauthenticated(
          sessionExpired: true,
          errorMessage: 'Your session expired. Please sign in again.',
        ),
      ],
      verify: (_) => expect(authGate.isAuthenticated, isFalse),
    );
  });
}
