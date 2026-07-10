import 'signal.dart';

/// An abstract base class for monitoring and tracing all [Signal] lifecycles and changes.
///
/// Subclass this and assign it to the global [signalObserver] to centrally monitor
/// signal creations, mutations, and disposals.
abstract class SignalObserver {
  /// Called when a [Signal] is created.
  void onSignalCreated(Signal signal);

  /// Called when a [Signal]'s value is updated.
  void onSignalChanged(Signal signal, Object? oldValue, Object? newValue);

  /// Called when a [Signal] is disposed.
  void onSignalDisposed(Signal signal);

  /// Enables console logging observer globally.
  static void enableLogging() {
    signalObserver = ConsoleSignalObserver();
  }
}

/// A concrete [SignalObserver] that prints signal lifecycle events and changes to the console.
class ConsoleSignalObserver extends SignalObserver {
  @override
  void onSignalCreated(Signal signal) {
    final label = signal.name ?? 'Signal';
    print('[Signal Created] $label');
  }

  @override
  void onSignalChanged(Signal signal, Object? oldValue, Object? newValue) {
    final label = signal.name ?? 'Signal';
    print('[Signal Changed] $label: $oldValue -> $newValue');
  }

  @override
  void onSignalDisposed(Signal signal) {
    final label = signal.name ?? 'Signal';
    print('[Signal Disposed] $label');
  }
}

/// The global registry for the active [SignalObserver].
SignalObserver? signalObserver;
