import 'package:flutter/widgets.dart';
import '../node.dart';

/// An [InheritedWidget] that provides a registry of signal or computed overrides
/// to a widget subtree.
///
/// This is highly useful for dependency injection, decoupling states from widgets,
/// and overriding states during testing and mocking.
class SignalScope extends InheritedWidget {
  /// Map of original nodes to their overridden counterparts.
  final Map<Node, Node> overrides;

  /// Creates a [SignalScope] with the given [overrides] and a [child] widget.
  const SignalScope({
    super.key,
    required this.overrides,
    required super.child,
  });

  /// Looks up the nearest [SignalScope] ancestor.
  static SignalScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SignalScope>();
  }

  /// Resolves the given [original] node.
  ///
  /// If the node is overridden in an ancestor [SignalScope], returns the overridden instance.
  /// Otherwise, returns [original].
  static N get<N extends Node>(BuildContext context, N original) {
    final scope = maybeOf(context);
    if (scope != null && scope.overrides.containsKey(original)) {
      return scope.overrides[original] as N;
    }
    return original;
  }

  @override
  bool updateShouldNotify(SignalScope oldWidget) {
    return oldWidget.overrides != overrides;
  }
}
