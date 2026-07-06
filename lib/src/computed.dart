import 'consumer.dart';
import 'node.dart';

/// A [Computed] value is a derived reactive value computed by a getter function.
///
/// It acts as both a [Node] (producing values for others) and a [DependencyTracker]
/// (consuming values from other signals or computeds). It evaluates lazily,
/// caching its value until one of its dependencies notifies it that it has changed.
class Computed<T> extends Node implements DependencyTracker {
  final T Function() _computeFn;
  T? _cachedValue;
  bool _isDirty = true;
  bool _isComputing = false;

  /// The set of nodes this computed currently depends on.
  final Set<Node> _dependencies = {};

  /// Creates a new [Computed] with the given computation function.
  Computed(this._computeFn);

  @override
  void addDependency(Node node) {
    _dependencies.add(node);
  }

  @override
  void clearDependencies() {
    for (final dep in _dependencies) {
      dep.removeObserver(this);
    }
    _dependencies.clear();
  }

  /// Gets the current computed value.
  ///
  /// If read within a reactive context (like an [Effect] or another [Computed]),
  /// it automatically registers itself as a dependency of that context.
  ///
  /// Recalculates the value only if it is marked dirty. If evaluation is already in
  /// progress on the call stack, throws a [StateError] to prevent circular dependencies.
  T get value {
    // 1. Dependency tracking for any active outer consumer (e.g. Effect or outer Computed)
    final active = activeConsumer;
    if (active != null) {
      addObserver(active);
      if (active is DependencyTracker) {
        active.addDependency(this);
      }
    }

    // 2. Recompute and cache if dirty
    if (_isDirty) {
      if (_isComputing) {
        throw StateError("Circular dependency detected during evaluation of Computed!");
      }
      _isComputing = true;
      clearDependencies();
      pushConsumer(this);
      try {
        _cachedValue = _computeFn();
        _isDirty = false;
      } finally {
        popConsumer();
        _isComputing = false;
      }
    }

    return _cachedValue as T;
  }

  /// Called when a dependency of this computed changes.
  ///
  /// Marks this computed as dirty (invalidating the cache) and propagates the
  /// notification to any observers watching this computed.
  @override
  void notify() {
    if (!_isDirty) {
      _isDirty = true;
      notifyObservers();
    }
  }

  @override
  String toString() => 'Computed($value)';
}
