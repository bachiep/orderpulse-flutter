import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/features/orders/data/order_dto.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';

/// Stateful in-memory merchant backend serving Demo Mode HTTP traffic over Dio.
class DemoBackendEngine {
  DemoBackendEngine({
    AppClock? clock,
    this.simulatedLatency = const Duration(milliseconds: 90),
  }) : _clock = clock ?? const SystemClock() {
    _orders.addAll(_buildInitialOrders(_clock.now()));
  }

  final AppClock _clock;
  final Duration simulatedLatency;

  int _tokenVersion = 1;
  String _activeAccessToken = 'demo-access-v1';
  String _activeRefreshToken = 'demo-refresh-v1';
  bool _accessExpired = false;
  bool _refreshExpired = false;

  int refreshCallCount = 0;
  int _nextOrderSequence = 1029;
  final List<Order> _orders = [];

  String get activeAccessToken => _activeAccessToken;
  String get activeRefreshToken => _activeRefreshToken;
  bool get isAccessExpired => _accessExpired;
  bool get isRefreshExpired => _refreshExpired;
  List<Order> get ordersSnapshot => List.unmodifiable(_orders);

  /// Marks the active access token expired so subsequent protected requests return `401`.
  void expireAccessToken() {
    _accessExpired = true;
  }

  /// Marks both access and refresh tokens expired to test forced session logout.
  void expireRefreshToken() {
    _accessExpired = true;
    _refreshExpired = true;
  }

  /// Resets token state and re-seeds demo orders for a fresh Demo login session.
  void resetSession() {
    _tokenVersion = 1;
    _activeAccessToken = 'demo-access-v1';
    _activeRefreshToken = 'demo-refresh-v1';
    _accessExpired = false;
    _refreshExpired = false;
    refreshCallCount = 0;
    _nextOrderSequence = 1029;
    _orders
      ..clear()
      ..addAll(_buildInitialOrders(_clock.now()));
  }

  /// Appends a freshly arrived customer order at the top of the queue.
  Order createIncomingDemoOrder({
    String? customerName,
    String? kitchenNotes,
  }) {
    final now = _clock.now();
    final seq = _nextOrderSequence++;
    final order = Order(
      id: 'ORD-$seq',
      customerName: customerName ?? 'Nguyen Hoang Nam',
      customerPhone: '0909 *** ${seq % 1000}',
      items: const [
        OrderItem(
          name: 'Bun Cha Ha Noi Dac Biet',
          quantity: 2,
          unitPriceVnd: 65000,
          note: 'Extra herbs',
        ),
        OrderItem(
          name: 'Tra Tac Mat Ong (Large)',
          quantity: 2,
          unitPriceVnd: 25000,
          note: 'Less ice',
        ),
      ],
      totalAmountVnd: 180000,
      status: OrderStatus.newOrder,
      createdAt: now,
      updatedAt: now,
      kitchenNotes: kitchenNotes ?? 'Pack dipping sauce separately.',
    );
    _orders.insert(0, order);
    return order;
  }

