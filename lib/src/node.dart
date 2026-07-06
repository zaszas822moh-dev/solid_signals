import 'consumer.dart';

/// An abstract base class for any reactive producer that can be observed
/// by one or more [Consumer]s.
abstract class Node {
  /// The set of active consumers currently observing this node.
  final Set<Consumer> observers = {};

  /// Registers a consumer to observe changes on this node.
  void addObserver(Consumer consumer) {
    observers.add(consumer);
  }

  /// Unregisters a consumer from observing this node.
  void removeObserver(Consumer consumer) {
    observers.remove(consumer);
  }

  /// Notifies all registered observers that the value of this node has changed.
  void notifyObservers() {
    // Copy the set to prevent ConcurrentModificationError during notification.
    for (final observer in List.of(observers)) {
      observer.notify();
    }
  }
}
