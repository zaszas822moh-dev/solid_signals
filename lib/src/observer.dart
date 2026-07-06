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
}

/// The global registry for the active [SignalObserver].
SignalObserver? signalObserver;
