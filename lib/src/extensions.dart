import 'signal.dart';
import 'computed.dart';
import 'effect.dart';

extension SignalValueExtension<T> on T {
  /// Wraps this value in a reactive [Signal].
  Signal<T> get signal => Signal<T>(this);

  /// Wraps this value in a reactive [Signal] with an optional name.
  Signal<T> toSignal({String? name}) => Signal<T>(this, name: name);
}

extension ComputedFunctionExtension<T> on T Function() {
  /// Wraps this function in a [Computed] value.
  Computed<T> get computed => Computed<T>(this);
}

extension EffectFunctionExtension on void Function() {
  /// Runs this function immediately and reactively inside an [Effect].
  Effect get effect => Effect(this);
}
