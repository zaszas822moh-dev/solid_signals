import 'node.dart';

/// An interface for any object that consumes reactive values and needs to
/// be notified when they change.
abstract class Consumer {
  /// Notifies the consumer that one of its dependencies has changed.
  void notify();
}

/// A specialized [Consumer] that tracks which [Node]s it depends on.
abstract class DependencyTracker implements Consumer {
  /// Registers a node as a dependency.
  void addDependency(Node node);

  /// Clears all existing registered dependencies and unsubscribes from them.
  void clearDependencies();
}

/// A global stack tracking the nested execution of reactive consumers
/// (such as [Computed] or [Effect]).
final List<Consumer> consumerStack = [];

/// Returns the currently active consumer, or `null` if no consumer is running.
Consumer? get activeConsumer => consumerStack.isEmpty ? null : consumerStack.last;

/// Pushes a consumer onto the execution stack.
void pushConsumer(Consumer consumer) {
  consumerStack.add(consumer);
}

/// Pops the top consumer off the execution stack.
void popConsumer() {
  if (consumerStack.isNotEmpty) {
    consumerStack.removeLast();
  }
}

// ==========================================
// Glitch-Free Batching Mechanism
// ==========================================

int _batchCount = 0;
final Set<Consumer> _pendingConsumers = {};

/// Returns `true` if a batch update is currently active.
bool get isBatching => _batchCount > 0;

/// Starts a batch update. Notifications to [Effect]s will be deferred.
void startBatch() {
  _batchCount++;
}

/// Ends a batch update. If the batch count drops to 0, all queued
/// consumers are executed.
void endBatch() {
  _batchCount--;
  if (_batchCount == 0) {
    // Copy the set to allow consumers to trigger new updates or nested batches safely
    final pending = List.of(_pendingConsumers);
    _pendingConsumers.clear();
    for (final consumer in pending) {
      consumer.notify();
    }
  }
}

/// Queues a consumer to run when the current batch finishes.
void queueConsumer(Consumer consumer) {
  _pendingConsumers.add(consumer);
}

/// Batches multiple signal updates together so that dependent effects only run once
/// after the batch function completes.
void batch(void Function() fn) {
  startBatch();
  try {
    fn();
  } finally {
    endBatch();
  }
}
