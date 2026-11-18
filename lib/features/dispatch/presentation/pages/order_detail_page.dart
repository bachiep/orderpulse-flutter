import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/core/di/injection.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/core/theme/app_theme.dart';
import 'package:orderpulse_flutter/core/time/app_clock.dart';
import 'package:orderpulse_flutter/core/widgets/state_views.dart';
import 'package:orderpulse_flutter/core/widgets/status_badge.dart';
import 'package:orderpulse_flutter/features/dispatch/domain/order_state_machine.dart';
import 'package:orderpulse_flutter/features/dispatch/presentation/bloc/order_action_bloc.dart';
import 'package:orderpulse_flutter/features/dispatch/presentation/widgets/kitchen_slip_sheet.dart';
import 'package:orderpulse_flutter/features/dispatch/presentation/widgets/reject_order_dialog.dart';
import 'package:orderpulse_flutter/features/dispatch/presentation/widgets/unchecked_prep_guard_dialog.dart';
import 'package:orderpulse_flutter/features/insights/presentation/bloc/shift_insights_cubit.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_repository.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_sla.dart';
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

  Future<void> _persistItemPrep(int itemIndex, bool isPrepped) async {
    final order = _order;
    if (order == null) return;

    final optimistic = order.toggleItemPrepped(itemIndex, isPrepped: isPrepped);
    setState(() => _order = optimistic);
    sl<OrderBoardBloc>().add(OrderBoardOrderUpserted(optimistic));
    if (sl.isRegistered<ShiftInsightsCubit>()) {
      sl<ShiftInsightsCubit>().upsertOrder(optimistic);
    }

    final result = await sl<OrderRepository>().toggleItemPrepped(
      orderId: order.id,
      itemIndex: itemIndex,
      isPrepped: isPrepped,
    );
    if (!mounted) return;
    if (result case Success<Order>(:final value)) {
      setState(() => _order = value);
      sl<OrderBoardBloc>().add(OrderBoardOrderUpserted(value));
      if (sl.isRegistered<ShiftInsightsCubit>()) {
        sl<ShiftInsightsCubit>().upsertOrder(value);
      }
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
          onItemPrepChanged: (itemIndex, isPrepped) {
            unawaited(_persistItemPrep(itemIndex, isPrepped));
          },
          onOrderUpdated: (updated) {
            setState(() => _order = updated);
            sl<OrderBoardBloc>().add(OrderBoardOrderUpserted(updated));
            if (sl.isRegistered<ShiftInsightsCubit>()) {
              sl<ShiftInsightsCubit>().upsertOrder(updated);
            }
          },
        ),
      ),
    );
  }
}

/// Pure declarative kitchen ticket, lifecycle stepper, interactive prep checklist, and dispatch bar.
class OrderDetailView extends StatefulWidget {
  const OrderDetailView({
    super.key,
    required this.order,
    required this.clock,
    this.onOrderUpdated,
    this.onItemPrepChanged,
  });

  final Order order;
  final AppClock clock;
  final ValueChanged<Order>? onOrderUpdated;
  final void Function(int itemIndex, bool isPrepped)? onItemPrepChanged;

  @override
  State<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends State<OrderDetailView> {
  late Order _currentOrder;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  @override
  void didUpdateWidget(covariant OrderDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.order != oldWidget.order) {
      _currentOrder = widget.order;
    }
  }

  void _toggleItem(int index) {
    if (_currentOrder.status == OrderStatus.completed ||
        _currentOrder.status == OrderStatus.rejected) {
      return;
    }
    final nextValue = !_currentOrder.items[index].isPrepped;
    setState(() {
      _currentOrder =
          _currentOrder.toggleItemPrepped(index, isPrepped: nextValue);
    });
    widget.onItemPrepChanged?.call(index, nextValue);
  }

  Future<void> _handleReject(BuildContext context) async {
    final reason = await RejectOrderDialog.show(context, _currentOrder.id);
    if (reason == null || !context.mounted) return;
    context.read<OrderActionBloc>().add(
          OrderTransitionRequested(
            order: _currentOrder,
            targetStatus: OrderStatus.rejected,
            rejectionReason: reason,
          ),
        );
  }

  Future<void> _handleMarkReady(BuildContext context) async {
    if (_currentOrder.items.isNotEmpty && !_currentOrder.allItemsPrepped) {
      final confirmed = await UncheckedPrepGuardDialog.show(
        context,
        _currentOrder,
      );
      if (!confirmed || !context.mounted) return;
    }
    _dispatch(context, OrderStatus.ready);
  }

