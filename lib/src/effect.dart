import 'consumer.dart';
import 'node.dart';

/// An [Effect] represents a side-effect function that automatically re-runs
/// whenever any of the signals or computed values it accesses during execution change.
class Effect implements DependencyTracker {
  final void Function()? _fn;
  final void Function(void Function(void Function()))? _cleanupFn;
  final Set<Node> _dependencies = {};
  final List<void Function()> _cleanups = [];
  bool _isDisposed = false;

  /// Creates a new [Effect] and executes the given function immediately.
  Effect(this._fn) : _cleanupFn = null {
    run();
  }

  /// Creates a new [Effect] without executing the callback function immediately.
  Effect.lazy(this._fn) : _cleanupFn = null;

  /// Creates an effect that can register cleanup callbacks for each run.
  ///
  /// Registered callbacks run before the next execution and when the effect is
  /// disposed. This is useful for timers, stream subscriptions, and listeners.
  Effect.withCleanup(void Function(void Function(void Function())) fn)
      : _fn = null,
        _cleanupFn = fn {
    run();
  }

  void _registerCleanup(void Function() cleanup) {
    if (!_isDisposed) _cleanups.add(cleanup);
  }

  void _runCleanups() {
    final cleanups = List<void Function()>.from(_cleanups);
    _cleanups.clear();
    for (final cleanup in cleanups.reversed) {
      try {
        cleanup();
      } catch (_) {
        // One failed cleanup must not prevent the remaining cleanups.
      }
    }
  }

  /// Runs the effect function, tracking any signals or computeds read during execution.
  void run() {
    if (_isDisposed) return;

    _runCleanups();
    pushConsumer(this);
    clearDependencies();
    try {
      _fn?.call();
      _cleanupFn?.call(_registerCleanup);
    } finally {
      popConsumer();
    }
  }

  /// Executes the given function [fn] within this effect's tracking context.
  ///
  /// This registers any signals read during [fn] as dependencies of this effect.
  R track<R>(R Function() fn) {
    if (_isDisposed) return fn();
    _runCleanups();
    pushConsumer(this);
    clearDependencies();
    try {
      return fn();
    } finally {
      popConsumer();
    }
  }

  @override
  void addDependency(Node node) {
    if (_isDisposed) return;
    _dependencies.add(node);
  }

  @override
  void clearDependencies() {
    for (final dep in _dependencies) {
      dep.removeObserver(this);
    }
    _dependencies.clear();
  }

  /// Called when any of the observed dependencies changes.
  ///
  /// If a batch is currently active, queues this effect to run after the batch
  /// finishes. Otherwise, executes immediately.
  @override
  void notify() {
    if (isBatching) {
      queueConsumer(this);
    } else {
      run();
    }
  }

  /// Disposes of the effect, clearing all dependencies and preventing further execution.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _runCleanups();
    clearDependencies();
  }
}

/// Helper function to create and run an [Effect].
///
/// Returns the created [Effect] instance, which can be disposed by calling [Effect.dispose].
Effect effect(void Function() fn) {
  return Effect(fn);
}

/// Creates an effect with per-run and disposal cleanup support.
Effect effectWithCleanup(void Function(void Function(void Function())) fn) {
  return Effect.withCleanup(fn);
}
