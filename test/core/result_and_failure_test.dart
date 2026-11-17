import 'package:flutter_test/flutter_test.dart';
import 'package:orderpulse_flutter/core/error/failures.dart';
import 'package:orderpulse_flutter/core/result/result.dart';

void main() {
  group('Result & Failure', () {
    test('Success exposes value and evaluates success branch', () {
      const Result<int> result = Success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);

      final mapped = result.when(
        success: (value) => 'ok:$value',
        err: (failure) => 'err:${failure.message}',
      );
      expect(mapped, 'ok:42');
    });

    test('Err exposes Failure and evaluates err branch', () {
      const Result<int> result = Err(
        ValidationFailure('Rejection reason required', code: 'REASON_EMPTY'),
      );

      expect(result.isSuccess, isFalse);
      expect(result.isErr, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isA<ValidationFailure>());

      final mapped = switch (result) {
        Success<int>(:final value) => 'ok:$value',
        Err<int>(:final failure) => switch (failure) {
          ValidationFailure(:final message, :final code) => '$code:$message',
          _ => failure.message,
        },
      };
      expect(mapped, 'REASON_EMPTY:Rejection reason required');
    });
  });
}
