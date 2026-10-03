# Neobank — Digital Banking Platform

Plataforma financiera digital de nueva generación construida en **Flutter**,
con un backend real en **Dart** y una arquitectura modular preparada para
evolucionar hacia múltiples dominios funcionales administrados por equipos
independientes.

> Reto técnico Senior Front-End. Ver `docs/` para arquitectura, decisiones
> (ADRs), estrategia de despliegue y operación.

## Estructura del repositorio

```
neobank_app/
├── apps/
│   └── neobank_mobile/     # App Flutter (Android / iOS) — Riverpod + features
├── services/
│   └── neobank_api/        # Backend Dart (shelf) + SQLite + JWT
├── packages/
│   └── neobank_core/       # Contratos, modelos y utilidades compartidas
├── docs/                   # Arquitectura, ADRs, runbook, IA
└── .github/workflows/      # CI
```

## Requisitos

- Flutter **3.47+** (Dart 3.13+)
- Xcode / Android Studio para emuladores
- No se requieren servicios externos de pago: el backend es parte del repo y la
  integración FX usa una API pública real (Frankfurter).

## Puesta en marcha rápida

```bash
# 1) Backend (puerto 8080)
cd services/neobank_api
dart pub get
dart run bin/server.dart

# 2) App Flutter
cd apps/neobank_mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator
# iOS simulator: --dart-define=API_BASE_URL=http://localhost:8080
```

Usuario demo: `ana@neobank.com` / `Password123`.

Ver `README` por componente y `docs/` para el detalle.

## Versionamiento

**Trunk Based Development**: rama `main` siempre desplegable, commits pequeños
y frecuentes, integración continua en cada push.

## Licencia

Uso exclusivo para evaluación técnica.
