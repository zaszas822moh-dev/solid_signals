import '../signal.dart';
import 'async_value.dart';

/// A [Signal] specifically designed to manage the state of asynchronous operations.
///
/// It wraps an [AsyncValue<T>] which can represent loading, success (with data), or error.
/// It supports dynamic re-fetching, execution ID tracking to ignore out-of-order completions,
/// and works seamlessly with [autoDispose] to only execute the future when observed.
class AsyncSignal<T> extends Signal<AsyncValue<T>> {
  final Future<T> Function() _futureFn;
  int _currentExecutionId = 0;

  /// Creates an [AsyncSignal] from a future-returning function.
  ///
  /// If [autoDispose] is true, the future is not run until the signal receives its first observer.
  /// When all observers leave, it disposes and cancels the active future updates, and will re-run
  /// the future when observed again.
  AsyncSignal.fromFuture(
    Future<T> Function() futureFn, {
    String? name,
    bool autoDispose = false,
    void Function()? onDispose,
  })  : _futureFn = futureFn,
        super(
          const AsyncLoading(),
          name: name,
          autoDispose: autoDispose,
          onDispose: onDispose,
        ) {
    if (autoDisposeEnabled) {
      onListenCallback = _fetch;
    } else {
      _fetch();
    }
  }

  void _fetch() async {
    // If not already loading, switch to loading state
    if (value is! AsyncLoading<T>) {
      setValueSilently(const AsyncLoading());
    }

    final execId = ++_currentExecutionId;
    try {
      final res = await _futureFn();
      if (execId == _currentExecutionId && !isDisposed) {
        value = AsyncData(res);
      }
    } catch (err, stack) {
      if (execId == _currentExecutionId && !isDisposed) {
        value = AsyncError(err, stack);
      }
    }
  }

  /// Re-triggers the asynchronous operation, invalidating the current execution
  /// and placing the signal back into a loading state.
  void refresh() {
    _fetch();
  }

  /// Helper pattern matching method that delegates directly to the current [AsyncValue].
  R when<R>({
    required R Function(T data) data,
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
  }) {
    return value.when(
      data: data,
      loading: loading,
      error: error,
    );
  }

  /// Returns `true` if the state is [AsyncLoading].
  bool get isLoading => value.isLoading;

  /// Returns `true` if the state is [AsyncError].
  bool get hasError => value.hasError;

  /// Returns `true` if the state is [AsyncData].
  bool get hasValue => value.hasValue;

  /// Alias for [hasValue].
  bool get hasData => value.hasData;

  /// Returns the value if the state is [AsyncData], otherwise `null`.
  T? get data => value.data;

  /// Returns the value if the state is [AsyncData], otherwise `null`.
  T? get valueOrNull => value.valueOrNull;

  /// Returns the value if the state is [AsyncData], otherwise throws a [StateError].
  T get requireValue => value.requireValue;

  /// Transforms the state to another type by matching the wrapper class.
  R map<R>({
    required R Function(AsyncData<T> data) data,
    required R Function(AsyncLoading<T> loading) loading,
    required R Function(AsyncError<T> error) error,
  }) {
    return value.map(
      data: data,
      loading: loading,
      error: error,
    );
  }

  /// Transforms the state to another type by matching the wrapper class, falling back to [orElse] if unmatched.
  R maybeMap<R>({
    R Function(AsyncData<T> data)? data,
    R Function(AsyncLoading<T> loading)? loading,
    R Function(AsyncError<T> error)? error,
    required R Function() orElse,
  }) {
    return value.maybeMap(
      data: data,
      loading: loading,
      error: error,
      orElse: orElse,
    );
  }

  @override
  void dispose() {
    if (isDisposed) return;
    _currentExecutionId++; // Increment to ignore any pending future resolutions
    super.dispose();
  }
}
