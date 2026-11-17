import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/simulator/domain/network_simulator_service.dart';

class SimulatorState extends Equatable {
  const SimulatorState({
    required this.isSupported,
    this.isRunning = false,
    this.isSocketHeldOffline = false,
    this.lastRefreshReport,
    this.eventLog = const [],
    this.lastError,
  });

  final bool isSupported;
  final bool isRunning;
  final bool isSocketHeldOffline;
  final ParallelRefreshReport? lastRefreshReport;
  final List<String> eventLog;
  final String? lastError;

  SimulatorState copyWith({
    bool? isRunning,
    bool? isSocketHeldOffline,
    ParallelRefreshReport? lastRefreshReport,
    List<String>? eventLog,
    String? lastError,
    bool clearError = false,
  }) {
    return SimulatorState(
      isSupported: isSupported,
      isRunning: isRunning ?? this.isRunning,
      isSocketHeldOffline: isSocketHeldOffline ?? this.isSocketHeldOffline,
      lastRefreshReport: lastRefreshReport ?? this.lastRefreshReport,
      eventLog: eventLog ?? this.eventLog,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => [
        isSupported,
        isRunning,
        isSocketHeldOffline,
        lastRefreshReport,
        eventLog,
        lastError,
      ];
}

/// Orchestrates standalone recruiter demo simulations and live diagnostic traces.
class SimulatorCubit extends Cubit<SimulatorState> {
  SimulatorCubit({required NetworkSimulatorService service})
      : _service = service,
        super(SimulatorState(isSupported: service.isSupported));

  final NetworkSimulatorService _service;

  Future<void> pushIncomingOrder() async {
    if (!state.isSupported || state.isRunning) return;
    emit(state.copyWith(isRunning: true, clearError: true));

    final result = await _service.pushIncomingOrder();
    switch (result) {
      case Success<Order>(:final value):
        emit(
          state.copyWith(
            isRunning: false,
            eventLog: _prependLog(
              'Pushed live order ${value.id} (${value.customerName}).',
            ),
          ),
        );
      case Err<Order>(:final failure):
        emit(state.copyWith(isRunning: false, lastError: failure.message));
    }
  }

  Future<void> testConcurrent401Refresh() async {
    if (!state.isSupported || state.isRunning) return;
    emit(state.copyWith(isRunning: true, clearError: true));

    final result = await _service.expireAccessTokenAndRunParallelRequests();
    switch (result) {
      case Success<ParallelRefreshReport>(:final value):
        final summary =
            '3 parallel calls -> ${value.succeededCount}/${value.requestCount} 200 OK with ${value.refreshCallsExecuted}x /auth/refresh.';
        emit(
          state.copyWith(
            isRunning: false,
            lastRefreshReport: value,
            eventLog: [
              summary,
              ...value.traces.reversed,
              ...state.eventLog,
            ].take(15).toList(growable: false),
          ),
        );
      case Err<ParallelRefreshReport>(:final failure):
        emit(
          state.copyWith(
            isRunning: false,
            lastError: failure.message,
            eventLog: _prependLog('401 test failed: ${failure.message}'),
          ),
        );
    }
  }

  Future<void> dropAndReconnectWebSocket() async {
    if (!state.isSupported || state.isRunning) return;
    _service.restoreWebSocket();
    await _service.dropWebSocket(stayOffline: false);
    emit(
      state.copyWith(
        isSocketHeldOffline: false,
        clearError: true,
        eventLog: _prependLog(
          'Dropped WebSocket; exponential backoff reconnect triggered.',
        ),
      ),
    );
  }

  Future<void> toggleHoldSocketOffline(bool holdOffline) async {
    if (!state.isSupported) return;
    if (holdOffline) {
      await _service.dropWebSocket(stayOffline: true);
      emit(
        state.copyWith(
          isSocketHeldOffline: true,
          eventLog: _prependLog(
            'Socket outage held active (watch backoff 1s -> 2s -> 4s...).',
          ),
        ),
      );
    } else {
      _service.restoreWebSocket();
      emit(
        state.copyWith(
          isSocketHeldOffline: false,
          eventLog: _prependLog(
            'Socket network restored; next backoff tick will reconnect.',
          ),
        ),
      );
    }
  }

  Future<void> simulateExpiredRefreshLogout() async {
    if (!state.isSupported || state.isRunning) return;
    emit(state.copyWith(isRunning: true, clearError: true));
    await _service.simulateRefreshTokenExpired();
    if (!isClosed) {
      emit(state.copyWith(isRunning: false));
    }
  }

  List<String> _prependLog(String line) {
    return [line, ...state.eventLog].take(15).toList(growable: false);
  }
}
