/// Resultado explícito de una operación que puede fallar.
///
/// Preferimos `Result` sobre excepciones en las capas de dominio/datos para
/// forzar el manejo de errores y habilitar reintentos/recovery controlados.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  Object? get errorOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final error) => error,
      };

  R fold<R>(R Function(T value) onOk, R Function(Object error) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final error) => onErr(error),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.error);
  final Object error;
}
