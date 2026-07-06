import 'package:flutter/widgets.dart';
import '../../reactive.dart';

/// A widget that rebuilds automatically when any [Signal] or [Computed] value
/// read inside its [builder] changes.
///
/// Under the hood, it creates an [Effect] on initialization and disposes of it
/// when the widget is unmounted, ensuring zero memory leaks.
class Observe extends StatefulWidget {
  /// The builder function that describes the widget subtree.
  ///
  /// Any reactive values accessed via `.value` inside this function will be
  /// registered as dependencies of this widget.
  final Widget Function(BuildContext context) builder;

  /// Creates an [Observe] widget with a reactive [builder].
  const Observe({super.key, required this.builder});

  @override
  State<Observe> createState() => _ObserveState();
}

class _ObserveState extends State<Observe> {
  late final Effect _effect;

  @override
  void initState() {
    super.initState();
    // Create a lazy effect that will invoke setState when dependencies notify change.
    _effect = Effect.lazy(_rebuild);
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    // Unsubscribe from all signals to prevent memory leaks.
    _effect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Run the builder function within the tracking context of our internal effect.
    return _effect.track(() => widget.builder(context));
  }
}
