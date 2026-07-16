import 'consumer.dart';
import 'signal.dart';

/// A cancellable subscription created by [Signal.listen].
class SignalSubscription<T> implements Consumer {
  final Signal<T> _signal;
  final void Function(T previous, T current) _listener;
  T _previous;
  bool _isCanceled = false;

  /// Creates a subscription and attaches it to [signal].
  SignalSubscription(
    Signal<T> signal,
    this._listener, {
    bool fireImmediately = false,
  })  : _signal = signal,
        _previous = signal.peek() {
    signal.addObserver(this);
    if (fireImmediately) {
      _listener(_previous, _previous);
    }
  }

  /// Whether this subscription has been canceled.
  bool get isCanceled => _isCanceled;

  @override
  void notify() {
    if (_isCanceled) return;
    final current = _signal.peek();
    final previous = _previous;
    _previous = current;
    _listener(previous, current);
  }

  /// Stops listening. Calling this more than once is safe.
  void cancel() {
    if (_isCanceled) return;
    _isCanceled = true;
    _signal.removeObserver(this);
  }
}
