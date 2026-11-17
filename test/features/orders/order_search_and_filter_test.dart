import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_filter_cubit.dart';
import 'package:orderpulse_flutter/features/orders/presentation/bloc/order_search_bloc.dart';

void main() {
  group('OrderFilterCubit', () {
    blocTest<OrderFilterCubit, OrderFilterTab>(
      'emits selected tabs and resets to all',
      build: OrderFilterCubit.new,
      act: (cubit) {
        cubit.selectTab(OrderFilterTab.newOrder);
        cubit.selectTab(OrderFilterTab.preparing);
        cubit.reset();
      },
      expect: () => const [
        OrderFilterTab.newOrder,
        OrderFilterTab.preparing,
        OrderFilterTab.all,
      ],
    );
  });

  group('OrderSearchBloc (restartable debounce)', () {
    blocTest<OrderSearchBloc, OrderSearchState>(
      'cancels superseded rapid queries and emits only the final debounced query',
      build: () => OrderSearchBloc(
        debounceDuration: const Duration(milliseconds: 50),
      ),
      act: (bloc) async {
        bloc.add(const OrderSearchQueryChanged('O'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const OrderSearchQueryChanged('OR'));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const OrderSearchQueryChanged('  ORD-1028  '));
      },
      wait: const Duration(milliseconds: 90),
      expect: () => const [OrderSearchState(query: 'ORD-1028')],
    );

    blocTest<OrderSearchBloc, OrderSearchState>(
      'clears query immediately on OrderSearchCleared',
      build: () => OrderSearchBloc(debounceDuration: Duration.zero),
      act: (bloc) async {
        bloc.add(const OrderSearchQueryChanged('Pho'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const OrderSearchCleared());
      },
      expect: () => const [
        OrderSearchState(query: 'Pho'),
        OrderSearchState(query: ''),
      ],
    );
  });
}
