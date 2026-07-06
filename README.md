# Solid Signals ⚡

A high-performance, ultra-lightweight, and fine-grained reactive state management solution for Flutter. It brings the power of transparent reactivity (Signals) to Flutter, completely eliminating the common architectural pitfalls of both `Provider` and `Riverpod`.

---

## ✨ Key Features

* 🚫 **Zero BuildContext Boilerplate:** Access, read, or mutate your state anywhere—inside repositories, background services, or pure Dart classes.
* 🎯 **Surgical UI Rebuilds:** No more massive widget tree re-renders. Only the specific widget consuming the exact piece of data will rebuild automatically.
* 📦 **Minimalist Syntax:** Say goodbye to complex `ConsumerWidget`, `WidgetRef`, or tedious `.select()` methods. Your widgets remain simple `StatelessWidget`s.
* 🔄 **Smart Evaluation & Caching:** `Computed` states dynamically track their dependencies, caching values and recomputing only when necessary (Glitch-Free).
* 🌐 **Enterprise Ready:** Out-of-the-box support for asynchronous operations (`AsyncSignal`), parameterization (`SignalFamily`), scoping, and central monitoring (`SignalObserver`).

---

## 📦 Installation

Add `solid_signals` to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  solid_signals: ^1.0.0
```
