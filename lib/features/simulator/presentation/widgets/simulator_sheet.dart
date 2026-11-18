import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/features/realtime/presentation/bloc/order_stream_bloc.dart';
import 'package:orderpulse_flutter/features/simulator/presentation/bloc/simulator_cubit.dart';

/// Interactive bottom sheet letting reviewers trigger live orders, 401 races, and socket drops.
class SimulatorSheet extends StatelessWidget {
  const SimulatorSheet({super.key});

  static Future<void> show(
    BuildContext context, {
    required SimulatorCubit simulatorCubit,
    required OrderStreamBloc orderStreamBloc,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: simulatorCubit),
          BlocProvider.value(value: orderStreamBloc),
        ],
        child: const SimulatorSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: BlocBuilder<SimulatorCubit, SimulatorState>(
        builder: (context, state) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 20 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.science_outlined, color: kds.brandAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Network & Stream Simulator',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: kds.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close simulator',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  'Trigger real in-memory backend and socket edge cases running through Dio QueuedInterceptorsWrapper and OrderStreamBloc.',
                  style: textTheme.bodySmall?.copyWith(
                    color: kds.textSecondary,
                  ),
                ),
                if (state.isRunning) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: state.isRunning
                      ? null
                      : () => context.read<SimulatorCubit>().pushIncomingOrder(),
                  icon: const Icon(Icons.add_alert_rounded),
                  label: const Text('Push Incoming Live Order'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: state.isRunning
                      ? null
                      : () => context
                          .read<SimulatorCubit>()
                          .testConcurrent401Refresh(),
                  icon: const Icon(Icons.sync_lock_rounded),
                  label: const Text(
                    'Expire Token & Fire 3 Parallel Requests',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: state.isRunning
                      ? null
                      : () => context
                          .read<SimulatorCubit>()
                          .dropAndReconnectWebSocket(),
                  icon: const Icon(Icons.wifi_off_rounded),
                  label: const Text('Drop & Reconnect WebSocket Stream'),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hold Socket Offline (Watch Backoff)'),
                  subtitle: const Text(
                    'Keeps reconnect failing so attempt 1s -> 2s -> 4s ticks up.',
                  ),
                  value: state.isSocketHeldOffline,
                  onChanged: (value) {
                    context
                        .read<SimulatorCubit>()
                        .toggleHoldSocketOffline(value);
                    if (!value) {
                      context
                          .read<OrderStreamBloc>()
                          .add(const OrderStreamConnectRequested());
                    }
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: kds.statusRejected,
                    side: BorderSide(
                      color: kds.statusRejected.withValues(alpha: 0.6),
                    ),
                  ),
                  onPressed: state.isRunning
                      ? null
                      : () async {
                          Navigator.of(context).pop();
                          await context
                              .read<SimulatorCubit>()
                              .simulateExpiredRefreshLogout();
                        },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Simulate Refresh Expired (401 -> Logout)'),
                ),
                if (state.lastRefreshReport != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kds.statusReadyContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: kds.statusReady.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last 401 Queue Verification',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: kds.onStatusReadyContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Parallel requests: ${state.lastRefreshReport!.succeededCount}/${state.lastRefreshReport!.requestCount} returned 200 OK',
                          style: tabularStyle(
                            textTheme.bodySmall?.copyWith(
                              color: kds.onStatusReadyContainer,
                            ),
                          ),
                        ),
                        Text(
                          'Refresh calls executed: ${state.lastRefreshReport!.refreshCallsExecuted} (single-flight verified)',
                          style: tabularStyle(
                            textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: kds.onStatusReadyContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (state.eventLog.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Live Intercept & Stream Trace',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: kds.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kds.cardElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kds.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: state.eventLog
                          .take(6)
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $entry',
                                style: tabularStyle(
                                  textTheme.bodySmall?.copyWith(
                                    color: kds.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
