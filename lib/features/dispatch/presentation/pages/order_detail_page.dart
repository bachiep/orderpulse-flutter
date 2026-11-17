import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/core/di/injection.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/core/widgets/state_views.dart';
import 'package:orderpulse_flutter/core/widgets/status_badge.dart';
import 'package:orderpulse_flutter/features/dispatch/domain/order_state_machine.dart';
import 'package:orderpulse_flutter/features/dispatch/presentation/bloc/order_action_bloc.dart';
import 'package:orderpulse_flutter/features/dispatch/presentation/widgets/reject_order_dialog.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_repository.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_board_bloc.dart';

/// Dependency-injected detail screen resolving an order by ID or route extra.
class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  final String orderId;
  final Order? initialOrder;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Order? _order;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder ?? _findInBoard();
    if (_order == null) {
      _loadOrder();
    }
  }

  Order? _findInBoard() {
    final boardState = sl<OrderBoardBloc>().state;
    if (boardState is OrderBoardLoaded) {
      for (final item in boardState.orders) {
        if (item.id == widget.orderId) return item;
      }
    }
    return null;
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await sl<OrderRepository>().fetchOrderById(widget.orderId);
    if (!mounted) return;
    switch (result) {
      case Success<Order>(:final value):
        setState(() {
          _order = value;
          _isLoading = false;
        });
      case Err<Order>(:final failure):
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.orderId)),
        body: const LoadingStateView(message: 'Loading ticket details...'),
      );
    }

    if (_errorMessage != null || _order == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.orderId)),
        body: ErrorStateView(
          message: _errorMessage ?? 'Order ${widget.orderId} not found.',
          onRetry: _loadOrder,
        ),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<OrderActionBloc>()),
        BlocProvider.value(value: sl<OrderBoardBloc>()),
      ],
      child: BlocListener<OrderBoardBloc, OrderBoardState>(
        listener: (context, boardState) {
          if (boardState is OrderBoardLoaded) {
            for (final item in boardState.orders) {
              if (item.id == widget.orderId && item != _order) {
                setState(() => _order = item);
                break;
              }
            }
          }
        },
        child: OrderDetailView(
          order: _order!,
          clock: sl<AppClock>(),
          onOrderUpdated: (updated) {
            setState(() => _order = updated);
            sl<OrderBoardBloc>().add(OrderBoardOrderUpserted(updated));
          },
        ),
      ),
    );
  }
}

/// Pure declarative kitchen ticket & dispatch state-machine view.
class OrderDetailView extends StatelessWidget {
  const OrderDetailView({
    super.key,
    required this.order,
    required this.clock,
    this.onOrderUpdated,
  });

  final Order order;
  final AppClock clock;
  final ValueChanged<Order>? onOrderUpdated;

  Future<void> _handleReject(BuildContext context) async {
    final reason = await RejectOrderDialog.show(context, order.id);
    if (reason == null || !context.mounted) return;
    context.read<OrderActionBloc>().add(
          OrderTransitionRequested(
            order: order,
            targetStatus: OrderStatus.rejected,
            rejectionReason: reason,
          ),
        );
  }

  void _dispatch(BuildContext context, OrderStatus targetStatus) {
    context.read<OrderActionBloc>().add(
          OrderTransitionRequested(
            order: order,
            targetStatus: targetStatus,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocConsumer<OrderActionBloc, OrderActionState>(
      listener: (context, state) {
        if (state is OrderActionSuccess && state.updatedOrder.id == order.id) {
          onOrderUpdated?.call(state.updatedOrder);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order ${state.updatedOrder.id} moved to ${state.updatedOrder.status.label}.',
              ),
            ),
          );
        } else if (state is OrderActionFailure && state.orderId == order.id) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: colorScheme.error,
              content: Text(state.message),
            ),
          );
        }
      },
      builder: (context, actionState) {
        final isBusy = actionState is OrderActionInProgress &&
            actionState.orderId == order.id;

        return Scaffold(
          appBar: AppBar(
            title: Text(order.id),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: OrderStatusBadge(status: order.status)),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                order.customerName,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              formatElapsedSince(order.createdAt, clock.now()),
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if (order.customerPhone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Contact: ${order.customerPhone}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (order.kitchenNotes != null &&
                            order.kitchenNotes!.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 18,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Kitchen Note: ${order.kitchenNotes!}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Items (${order.totalItemCount})',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...order.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${item.quantity}x',
                                    style: textTheme.labelMedium?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (item.note != null &&
                                          item.note!.trim().isNotEmpty)
                                        Text(
                                          item.note!,
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatVnd(item.lineTotalVnd),
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Total Payout',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatVnd(order.totalAmountVnd),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (order.riderName != null || order.rejectionReason != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (order.riderName != null) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.delivery_dining_rounded,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Assigned Rider: ${order.riderName}',
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (order.riderPlate != null)
                                        Text(
                                          'Plate: ${order.riderPlate}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (order.rejectionReason != null) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.cancel_outlined,
                                  color: colorScheme.error,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Rejected: ${order.rejectionReason!}',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isBusy) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 10),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                        ),
                        onPressed: !isBusy &&
                                OrderStateMachine.canReject(order.status)
                            ? () => _handleReject(context)
                            : null,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Reject Order'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: !isBusy &&
                                OrderStateMachine.canAcceptAndPrepare(
                                  order.status,
                                )
                            ? () => _dispatch(context, OrderStatus.preparing)
                            : null,
                        icon: const Icon(Icons.local_fire_department_outlined),
                        label: const Text('Accept & Prepare'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: !isBusy &&
                                OrderStateMachine.canMarkReady(order.status)
                            ? () => _dispatch(context, OrderStatus.ready)
                            : null,
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Mark Ready'),
                      ),
                      FilledButton.icon(
                        onPressed: !isBusy &&
                                OrderStateMachine.canHandoverComplete(
                                  order.status,
                                )
                            ? () => _dispatch(context, OrderStatus.completed)
                            : null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Handover to Rider'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
