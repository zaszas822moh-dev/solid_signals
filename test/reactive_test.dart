import 'dart:async';
import 'package:solid_signals/reactive.dart';
import 'package:test/test.dart';

void main() {
  group('Signal', () {
    test('should hold and update value', () {
      final s = Signal(10);
      expect(s.value, equals(10));
      s.value = 20;
      expect(s.value, equals(20));
    });

    test('should notify listener on change', () {
      final s = Signal(1);
      int calls = 0;
      effect(() {
        s.value;
        calls++;
      });
      expect(calls, equals(1));
      s.value = 2;
      expect(calls, equals(2));
    });

    test('should not notify if value is same', () {
      final s = Signal(1);
      int calls = 0;
      effect(() {
        s.value;
        calls++;
      });
      expect(calls, equals(1));
      s.value = 1;
      expect(calls, equals(1));
    });
  });

  group('Computed', () {
    test('should compute and cache derived value', () {
      final s = Signal(2);
      int computations = 0;
      final c = Computed(() {
        computations++;
        return s.value * 2;
      });

      expect(computations, equals(0)); // lazy evaluation: not computed yet
      expect(c.value, equals(4));
      expect(computations, equals(1));

      // Access again, should use cache
      expect(c.value, equals(4));
      expect(computations, equals(1));

      // Update signal, should recompute next time it is read
      s.value = 3;
      expect(computations, equals(1)); // lazy: not computed immediately
      expect(c.value, equals(6));
      expect(computations, equals(2));
    });

    test('should work with nested computed values', () {
      final a = Signal(1);
      final b = Computed(() => a.value + 1);
      final c = Computed(() => b.value + 1);

      expect(c.value, equals(3));
      a.value = 10;
      expect(c.value, equals(12));
    });

    test('should handle dynamic dependency tracking', () {
      final condition = Signal(true);
      final a = Signal('A');
      final b = Signal('B');

      int computations = 0;
      final derived = Computed(() {
        computations++;
        return condition.value ? a.value : b.value;
      });

      expect(derived.value, equals('A'));
      expect(computations, equals(1));

      // Update b (not active dependency) -> should not mark dirty or recompute
      b.value = 'BB';
      expect(derived.value, equals('A'));
      expect(computations, equals(1)); // remains cached

      // Update a -> should recompute
      a.value = 'AA';
      expect(derived.value, equals('AA'));
      expect(computations, equals(2));

      // Switch condition -> should recompute
      condition.value = false;
      expect(derived.value, equals('BB'));
      expect(computations, equals(3));

      // Update a (no longer active dependency) -> should not recompute
      a.value = 'AAA';
      expect(derived.value, equals('BB'));
      expect(computations, equals(3));

      // Update b -> should recompute
      b.value = 'BBB';
      expect(derived.value, equals('BBB'));
      expect(computations, equals(4));
    });

    test('should detect circular dependency and throw StateError', () {
      late Computed<int> c1;
      late Computed<int> c2;

      c1 = Computed(() => c2.value + 1);
      c2 = Computed(() => c1.value + 1);

      expect(() => c1.value, throwsStateError);
    });
  });

  group('Effect', () {
    test('should run immediately and on dependency changes', () {
      final s = Signal(1);
      final list = <int>[];
      final eff = effect(() {
        list.add(s.value);
      });

      expect(list, equals([1]));
      s.value = 2;
      expect(list, equals([1, 2]));

      eff.dispose();
      s.value = 3;
      expect(list, equals([1, 2])); // no more runs after dispose
    });
  });

  group('AutoDispose', () {
    test('should dispose signal when observers drop to zero', () {
      int disposeCalls = 0;
      int listenCalls = 0;
      final s = Signal(
        0,
        autoDispose: true,
        onDispose: () => disposeCalls++,
        onListen: () => listenCalls++,
      );

      expect(disposeCalls, equals(0));
      expect(listenCalls, equals(0));

      final eff = effect(() {
        s.value;
      });

      expect(listenCalls, equals(1));
      expect(disposeCalls, equals(0));

      eff.dispose();

      expect(disposeCalls, equals(1));
    });

    test('should support builder chaining with autoDispose()', () {
      int disposeCalls = 0;
      final s = Signal(0).autoDispose(onDispose: () => disposeCalls++);

      expect(disposeCalls, equals(1)); // disposed immediately since it starts with 0 observers!

      // Re-observe
      final eff = effect(() {
        s.value;
      });
      expect(s.isDisposed, isFalse);

      eff.dispose();
      expect(disposeCalls, equals(2));
    });
  });

  group('AsyncSignal', () {
    test('should transition to AsyncData on success', () async {
      final s = AsyncSignal.fromFuture(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 'success';
      });

      expect(s.value, equals(const AsyncLoading<String>()));

      // Wait for future to complete
      await Future.delayed(const Duration(milliseconds: 20));

      expect(s.value, equals(const AsyncData('success')));

      // pattern matching
      final text = s.when(
        data: (d) => d,
        loading: () => 'loading',
        error: (e, st) => 'error',
      );
      expect(text, equals('success'));
    });

    test('should transition to AsyncError on failure', () async {
      final s = AsyncSignal.fromFuture(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        throw Exception('failed');
      });

      expect(s.value, equals(const AsyncLoading<dynamic>()));

      // Wait for future to complete
      await Future.delayed(const Duration(milliseconds: 20));

      expect(s.value, isA<AsyncError>());
      final isErr = s.when(
        data: (d) => false,
        loading: () => false,
        error: (e, st) => true,
      );
      expect(isErr, isTrue);
    });

    test('should support autoDispose and re-fetch when re-observed', () async {
      int fetchCount = 0;
      final s = AsyncSignal.fromFuture(
        () async {
          fetchCount++;
          return fetchCount;
        },
        autoDispose: true,
      );

      expect(fetchCount, equals(0)); // lazy, doesn't fetch yet
      expect(s.value, equals(const AsyncLoading<int>()));

      // First observation
      final eff1 = effect(() {
        s.value;
      });

      expect(fetchCount, equals(1));
      await Future.delayed(Duration.zero);
      expect(s.value, equals(const AsyncData(1)));

      // Remove observer -> disposes
      eff1.dispose();
      expect(s.isDisposed, isTrue);

      // Re-observe -> should re-fetch
      final eff2 = effect(() {
        s.value;
      });

      expect(fetchCount, equals(2));
      await Future.delayed(Duration.zero);
      expect(s.value, equals(const AsyncData(2)));

      eff2.dispose();
    });

    test('should ignore values if disposed before future completes', () async {
      int fetchCount = 0;
      final s = AsyncSignal.fromFuture(
        () async {
          fetchCount++;
          await Future.delayed(const Duration(milliseconds: 10));
          return fetchCount;
        },
        autoDispose: true,
      );

      final eff = effect(() {
        s.value;
      });

      expect(fetchCount, equals(1));
      expect(s.value, equals(const AsyncLoading<int>()));

      // Dispose before completion
      eff.dispose();
      expect(s.isDisposed, isTrue);

      // Wait past duration
      await Future.delayed(const Duration(milliseconds: 20));

      // The value should still be AsyncLoading (since updates from the old future are ignored)
      expect(s.value, equals(const AsyncLoading<int>()));
    });
  });

  group('SignalObserver', () {
    test('should monitor creation, changes, and disposal', () {
      final observer = TestSignalObserver();
      signalObserver = observer;

      final s = Signal(10);
      expect(observer.logs, contains('created: 10'));

      s.value = 20;
      expect(observer.logs, contains('changed: 10 -> 20'));

      s.dispose();
      expect(observer.logs, contains('disposed: 20'));

      signalObserver = null;
    });
  });

  group('SignalFamily', () {
    test('should cache and return the same signal for the same argument', () {
      final family = SignalFamily<int, String>((id) => Signal(0));

      final s1 = family('a');
      final s2 = family('a');
      final s3 = family('b');

      expect(s1, same(s2));
      expect(s1, isNot(same(s3)));
    });

    test('should evict signal from cache when disposed under autoDispose', () {
      final family = SignalFamily<int, String>((id) => Signal(0, autoDispose: true));

      final s1 = family('a');
      expect(family.cache.containsKey('a'), isTrue);

      final eff = effect(() {
        s1.value;
      });
      eff.dispose();

      expect(family.cache.containsKey('a'), isFalse);
    });
  });

  group('AsyncSignalFamily', () {
    test('should cache and return the same async signal for the same argument', () {
      final family = AsyncSignalFamily<int, String>((id) => AsyncSignal.fromFuture(() async => 0));

      final s1 = family('a');
      final s2 = family('a');
      final s3 = family('b');

      expect(s1, same(s2));
      expect(s1, isNot(same(s3)));
    });
  });

  group('AsyncValue and AsyncSignal Enhancements', () {
    test('AsyncValue getters and map methods', () {
      const loading = AsyncLoading<int>();
      expect(loading.isLoading, isTrue);
      expect(loading.hasError, isFalse);
      expect(loading.hasValue, isFalse);
      expect(loading.hasData, isFalse);
      expect(loading.data, isNull);
      expect(loading.valueOrNull, isNull);
      expect(() => loading.requireValue, throwsStateError);

      const error = AsyncError<int>('err', StackTrace.empty);
      expect(error.isLoading, isFalse);
      expect(error.hasError, isTrue);
      expect(error.hasValue, isFalse);
      expect(error.data, isNull);
      expect(() => error.requireValue, throwsStateError);

      const data = AsyncData<int>(42);
      expect(data.isLoading, isFalse);
      expect(data.hasError, isFalse);
      expect(data.hasValue, isTrue);
      expect(data.data, equals(42));
      expect(data.valueOrNull, equals(42));
      expect(data.requireValue, equals(42));

      // Test map
      expect(loading.map(
        data: (d) => 'data',
        loading: (l) => 'loading',
        error: (e) => 'error',
      ), equals('loading'));

      expect(error.map(
        data: (d) => 'data',
        loading: (l) => 'loading',
        error: (e) => 'error',
      ), equals('error'));

      expect(data.map(
        data: (d) => 'data ${d.value}',
        loading: (l) => 'loading',
        error: (e) => 'error',
      ), equals('data 42'));

      // Test maybeMap
      expect(loading.maybeMap(
        loading: (l) => 'loading',
        orElse: () => 'else',
      ), equals('loading'));

      expect(loading.maybeMap(
        data: (d) => 'data',
        orElse: () => 'else',
      ), equals('else'));
    });

    test('AsyncSignal delegation', () async {
      final s = AsyncSignal.fromFuture(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 42;
      });

      expect(s.isLoading, isTrue);
      expect(s.hasError, isFalse);
      expect(s.hasValue, isFalse);
      expect(s.data, isNull);

      await Future.delayed(const Duration(milliseconds: 15));

      expect(s.isLoading, isFalse);
      expect(s.hasError, isFalse);
      expect(s.hasValue, isTrue);
      expect(s.hasData, isTrue);
      expect(s.data, equals(42));
      expect(s.valueOrNull, equals(42));
      expect(s.requireValue, equals(42));

      expect(s.map(
        data: (d) => 'data ${d.value}',
        loading: (l) => 'loading',
        error: (e) => 'error',
      ), equals('data 42'));

      expect(s.maybeMap(
        data: (d) => 'data ${d.value}',
        orElse: () => 'else',
      ), equals('data 42'));
    });
  });

  group('Dart Extensions', () {
    test('should wrap value in Signal using .signal extension', () {
      final s = 42.signal;
      expect(s, isA<Signal<int>>());
      expect(s.value, equals(42));
    });

    test('should wrap value in Signal with custom name using .toSignal extension', () {
      final s = 'hello'.toSignal(name: 'greeting');
      expect(s, isA<Signal<String>>());
      expect(s.value, equals('hello'));
      expect(s.name, equals('greeting'));
    });

    test('should wrap function in Computed using .computed extension', () {
      final count = 10.signal;
      final doubled = (() => count.value * 2).computed;
      expect(doubled, isA<Computed<int>>());
      expect(doubled.value, equals(20));

      count.value = 15;
      expect(doubled.value, equals(30));
    });

    test('should wrap and run function in Effect using .effect extension', () {
      final count = 5.signal;
      int triggerCount = 0;
      final eff = (() {
        count.value;
        triggerCount++;
      }).effect;

      expect(eff, isA<Effect>());
      expect(triggerCount, equals(1));

      count.value = 10;
      expect(triggerCount, equals(2));
      eff.dispose();
    });
  });

  group('ConsoleSignalObserver', () {
    test('should print lifecycle events if enabled', () {
      final printedLogs = <String>[];
      final zoneSpec = ZoneSpecification(
        print: (self, parent, zone, line) {
          printedLogs.add(line);
        },
      );

      Zone.current.fork(specification: zoneSpec).run(() {
        SignalObserver.enableLogging();
        final s = Signal(10, name: 'my_test_signal');
        s.value = 20;
        s.dispose();
        signalObserver = null;
      });

      expect(printedLogs, contains('[Signal Created] my_test_signal'));
      expect(printedLogs, contains('[Signal Changed] my_test_signal: 10 -> 20'));
      expect(printedLogs, contains('[Signal Disposed] my_test_signal'));
    });
  });
}

class TestSignalObserver extends SignalObserver {
  final List<String> logs = [];

  @override
  void onSignalCreated(Signal signal) {
    logs.add('created: ${signal.value}');
  }

  @override
  void onSignalChanged(Signal signal, Object? oldValue, Object? newValue) {
    logs.add('changed: $oldValue -> $newValue');
  }

  @override
  void onSignalDisposed(Signal signal) {
    logs.add('disposed: ${signal.value}');
  }
}
