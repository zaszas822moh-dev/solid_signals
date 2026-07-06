import 'consumer.dart';
import 'node.dart';

/// An [Effect] represents a side-effect function that automatically re-runs
/// whenever any of the signals or computed values it accesses during execution change.
class Effect implements DependencyTracker {
  final void Function() _fn;
  final Set<Node> _dependencies = {};
  bool _isDisposed = false;

  /// Creates a new [Effect] and executes the given function immediately.
  Effect(this._fn) {
    run();
  }

  /// Creates a new [Effect] without executing the callback function immediately.
  Effect.lazy(this._fn);

  /// Runs the effect function, tracking any signals or computeds read during execution.
  void run() {
    if (_isDisposed) return;

    clearDependencies();
    pushConsumer(this);
    try {
      _fn();
    } finally {
      popConsumer();
    }
  }

  /// Executes the given function [fn] within this effect's tracking context.
  ///
  /// This registers any signals read during [fn] as dependencies of this effect.
  R track<R>(R Function() fn) {
    if (_isDisposed) return fn();
    clearDependencies();
    pushConsumer(this);
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
    _isDisposed = true;
    clearDependencies();
  }
}

/// Helper function to create and run an [Effect].
///
/// Returns the created [Effect] instance, which can be disposed by calling [Effect.dispose].
Effect effect(void Function() fn) {
  return Effect(fn);
}