  /// Marks an active order as rejected/cancelled by customer or system.
  Order? cancelOrderById(String orderId, String reason) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return null;
    final updated = _orders[index].copyWith(
      status: OrderStatus.rejected,
      rejectionReason: reason,
      updatedAt: _clock.now(),
    );
    _orders[index] = updated;
    return updated;
  }

  /// Assigns a delivery rider to an existing order.
  Order? assignRider(String orderId, String riderName, String riderPlate) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) return null;
    final updated = _orders[index].copyWith(
      riderName: riderName,
      riderPlate: riderPlate,
      updatedAt: _clock.now(),
    );
    _orders[index] = updated;
    return updated;
  }

  Future<ResponseBody> handleRequest(
    RequestOptions options,
    Map<String, dynamic>? body,
  ) async {
    if (simulatedLatency > Duration.zero) {
      await Future<void>.delayed(simulatedLatency);
    }

    final path = options.path;
    final method = options.method.toUpperCase();

    if (method == 'POST' && path == '/auth/login') {
      resetSession();
      final email = (body?['email'] as String?)?.trim();
      return _jsonResponse(200, {
        'accessToken': _activeAccessToken,
        'refreshToken': _activeRefreshToken,
        'expiresAt': _clock.now().add(const Duration(minutes: 15)).toIso8601String(),
        'merchant': {
          'id': 'merchant-demo-01',
          'merchantName': 'OrderPulse Kitchen - Demo',
          'branchName': 'District 1 Flagship',
          'email': (email != null && email.isNotEmpty)
              ? email
              : 'merchant@orderpulse.demo',
        },
      });
    }

    if (method == 'POST' && path == '/auth/refresh') {
      refreshCallCount += 1;
      final submittedRefresh = body?['refreshToken'] as String?;
      if (_refreshExpired || submittedRefresh != _activeRefreshToken) {
        return _jsonResponse(401, {
          'message': 'Refresh token expired or revoked.',
        });
      }
      _tokenVersion += 1;
      _activeAccessToken = 'demo-access-v$_tokenVersion';
      _activeRefreshToken = 'demo-refresh-v$_tokenVersion';
      _accessExpired = false;
      return _jsonResponse(200, {
        'accessToken': _activeAccessToken,
        'refreshToken': _activeRefreshToken,
        'expiresAt': _clock.now().add(const Duration(minutes: 15)).toIso8601String(),
      });
    }

    if (method == 'POST' && path == '/auth/logout') {
      return _jsonResponse(200, {'ok': true});
    }

    if (!_isAuthorized(options)) {
      return _jsonResponse(401, {
        'message': 'Access token expired or invalid.',
      });
    }

    if (method == 'GET' && path == '/merchant/profile') {
      return _jsonResponse(200, {
        'id': 'merchant-demo-01',
        'merchantName': 'OrderPulse Kitchen - Demo',
        'branchName': 'District 1 Flagship',
        'email': 'merchant@orderpulse.demo',
      });
    }

    if (method == 'GET' && path == '/orders/stats') {
      final activeCount = _orders
          .where((o) =>
              o.status == OrderStatus.newOrder ||
              o.status == OrderStatus.preparing ||
              o.status == OrderStatus.ready)
          .length;
      final completed =
          _orders.where((o) => o.status == OrderStatus.completed).toList();
      final revenue = completed.fold<int>(0, (sum, o) => sum + o.totalAmountVnd);
      return _jsonResponse(200, {
        'activeCount': activeCount,
        'completedToday': completed.length,
        'revenueTodayVnd': revenue,
        'avgPrepMinutes': 11.4,
      });
    }

    if (method == 'GET' && path == '/orders') {
      return _handleListOrders(options.queryParameters);
    }

    if (method == 'GET' && path.startsWith('/orders/')) {
      final id = path.substring('/orders/'.length);
      final match = _orders.where((o) => o.id == id);
      if (match.isEmpty) {
        return _jsonResponse(404, {'message': 'Order $id not found.'});
      }
      return _jsonResponse(200, OrderDto.toJson(match.first));
    }

    if (method == 'PATCH' &&
        path.startsWith('/orders/') &&
        path.endsWith('/status')) {
      final orderId = path.substring(
        '/orders/'.length,
        path.length - '/status'.length,
      );
      return _handleTransitionOrder(orderId, body);
    }

    return _jsonResponse(404, {'message': 'Route not found: $method $path'});
  }

  ResponseBody _handleListOrders(Map<String, dynamic> query) {
    final statusParam = query['status'] as String?;
    final searchQuery = (query['q'] as String? ?? '').trim().toLowerCase();
    final page = (query['page'] as num?)?.toInt() ?? 1;
    final pageSize = (query['pageSize'] as num?)?.toInt() ?? 8;

    Iterable<Order> filtered = _orders;
    if (statusParam != null && statusParam.isNotEmpty) {
      final targetStatus = OrderStatus.fromApi(statusParam);
      filtered = filtered.where((o) => o.status == targetStatus);
    }
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where(
        (o) =>
            o.id.toLowerCase().contains(searchQuery) ||
            o.customerName.toLowerCase().contains(searchQuery) ||
            o.items.any(
              (item) => item.name.toLowerCase().contains(searchQuery),
            ),
      );
    }

    final list = filtered.toList(growable: false);
    final start = ((page - 1) * pageSize).clamp(0, list.length);
    final end = (start + pageSize).clamp(0, list.length);
    final slice = list.sublist(start, end);

    return _jsonResponse(200, {
      'items': slice.map(OrderDto.toJson).toList(growable: false),
      'page': page,
      'pageSize': pageSize,
      'hasMore': end < list.length,
      'totalCount': list.length,
    });
  }

  ResponseBody _handleTransitionOrder(
    String orderId,
    Map<String, dynamic>? body,
  ) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) {
      return _jsonResponse(404, {'message': 'Order $orderId not found.'});
    }

    final current = _orders[index];
    final targetStatusRaw = body?['status'] as String? ?? '';
    final targetStatus = OrderStatus.fromApi(targetStatusRaw);
    final reason = (body?['rejectionReason'] as String?)?.trim();

    final isAllowed = switch ((current.status, targetStatus)) {
      (OrderStatus.newOrder, OrderStatus.preparing) => true,
      (OrderStatus.newOrder, OrderStatus.rejected) =>
        reason != null && reason.isNotEmpty,
      (OrderStatus.preparing, OrderStatus.ready) => true,
      (OrderStatus.ready, OrderStatus.completed) => true,
      _ => false,
    };

    if (!isAllowed) {
      return _jsonResponse(409, {
        'message':
            'Transition ${current.status.apiValue} -> ${targetStatus.apiValue} is not allowed.',
      });
    }

    final updated = current.copyWith(
      status: targetStatus,
      updatedAt: _clock.now(),
      rejectionReason: targetStatus == OrderStatus.rejected ? reason : null,
      riderName: targetStatus == OrderStatus.ready && current.riderName == null
          ? 'Pham Van Tien'
          : current.riderName,
      riderPlate:
          targetStatus == OrderStatus.ready && current.riderPlate == null
              ? '59-P2 482.19'
              : current.riderPlate,
    );
    _orders[index] = updated;
    return _jsonResponse(200, OrderDto.toJson(updated));
  }

  bool _isAuthorized(RequestOptions options) {
    if (_accessExpired) return false;
    final authHeader = options.headers['Authorization'] as String?;
    return authHeader == 'Bearer $_activeAccessToken';
  }

  ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> payload) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  List<Order> _buildInitialOrders(DateTime now) {
    return [
      Order(
        id: 'ORD-1028',
        customerName: 'Tran Minh Anh',
        customerPhone: '0912 *** 401',
        items: const [
          OrderItem(
            name: 'Com Tam Suon Bi Cha',
            quantity: 2,
            unitPriceVnd: 58000,
            note: 'No scallion oil',
          ),
          OrderItem(
            name: 'Ca Phe Sua Da',
            quantity: 1,
            unitPriceVnd: 32000,
          ),
        ],
        totalAmountVnd: 148000,
        status: OrderStatus.newOrder,
        createdAt: now.subtract(const Duration(minutes: 2)),
        updatedAt: now.subtract(const Duration(minutes: 2)),
        kitchenNotes: 'Peanut allergy: keep crushed peanuts out.',
      ),
      Order(
        id: 'ORD-1027',
        customerName: 'Le Quoc Bao',
        customerPhone: '0938 *** 118',
        items: const [
          OrderItem(
            name: 'Pho Bo Tai Nam',
            quantity: 2,
            unitPriceVnd: 72000,
          ),
          OrderItem(
            name: 'Quay Nong (Set)',
            quantity: 1,
            unitPriceVnd: 18000,
          ),
        ],
        totalAmountVnd: 162000,
        status: OrderStatus.newOrder,
        createdAt: now.subtract(const Duration(minutes: 4)),
        updatedAt: now.subtract(const Duration(minutes: 4)),
        kitchenNotes: 'Separate broth and noodles.',
      ),
      Order(
        id: 'ORD-1026',
        customerName: 'Pham Ngoc Han',
        customerPhone: '0977 *** 905',
        items: const [
          OrderItem(
            name: 'Banh Mi Chao Dac Biet',
            quantity: 1,
            unitPriceVnd: 69000,
          ),
          OrderItem(
            name: 'Nuoc Ep Cam Tuoi',
            quantity: 2,
            unitPriceVnd: 35000,
          ),
        ],
        totalAmountVnd: 139000,
        status: OrderStatus.preparing,
        createdAt: now.subtract(const Duration(minutes: 8)),
        updatedAt: now.subtract(const Duration(minutes: 5)),
        riderName: 'Nguyen Van Hung',
        riderPlate: '59-C1 731.04',
      ),
      Order(
        id: 'ORD-1025',
        customerName: 'Vo Tuan Kiet',
        customerPhone: '0908 *** 623',
        items: const [
          OrderItem(
            name: 'Bun Bo Hue Gio Heo',
            quantity: 3,
            unitPriceVnd: 68000,
            note: 'Mild chili',
          ),
        ],
        totalAmountVnd: 204000,
        status: OrderStatus.preparing,
        createdAt: now.subtract(const Duration(minutes: 11)),
        updatedAt: now.subtract(const Duration(minutes: 6)),
        kitchenNotes: 'Include extra lime wedges.',
      ),
      Order(
        id: 'ORD-1024',
        customerName: 'Do Thao Nhi',
        customerPhone: '0983 *** 312',
        items: const [
          OrderItem(
            name: 'Tra Sua O Long Nhai',
            quantity: 3,
            unitPriceVnd: 45000,
            note: '50% sugar',
          ),
          OrderItem(
            name: 'Banh Flan Caramen',
            quantity: 2,
            unitPriceVnd: 22000,
          ),
        ],
        totalAmountVnd: 179000,
        status: OrderStatus.ready,
        createdAt: now.subtract(const Duration(minutes: 16)),
        updatedAt: now.subtract(const Duration(minutes: 3)),
        riderName: 'Tran Duc Long',
        riderPlate: '59-X3 204.88',
      ),
      Order(
        id: 'ORD-1023',
        customerName: 'Hoang Gia Huy',
        customerPhone: '0945 *** 510',
        items: const [
          OrderItem(
            name: 'Ga Nuong Mat Ong + Xoi',
            quantity: 1,
            unitPriceVnd: 195000,
          ),
        ],
        totalAmountVnd: 195000,
        status: OrderStatus.ready,
        createdAt: now.subtract(const Duration(minutes: 19)),
        updatedAt: now.subtract(const Duration(minutes: 4)),
        riderName: 'Le Minh Tri',
        riderPlate: '59-T2 991.50',
      ),
      Order(
        id: 'ORD-1022',
        customerName: 'Bui Khanh Linh',
        customerPhone: '0919 *** 224',
        items: const [
          OrderItem(
            name: 'Mi Quang Tom Thit',
            quantity: 2,
            unitPriceVnd: 62000,
          ),
        ],
        totalAmountVnd: 124000,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(minutes: 28)),
        updatedAt: now.subtract(const Duration(minutes: 12)),
        riderName: 'Phan Thanh Tung',
        riderPlate: '59-D1 615.32',
      ),
      Order(
        id: 'ORD-1021',
        customerName: 'Dang Hai Phong',
        customerPhone: '0966 *** 771',
        items: const [
          OrderItem(
            name: 'Hu Tieu Nam Vang Kho',
            quantity: 2,
            unitPriceVnd: 65000,
          ),
          OrderItem(
            name: 'Sua Dau Nanh Lanh',
            quantity: 2,
            unitPriceVnd: 18000,
          ),
        ],
        totalAmountVnd: 166000,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(minutes: 34)),
        updatedAt: now.subtract(const Duration(minutes: 18)),
        riderName: 'Vo Hoang Phuc',
        riderPlate: '59-B1 108.44',
      ),
      Order(
        id: 'ORD-1020',
        customerName: 'Nguyen Thu Trang',
        customerPhone: '0932 *** 849',
        items: const [
          OrderItem(
            name: 'Goi Cuon Tom Thit (4 pcs)',
            quantity: 2,
            unitPriceVnd: 48000,
          ),
          OrderItem(
            name: 'Cha Gio Re Gion',
            quantity: 1,
            unitPriceVnd: 52000,
          ),
        ],
        totalAmountVnd: 148000,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(minutes: 42)),
        updatedAt: now.subtract(const Duration(minutes: 25)),
      ),
      Order(
        id: 'ORD-1019',
        customerName: 'Truong Dinh Quan',
        customerPhone: '0904 *** 193',
        items: const [
          OrderItem(
            name: 'Lau Thai Hai San (2P)',
            quantity: 1,
            unitPriceVnd: 285000,
          ),
        ],
        totalAmountVnd: 285000,
        status: OrderStatus.rejected,
        createdAt: now.subtract(const Duration(minutes: 48)),
        updatedAt: now.subtract(const Duration(minutes: 45)),
        rejectionReason: 'Fresh squid out of stock for evening shift.',
      ),
      Order(
        id: 'ORD-1018',
        customerName: 'Ly Hoang Yen',
        customerPhone: '0971 *** 064',
        items: const [
          OrderItem(
            name: 'Matcha Latte Oatmilk',
            quantity: 2,
            unitPriceVnd: 55000,
          ),
        ],
        totalAmountVnd: 110000,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(minutes: 56)),
        updatedAt: now.subtract(const Duration(minutes: 39)),
      ),
      Order(
        id: 'ORD-1017',
        customerName: 'Mai Phuoc Loc',
        customerPhone: '0917 *** 530',
        items: const [
          OrderItem(
            name: 'Com Ga Xoi Mo',
            quantity: 2,
            unitPriceVnd: 60000,
          ),
        ],
        totalAmountVnd: 120000,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(minutes: 64)),
        updatedAt: now.subtract(const Duration(minutes: 47)),
      ),
    ];
  }
}

/// Custom Dio [HttpClientAdapter] routing requests to [DemoBackendEngine] in-memory.
class DemoBackendHttpAdapter implements HttpClientAdapter {
  DemoBackendHttpAdapter(this.engine);

  final DemoBackendEngine engine;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Map<String, dynamic>? jsonBody;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      final bytes = chunks.expand((e) => e).toList();
      if (bytes.isNotEmpty) {
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is Map<String, dynamic>) {
          jsonBody = decoded;
        }
      }
    } else if (options.data is Map<String, dynamic>) {
      jsonBody = options.data as Map<String, dynamic>;
    }

    return engine.handleRequest(options, jsonBody);
  }

  @override
  void close({bool force = false}) {}
}
