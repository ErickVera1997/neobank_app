# Estrategia de pruebas

## Pirámide

```text
        ▲  E2E (integration_test)         1 flujo crítico
       ███ Widget tests                    UI y módulos
     █████ Unit tests                      dinero, JSON, seguridad, HTTP, FX
```

| Nivel | Ubicación | Qué cubre | Comando |
| --- | --- | --- | --- |
| Unit (core) | `packages/neobank_core/test` | `Money`, `Result`, parseo JSON, modelos | `dart test` |
| Unit + integración (backend) | `services/neobank_api/test` | PBKDF2, JWT, FX con proveedor caído, API completa sobre SQLite en memoria | `dart test` |
| Unit (app) | `apps/neobank_mobile/test/core` | Cliente HTTP: caché offline, refresh 401, reintentos 5xx | `flutter test` |
| Widget | `apps/neobank_mobile/test/widget` | `MoneyText`, `ErrorView`, banner de conectividad, módulo de saldo, validación de login | `flutter test` |
| E2E | `apps/neobank_mobile/integration_test` | login → home personalizado → cuentas → movimientos | ver abajo |

## Ejecutar todo

```bash
# 1) Contratos
cd packages/neobank_core && dart pub get && dart analyze && dart test

# 2) Backend
cd services/neobank_api && dart pub get && dart analyze && dart test

# 3) App (unit + widget)
cd apps/neobank_mobile && flutter pub get && flutter analyze && flutter test

# 4) E2E en un dispositivo/emulador
flutter test integration_test/app_e2e_test.dart -d <device-id>
```

## Flujo E2E crítico

`integration_test/app_e2e_test.dart` levanta **la app real** con un
`HttpClientAdapter` falso a nivel HTTP. Se ejercita el stack completo: Dio,
`ApiClient` (auth, caché), repositorios, providers de Riverpod, enrutado por
sesión y la UI. El escenario:

1. Arranque sin sesión → pantalla de login.
2. Login con el usuario demo.
3. Home **personalizado por el backend**: saludo, saldo consolidado y módulo
   de divisas.
4. Navegación a la lista de cuentas.
5. Apertura del detalle y verificación de movimientos.

¿Por qué así? Ver **ADR-010** en `docs/decisions.md`: máxima fidelidad de
código con determinismo total, sin depender de red ni credenciales.

## Escenarios de degradación cubiertos por pruebas

| Escenario | Dónde se prueba |
| --- | --- |
| Sin red con caché disponible | `test/core/api_client_test.dart` |
| Sin red sin caché → error tipado | `test/core/api_client_test.dart` |
| 401 → refresh y reintento | `test/core/api_client_test.dart` |
| 5xx → reintentos con backoff | `test/core/api_client_test.dart` |
| Proveedor FX caído con caché | `services/neobank_api/test/fx_service_test.dart` |
| Proveedor FX caído sin caché → 503 | `services/neobank_api/test/fx_service_test.dart` |
| Fondos insuficientes → 409 | `services/neobank_api/test/api_test.dart` |

## Convenciones

- Cada bug corregido debería incorporar una prueba que lo reproduzca.
- Los tests no dependen de la red ni de credenciales; usan adaptadores y
  clientes simulados.
- Los datos de prueba son deterministas (semilla en memoria).