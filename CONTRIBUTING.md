# Contribuir a Neobank

## Modelo de ramas (Trunk Based Development)

- `main` es la **única** rama de larga vida y debe estar siempre desplegable.
- Trabajos pequeños: commit directo a `main` (o PR de vida corta, < 1 día).
- Trabajos grandes: se integran de forma incremental detrás de **feature
  flags** (`feature_flags` en el backend), evitando ramas largas.
- Ante un problema en producción: se revierte por commit y/o se desactiva la
  flag. Nunca se “arregla con ramas”.

## Convención de commits (Conventional Commits)

Formato:

```text
<tipo>(<alcance>): <descripción en imperativo>

[cuerpo opcional]

[footer opcional]
```

Tipos permitidos:

| Tipo | Uso |
| --- | --- |
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de bug |
| `refactor` | Cambio interno sin alterar comportamiento |
| `test` | Añadir o corregir pruebas |
| `docs` | Documentación |
| `chore` | Mantenimiento, dependencias, scaffolding |
| `ci` | Integración continua |
| `perf` | Mejora de rendimiento |

Alcances usados: `api`, `app`, `core`, `docs`.

Ejemplos reales del historial:

```text
feat(api): expose banking, FX, personalization and notification endpoints
feat(app): onboarding, dynamic home, accounts, FX, transfers and alerts
test(app): cover HTTP resilience, widgets and the critical E2E flow
docs: add architecture, ADR, operations and AI-usage guides
```

Reglas:

1. Commits **pequeños y atómicos**: una unidad lógica por commit.
2. No se commitea con `analyze` o pruebas en rojo.
3. El mensaje explica el *porqué* en el cuerpo cuando no es obvio.

## Checklist antes de commitear

```bash
dart format .                       # en cada paquete (ver nota)
dart analyze                        # core y api
flutter analyze                     # app
dart test                           # core y api
flutter test                        # app
```

> La app usa `require_trailing_commas`; deja que `dart format` ordene el código
> con comas finales y evita diffs ruidosos.

## Definición de terminado

- [ ] La funcionalidad respeta la **regla de dependencias** (`feature →
      core`, nunca UI de una feature importando la UI de otra).
- [ ] `analyze` limpio y pruebas existentes en verde.
- [ ] Nueva lógica relevante con prueba (unitaria, widget o integración).
- [ ] Si cambia comportamiento ante red degradada, se documenta en
      `docs/operations.md`.
- [ ] Si es una decisión arquitectónica, se añade un ADR en
      `docs/decisions.md`.
- [ ] Documentación actualizada (README/`docs/`).

## Configuración local

1. Instala Flutter 3.47+ (ver README).
2. Prepara el entorno de IA (opcional): abre la carpeta del proyecto en
   OpenCode; MCP, skills y reglas se detectan desde la configuración del repo.
3. Ejecuta backend y app según el README.

## Estilo

- Dart/Flutter idiomático; comillas simples; comas finales.
- Nombres en inglés para código; español para textos de usuario.
- Errores de dominio con `AppException` (app) y `ApiException` (backend).
- Nada de secretos en el repositorio.