  void _dispatch(BuildContext context, OrderStatus targetStatus) {
    context.read<OrderActionBloc>().add(
          OrderTransitionRequested(
            order: _currentOrder,
            targetStatus: targetStatus,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final now = widget.clock.now();
    final sla = OrderSlaEvaluator.evaluate(_currentOrder, now);

    return BlocConsumer<OrderActionBloc, OrderActionState>(
      listener: (context, state) {
        if (state is OrderActionSuccess &&
            state.updatedOrder.id == _currentOrder.id) {
          setState(() => _currentOrder = state.updatedOrder);
          widget.onOrderUpdated?.call(state.updatedOrder);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Order ${state.updatedOrder.id} moved to ${state.updatedOrder.status.label}.',
              ),
            ),
          );
        } else if (state is OrderActionFailure &&
            state.orderId == _currentOrder.id) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: kds.statusRejected,
              content: Text(state.message),
            ),
          );
        }
      },
      builder: (context, actionState) {
        final isBusy = actionState is OrderActionInProgress &&
            actionState.orderId == _currentOrder.id;
        final canCheckItems =
            _currentOrder.status != OrderStatus.completed &&
                _currentOrder.status != OrderStatus.rejected;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 8,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentOrder.id,
                  style: tabularStyle(
                    textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: kds.textPrimary,
                    ),
                  ),
                ),
                Text(
                  'Pickup ${_currentOrder.resolvedPickupCode}',
                  style: tabularStyle(
                    textTheme.labelSmall?.copyWith(color: kds.textSecondary),
                  ),
                ),
              ],
            ),
            actions: [
              if (sla.urgency != SlaUrgency.none)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Center(child: OrderSlaBadge(slaStatus: sla)),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: OrderStatusBadge(status: _currentOrder.status),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
              children: [
                _CustomerTicketHeaderCard(
                  order: _currentOrder,
                  now: now,
                  onShowKitchenSlip: () => KitchenSlipSheet.show(
                    context,
                    order: _currentOrder,
                    now: now,
                  ),
                ),
                if (_currentOrder.kitchenNotes != null &&
                    _currentOrder.kitchenNotes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _AllergenNotesBanner(note: _currentOrder.kitchenNotes!),
                ],
                const SizedBox(height: 12),
                _LifecycleStepperCard(order: _currentOrder),
                const SizedBox(height: 12),
                _PrepChecklistCard(
                  order: _currentOrder,
                  canToggle: canCheckItems && !isBusy,
                  onToggleItem: _toggleItem,
                ),
                const SizedBox(height: 12),
                _CourierDispatchCard(order: _currentOrder),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: kds.card,
                border: Border(top: BorderSide(color: kds.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isBusy) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            foregroundColor: kds.statusRejected,
                            side: BorderSide(
                              color: OrderStateMachine.canReject(
                                      _currentOrder.status)
                                  ? kds.statusRejected.withValues(alpha: 0.7)
                                  : kds.border,
                            ),
                          ),
                          onPressed: !isBusy &&
                                  OrderStateMachine.canReject(
                                      _currentOrder.status)
                              ? () => _handleReject(context)
                              : null,
                          icon: const Icon(Icons.close_rounded, size: 17),
                          label: const Text(
                            'Reject Order',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: !isBusy &&
                                  OrderStateMachine.canAcceptAndPrepare(
                                    _currentOrder.status,
                                  )
                              ? () => _dispatch(context, OrderStatus.preparing)
                              : null,
                          icon: const Icon(
                            Icons.local_fire_department_outlined,
                            size: 17,
                          ),
                          label: const Text(
                            'Accept & Prepare',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: !isBusy &&
                                  OrderStateMachine.canMarkReady(
                                      _currentOrder.status)
                              ? () => _handleMarkReady(context)
                              : null,
                          icon: const Icon(
                            Icons.inventory_2_outlined,
                            size: 17,
                          ),
                          label: const Text(
                            'Mark Ready',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            textStyle: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: !isBusy &&
                                  OrderStateMachine.canHandoverComplete(
                                    _currentOrder.status,
                                  )
                              ? () => _dispatch(context, OrderStatus.completed)
                              : null,
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 17,
                          ),
                          label: const Text(
                            'Handover to Rider',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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

class _CustomerTicketHeaderCard extends StatelessWidget {
  const _CustomerTicketHeaderCard({
    required this.order,
    required this.now,
    required this.onShowKitchenSlip,
  });

  final Order order;
  final DateTime now;
  final VoidCallback onShowKitchenSlip;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: kds.cardElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kds.border),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: kds.brandAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: kds.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.customerPhone.isNotEmpty
                            ? '${order.customerPhone} • Placed ${formatClockTime(order.createdAt)}'
                            : 'Placed ${formatClockTime(order.createdAt)}',
                        style: tabularStyle(
                          textTheme.bodySmall?.copyWith(color: kds.textSecondary),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatElapsedSince(order.createdAt, now),
                      style: tabularStyle(
                        textTheme.labelMedium?.copyWith(
                          color: kds.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'SLA ${order.targetPrepMinutes}m',
                      style: tabularStyle(
                        textTheme.labelSmall?.copyWith(color: kds.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ticket ${order.resolvedPickupCode} • ${order.totalItemCount} item(s)',
                    style: tabularStyle(
                      textTheme.labelMedium?.copyWith(
                        color: kds.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(color: kds.brandAccent.withValues(alpha: 0.65)),
                    foregroundColor: kds.brandAccent,
                    textStyle: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: onShowKitchenSlip,
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('Kitchen Slip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AllergenNotesBanner extends StatelessWidget {
  const _AllergenNotesBanner({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kds.statusNewContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kds.statusNew.withValues(alpha: 0.75)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: kds.onStatusNewContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kitchen & Allergen Note',
                  style: textTheme.labelSmall?.copyWith(
                    color: kds.onStatusNewContainer,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: textTheme.bodySmall?.copyWith(
                    color: kds.onStatusNewContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LifecycleStepperCard extends StatelessWidget {
  const _LifecycleStepperCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    final isRejected = order.status == OrderStatus.rejected;
    final acceptedTime = order.acceptedAt ??
        (order.status == OrderStatus.preparing ||
                order.status == OrderStatus.ready ||
                order.status == OrderStatus.completed
            ? order.updatedAt
            : null);
    final readyTime = order.readyAt ??
        (order.status == OrderStatus.ready ||
                order.status == OrderStatus.completed
            ? order.updatedAt
            : null);
    final completedTime = order.completedAt ??
        (order.status == OrderStatus.completed || isRejected
            ? order.updatedAt
            : null);

    final steps = [
      _TimelineStepData(
        title: 'Placed',
        timeLabel: formatClockTime(order.createdAt),
        isDone: true,
        isCurrent: order.status == OrderStatus.newOrder,
        color: kds.statusReady,
      ),
      if (isRejected)
        _TimelineStepData(
          title: 'Rejected',
          subtitle: order.rejectionReason,
          timeLabel:
              completedTime != null ? formatClockTime(completedTime) : '--:--',
          isDone: true,
          isCurrent: true,
          color: kds.statusRejected,
          isError: true,
        )
      else ...[
        _TimelineStepData(
          title: 'Kitchen Accepted',
          timeLabel:
              acceptedTime != null ? formatClockTime(acceptedTime) : 'Pending',
          isDone: acceptedTime != null,
          isCurrent: order.status == OrderStatus.preparing,
          color: kds.statusPreparing,
        ),
        _TimelineStepData(
          title: 'Ready for Pickup',
          timeLabel:
              readyTime != null ? formatClockTime(readyTime) : 'Pending',
          isDone: readyTime != null,
          isCurrent: order.status == OrderStatus.ready,
          color: kds.statusReady,
        ),
        _TimelineStepData(
          title: 'Completed',
          timeLabel: completedTime != null
              ? formatClockTime(completedTime)
              : 'Pending',
          isDone: order.status == OrderStatus.completed,
          isCurrent: order.status == OrderStatus.completed,
          color: kds.statusCompleted,
        ),
      ],
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline_rounded, size: 18, color: kds.brandAccent),
                const SizedBox(width: 8),
                Text(
                  'Order Lifecycle',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: kds.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isLast = index == steps.length - 1;
              final nodeColor = step.isDone ? step.color : kds.border;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Column(
                        children: [
                          Icon(
                            step.isError
                                ? Icons.cancel_rounded
                                : step.isDone
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: nodeColor,
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                color: step.isDone
                                    ? nodeColor.withValues(alpha: 0.5)
                                    : kds.border,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.title,
                                    style: textTheme.bodySmall?.copyWith(
                                      fontWeight: step.isCurrent || step.isDone
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: step.isDone
                                          ? kds.textPrimary
                                          : kds.textSecondary,
                                    ),
                                  ),
                                  if (step.subtitle != null &&
                                      step.subtitle!.trim().isNotEmpty)
                                    Text(
                                      step.subtitle!,
                                      style: textTheme.labelSmall?.copyWith(
                                        color: kds.onStatusRejectedContainer,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              step.timeLabel,
                              style: tabularStyle(
                                textTheme.labelSmall?.copyWith(
                                  color: step.isDone
                                      ? kds.textPrimary
                                      : kds.textSecondary,
                                  fontWeight: step.isDone
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TimelineStepData {
  const _TimelineStepData({
    required this.title,
    required this.timeLabel,
    required this.isDone,
    required this.isCurrent,
    required this.color,
    this.subtitle,
    this.isError = false,
  });

  final String title;
  final String timeLabel;
  final bool isDone;
  final bool isCurrent;
  final Color color;
  final String? subtitle;
  final bool isError;
}

class _PrepChecklistCard extends StatelessWidget {
  const _PrepChecklistCard({
    required this.order,
    required this.canToggle,
    required this.onToggleItem,
  });

  final Order order;
  final bool canToggle;
  final ValueChanged<int> onToggleItem;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final allDone = order.allItemsPrepped;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist_rounded,
                  size: 18,
                  color: kds.statusPreparing,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kitchen Prep Checklist',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: kds.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: allDone
                        ? kds.statusReadyContainer
                        : kds.statusPreparingContainer,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: (allDone ? kds.statusReady : kds.statusPreparing)
                          .withValues(alpha: 0.65),
                    ),
                  ),
                  child: Text(
                    '${order.preppedLineCount}/${order.totalLineCount} prepped',
                    style: tabularStyle(
                      textTheme.labelSmall?.copyWith(
                        color: allDone
                            ? kds.onStatusReadyContainer
                            : kds.onStatusPreparingContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...order.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: canToggle ? () => onToggleItem(index) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Checkbox(
                          value: item.isPrepped,
                          onChanged:
                              canToggle ? (_) => onToggleItem(index) : null,
                          activeColor: kds.statusReady,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: kds.cardElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: kds.border),
                        ),
                        child: Text(
                          '${item.quantity}x',
                          style: tabularStyle(
                            textTheme.labelMedium?.copyWith(
                              color: kds.brandAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: item.isPrepped
                                    ? kds.textSecondary
                                    : kds.textPrimary,
                                decoration: item.isPrepped
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (item.note != null &&
                                item.note!.trim().isNotEmpty)
                              Text(
                                item.note!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: kds.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatVnd(item.lineTotalVnd),
                        style: tabularStyle(
                          textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: kds.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Total Payout (${order.totalItemCount} items)',
                    style: tabularStyle(
                      textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: kds.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatVnd(order.totalAmountVnd),
                  style: tabularStyle(
                    textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: kds.brandAccent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CourierDispatchCard extends StatelessWidget {
  const _CourierDispatchCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final kds = KdsColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    if (order.rejectionReason != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cancel_outlined, color: kds.statusRejected),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rejection Audit Note',
                      style: textTheme.labelSmall?.copyWith(
                        color: kds.onStatusRejectedContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.rejectionReason!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: kds.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasRider = order.riderName != null && order.riderName!.isNotEmpty;
    final etaLabel = order.riderEtaMinutes != null
        ? 'ETA ${order.riderEtaMinutes}m'
        : (hasRider ? 'En route' : 'Matching');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.two_wheeler_rounded,
                  size: 18,
                  color: hasRider ? kds.statusReady : kds.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Courier & Delivery Dispatch',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: kds.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: hasRider
                        ? kds.statusReadyContainer
                        : kds.cardElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasRider
                          ? kds.statusReady.withValues(alpha: 0.6)
                          : kds.border,
                    ),
                  ),
                  child: Text(
                    etaLabel,
                    style: tabularStyle(
                      textTheme.labelSmall?.copyWith(
                        color: hasRider
                            ? kds.onStatusReadyContainer
                            : kds.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (hasRider) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.riderName!,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: kds.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (order.riderVehicle != null) order.riderVehicle!,
                            if (order.riderPlate != null) order.riderPlate!,
                          ].join(' • '),
                          style: tabularStyle(
                            textTheme.bodySmall?.copyWith(
                              color: kds.textSecondary,
                            ),
                          ),
                        ),
                        if (order.riderPhone != null)
                          Text(
                            'Rider Contact: ${order.riderPhone!}',
                            style: tabularStyle(
                              textTheme.labelSmall?.copyWith(
                                color: kds.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kds.cardElevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kds.border),
                    ),
                    child: Text(
                      order.resolvedPickupCode,
                      style: tabularStyle(
                        textTheme.labelMedium?.copyWith(
                          color: kds.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Awaiting courier assignment • Pickup code ${order.resolvedPickupCode}',
                      style: tabularStyle(
                        textTheme.bodySmall?.copyWith(color: kds.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
