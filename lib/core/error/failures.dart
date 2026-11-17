import 'package:equatable/equatable.dart';

/// Typed domain failure hierarchy for exhaustive error handling across repositories and Blocs.
sealed class Failure extends Equatable {
  const Failure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'Unable to reach server. Please check your connection.',
    String? code,
  ]) : super(code: code);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.message = 'Session expired. Please sign in again.',
    String? code,
  ]) : super(code: code);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

final class ConflictFailure extends Failure {
  const ConflictFailure(super.message, {super.code});
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.code, this.statusCode});

  final int? statusCode;

  @override
  List<Object?> get props => [message, code, statusCode];
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([
    super.message = 'An unexpected error occurred.',
    String? code,
  ]) : super(code: code);
}
