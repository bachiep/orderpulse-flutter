import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';

/// Manages the selected order status filter tab on the merchant board.
class OrderFilterCubit extends Cubit<OrderFilterTab> {
  OrderFilterCubit() : super(OrderFilterTab.all);

  void selectTab(OrderFilterTab tab) {
    if (tab == state) return;
    emit(tab);
  }

  void reset() {
    if (state == OrderFilterTab.all) return;
    emit(OrderFilterTab.all);
  }
}
