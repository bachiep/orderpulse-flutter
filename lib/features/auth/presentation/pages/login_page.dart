import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/core/config/app_config.dart';
import 'package:orderpulse_flutter/core/di/injection.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/core/theme/theme_cubit.dart';
import 'package:orderpulse_flutter/features/auth/presentation/bloc/auth_bloc.dart';

/// Merchant login screen offering Live Server authentication and 1-Tap Demo Merchant entry.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _apiUrlController;
  late final TextEditingController _wsUrlController;
  bool _showServerSettings = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final config = sl<AppConfig>();
    _emailController = TextEditingController(text: 'cashier@merchant.vn');
    _passwordController = TextEditingController();
    _apiUrlController = TextEditingController(text: config.apiBaseUrl);
    _wsUrlController = TextEditingController(text: config.wsBaseUrl);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _apiUrlController.dispose();
    _wsUrlController.dispose();
    super.dispose();
  }

  void _submitLiveLogin() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthBloc>().add(
          AuthLiveSignInRequested(
            email: _emailController.text,
            password: _passwordController.text,
            apiBaseUrl: _apiUrlController.text,
            wsBaseUrl: _wsUrlController.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, authState) {
            final isBusy = authState is AuthAuthenticating;
            final errorMessage = switch (authState) {
              AuthUnauthenticated(:final errorMessage) => errorMessage,
              _ => null,
            };

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 24 + bottomInset),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Toggle theme',
                          onPressed: () => context.read<ThemeCubit>().toggle(),
                          icon: Icon(
                            isDark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: kds.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: kds.brandAccent.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Icon(
                            Icons.storefront_rounded,
                            size: 38,
                            color: kds.brandAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'OrderPulse Merchant',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: kds.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Realtime O2O Order Board & Kitchen Dispatch Monitor',
                        style: textTheme.bodyMedium?.copyWith(
                          color: kds.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kds.statusRejectedContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kds.statusRejected.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: kds.onStatusRejectedContainer,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  errorMessage,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: kds.onStatusRejectedContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: kds.brandAccent.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    color: kds.statusNew,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Standalone Interactive Demo',
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: kds.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Test live order dispatch, SLA countdowns, WebSocket reconnect backoff, and queued 401 token refresh without a local backend.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: kds.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                onPressed: isBusy
                                    ? null
                                    : () => context.read<AuthBloc>().add(
                                          const AuthDemoSignInRequested(),
                                        ),
                                icon: isBusy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.play_arrow_rounded),
                                label: const Text('Try Demo Merchant'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR LIVE SERVER',
                              style: textTheme.labelSmall?.copyWith(
                                color: kds.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Merchant Email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Email is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      tooltip: 'Toggle password visibility',
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => setState(
                                      () => _showServerSettings =
                                          !_showServerSettings,
                                    ),
                                    icon: Icon(
                                      _showServerSettings
                                          ? Icons.expand_less
                                          : Icons.tune_rounded,
                                    ),
                                    label: const Text('Server Endpoint Settings'),
                                  ),
                                ),
                                if (_showServerSettings) ...[
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _apiUrlController,
                                    decoration: const InputDecoration(
                                      labelText: 'API Base URL',
                                      helperText:
                                          'Android Emulator: http://10.0.2.2:8301 | Desktop/iOS: http://localhost:8301',
                                      helperMaxLines: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _wsUrlController,
                                    decoration: const InputDecoration(
                                      labelText: 'WebSocket URL',
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                  ),
                                  onPressed: isBusy ? null : _submitLiveLogin,
                                  icon: const Icon(Icons.login_rounded),
                                  label: const Text('Sign In to Live Server'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
