import 'package:flutter/widgets.dart';
import '../computed.dart';
import '../consumer.dart';
import '../node.dart';
import '../signal.dart';
import 'scope.dart';

/// Tracks the set of reactive nodes that are currently watched by each [Element].
///
/// Expando uses weak keys, so when an [Element] is disposed and no longer referenced elsewhere,
/// its entry is automatically garbage-collected.
final Expando<Set<Node>> _elementNodes = Expando();

/// A specialized observer that holds a [WeakReference] to a Flutter [Element]
/// to trigger rebuilds on value change without causing memory leaks.
class FlutterSignalObserver implements Consumer {
  /// Weak reference to the element to avoid preventing GC.
  final WeakReference<Element> elementRef;

  /// The node being observed.
  final Node node;

  /// Creates a new observer for the given [element] and [node].
  FlutterSignalObserver(Element element, this.node) : elementRef = WeakReference(element);

  @override
  void notify() {
    final element = elementRef.target;
    if (element == null || !element.mounted) {
      // The element is dead or unmounted, unsubscribe immediately
      node.removeObserver(this);
    } else {
      element.markNeedsBuild();
    }
  }

  /// Returns `true` if the referenced element has been garbage-collected or unmounted.
  bool get isDead {
    final element = elementRef.target;
    return element == null || !element.mounted;
  }
}

/// Helper function to subscribe an [Element] to a [Node].
void _watchNode(Element element, Node node) {
  // Clean up any dead observers on the node to prevent memory leak build-up
  final dead = node.observers.whereType<FlutterSignalObserver>().where((o) => o.isDead).toList();
  for (final observer in dead) {
    node.removeObserver(observer);
  }

  final watched = _elementNodes[element] ??= {};
  if (!watched.contains(node)) {
    watched.add(node);
    node.addObserver(FlutterSignalObserver(element, node));
  }
}

extension SignalFlutterExtension<T> on Signal<T> {
  /// Subscribes the current [BuildContext] (widget) to this signal.
  ///
  /// The widget will automatically rebuild whenever this signal's value changes.
  /// Returns the current value of the signal (or its scope override).
  T watch(BuildContext context) {
    final resolved = SignalScope.get(context, this);
    _watchNode(context as Element, resolved);
    return resolved.value;
  }
}

extension ComputedFlutterExtension<T> on Computed<T> {
  /// Subscribes the current [BuildContext] (widget) to this computed value.
  ///
  /// The widget will automatically rebuild whenever this computed value changes.
  /// Returns the current computed value (or its scope override).
  T watch(BuildContext context) {
    final resolved = SignalScope.get(context, this);
    _watchNode(context as Element, resolved);
    return resolved.value;
  }
}
