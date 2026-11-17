import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Route paths used across OrderPulse navigation.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String orders = '/orders';
  static String orderDetail(String orderId) => '/orders/$orderId';
}

/// Auth session state holder notifying `go_router` when authentication changes.
class AuthSessionGate extends ChangeNotifier {
  AuthSessionGate({bool isAuthenticated = false})
      : _isAuthenticated = isAuthenticated;

  bool _isAuthenticated;

  bool get isAuthenticated => _isAuthenticated;

  void setAuthenticated(bool value) {
    if (_isAuthenticated == value) return;
    _isAuthenticated = value;
    notifyListeners();
  }
}

/// Builds the declarative `GoRouter` with an authentication redirect guard.
GoRouter createAppRouter({
  required AuthSessionGate authGate,
  required WidgetBuilder loginBuilder,
  required WidgetBuilder ordersBuilder,
  Widget Function(BuildContext context, String orderId)? orderDetailBuilder,
}) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: authGate,
    redirect: (context, state) {
      final loggedIn = authGate.isAuthenticated;
      final atLogin = state.matchedLocation == AppRoutes.login;

      if (!loggedIn && !atLogin) {
        return AppRoutes.login;
      }
      if (loggedIn && atLogin) {
        return AppRoutes.orders;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => loginBuilder(context),
      ),
      GoRoute(
        path: AppRoutes.orders,
        builder: (context, state) => ordersBuilder(context),
        routes: [
          if (orderDetailBuilder != null)
            GoRoute(
              path: ':id',
              builder: (context, state) => orderDetailBuilder(
                context,
                state.pathParameters['id'] ?? '',
              ),
            ),
        ],
      ),
    ],
  );
}
