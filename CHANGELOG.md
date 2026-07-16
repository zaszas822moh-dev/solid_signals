## Unreleased

* Added cancellable Signal.listen subscriptions with previous/current values.
* Added Signal.peek for untracked reads.
* Added reactive Future sources, Stream sources, cancellation hooks, retry,
  reload, invalidation, and retained data during AsyncSignal refreshes.

## 1.0.0

* Initial stable release of `solid_signals`.
* Core `Signal` and `Computed` reactivity engine.
* Added `Observe` widget and `.watch(context)` extension for surgical UI rebuilds.
* Built-in asynchronous state management with `AsyncSignal`.

## 1.0.2

* Fixed `AsyncSignal` re-fetch infinite notification loop by correcting evaluation order in `Effect` and `Computed`.
* Added Dart DX Extensions (`.signal`, `.toSignal()`, `.computed`, `.effect`).
* Added Persistence & Hydration API (`SignalStorage`, `globalSignalStorage`, `.hydrate()`).
* Added central logging observer (`ConsoleSignalObserver` and `SignalObserver.enableLogging()`).
* Added optional `name` property to `Signal` and `AsyncSignal.fromFuture` constructors for easier diagnostics.

## 1.0.1

* Add official repository and documentation website links.
