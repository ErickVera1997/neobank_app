# Neobank — Plataforma financiera digital

Aplicación bancaria digital de nueva generación construida en **Flutter**, con
un **backend real en Dart** y una arquitectura modular preparada para
evolucionar hacia múltiples dominios administrados por equipos independientes.

> Reto técnico Senior Front-End. Toda la documentación está en [`docs/`](docs/).

## ✨ Capacidades

- **Onboarding y autenticación**: registro, login, OTP y restauración de sesión
  con refresh rotativo.
- **Cuentas**: saldo consolidado, detalle por cuenta y movimientos con
  paginación por cursor.
- **Personalización dinámica**: el backend define módulos del home, ofertas,
  feature flags y tema por **segmento** (Server-Driven UI).
- **Micro-app de divisas (FX)**: tasas reales de un proveedor externo, caché y
  respuesta *stale* si el proveedor falla.
- **Transferencias**: internas y a terceros, con notificación automática.
- **Notificaciones**: centro in-app + registro de dispositivo y notificaciones
  locales; gateway push desacoplado para FCM/APNs.
- **Resiliencia**: caché offline, reintentos con backoff, refresh automático y
  un **simulador de red** para demostrar degradación (offline/latencia/fallos).
- **Pruebas**: unitarias, de widgets y un flujo E2E crítico.

## 🧱 Estructura

```text
neobank_app/
├── apps/neobank_mobile/     # App Flutter (Android / iOS)
├── services/neobank_api/    # Backend Dart (shelf + SQLite + JWT)
├── packages/neobank_core/   # Contratos compartidos (DTOs, Money, Result)
├── docs/                    # Arquitectura, decisiones, operación, pruebas, IA
└── .github/workflows/       # CI
```

## ✅ Requisitos

- Flutter **3.47+** (Dart 3.13+)
- Xcode (iOS) y/o Android Studio (Android)
- No se requieren servicios de pago ni credenciales: el backend vive en el
  repo y la integración FX usa una API pública real.

## 🚀 Puesta en marcha

### 1. Backend

```bash
cd services/neobank_api
dart pub get
dart run bin/server.dart
# → http://localhost:8080
```

Variables de entorno opcionales: `PORT`, `DB_PATH`, `JWT_SECRET`,
`FX_BASE_URL`, `PUSH_WEBHOOK_URL`, `ENV`.

### 2. App Flutter

```bash
cd apps/neobank_mobile
flutter pub get

# Android emulator (host = 10.0.2.2)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080

# iOS simulator (host = localhost)
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

### Usuario demo

| Email | Contraseña |
| --- | --- |
| `ana@neobank.com` | `Password123` |

También puedes registrarte: se crea una cuenta con un bono de bienvenida.

## 🧪 Pruebas

```bash
# Contratos
cd packages/neobank_core && dart test

# Backend (SQLite en memoria)
cd services/neobank_api && dart test

# App (unit + widgets)
cd apps/neobank_mobile && flutter test

# E2E crítico (requiere un emulador/simulador)
cd apps/neobank_mobile
flutter test integration_test/app_e2e_test.dart -d <device-id>
```

Detalle de la estrategia y escenarios cubiertos: [`docs/testing.md`](docs/testing.md).

## 🌐 Comportamiento degradado (demostración)

Perfil → **Simulador de red**:

- **Modo offline** → datos desde caché + banner superior.
- **Latencia** (hasta 5 s) → estados de carga visibles.
- **Tasa de fallos** → reintentos automáticos con backoff.
- **Restaurar** → la app se recupera sin reiniciar.

## 📚 Documentación

| Documento | Contenido |
| --- | --- |
| [`docs/architecture.md`](docs/architecture.md) | Componentes, flujos, supuestos, riesgos y escalamiento |
| [`docs/decisions.md`](docs/decisions.md) | ADRs: problema, alternativas, trade-offs e impacto |
| [`docs/operations.md`](docs/operations.md) | Despliegue, observabilidad, SLOs y runbook |
| [`docs/testing.md`](docs/testing.md) | Pirámide de pruebas y escenarios de degradación |
| [`docs/ai-usage.md`](docs/ai-usage.md) | Uso de IA y su impacto |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Trunk Based Development y Conventional Commits |

## 🤖 Desarrollo asistido por IA

El repositorio incluye la configuración del plugin oficial de Dart/Flutter para
agentes ([`flutter/agent-plugins`](https://github.com/flutter/agent-plugins)):
25 skills en `.agents/skills`, MCP de Dart en `.opencode`/`.vscode` y reglas en
`AGENTS.md`. Ver [`docs/ai-usage.md`](docs/ai-usage.md).

## 📄 Licencia

Uso exclusivo para evaluación técnica.