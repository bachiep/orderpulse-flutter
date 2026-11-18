import 'dart:convert';
import 'dart:math' as math;
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
      pickupCode: 'PK-$seq',
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
      riderPhone: '0903 *** 482',
      riderVehicle: 'Honda Wave RSX',
      riderEtaMinutes: 4,
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
          'merchantName': 'OrderPulse',
          'branchName': 'District 1 • Demo Kitchen',
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
        'merchantName': 'OrderPulse',
        'branchName': 'District 1 • Demo Kitchen',
        'email': 'merchant@orderpulse.demo',
      });
    }

    if (method == 'GET' && path == '/orders/stats') {
      final activeCount = _orders.where((o) => o.status.isActive).length;
      final completed =
          _orders.where((o) => o.status == OrderStatus.completed).toList();
      final revenue = completed.fold<int>(0, (sum, o) => sum + o.totalAmountVnd);
      final prepDurations = _orders
          .where(
            (o) =>
                o.status == OrderStatus.ready ||
                o.status == OrderStatus.completed,
          )
          .map((o) {
            final finish = o.readyAt ?? o.completedAt ?? o.updatedAt;
            return math.max(1.0, finish.difference(o.createdAt).inSeconds / 60.0);
          })
          .toList();
      final avgPrep = prepDurations.isEmpty
          ? 0.0
          : prepDurations.reduce((a, b) => a + b) / prepDurations.length;

      return _jsonResponse(200, {
        'activeCount': activeCount,
        'completedToday': completed.length,
        'revenueTodayVnd': revenue,
        'avgPrepMinutes': double.parse(avgPrep.toStringAsFixed(1)),
      });
    }

    if (method == 'GET' && path == '/orders') {
      return _handleListOrders(options.queryParameters);
    }

    final itemPrepMatch =
        RegExp(r'^/orders/([^/]+)/items/(\d+)$').firstMatch(path);
    if (method == 'PATCH' && itemPrepMatch != null) {
      final orderId = itemPrepMatch.group(1)!;
      final itemIndex = int.tryParse(itemPrepMatch.group(2)!) ?? -1;
      final isPrepped = body?['isPrepped'] as bool?;
      return _handleToggleItemPrepped(orderId, itemIndex, isPrepped);
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

    if (method == 'GET' && path.startsWith('/orders/')) {
      final id = path.substring('/orders/'.length);
      final match = _orders.where((o) => o.id == id);
      if (match.isEmpty) {
        return _jsonResponse(404, {'message': 'Order $id not found.'});
      }
      return _jsonResponse(200, OrderDto.toJson(match.first));
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

  ResponseBody _handleToggleItemPrepped(
    String orderId,
    int itemIndex,
    bool? isPrepped,
  ) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) {
      return _jsonResponse(404, {'message': 'Order $orderId not found.'});
    }
    final current = _orders[index];
    if (itemIndex < 0 || itemIndex >= current.items.length) {
      return _jsonResponse(400, {'message': 'Invalid item index $itemIndex.'});
    }
    final updated = current.toggleItemPrepped(itemIndex, isPrepped: isPrepped);
    _orders[index] = updated;
    return _jsonResponse(200, OrderDto.toJson(updated));
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
    final now = _clock.now();

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

    final shouldAutoAssignRider =
        targetStatus == OrderStatus.ready && current.riderName == null;
    final nextItems = targetStatus == OrderStatus.ready
        ? current.items
            .map((item) => item.copyWith(isPrepped: true))
            .toList(growable: false)
        : current.items;

    final updated = current.copyWith(
      items: nextItems,
      status: targetStatus,
      updatedAt: now,
      acceptedAt: targetStatus == OrderStatus.preparing
          ? (current.acceptedAt ?? now)
          : current.acceptedAt,
      readyAt: targetStatus == OrderStatus.ready
          ? (current.readyAt ?? now)
          : current.readyAt,
      completedAt: targetStatus == OrderStatus.completed
          ? (current.completedAt ?? now)
          : current.completedAt,
      rejectionReason: targetStatus == OrderStatus.rejected ? reason : null,
      riderName: shouldAutoAssignRider ? 'Pham Van Tien' : current.riderName,
      riderPlate: shouldAutoAssignRider ? '59-P2 482.19' : current.riderPlate,
      riderPhone: shouldAutoAssignRider ? '0907 *** 635' : current.riderPhone,
      riderVehicle:
          shouldAutoAssignRider ? 'Yamaha Sirius' : current.riderVehicle,
      riderEtaMinutes:
          shouldAutoAssignRider ? 3 : current.riderEtaMinutes,
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
        pickupCode: 'PK-284',
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
        createdAt: now.subtract(const Duration(minutes: 12)),
        updatedAt: now.subtract(const Duration(minutes: 12)),
        pickupCode: 'PK-279',
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
            isPrepped: true,
          ),
          OrderItem(
            name: 'Ca Phe Sua Da',
            quantity: 2,
            unitPriceVnd: 32000,
          ),
        ],
        totalAmountVnd: 133000,
        status: OrderStatus.preparing,
        createdAt: now.subtract(const Duration(minutes: 8)),
        updatedAt: now.subtract(const Duration(minutes: 5)),
        acceptedAt: now.subtract(const Duration(minutes: 6)),
        pickupCode: 'PK-261',
        riderName: 'Nguyen Van Hung',
        riderPlate: '59-C1 731.04',
        riderPhone: '0903 *** 812',
        riderVehicle: 'Honda Wave RSX',
        riderEtaMinutes: 4,
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
            isPrepped: true,
          ),
          OrderItem(
            name: 'Tra Dao Cam Sa',
            quantity: 2,
            unitPriceVnd: 38000,
          ),
        ],
        totalAmountVnd: 280000,
        status: OrderStatus.preparing,
        createdAt: now.subtract(const Duration(minutes: 19)),
        updatedAt: now.subtract(const Duration(minutes: 13)),
        acceptedAt: now.subtract(const Duration(minutes: 13)),
        pickupCode: 'PK-255',
        kitchenNotes: 'Include extra lime wedges and shrimp paste on side.',
        riderName: 'Le Hoang Duy',
        riderPlate: '59-D2 814.20',
        riderPhone: '0914 *** 520',
        riderVehicle: 'Honda Winner X',
        riderEtaMinutes: 2,
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
            isPrepped: true,
          ),
          OrderItem(
            name: 'Banh Flan Caramen',
            quantity: 2,
            unitPriceVnd: 22000,
            isPrepped: true,
          ),
        ],
        totalAmountVnd: 179000,
        status: OrderStatus.ready,
        createdAt: now.subtract(const Duration(minutes: 11)),
        updatedAt: now.subtract(const Duration(minutes: 2)),
        acceptedAt: now.subtract(const Duration(minutes: 9)),
        readyAt: now.subtract(const Duration(minutes: 2)),
        pickupCode: 'PK-248',
        riderName: 'Tran Duc Long',
        riderPlate: '59-X3 204.88',
        riderPhone: '0908 *** 294',
        riderVehicle: 'Yamaha Exciter',
        riderEtaMinutes: 1,
      ),
      Order(
        id: 'ORD-1023',
        customerName: 'Hoang Gia Huy',
        customerPhone: '0945 *** 510',
        items: const [
          OrderItem(
            name: 'Com Tam Suon Bi Cha',
            quantity: 2,
            unitPriceVnd: 58000,
            isPrepped: true,
          ),
          OrderItem(
            name: 'Ca Phe Sua Da',
            quantity: 2,
            unitPriceVnd: 32000,
            isPrepped: true,
          ),
        ],
        totalAmountVnd: 180000,
        status: OrderStatus.ready,
        createdAt: now.subtract(const Duration(minutes: 17)),
        updatedAt: now.subtract(const Duration(minutes: 4)),
        acceptedAt: now.subtract(const Duration(minutes: 14)),
        readyAt: now.subtract(const Duration(minutes: 4)),
        pickupCode: 'PK-237',
        riderName: 'Le Minh Tri',
        riderPlate: '59-T2 991.50',
        riderPhone: '0933 *** 741',
        riderVehicle: 'Honda Vision',
        riderEtaMinutes: 2,
      ),
      Order(
        id: 'ORD-1022',
        customerName: 'Bui Khanh Linh',
        customerPhone: '0919 *** 224',
        items: const [
          OrderItem(
            name: 'Pho Bo Tai Nam',
            quantity: 2,
            unitPriceVnd: 72000,
            isPrepped: true,
          ),
        ],
        totalAmountVnd: 144000,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(minutes: 32)),
        updatedAt: now.subtract(const Duration(minutes: 20)),
        acceptedAt: now.subtract(const Duration(minutes: 30)),
        readyAt: now.subtract(const Duration(minutes: 22)),
        completedAt: now.subtract(const Duration(minutes: 20)),
        pickupCode: 'PK-224',
        riderName: 'Phan Thanh Tung',
        riderPlate: '59-D1 615.32',
        riderPhone: '0972 *** 118',
        riderVehicle: 'Honda AirBlade',
      ),
      Order(
        id: 'ORD-1021',
        customerName: 'Dang Hai Phong',
        customerPhone: '0966 *** 771',
        items: const [
          OrderItem(
            name: 'Com Tam Suon Bi Cha',
            quantity: 2,
            unitPriceVnd: 58000,
            isPrepped: true,
          ),
          OrderItem(
            name: 'Ca Phe Sua Da',
            quantity: 2,
            unitPriceVnd: 32000,
            isPrepped: true,
          ),
        ],
        totalAmountVnd: 180000,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(minutes: 72)),
        updatedAt: now.subtract(const Duration(minutes: 58)),
        acceptedAt: now.subtract(const Duration(minutes: 70)),
        readyAt: now.subtract(const Duration(minutes: 61)),
        completedAt: now.subtract(const Duration(minutes: 58)),
        pickupCode: 'PK-219',
        riderName: 'Vo Hoang Phuc',
        riderPlate: '59-B1 108.44',
        riderPhone: '0901 *** 663',
        riderVehicle: 'Honda Wave Alpha',
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
            isPrepped: true,
          ),
          OrderItem(
            name: 'Tra Sua O Long Nhai',
            quantity: 2,
            unitPriceVnd: 45000,
            isPrepped: true,
          ),
        ],
        totalAmountVnd: 186000,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(minutes: 88)),
        updatedAt: now.subtract(const Duration(minutes: 75)),
        acceptedAt: now.subtract(const Duration(minutes: 86)),
        readyAt: now.subtract(const Duration(minutes: 78)),
        completedAt: now.subtract(const Duration(minutes: 75)),
        pickupCode: 'PK-203',
        riderName: 'Doan Quoc Huy',
        riderPlate: '59-L1 392.11',
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
        createdAt: now.subtract(const Duration(minutes: 96)),
        updatedAt: now.subtract(const Duration(minutes: 93)),
        pickupCode: 'PK-194',
        rejectionReason: 'Fresh squid out of stock for evening shift.',
      ),
      Order(
        id: 'ORD-1018',
        customerName: 'Ly Hoang Yen',
        customerPhone: '0971 *** 064',
        items: const [
          OrderItem(
            name: 'Pho Bo Tai Nam',
            quantity: 3,
            unitPriceVnd: 72000,
            isPrepped: true,
          ),
          OrderItem(
            name: 'Ca Phe Sua Da',
            quantity: 2,
            unitPriceVnd: 32000,
            isPrepped: true,
          ),
        ],
        totalAmountVnd: 280000,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(minutes: 132)),
        updatedAt: now.subtract(const Duration(minutes: 118)),
        acceptedAt: now.subtract(const Duration(minutes: 130)),
        readyAt: now.subtract(const Duration(minutes: 120)),
        completedAt: now.subtract(const Duration(minutes: 118)),
        pickupCode: 'PK-188',
        riderName: 'Nguyen Van Hung',
        riderPlate: '59-C1 731.04',
      ),
      Order(
        id: 'ORD-1017',
        customerName: 'Mai Phuoc Loc',
        customerPhone: '0917 *** 530',
        items: const [
          OrderItem(
            name: 'Bun Bo Hue Gio Heo',
            quantity: 2,
            unitPriceVnd: 68000,
            isPrepped: true,
          ),
          OrderItem(
            name: 'Quay Nong (Set)',
            quantity: 2,
            unitPriceVnd: 18000,
            isPrepped: true,
          ),
        ],
        totalAmountVnd: 172000,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(minutes: 145)),
        updatedAt: now.subtract(const Duration(minutes: 131)),
        acceptedAt: now.subtract(const Duration(minutes: 143)),
        readyAt: now.subtract(const Duration(minutes: 134)),
        completedAt: now.subtract(const Duration(minutes: 131)),
        pickupCode: 'PK-176',
        riderName: 'Pham Van Tien',
        riderPlate: '59-P2 482.19',
      ),
      Order(
        id: 'ORD-1016',
        customerName: 'Huynh Ngoc Mai',
        customerPhone: '0902 *** 819',
        items: const [
          OrderItem(
            name: 'Com Tam Suon Bi Cha',
            quantity: 3,
            unitPriceVnd: 58000,
            isPrepped: true,
          ),
          OrderItem(
            name: 'Tra Dao Cam Sa',
            quantity: 2,
            unitPriceVnd: 38000,
            isPrepped: true,
          ),
        ],
        totalAmountVnd: 250000,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(minutes: 192)),
        updatedAt: now.subtract(const Duration(minutes: 180)),
        acceptedAt: now.subtract(const Duration(minutes: 190)),
        readyAt: now.subtract(const Duration(minutes: 182)),
        completedAt: now.subtract(const Duration(minutes: 180)),
        pickupCode: 'PK-162',
        riderName: 'Tran Duc Long',
        riderPlate: '59-X3 204.88',
      ),
      Order(
        id: 'ORD-1015',
        customerName: 'Cao Tuan Anh',
        customerPhone: '0939 *** 302',
        items: const [
          OrderItem(
            name: 'Banh Mi Chao Dac Biet',
            quantity: 2,
            unitPriceVnd: 69000,
            isPrepped: true,
          ),
          OrderItem(
            name: 'Ca Phe Sua Da',
            quantity: 1,
            unitPriceVnd: 32000,
            isPrepped: true,
          ),
        ],
        totalAmountVnd: 170000,
        status: OrderStatus.completed,
        createdAt: now.subtract(const Duration(minutes: 210)),
        updatedAt: now.subtract(const Duration(minutes: 198)),
        acceptedAt: now.subtract(const Duration(minutes: 208)),
        readyAt: now.subtract(const Duration(minutes: 200)),
        completedAt: now.subtract(const Duration(minutes: 198)),
        pickupCode: 'PK-151',
        riderName: 'Le Minh Tri',
        riderPlate: '59-T2 991.50',
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
