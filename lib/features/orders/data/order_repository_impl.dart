import 'package:dio/dio.dart';
import 'package:orderpulse_flutter/core/error/failures.dart';
import 'package:orderpulse_flutter/core/network/dio_error_mapper.dart';
import 'package:orderpulse_flutter/core/result/result.dart';
import 'package:orderpulse_flutter/features/orders/data/order_dto.dart';
import 'package:orderpulse_flutter/features/orders/domain/order.dart';
import 'package:orderpulse_flutter/features/orders/domain/order_repository.dart';

/// Dio-backed [OrderRepository] compatible with both Live API and Demo HTTP adapter.
class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<Result<OrderPage>> fetchOrders({
    OrderStatus? status,
    String query = '',
    int page = 1,
    int pageSize = 8,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/orders',
        queryParameters: {
          if (status != null) 'status': status.apiValue,
          if (query.trim().isNotEmpty) 'q': query.trim(),
          'page': page,
          'pageSize': pageSize,
        },
      );
      final data = response.data;
      if (data == null) {
        return const Err(ServerFailure('Empty orders payload from server.'));
      }
      return Success(OrderDto.pageFromJson(data));
    } on DioException catch (error) {
      return Err(mapDioExceptionToFailure(error));
    } catch (_) {
      return const Err(UnexpectedFailure('Failed to parse order list.'));
    }
  }

  @override
  Future<Result<Order>> fetchOrderById(String orderId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/orders/$orderId');
      final data = response.data;
      if (data == null) {
        return const Err(ServerFailure('Order not found.'));
      }
      return Success(OrderDto.fromJson(data));
    } on DioException catch (error) {
      return Err(mapDioExceptionToFailure(error));
    } catch (_) {
      return const Err(UnexpectedFailure('Failed to load order details.'));
    }
  }

  @override
  Future<Result<MerchantShiftStats>> fetchShiftStats() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/orders/stats');
      final data = response.data;
      if (data == null) {
        return const Err(ServerFailure('Empty shift stats response.'));
      }
      return Success(OrderDto.statsFromJson(data));
    } on DioException catch (error) {
      return Err(mapDioExceptionToFailure(error));
    } catch (_) {
      return const Err(UnexpectedFailure('Failed to load shift stats.'));
    }
  }

  @override
  Future<Result<Order>> transitionOrder({
    required String orderId,
    required OrderStatus targetStatus,
    String? rejectionReason,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/orders/$orderId/status',
        data: {
          'status': targetStatus.apiValue,
          if (rejectionReason != null && rejectionReason.trim().isNotEmpty)
            'rejectionReason': rejectionReason.trim(),
        },
      );
      final data = response.data;
      if (data == null) {
        return const Err(ServerFailure('Empty dispatch transition response.'));
      }
      return Success(OrderDto.fromJson(data));
    } on DioException catch (error) {
      return Err(mapDioExceptionToFailure(error));
    } catch (_) {
      return const Err(UnexpectedFailure('Failed to update order status.'));
    }
  }
}
