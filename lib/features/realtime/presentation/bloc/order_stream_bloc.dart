import 'dart:async';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/features/realtime/domain/order_realtime_event.dart';
import 'package:orderpulse_flutter/features/realtime/domain/order_realtime_source.dart';

sealed class OrderStreamEvent extends Equatable {
  const OrderStreamEvent();

  @override
  List<Object?> get props => [];
}

final class OrderStreamConnectRequested extends OrderStreamEvent {
  const OrderStreamConnectRequested();
}

final class OrderStreamDisconnectRequested extends OrderStreamEvent {
  const OrderStreamDisconnectRequested();
}

final class _OrderStreamMessageReceived extends OrderStreamEvent {
  const _OrderStreamMessageReceived(this.event);

  final OrderRealtimeEvent event;

  @override
  List<Object?> get props => [event];
}

final class _OrderStreamConnectionLost extends OrderStreamEvent {
  const _OrderStreamConnectionLost();
}

final class _OrderStreamReconnectTick extends OrderStreamEvent {
  const _OrderStreamReconnectTick();
}

sealed class OrderStreamState extends Equatable {
  const OrderStreamState();

  @override
  List<Object?> get props => [];
}

final class OrderStreamOffline extends OrderStreamState {
  const OrderStreamOffline({this.reason});

  final String? reason;

  @override
  List<Object?> get props => [reason];
}

final class OrderStreamConnecting extends OrderStreamState {
  const OrderStreamConnecting();
}

final class OrderStreamLive extends OrderStreamState {
  const OrderStreamLive({
    this.receivedCount = 0,
    this.lastEventAt,
    this.latestEvent,
  });

  final int receivedCount;
  final DateTime? lastEventAt;
  final OrderRealtimeEvent? latestEvent;

  @override
  List<Object?> get props => [receivedCount, lastEventAt, latestEvent];
}

final class OrderStreamReconnecting extends OrderStreamState {
  const OrderStreamReconnecting({
    required this.attempt,
    required this.nextRetryDelay,
  });

  final int attempt;
  final Duration nextRetryDelay;

  @override
  List<Object?> get props => [attempt, nextRetryDelay];
}

/// Manages WebSocket lifecycle and bounded exponential-backoff reconnection.
class OrderStreamBloc extends Bloc<OrderStreamEvent, OrderStreamState> {
  OrderStreamBloc({
    required OrderRealtimeDataSource dataSource,
    AppClock? clock,
    this.initialBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(seconds: 16),
  })  : _dataSource = dataSource,
        _clock = clock ?? const SystemClock(),
        super(const OrderStreamOffline()) {
    on<OrderStreamConnectRequested>(_onConnectRequested);
    on<OrderStreamDisconnectRequested>(_onDisconnectRequested);
    on<_OrderStreamMessageReceived>(_onMessageReceived);
    on<_OrderStreamConnectionLost>(_onConnectionLost);
    on<_OrderStreamReconnectTick>(_onReconnectTick);
  }

  final OrderRealtimeDataSource _dataSource;
  final AppClock _clock;
  final Duration initialBackoff;
  final Duration maxBackoff;

  StreamSubscription<OrderRealtimeEvent>? _subscription;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  int _receivedCount = 0;
  DateTime? _lastEventAt;
  bool _manualDisconnect = false;

  /// Computes bounded exponential backoff (`1s -> 2s -> 4s -> 8s -> max 16s`).
  Duration backoffForAttempt(int attempt) {
    final safeAttempt = attempt < 1 ? 1 : attempt;
    final multiplier = 1 << math.min(safeAttempt - 1, 10);
    final candidateMs = initialBackoff.inMilliseconds * multiplier;
    return Duration(
      milliseconds: math.min(candidateMs, maxBackoff.inMilliseconds),
    );
  }

  Future<void> _onConnectRequested(
    OrderStreamConnectRequested event,
    Emitter<OrderStreamState> emit,
  ) async {
    _manualDisconnect = false;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _cancelSubscription();

    emit(const OrderStreamConnecting());
    await _attemptConnect(emit);
  }

  Future<void> _onDisconnectRequested(
    OrderStreamDisconnectRequested event,
    Emitter<OrderStreamState> emit,
  ) async {
    _manualDisconnect = true;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _cancelSubscription();
    await _dataSource.disconnect();
    emit(const OrderStreamOffline());
  }

  void _onMessageReceived(
    _OrderStreamMessageReceived event,
    Emitter<OrderStreamState> emit,
  ) {
    _receivedCount += 1;
    _lastEventAt = _clock.now();
    emit(
      OrderStreamLive(
        receivedCount: _receivedCount,
        lastEventAt: _lastEventAt,
        latestEvent: event.event,
      ),
    );
  }

  Future<void> _onConnectionLost(
    _OrderStreamConnectionLost event,
    Emitter<OrderStreamState> emit,
  ) async {
    if (_manualDisconnect || isClosed) return;
    await _cancelSubscription();
    _scheduleReconnect(emit);
  }

  Future<void> _onReconnectTick(
    _OrderStreamReconnectTick event,
    Emitter<OrderStreamState> emit,
  ) async {
    if (_manualDisconnect || isClosed) return;
    await _attemptConnect(emit);
  }

  Future<void> _attemptConnect(Emitter<OrderStreamState> emit) async {
    try {
      final stream = await _dataSource.connect();
      if (_manualDisconnect || isClosed) {
        await _dataSource.disconnect();
        return;
      }

      _reconnectAttempt = 0;
      _subscription = stream.listen(
        (event) {
          if (!isClosed) {
            add(_OrderStreamMessageReceived(event));
          }
        },
        onError: (_, _) => _notifyConnectionLost(),
        onDone: _notifyConnectionLost,
      );

      emit(
        OrderStreamLive(
          receivedCount: _receivedCount,
          lastEventAt: _lastEventAt,
        ),
      );
    } catch (_) {
      if (!_manualDisconnect && !isClosed) {
        _scheduleReconnect(emit);
      }
    }
  }

  void _notifyConnectionLost() {
    if (_manualDisconnect || isClosed) return;
    if (_subscription == null) return;
    unawaited(_subscription?.cancel());
    _subscription = null;
    add(const _OrderStreamConnectionLost());
  }

  void _scheduleReconnect(Emitter<OrderStreamState> emit) {
    _reconnectTimer?.cancel();
    _reconnectAttempt += 1;
    final delay = backoffForAttempt(_reconnectAttempt);

    emit(
      OrderStreamReconnecting(
        attempt: _reconnectAttempt,
        nextRetryDelay: delay,
      ),
    );

    _reconnectTimer = Timer(delay, () {
      if (!_manualDisconnect && !isClosed) {
        add(const _OrderStreamReconnectTick());
      }
    });
  }

  Future<void> _cancelSubscription() async {
    final active = _subscription;
    _subscription = null;
    if (active != null) {
      await active.cancel();
    }
  }

  @override
  Future<void> close() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final active = _subscription;
    _subscription = null;
    if (active != null) {
      unawaited(active.cancel());
    }
    unawaited(_dataSource.disconnect());
    return super.close();
  }
}
