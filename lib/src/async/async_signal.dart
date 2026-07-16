import 'dart:async';

import '../consumer.dart';
import '../node.dart';
import '../signal.dart';
import 'async_value.dart';

/// Reactive state for a Future or Stream operation.
///
/// Signal reads performed synchronously by the source factory are tracked.
/// Changing one of those dependencies automatically reloads the operation.
class AsyncSignal<T> extends Signal<AsyncValue<T>>
    implements DependencyTracker {
  final Future<T> Function()? _futureFactory;
  final Stream<T> Function()? _streamFactory;
  final FutureOr<void> Function()? _onCancel;
  final Set<Node> _dependencies = {};

  StreamSubscription<T>? _streamSubscription;
  int _currentExecutionId = 0;
  bool _operationActive = false;

  /// Creates an AsyncSignal from a Future factory.
  ///
  /// Dart Futures are not intrinsically cancellable. Use [onCancel] to cancel
  /// the underlying HTTP request, isolate task, or other operation when this
  /// signal reloads or is disposed.
  AsyncSignal.fromFuture(
    Future<T> Function() futureFn, {
    String? name,
    bool autoDispose = false,
    void Function()? onDispose,
    FutureOr<void> Function()? onCancel,
  })  : _futureFactory = futureFn,
        _streamFactory = null,
        _onCancel = onCancel,
        super(
          const AsyncLoading(),
          name: name,
          autoDispose: autoDispose,
          onDispose: onDispose,
        ) {
    _initialize();
  }

  /// Creates an AsyncSignal from a Stream factory.
  ///
  /// The active stream subscription is canceled on reload and disposal.
  AsyncSignal.fromStream(
    Stream<T> Function() streamFn, {
    String? name,
    bool autoDispose = false,
    void Function()? onDispose,
    FutureOr<void> Function()? onCancel,
  })  : _futureFactory = null,
        _streamFactory = streamFn,
        _onCancel = onCancel,
        super(
          const AsyncLoading(),
          name: name,
          autoDispose: autoDispose,
          onDispose: onDispose,
        ) {
    _initialize();
  }

  void _initialize() {
    if (autoDisposeEnabled) {
      onListenCallback = () {
        unawaited(_start());
      };
    } else {
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    if (isDisposed) return;

    final executionId = ++_currentExecutionId;
    _cancelActive();

    final previous = _previousData(peek());
    value = AsyncLoading<T>(previous);

    if (_futureFactory != null) {
      await _startFuture(executionId, previous);
    } else {
      _startStream(executionId, previous);
    }
  }

  Future<void> _startFuture(
    int executionId,
    AsyncData<T>? previous,
  ) async {
    late Future<T> pending;
    try {
      pending = _trackSource(_futureFactory!);
      _operationActive = true;
    } catch (error, stackTrace) {
      _setError(executionId, error, stackTrace, previous);
      return;
    }

    try {
      final result = await pending;
      if (_isCurrent(executionId)) {
        _operationActive = false;
        value = AsyncData<T>(result);
      }
    } catch (error, stackTrace) {
      _setError(executionId, error, stackTrace, previous);
    }
  }

  void _startStream(
    int executionId,
    AsyncData<T>? previous,
  ) {
    late Stream<T> stream;
    try {
      stream = _trackSource(_streamFactory!);
      _operationActive = true;
    } catch (error, stackTrace) {
      _setError(executionId, error, stackTrace, previous);
      return;
    }

    _streamSubscription = stream.listen(
      (event) {
        if (_isCurrent(executionId)) {
          value = AsyncData<T>(event);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_isCurrent(executionId)) {
          final retained = _previousData(peek()) ?? previous;
          value = AsyncError<T>(
            error,
            stackTrace,
            previous: retained,
          );
        }
      },
      onDone: () {
        if (_isCurrent(executionId)) {
          _operationActive = false;
          _streamSubscription = null;
        }
      },
    );
  }

  R _trackSource<R>(R Function() sourceFactory) {
    pushConsumer(this);
    clearDependencies();
    try {
      return sourceFactory();
    } finally {
      popConsumer();
    }
  }

  void _setError(
    int executionId,
    Object error,
    StackTrace stackTrace,
    AsyncData<T>? previous,
  ) {
    if (_isCurrent(executionId)) {
      _operationActive = false;
      value = AsyncError<T>(
        error,
        stackTrace,
        previous: previous,
      );
    }
  }

  bool _isCurrent(int executionId) =>
      executionId == _currentExecutionId && !isDisposed;

  AsyncData<T>? _previousData(AsyncValue<T> state) {
    if (state is AsyncData<T>) return state;
    if (state is AsyncLoading<T>) return state.previous;
    if (state is AsyncError<T>) return state.previous;
    return null;
  }

  void _cancelActive() {
    final subscription = _streamSubscription;
    _streamSubscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    if (_operationActive && _onCancel != null) {
      unawaited(Future<void>.sync(_onCancel!).catchError((_) {}));
    }
    _operationActive = false;
  }

  /// Reloads the source and completes when a Future source settles.
  ///
  /// For Stream sources this completes after the new subscription is created.
  Future<void> refresh() => _start();

  /// Alias for [refresh], useful after an error.
  Future<void> retry() => _start();

  /// Alias for [refresh].
  Future<void> reload() => _start();

  /// Invalidates the current operation and immediately starts a new one.
  Future<void> invalidate() => _start();

  /// Whether previous data is being retained during a refresh.
  bool get isRefreshing => value.isRefreshing;

  /// Alias for [isRefreshing].
  bool get isReloading => isRefreshing;

  @override
  void addDependency(Node node) {
    _dependencies.add(node);
  }

  @override
  void clearDependencies() {
    for (final dependency in _dependencies) {
      dependency.removeObserver(this);
    }
    _dependencies.clear();
  }

  /// Reloads when a reactive dependency used by the source changes.
  @override
  void notify() {
    unawaited(_start());
  }

  /// Pattern matching delegated to the current AsyncValue.
  R when<R>({
    required R Function(T data) data,
    required R Function() loading,
    required R Function(Object error, StackTrace stackTrace) error,
  }) {
    return value.when(data: data, loading: loading, error: error);
  }

  bool get isLoading => value.isLoading;
  bool get hasError => value.hasError;
  bool get hasValue => value.hasValue;
  bool get hasData => value.hasData;
  T? get data => value.data;
  T? get valueOrNull => value.valueOrNull;
  T get requireValue => value.requireValue;

  R map<R>({
    required R Function(AsyncData<T> data) data,
    required R Function(AsyncLoading<T> loading) loading,
    required R Function(AsyncError<T> error) error,
  }) {
    return value.map(data: data, loading: loading, error: error);
  }

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
    _currentExecutionId++;
    _cancelActive();
    clearDependencies();
    super.dispose();
  }
}
