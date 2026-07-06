import 'consumer.dart';
import 'node.dart';
import 'observer.dart';

/// A [Signal] holds a single reactive value of type [T].
///
/// When its [value] is read, it automatically registers the currently active
/// consumer as an observer. When its [value] changes, it notifies all observers.
///
/// Supports automatic lifecycle management via [autoDispose] and lifecycle callbacks
/// [onListen] and [onDispose].
class Signal<T> extends Node {
  T _value;

  /// Whether this signal should automatically dispose of its resources when it has no observers.
  bool autoDisposeEnabled;

  /// Callback executed when this signal goes from 0 to 1 observer.
  void Function()? onListenCallback;

  /// Callback executed when this signal is disposed (e.g. observers drop to 0 under autoDispose).
  void Function()? onDisposeCallback;

  /// Tracks whether the signal is currently in a disposed state.
  bool isDisposed = false;

  /// Creates a new [Signal] with the given initial value and optional lifecycle callbacks.
  Signal(
    this._value, {
    bool autoDispose = false,
    void Function()? onDispose,
    void Function()? onListen,
  })  : autoDisposeEnabled = autoDispose,
        onDisposeCallback = onDispose,
        onListenCallback = onListen {
    signalObserver?.onSignalCreated(this);
  }

  /// Configures this signal to automatically dispose when all observers are removed,
  /// returning the signal itself to allow fluent builder chaining.
  Signal<T> autoDispose({void Function()? onDispose}) {
    autoDisposeEnabled = true;
    if (onDispose != null) {
      final previousOnDispose = onDisposeCallback;
      onDisposeCallback = () {
        previousOnDispose?.call();
        onDispose();
      };
    }
    // If it currently has no observers, dispose immediately
    if (observers.isEmpty && !isDisposed) {
      dispose();
    }
    return this;
  }

  /// Disposes of the resources associated with this signal, executing the [onDisposeCallback].
  void dispose() {
    if (isDisposed) return;
    isDisposed = true;
    signalObserver?.onSignalDisposed(this);
    onDisposeCallback?.call();
  }

  @override
  void addObserver(Consumer consumer) {
    if (isDisposed) {
      isDisposed = false;
    }
    final wasEmpty = observers.isEmpty;
    super.addObserver(consumer);
    if (wasEmpty) {
      onListenCallback?.call();
    }
  }

  @override
  void removeObserver(Consumer consumer) {
    super.removeObserver(consumer);
    if (autoDisposeEnabled && observers.isEmpty && !isDisposed) {
      dispose();
    }
  }

  /// Gets the current value of the signal.
  ///
  /// If read within a reactive context (like an [Effect] or [Computed]),
  /// it registers that context as an observer/dependency.
  T get value {
    final active = activeConsumer;
    if (active != null) {
      addObserver(active);
      if (active is DependencyTracker) {
        active.addDependency(this);
      }
    }
    return _value;
  }

  /// Sets a new value for the signal.
  ///
  /// If the new value is different from the current value (using standard `!=` equality),
  /// updates the stored value and notifies all observers. The notification phase is batched
  /// to prevent glitches (inconsistent temporary states).
  set value(T newValue) {
    if (_value != newValue) {
      final oldValue = _value;
      _value = newValue;
      signalObserver?.onSignalChanged(this, oldValue, newValue);
      startBatch();
      try {
        notifyObservers();
      } finally {
        endBatch();
      }
    }
  }

  @override
  String toString() => 'Signal($value)';
}
