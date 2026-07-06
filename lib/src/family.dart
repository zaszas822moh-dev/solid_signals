import 'async/async_signal.dart';
import 'signal.dart';

/// A caching registry that creates and manages a family of [Signal]s based on arguments.
///
/// If a signal created by the family has `autoDispose` enabled, it will automatically
/// evict itself from the cache when it is disposed (observers drop to zero), ensuring
/// memory efficiency.
class SignalFamily<T, Arg> {
  final Signal<T> Function(Arg arg) _creator;
  final Map<Arg, Signal<T>> _cache = {};

  /// Creates a [SignalFamily] using the provided [_creator] function.
  SignalFamily(this._creator);

  /// Retrieves the cached signal for [arg], creating it if it doesn't exist.
  Signal<T> call(Arg arg) {
    if (_cache.containsKey(arg)) {
      return _cache[arg]!;
    }
    final sig = _creator(arg);
    _cache[arg] = sig;

    if (sig.autoDisposeEnabled) {
      final previousOnDispose = sig.onDisposeCallback;
      sig.onDisposeCallback = () {
        previousOnDispose?.call();
        _cache.remove(arg);
      };
    }
    return sig;
  }

  /// Disposes and clears all cached signals in this family.
  void dispose() {
    for (final sig in List.of(_cache.values)) {
      sig.dispose();
    }
    _cache.clear();
  }

  /// Exposed for testing purposes to inspect the cache.
  Map<Arg, Signal<T>> get cache => Map.unmodifiable(_cache);
}

/// A caching registry that creates and manages a family of [AsyncSignal]s based on arguments.
///
/// If an async signal created by the family has `autoDispose` enabled, it will automatically
/// evict itself from the cache when it is disposed, ensuring memory efficiency.
class AsyncSignalFamily<T, Arg> {
  final AsyncSignal<T> Function(Arg arg) _creator;
  final Map<Arg, AsyncSignal<T>> _cache = {};

  /// Creates an [AsyncSignalFamily] using the provided [_creator] function.
  AsyncSignalFamily(this._creator);

  /// Retrieves the cached async signal for [arg], creating it if it doesn't exist.
  AsyncSignal<T> call(Arg arg) {
    if (_cache.containsKey(arg)) {
      return _cache[arg]!;
    }
    final sig = _creator(arg);
    _cache[arg] = sig;

    if (sig.autoDisposeEnabled) {
      final previousOnDispose = sig.onDisposeCallback;
      sig.onDisposeCallback = () {
        previousOnDispose?.call();
        _cache.remove(arg);
      };
    }
    return sig;
  }

  /// Disposes and clears all cached async signals in this family.
  void dispose() {
    for (final sig in List.of(_cache.values)) {
      sig.dispose();
    }
    _cache.clear();
  }

  /// Exposed for testing purposes to inspect the cache.
  Map<Arg, AsyncSignal<T>> get cache => Map.unmodifiable(_cache);
}
