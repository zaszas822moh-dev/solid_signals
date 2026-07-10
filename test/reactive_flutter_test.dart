import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solid_signals/reactive_flutter.dart';

void main() {
  group('Observe Widget', () {
    testWidgets('should render initial value and rebuild when signal changes', (tester) async {
      final counter = Signal(0);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Observe(
              builder: (context) {
                buildCount++;
                return Text('Count: ${counter.value}');
              },
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      expect(buildCount, equals(1));

      // Update signal
      counter.value = 1;
      await tester.pump(); // trigger frame

      expect(find.text('Count: 1'), findsOneWidget);
      expect(buildCount, equals(2));
    });

    testWidgets('should clean up subscriptions when disposed', (tester) async {
      final counter = Signal(0);
      final showWidget = Signal(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Observe(
              builder: (context) {
                if (showWidget.value) {
                  return Observe(
                    builder: (context) => Text('Inner: ${counter.value}'),
                  );
                } else {
                  return const Text('Gone');
                }
              },
            ),
          ),
        ),
      );

      expect(find.text('Inner: 0'), findsOneWidget);
      // The inner Observe widget has registered its effect to counter
      expect(counter.observers.isNotEmpty, isTrue);

      // Hide the inner observe widget, forcing its disposal
      showWidget.value = false;
      await tester.pump();

      expect(find.text('Gone'), findsOneWidget);
      expect(find.text('Inner: 0'), findsNothing);
      // The inner Observe widget is disposed, so counter observers should be empty
      expect(counter.observers.isEmpty, isTrue);
    });
  });

  group('watch(context) extension', () {
    testWidgets('should rebuild StatelessWidget when watched signal changes', (tester) async {
      final counter = Signal(10);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WatchTestWidget(counter: counter),
          ),
        ),
      );

      expect(find.text('Value: 10'), findsOneWidget);

      counter.value = 20;
      await tester.pump();

      expect(find.text('Value: 20'), findsOneWidget);
    });
  });

  group('SignalScope', () {
    testWidgets('should resolve overridden signal inside a scope', (tester) async {
      final original = Signal(10);
      final overridden = Signal(99);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignalScope(
              overrides: {
                original: overridden,
              },
              child: WatchTestWidget(counter: original),
            ),
          ),
        ),
      );

      expect(find.text('Value: 99'), findsOneWidget);

      overridden.value = 100;
      await tester.pump();
      expect(find.text('Value: 100'), findsOneWidget);

      original.value = 50;
      await tester.pump();
      expect(find.text('Value: 100'), findsOneWidget);
    });
  });

  group('SignalListener', () {
    testWidgets('should call listener callback on change without rebuilding child', (tester) async {
      final counter = Signal(0);
      final calls = <int>[];
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SignalListener<int>(
              select: () => counter.value,
              listener: (val) => calls.add(val),
              child: Builder(
                builder: (context) {
                  buildCount++;
                  return const Text('Child');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Child'), findsOneWidget);
      expect(calls.isEmpty, isTrue);
      expect(buildCount, equals(1));

      counter.value = 1;
      await tester.pump();

      expect(calls, equals([1]));
      expect(buildCount, equals(1));

      counter.value = 2;
      await tester.pump();

      expect(calls, equals([1, 2]));
      expect(buildCount, equals(1));
    });
  });
}

class WatchTestWidget extends StatelessWidget {
  final Signal<int> counter;
  const WatchTestWidget({super.key, required this.counter});

  @override
  Widget build(BuildContext context) {
    final val = counter.watch(context);
    return Text('Value: $val');
  }
}
