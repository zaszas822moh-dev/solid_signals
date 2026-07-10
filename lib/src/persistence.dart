import 'effect.dart';
import 'signal.dart';

/// An interface for storing and retrieving persisted signal states.
abstract class SignalStorage {
  /// Reads the string value associated with [key], or `null` if not found.
  String? read(String key);

  /// Writes the string [value] associated with [key] to storage.
  void write(String key, String value);

  /// Removes the value associated with [key] from storage.
  void delete(String key);
}

/// Global registry for the active [SignalStorage].
SignalStorage? globalSignalStorage;

/// A default in-memory implementation of [SignalStorage] used as a fallback.
class InMemorySignalStorage implements SignalStorage {
  final Map<String, String> _storage = {};

  @override
  String? read(String key) => _storage[key];

  @override
  void write(String key, String value) => _storage[key] = value;

  @override
  void delete(String key) => _storage.remove(key);
}

extension HydratedSignalExtension<T> on Signal<T> {
  /// Hydrates (persists) the current signal using the provided storage or [globalSignalStorage].
  ///
  /// It immediately reads the stored value associated with [key]. If a value is found,
  /// it updates the signal's value silently. It then registers an [Effect] to automatically
  /// write any subsequent value changes back to storage.
  Signal<T> hydrate({
    required String key,
    required T Function(String value) fromJson,
    required String Function(T value) toJson,
    SignalStorage? storage,
  }) {
    final activeStorage = storage ?? globalSignalStorage ?? InMemorySignalStorage();
    try {
      final stored = activeStorage.read(key);
      if (stored != null) {
        setValueSilently(fromJson(stored));
      }
    } catch (_) {
      // Ignore initial read error to allow fallback/empty state
    }

    // Reactively write updates to storage
    effect(() {
      try {
        activeStorage.write(key, toJson(value));
      } catch (_) {
        // Ignore write errors
      }
    });

    return this;
  }
}
