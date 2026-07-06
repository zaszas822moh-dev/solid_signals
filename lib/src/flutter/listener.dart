import 'package:flutter/widgets.dart';
import '../effect.dart';

/// A widget that listens to a reactive [select] function and invokes the [listener] callback
/// for side-effects (such as showing SnackBars, dialogs, or triggering navigation)
/// without rebuilding the widget tree.
class SignalListener<T> extends StatefulWidget {
  /// A reactive selector function.
  ///
  /// Any signal read inside this callback (using `.value`) will register it
  /// as a dependency.
  final T Function() select;

  /// The callback executed when the value computed by [select] changes.
  ///
  /// It is NOT called on the initial mount, only on subsequent changes.
  final void Function(T value) listener;

  /// The child widget.
  final Widget child;

  /// Creates a [SignalListener] widget.
  const SignalListener({
    super.key,
    required this.select,
    required this.listener,
    required this.child,
  });

  @override
  State<SignalListener<T>> createState() => _SignalListenerState<T>();
}

class _SignalListenerState<T> extends State<SignalListener<T>> {
  Effect? _effect;
  bool _isFirstRun = true;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(SignalListener<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unsubscribe();
    _subscribe();
  }

  void _subscribe() {
    _isFirstRun = true;
    _effect = Effect(() {
      final val = widget.select();
      if (_isFirstRun) {
        _isFirstRun = false;
      } else {
        widget.listener(val);
      }
    });
  }

  void _unsubscribe() {
    _effect?.dispose();
    _effect = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
