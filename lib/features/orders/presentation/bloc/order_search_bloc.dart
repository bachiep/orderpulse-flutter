import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class OrderSearchEvent extends Equatable {
  const OrderSearchEvent();

  @override
  List<Object?> get props => [];
}

final class OrderSearchQueryChanged extends OrderSearchEvent {
  const OrderSearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class OrderSearchCleared extends OrderSearchEvent {
  const OrderSearchCleared();
}

class OrderSearchState extends Equatable {
  const OrderSearchState({this.query = ''});

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Debounces merchant order search input using `restartable()` concurrency.
class OrderSearchBloc extends Bloc<OrderSearchEvent, OrderSearchState> {
  OrderSearchBloc({
    this.debounceDuration = const Duration(milliseconds: 300),
  }) : super(const OrderSearchState()) {
    on<OrderSearchQueryChanged>(
      _onQueryChanged,
      transformer: restartable(),
    );
    on<OrderSearchCleared>(_onCleared);
  }

  final Duration debounceDuration;

  Future<void> _onQueryChanged(
    OrderSearchQueryChanged event,
    Emitter<OrderSearchState> emit,
  ) async {
    final trimmed = event.query.trim();
    if (debounceDuration > Duration.zero) {
      await Future<void>.delayed(debounceDuration);
    }
    if (emit.isDone) return;
    if (trimmed != state.query) {
      emit(OrderSearchState(query: trimmed));
    }
  }

  void _onCleared(
    OrderSearchCleared event,
    Emitter<OrderSearchState> emit,
  ) {
    if (state.query.isNotEmpty) {
      emit(const OrderSearchState(query: ''));
    }
  }
}
