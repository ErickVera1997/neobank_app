# Despliegue y Operación — Neobank

## 1. Entornos

| Entorno | App | Backend | Datos |
| --- | --- | --- | --- |
| Local | `flutter run` | `dart run bin/server.dart` | SQLite + seed demo |
| CI | `flutter test`, `dart test` | contenedor efímero | SQLite `:memory:` |
| Staging | build interno / TestFlight | 1 réplica | SQLite/PostgreSQL de staging |
| Producción | tiendas | N réplicas + balanceador | PostgreSQL administrado |

## 2. Configuración (12-factor)

Toda la configuración del backend viene de variables de entorno; nada de
secretos en el repositorio.

| Variable | Default | Descripción |
| --- | --- | --- |
| `PORT` | `8080` | Puerto HTTP |
| `DB_PATH` | `data/neobank.sqlite` | Ruta SQLite (`:memory:` en CI) |
| `JWT_SECRET` | `dev-secret-change-me` | **Obligatorio** cambiarlo en prod |
| `FX_BASE_URL` | `https://api.frankfurter.app` | Proveedor FX |
| `PUSH_WEBHOOK_URL` | vacío | Relay hacia FCM/APNs (si vacío → noop) |
| `ENV` | `development` | `development` expone `devCode` del OTP |

La app recibe la URL del backend por `--dart-define`:

```bash
flutter run --dart-define=API_BASE_URL=https://api.staging.neobank.dev
# Android emulator contra host local:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

## 3. Build y release

### Backend

```bash
# Compilar a un ejecutable único
dart compile exe services/neobank_api/bin/server.dart -o build/neobank_api

# Imagen mínima (ejemplo)
docker build -t neobank-api services/neobank_api
```

Despliegue recomendado: contenedor sin estado detrás de un balanceador con TLS
terminado en el borde. La base de datos, en producción, es un servicio
administrado (Cloud SQL/RDS).

### App

```bash
cd apps/neobank_mobile
flutter build apk --release   --dart-define=API_BASE_URL=https://api.neobank.dev
flutter build ipa --release   --dart-define=API_BASE_URL=https://api.neobank.dev
```

- **Versionado**: `version: 1.0.0+1` (semver + build number) [TBD].
- **Canales**: `main` → build automático → TestFlight / internal testing.
- **Rollback**: por commit en `main` + *feature flags* para desactivar
  capacidades sin re-publicar.

## 4. Observabilidad

### 4.1 Logs

- Backend: una línea por request con método, ruta, status y duración
  (`logRequests`); errores no controlados con stack trace.
- App: interceptor de red en debug; errores tipados (`AppErrorKind`) listos
  para enviarse a un backend de crashes.

### 4.2 Métricas

| Métrica | Tipo | Alerta sugerida |
| --- | --- | --- |
| `http_requests_total{route,status}` | contador | 5xx > 1 % durante 5 min |
| `http_request_duration_seconds` (p95) | histograma | p95 > 800 ms durante 10 min |
| `fx_provider_failures_total` | contador | > 5 en 10 min |
| `fx_stale_responses_total` | contador | > 20 % de requests FX |
| `auth_refresh_failures_total` | contador | > 2 % de refrescos |
| `push_delivery_failures_total` | contador | > 10 en 15 min |
| `db_file_size_bytes` / `db_locked_total` | gauge/contador | crecimiento o locks anómalos |

### 4.3 Trazas

Instrumentar el backend con OpenTelemetry (HTTP → handler → SQLite → proveedor
FX) y propagar `traceparent` desde la app cuando exista backend real de
telemetría. Cada transferencia debe ser trazable end-to-end por su `id`.

### 4.4 Experiencia de usuario (RUM)

- Crash-free sessions y ANR rate (Firebase Crashlytics/Sentry).
- Tiempo de carga del home (bootstrap) y tasa de datos servidos desde caché.
- Errores por pantalla con `AppErrorKind`.

### 4.5 SLOs propuestos

| SLO | Objetivo |
| --- | --- |
| Disponibilidad del API | 99.9 % mensual |
| Latencia p95 de `/accounts` | < 400 ms |
| Éxito de login | > 99 % |
| Frescura FX | < 15 min en ≥ 95 % de lecturas |

## 5. Runbook (diagnóstico de incidentes)

| Síntoma | ¿Cómo detectarlo? | Acción |
| --- | --- | --- |
| API no responde | `/health` falla + 5xx | Reiniciar réplica, revisar logs y conexiones a DB |
| Latencia alta | p95 > SLO | Revisar índice de transacciones, pool de conexiones, tamaño de DB |
| FX desactualizado | `fx_stale_responses_total` alto | Verificar proveedor; si persiste, la app sigue operando con caché |
| Usuarios no pueden entrar | `auth_refresh_failures_total` alto | Verificar `JWT_SECRET`, reloj del servidor y tabla de refresh tokens |
| Push no llega | `push_delivery_failures_total` | Revisar relay (`PUSH_WEBHOOK_URL`) y tokens de dispositivo |
| DB bloqueada | `db_locked_total` | Reducir escrituras concurrentes; migrar a PostgreSQL |
| App lenta/caída | Crash-free rate / ANR | Revisar release, feature flags y rollback por commit |

## 6. Gestión de datos

- **Migraciones**: `AppDatabase._migrate()` es idempotente y se ejecuta al
  arrancar; añadir migraciones nuevas sin romper las existentes.
- **Backups**: en producción, snapshots automáticos del motor administrado; en
  SQLite, copia del archivo + WAL.
- **PII**: los datos de demo son sintéticos. En producción: cifrado en reposo,
  retención por política y minimización (sólo lo necesario para el servicio).
- **Secretos**: gestor de secretos del proveedor cloud; nunca en el repo.

## 7. Matriz de degradación (resumen)

| Falla | API | App | Recuperación |
| --- | --- | --- | --- |
| Sin red (dispositivo) | — | Banner + caché | Automática al reconectar |
| Latencia alta | Timeout 8–15 s | Spinners/skeletons | Reintento manual/automático |
| 5xx intermitente | — | 2 reintentos con backoff | Automática |
| FX caído | Stale desde caché | Etiqueta “cache/desactualizado” | Al recuperar el proveedor |
| Sesión expirada | 401 | Refresh automático | Si falla → login |
| Backend caído | 503 | Datos cacheados + acciones deshabilitadas | Al volver el servicio |

## 8. CI/CD (ver `.github/workflows/ci.yml`)

En cada push a `main` y en cada PR:

1. `neobank_core`: `dart analyze` + `dart test`.
2. `neobank_api`: `dart analyze` + `dart test` (SQLite en memoria).
3. `neobank_mobile`: `flutter analyze` + `flutter test`.
4. (Opcional) E2E en emulador cuando haya runners disponibles.