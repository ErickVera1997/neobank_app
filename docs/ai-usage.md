# Uso de IA en el desarrollo

> Requisito del reto: documentar cómo se usaron herramientas de IA y cuál fue
> su impacto en productividad, calidad, documentación y pruebas.

## 1. Herramientas y configuración

- **OpenCode** como agente de desarrollo en terminal (compositor de cambios,
  ejecución de comandos y generación de código).
- **Plugin oficial de Dart y Flutter** para agentes
  ([`flutter/agent-plugins`](https://github.com/flutter/agent-plugins) +
  [`dart-lang/skills`](https://github.com/dart-lang/skills)) con tres piezas:
  - **Skills** (25): guías procedimentales cargadas bajo demanda
    (`flutter-apply-architecture-best-practices`,
    `flutter-setup-declarative-routing`, `dart-run-static-analysis`,
    `flutter-add-widget-test`, `flutter-add-integration-test`…).
  - **MCP server oficial de Dart** (`dart mcp-server`): análisis en vivo,
    resolución de símbolos, ejecución de pruebas, hot reload y acceso al Dart
    Tooling Daemon desde el agente.
  - **Reglas** (`AGENTS.md`): hot reload/restart proactivo al editar `lib/` y
    uso de `--print-dtd` al lanzar apps.
- **Modelo**: DeepSeek V4.1 Flash vía OpenCode.

## 2. Cómo se usó (ejemplos concretos)

| Área | Uso | Evidencia en el repo |
| --- | --- | --- |
| Arquitectura | Definición del monorepo, contratos y ADRs | `docs/architecture.md`, `docs/decisions.md` |
| Contratos | DTOs compartidos app/backend | `packages/neobank_core` |
| Backend | Rutas, seguridad, SQLite y servicios | `services/neobank_api` |
| App | Features, tema, enrutado, resiliencia | `apps/neobank_mobile/lib/src` |
| Pruebas | Unitarias, widgets y E2E | `*_test.dart`, `integration_test/` |
| Revisión | `dart analyze` + `flutter analyze` + test como red de seguridad | CI |
| Documentación | README, ADRs, runbook y este documento | `docs/` |

### Skills aplicadas (ejemplos)

- **`dart-run-static-analysis`**: fijó el ciclo “cambiar → `analyze` → `fix` →
  test” que se usó en cada unidad de trabajo.
- **`flutter-apply-architecture-best-practices`**: guió la separación
  UI/lógica/datos y la regla de dependencia hacia `neobank_core`.
- **`flutter-setup-declarative-routing`**: base para el `GoRouter` con
  `redirect` según sesión.
- **`flutter-add-widget-test` / `flutter-add-integration-test`**: estructura de
  las pruebas de widget y del flujo E2E.
- **MCP `dart mcp-server`**: `analyze_files`, `run_tests` y `pub` integrados en
  el ciclo del agente; `hot_reload`/`dtd` disponibles para iterar en caliente.

## 3. Impacto medido (cualitativo)

### Productividad

- El andamiaje del monorepo (app + backend + paquete compartido) y las
  dependencias se resolvieron en minutos, incluida la resolución de conflictos
  de versiones entre plugins.
- Los commits pequeños (Conventional Commits) se generaron a medida que cada
  unidad quedaba verde, sin una sesión de “limpieza” final.
- El agente detectó y corrigió errores en cadena: tipos no exhaustivos de Dio,
  lints nuevos de Flutter, conflictos de `widget`/`cv`, un bug real en el
  generador de refresh tokens (`base64` con bytes fuera de rango).

### Calidad

- **Ninguna unidad se commiteó sin `analyze` limpio y pruebas en verde.**
- La IA escribió pruebas *antes* de dar por buena una funcionalidad en varios
  casos (cliente HTTP con fallos simulados, FX con proveedor caído, login).
- El bug de `base64` fue descubierto por las **pruebas de integración**, no por
  revisión manual: evidencia del retorno de la IA en calidad.

### Documentación

- Los ADRs, el runbook y la arquitectura se generaron a partir de las mismas
  decisiones tomadas durante la implementación, evitando documentación
  desincronizada.

### Pruebas

- 12 pruebas en `neobank_core`, **30 en el backend** y 14 en la app (incluido el
  E2E), todas ejecutables sin credenciales externas.
- El **smoke test** (`make smoke`) se usó como verificación de cierre de cada
  incremento del bonus: levanta el servidor real y valida el flujo completo.

### Bonus acelerados con IA

- **Motor de insights** (agregados, mensajes y ofertas por comportamiento) y
  **copiloto financiero** (detección de intención, tarjetas estructuradas)
  se diseñaron e implementaron en una sola iteración, con 8 pruebas nuevas
  derivadas de los escenarios que la IA propuso y el humano validó.
- **Automatizaciones**: el smoke test E2E, el `Makefile` y el job de CI se
  generaron y verificaron ejecutándose de verdad contra el proveedor FX.

## 4. Guardias y verificación humana

- **La IA propone, los tests disponen**: cada afirmación se valida con
  `analyze`/tests; nada se acepta “porque compila”.
- **Contratos explícitos**: los DTOs compartidos y las rutas centralizadas
  (`ApiPaths`) evitan que el agente invente interfaces.
- **Revisión de diffs** y commits atómicos por unidad lógica.
- **Secretos**: nunca se piden ni se escriben en el repositorio; el
  almacenamiento de tokens usa Keychain/Keystore.

## 5. Límites encontrados

- Los lints más recientes de Flutter/Dart introducen ruido; se desactivaron de
  forma explícita y justificada en `analysis_options.yaml`.
- La IA no puede ejecutar un E2E en un dispositivo físico sin firma; se optó
  por un simulador + adaptador HTTP falso (ver ADR-010).
- Las decisiones de producto (segmentos, ofertas, alcance) requieren criterio
  humano; la IA aceleró su implementación, no su priorización.

## 6. Recomendaciones para el equipo

1. Mantener las **skills** versionadas en `.agents/skills` (ya en el repo) para
   que todo el equipo use las mismas recetas.
2. Exigir en CI el mismo trío que usó el agente: `analyze` + `test` + build.
3. Usar el **MCP de Dart** en el IDE para que el agente vea errores/runtime
   reales en lugar de suposiciones.
4. Registrar nuevas decisiones como ADR en el momento, no al final.