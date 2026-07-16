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

  /// Transforms the state to another type by matching the wrapper class.
  R map<R>({
    required R Function(AsyncData<T> data) data,
    required R Function(AsyncLoading<T> loading) loading,
    required R Function(AsyncError<T> error) error,
  });

  /// Transforms the state to another type by matching the wrapper class, falling back to [orElse] if unmatched.
  R maybeMap<R>({
    R Function(AsyncData<T> data)? data,
    R Function(AsyncLoading<T> loading)? loading,
    R Function(AsyncError<T> error)? error,
    required R Function() orElse,
  });

  /// Returns `true` if the state is [AsyncLoading].
  bool get isLoading => this is AsyncLoading<T>;

  /// Returns `true` if the state is [AsyncError].
  bool get hasError => this is AsyncError<T>;

  /// Returns `true` if the state is [AsyncData].
  bool get hasValue =>
      this is AsyncData<T> ||
      (this is AsyncLoading<T> && (this as AsyncLoading<T>).previous != null) ||
      (this is AsyncError<T> && (this as AsyncError<T>).previous != null);

  /// Alias for [hasValue].
  bool get hasData => hasValue;

  /// Returns the value if the state is [AsyncData], otherwise `null`.
  T? get data {
    final self = this;
    if (self is AsyncData<T>) return self.value;
    if (self is AsyncLoading<T>) return self.previous?.value;
    if (self is AsyncError<T>) return self.previous?.value;
    return null;
  }

  /// Whether a loading state is refreshing previously loaded data.
  bool get isRefreshing =>
      this is AsyncLoading<T> && (this as AsyncLoading<T>).previous != null;

  /// Returns the value if the state is [AsyncData], otherwise `null`.
  T? get valueOrNull => data;

  /// Returns the value if the state is [AsyncData], otherwise throws a [StateError].
  T get requireValue {
    final self = this;
    if (self is AsyncData<T>) return self.value;
    if (self is AsyncLoading<T> && self.previous != null) {
      return self.previous!.value;
    }
    if (self is AsyncError<T> && self.previous != null) {
      return self.previous!.value;
    }
    if (self is AsyncError<T>) {
      throw StateError('AsyncValue has error: ' + self.error.toString());
    }
    throw StateError('AsyncValue is in Loading state');
  }
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
  R map<R>({
    required R Function(AsyncData<T> data) data,
    required R Function(AsyncLoading<T> loading) loading,
    required R Function(AsyncError<T> error) error,
  }) {
    return data(this);
  }

  @override
  R maybeMap<R>({
    R Function(AsyncData<T> data)? data,
    R Function(AsyncLoading<T> loading)? loading,
    R Function(AsyncError<T> error)? error,
    required R Function() orElse,
  }) {
    if (data != null) return data(this);
    return orElse();
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
  /// Data retained while a refresh is in progress.
  final AsyncData<T>? previous;

  /// Creates an [AsyncLoading] state.
  const AsyncLoading([this.previous]);

  @override
  R when<R>({
    required R Function(T data) data,
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
  }) {
    return loading();
  }

  @override
  R map<R>({
    required R Function(AsyncData<T> data) data,
    required R Function(AsyncLoading<T> loading) loading,
    required R Function(AsyncError<T> error) error,
  }) {
    return loading(this);
  }

  @override
  R maybeMap<R>({
    R Function(AsyncData<T> data)? data,
    R Function(AsyncLoading<T> loading)? loading,
    R Function(AsyncError<T> error)? error,
    required R Function() orElse,
  }) {
    if (loading != null) return loading(this);
    return orElse();
  }

  @override
  bool operator ==(Object other) =>
      other is AsyncLoading<T> && other.previous == previous;

  @override
  int get hashCode => Object.hash(runtimeType, previous);

  @override
  String toString() => 'AsyncLoading<$T>()';
}

/// The state of an [AsyncValue] when the asynchronous operation has failed.
class AsyncError<T> extends AsyncValue<T> {
  /// The error object.
  final Object error;

  /// The stack trace.
  final StackTrace stackTrace;

  /// Data retained when a refresh fails.
  final AsyncData<T>? previous;

  /// Creates an [AsyncError] state with the given [error] and [stackTrace].
  const AsyncError(this.error, this.stackTrace, {this.previous});

  @override
  R when<R>({
    required R Function(T data) data,
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
  }) {
    return error(this.error, stackTrace);
  }

  @override
  R map<R>({
    required R Function(AsyncData<T> data) data,
    required R Function(AsyncLoading<T> loading) loading,
    required R Function(AsyncError<T> error) error,
  }) {
    return error(this);
  }

  @override
  R maybeMap<R>({
    R Function(AsyncData<T> data)? data,
    R Function(AsyncLoading<T> loading)? loading,
    R Function(AsyncError<T> error)? error,
    required R Function() orElse,
  }) {
    if (error != null) return error(this);
    return orElse();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AsyncError<T> &&
          other.error == error &&
          other.stackTrace == stackTrace &&
          other.previous == previous);

  @override
  int get hashCode => Object.hash(error, stackTrace, previous);

  @override
  String toString() => 'AsyncError($error)';
}
