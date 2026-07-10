# Solid Signals ⚡

A high-performance, ultra-lightweight, and fine-grained reactive state management solution for Flutter. It brings the power of transparent reactivity (Signals) to Flutter, completely eliminating the common architectural pitfalls of both `Provider` and `Riverpod`.

---

## ✨ Key Features

* 🚫 **Zero BuildContext Boilerplate:** Access, read, or mutate your state anywhere—inside repositories, background services, or pure Dart classes.
* 🎯 **Surgical UI Rebuilds:** No more massive widget tree re-renders. Only the specific widget consuming the exact piece of data will rebuild automatically.
* 📦 **Minimalist Syntax:** Say goodbye to complex `ConsumerWidget`, `WidgetRef`, or tedious `.select()` methods. Write simple `StatelessWidget`s and read values seamlessly.
* 🔄 **Smart Caching & Caching:** `Computed` states dynamically track their dependencies, caching values and recomputing only when necessary, guaranteed to be **Glitch-Free**.
* 💾 **Persistence (Hydration):** Save and load signal states automatically using a simple storage interface.
* 🔍 **Central Monitoring (DevTools):** Enable global logging with `SignalObserver` to monitor creations, changes, and disposals of states centrally.

---

## 📦 Installation

Add `solid_signals` to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  solid_signals: ^1.0.2
```

Import it in your Dart code:

```dart
import 'package:solid_signals/reactive_flutter.dart';
```

---

## 🚀 Core Concepts

### 1. Signals
A `Signal` holds a single reactive value. When its value changes, all dependent effects, computed values, and UI widgets are notified.

```dart
// Standard constructor
final counter = Signal<int>(0);

// Using DX Extensions
final counter = 0.signal;
final user = User(name: 'Alice').toSignal(name: 'user_signal');
```

Update or read the value:
```dart
print(counter.value); // Read
counter.value = 10;   // Mutate
```

### 2. Computed
`Computed` values derive their state from other signals or computed values. They evaluate lazily, cache their results, and automatically recompute only when their dependencies change.

```dart
final count = 10.signal;

// Standard constructor
final doubled = Computed(() => count.value * 2);

// Using DX Extensions
final doubled = (() => count.value * 2).computed;
```

### 3. Effects
`Effect`s run a side-effect function immediately and reactively re-run it whenever any of the signals read inside it change.

```dart
final count = 0.signal;

// Standard constructor
final eff = effect(() {
  print("Current count: ${count.value}");
});

// Using DX Extensions
final eff = (() => print("Current count: ${count.value}")).effect;

// Stop the effect from running
eff.dispose();
```

### 4. Persistence & Hydration
Hydrate signals to save and load state automatically when the app restarts. You can set a global storage provider or pass a custom one.

```dart
// 1. Define a storage provider wrapping shared_preferences, Hive, secure_storage, etc.
class MyStorage implements SignalStorage {
  final SharedPreferences prefs;
  MyStorage(this.prefs);

  @override
  String? read(String key) => prefs.getString(key);

  @override
  void write(String key, String value) => prefs.setString(key, value);

  @override
  void delete(String key) => prefs.remove(key);
}

// 2. Register it globally in main()
globalSignalStorage = MyStorage(prefs);

// 3. Hydrate your signals
final themeMode = 'dark'.toSignal(name: 'theme_mode').hydrate(
  key: 'app_theme',
  fromJson: (value) => value,
  toJson: (value) => value,
);
```

---

## 📱 Flutter Integration

### Option A: `Observe` Widget (Recommended for surgical UI rebuilds)
Wrap only the specific text or widget that depends on the signal. This prevents the parent widgets from rebuilding unnecessarily.

```dart
final counter = 0.signal;

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Center(
      child: Observe(
        builder: (context) => Text('Count: ${counter.value}'),
      ),
    ),
  );
}
```

### Option B: `.watch(context)` Extension
If you want the entire widget to rebuild on change, use the `.watch(context)` extension:

```dart
final counter = 0.signal;

class CounterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Rebuilds entire widget when counter changes
    final value = counter.watch(context);
    return Text('Count: $value');
  }
}
```

### Scoping and Overrides (`SignalScope`)
Override signals down the widget tree. Perfect for testing, mock injection, or reusable UI components.

```dart
final userSignal = Signal(User(name: 'Guest'));

Widget build(BuildContext context) {
  return SignalScope(
    overrides: [
      userSignal.overrideWithValue(User(name: 'John Doe')),
    ],
    child: UserProfileWidget(), // Reads the overridden John Doe value
  );
}
```

---

## 🛠️ Diagnostics & Logger Observer

Turn on built-in global logging in your `main()` entrypoint to trace all signal creations, updates, and disposals centrally in the console:

```dart
void main() {
  SignalObserver.enableLogging();
  
  runApp(const MyApp());
}
```

Example Console Output:
```plaintext
[Signal Created] cart
[Signal Changed] cart: [] -> [Product(id: 1, name: Headphones)]
[Signal Disposed] review_product_1
```
