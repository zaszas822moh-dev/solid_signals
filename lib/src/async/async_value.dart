/// A sealed class representing the state of an asynchronous operation (such as a [Future] or [Stream]).
///
/// It can be in one of three states:
/// - [AsyncData]: Operation completed successfully with a value.
/// - [AsyncLoading]: Operation is currently in progress.
/// - [AsyncError]: Operation failed with an error.
sealed class AsyncValue<T> {
  /// Const constructor to allow const instantiation in subclasses.
  const AsyncValue();

  /// Pattern matching method to execute different callbacks depending on the current state.
  R when<R>({
    required R Function(T data) data,
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
  });
}

/// The state of an [AsyncValue] when the asynchronous operation has completed successfully.
class AsyncData<T> extends AsyncValue<T> {
  /// The resolved value.
  final T value;

  /// Creates an [AsyncData] state with the given [value].
  const AsyncData(this.value);

  @override
  R when<R>({
    required R Function(T data) data,
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
  }) {
    return data(value);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AsyncData<T> && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AsyncData($value)';
}

/// The state of an [AsyncValue] when the asynchronous operation is in progress.
class AsyncLoading<T> extends AsyncValue<T> {
  /// Creates an [AsyncLoading] state.
  const AsyncLoading();

  @override
  R when<R>({
    required R Function(T data) data,
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
  }) {
    return loading();
  }

  @override
  bool operator ==(Object other) => other is AsyncLoading<T>;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AsyncLoading<$T>()';
}

/// The state of an [AsyncValue] when the asynchronous operation has failed.
class AsyncError<T> extends AsyncValue<T> {
  /// The error object.
  final Object error;

  /// The stack trace.
  final StackTrace stackTrace;

  /// Creates an [AsyncError] state with the given [error] and [stackTrace].
  const AsyncError(this.error, this.stackTrace);

  @override
  R when<R>({
    required R Function(T data) data,
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
  }) {
    return error(this.error, stackTrace);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AsyncError<T> && other.error == error && other.stackTrace == stackTrace);

  @override
  int get hashCode => Object.hash(error, stackTrace);

  @override
  String toString() => 'AsyncError($error)';
}
