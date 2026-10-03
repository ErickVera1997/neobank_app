# Registro de Decisiones de Arquitectura (ADR)

Cada decisión usa el formato exigido: **Problema → Alternativas evaluadas →
Opción seleccionada → Trade-offs → Impacto a largo plazo**.

---

## ADR-001 · Backend propio en Dart dentro del repositorio

**Problema.** El reto exige evidencia de interacción real con servicios y
procesamiento dinámico, pero no provee credenciales ni un backend.

**Alternativas evaluadas.**
1. **Firebase** (Auth + Firestore + FCM): real, pero acopla el resultado a una
   cuenta externa y oculta parte de la lógica de negocio.
2. **BaaS de terceros / API pública financiera**: rápido, pero con datos
   limitados y sin control del modelo de dominio.
3. **Backend propio en el repo**: API real, persistencia y reglas de negocio
   versionadas y reproducibles.

**Opción seleccionada.** Backend **Dart + shelf + SQLite** con JWT,
feature flags y proxy FX real.

**Trade-offs.** Más código y más superficie que Firebase, y un solo nodo de
base de datos. A cambio: cero dependencias externas para reproducir la demo,
propiedad total del dominio y portabilidad (Docker).

**Impacto a largo plazo.** `Store` encapsula el SQL → migrar a PostgreSQL es
local. Los handlers ya están separados por dominio, lo que habilita extraer
servicios por equipo sin reescribir contratos.

---

## ADR-002 · Riverpod como gestión de estado

**Problema.** La personalización dinámica y la resiliencia requieren estado
derivado, invalidación selectiva y testeo sin `BuildContext`.

**Alternativas evaluadas.**
1. **BLoC**: explícito y probado, pero verboso para un entregable individual.
2. **Provider**: simple, pero se queda corto para estado asíncrono derivado.
3. **Riverpod**: providers componibles, asíncronos y testeables sin `context`.

**Opción seleccionada.** **Riverpod 3** (`AsyncNotifier`, `Notifier`,
`FutureProvider`).

**Trade-offs.** Curva de aprendizaje y una API que evolucionó entre versiones
mayores. A cambio: dependencias explícitas entre features, overrides triviales
en pruebas e invalidación precisa tras una transferencia.

**Impacto a largo plazo.** Los providers son el contrato entre features; un
equipo puede reemplazar su capa de estado sin tocar a los demás. Los overrides
facilitan pruebas de widget y E2E sin backend.

---

## ADR-003 · Server-Driven UI para el home y la personalización

**Problema.** Lanzar experiencias nuevas sin publicar la app y adaptar la
experiencia a segmento, comportamiento o preferencias.

**Alternativas evaluadas.**
1. **Hardcodear el home**: simple pero exige release por cada cambio.
2. **Remote config de flags** (mostrar/ocultar): útil, pero el orden y la
   composición siguen en el cliente.
3. **Server-Driven UI**: el backend devuelve una lista ordenada de módulos con
   configuración; el cliente mapea tipos conocidos.

**Opción seleccionada.** **SDUI** con tipos de módulo (`heroBalance`,
`quickActions`, `fxWidget`, `promo`, `insights`, `offersCarousel`) +
**feature flags por segmento** + tokens de tema remotos.

**Trade-offs.** El cliente debe tolerar módulos desconocidos (fallback
`custom`); mayor disciplina de contrato. A cambio: experimentación sin release
y composición por segmento.

**Impacto a largo plazo.** Base para un CMS de producto y experimentación A/B
gestionada por negocio; escalable a componentes visuales versionados.

---

## ADR-004 · Persistencia SQLite en el backend

**Problema.** Necesitamos persistencia real y migraciones reproducibles para la
demo, sin depender de infraestructura externa.

**Alternativas evaluadas.**
1. **PostgreSQL**: ideal en producción, pero exige un contenedor/servicio.
2. **En memoria**: no permite demostrar persistencia real.
3. **SQLite**: archivo local, transaccional, portable y con SQL estándar.

**Opción seleccionada.** **SQLite** con migraciones idempotentes y acceso
encapsulado en `Store`.

**Trade-offs.** Escritura concurrente limitada; no apto para múltiples nodos.
A cambio: reproducibilidad total y foco en el dominio.

**Impacto a largo plazo.** La interfaz de `Store` aísla el motor; el salto a
PostgreSQL es una capa de adaptación, no un rediseño.

---

## ADR-005 · JWT corto + refresh opaco rotativo

**Problema.** Autenticación stateless en el backend y sesiones duraderas en el
dispositivo sin comprometer seguridad.

**Alternativas evaluadas.**
1. **Sesiones en servidor**: revocables al instante, requieren estado.
2. **JWT de larga duración**: simple, pero difícil de revocar.
3. **JWT corto + refresh rotativo persistido (hasheado)**: stateless para
   tráfico normal, con revocación efectiva del refresh.

**Opción seleccionada.** Access JWT HS256 (30 min) + refresh opaco (30 días)
almacenado **hasheado** y **rotado** en cada uso; logout revoca.

**Trade-offs.** Más pasos de protocolo y clientes con manejo de concurrencia
(resuelto con *single-flight*). A cambio: ventana de exposición corta y
revocación real.

**Impacto a largo plazo.** Compatible con múltiples dispositivos y con
migración a un proveedor de identidad (OIDC) sin cambiar el contrato de la app.

---

## ADR-006 · FX a través del backend con caché y *stale-while-error*

**Problema.** Integrar un servicio externo real sin que su disponibilidad ni
su latencia degraden la app.

**Alternativas evaluadas.**
1. **Llamar al proveedor desde la app**: menos saltos, pero expone claves,
   mezcla CORS/red del dispositivo y no centraliza caché.
2. **Backend sin caché**: simple, pero cada fallo del proveedor rompe la UX.
3. **Backend con caché y fallback stale**: el proveedor es una dependencia
   tolerada; la app nunca se bloquea si hay datos previos.

**Opción seleccionada.** **Proxy en el backend** (Frankfurter) con TTL de 15
min, timeout de 8 s y respuesta `stale=true` desde caché ante fallo; `503` sólo
si no hay caché.

**Trade-offs.** Datos potencialmente desactualizados (mitigado etiquetándolos
en la UI) y un salto extra de red. A cambio: resiliencia, control y
observabilidad de la dependencia.

**Impacto a largo plazo.** El patrón se reutiliza para cualquier integración
externa (pagos, scoring, marketplace) como `Adapter + Cache + Fallback`.

---

## ADR-007 · Notificaciones: centro in-app + gateway push desacoplado

**Problema.** Notificar a los clientes sin atar la demo a una cuenta de
Firebase/APNs, pero dejando el camino real preparado.

**Alternativas evaluadas.**
1. **FCM/APNs directo**: real, requiere credenciales y configuración de
   plataforma que no se pueden versionar.
2. **Solo in-app**: sin dependencias, pero no demuestra el canal push.
3. **Gateway desacoplado**: el backend persiste la notificación y la envía a un
   `PushGateway`; por defecto *noop* y en producción un webhook hacia el relay
   FCM/APNs. La app registra su token de dispositivo y usa notificaciones
   locales para la demo.

**Opción seleccionada.** **`PushGateway`** (interfaz) + registro de
dispositivo real (`POST /devices`) + notificaciones locales configurables con
`flutter_local_notifications`. Con `PUSH_WEBHOOK_URL` el envío deja de ser
noop.

**Trade-offs.** El push remoto extremo a extremo requiere configurar el relay.
A cambio: la demo funciona sin credenciales y el punto de extensión es una
variable de entorno.

**Impacto a largo plazo.** Cambiar de proveedor push no toca el dominio; sólo
se implementa otro `PushGateway`.

---

## ADR-008 · Arquitectura feature-first por capas livianas

**Problema.** Organizar el código para varios dominios y equipos sin la
ceremonia de una Clean Architecture completa.

**Alternativas evaluadas.**
1. **Clean Architecture canónica** (domain/data/presentation global): rigurosa,
   pero con mucho *boilerplate* para el plazo.
2. **Por tipo** (`models/`, `services/`…): sencilla, pero no escala a equipos.
3. **Feature-first con capas internas** (`data` / `application` /
   `presentation`): aislamiento por dominio y menos ceremonia.

**Opción seleccionada.** **Feature-first**: cada feature expone providers;
los DTOs y utilidades compartidas viven en `neobank_core`.

**Trade-offs.** Menos pureza de capas (no hay entidades de dominio separadas de
los DTOs). A cambio: velocidad, claridad y rutas de extracción a paquetes.

**Impacto a largo plazo.** Un equipo = una carpeta de feature; extraer a
`packages/feature_x` es un movimiento mecánico.

---

## ADR-009 · Trunk Based Development con Conventional Commits

**Problema.** El reto exige Trunk Based Development y un historial de calidad.

**Alternativas evaluadas.**
1. **GitFlow**: ramas largas, poco compatible con integración frecuente.
2. **Feature branches largas**: riesgo de *merge hell*.
3. **TBD**: `main` siempre desplegable, commits pequeños y frecuentes.

**Opción seleccionada.** **TBD** en `main` + **Conventional Commits**
(`feat`, `fix`, `test`, `docs`, `chore`, `ci`), verificado por CI.

**Trade-offs.** Exige disciplina de commits atómicos y *feature flags* para
trabajo incompleto. A cambio: integración continua real e historial legible.

**Impacto a largo plazo.** Base para CI/CD con releases frecuentes y *rollback*
por commit.

---

## ADR-010 · E2E con backend simulado a nivel HTTP

**Problema.** Un E2E de UI necesita determinismo y no puede depender de un
servidor levantado a mano ni de credenciales de plataforma.

**Alternativas evaluadas.**
1. **E2E contra backend real en dispositivo**: máxima fidelidad, frágil y lento
   en CI (requiere red y datos sembrados).
2. **E2E con mocks en la capa de repositorios**: rápido, pero no ejercita
   serialización ni el stack HTTP.
3. **E2E con un `HttpClientAdapter` falso**: se mantiene el 100 % del código
   real (Dio, ApiClient, repos, Riverpod, UI) y sólo se sustituye el transporte.

**Opción seleccionada.** **Adaptador HTTP falso** con respuestas del backend
contrato. Complementado por las pruebas de integración del backend real
(`dart test`) que sí validan SQLite, JWT y el flujo HTTP completo.

**Trade-offs.** No valida el TLS ni la red física. A cambio: E2E estable,
rápido y ejecutable en cualquier emulador/CI, más fidelidad que un mock de
repositorio.

**Impacto a largo plazo.** El mismo patrón permite *contract tests*: el
adaptador puede alimentarse desde grabaciones del backend real.

---

## ADR-011 · Copiloto financiero determinista (con extensión a LLM)

**Problema.** Ofrecer asistencia avanzada dentro de la app sin atar la demo a
credenciales, coste o latencia de un proveedor de LLM, y sin sacrificar la
exactitud de la información financiera.

**Alternativas evaluadas.**
1. **LLM externo directo**: conversación fluida, pero requiere API key, coste
   por token, latencia variable y riesgo de respuestas incorrectas sobre dinero.
2. **RAG clásico (LLM + datos)**: mejor precisión, pero añade vector store e
   infraestructura no justificada para un alcance acotado.
3. **Motor determinista de intención sobre datos reales**: respuestas exactas,
   sin coste, auditables y con latencia mínima. La redacción es menos libre.

**Opción seleccionada.** **Motor determinista** (`AssistantService`): detecta
intención, agrega los datos reales del usuario (o consulta FX en vivo) y
devuelve texto + tarjetas estructuradas. Se deja preparado el punto de
extensión para delegar redacción/clasificación a un LLM.

**Trade-offs.** Menor flexibilidad conversacional ante preguntas fuera del
catálogo (responderá con ayuda). A cambio: cero coste, respuestas verificables
y ninguna dependencia externa obligatoria.

**Impacto a largo plazo.** Un LLM puede incorporarse más adelante como capa de
*NLU/redacción* manteniendo el mismo contrato (`AssistantAnswer`), los mismos
datos y las mismas pruebas; el riesgo se concentra en la capa que se puede
apagar con una flag.

---

## ADR-012 · Automatización con smoke test E2E del backend

**Problema.** El reto pide evidenciar interacción real y automatizaciones, pero
un E2E completo depende de red, credenciales y despliegues.

**Alternativas evaluadas.**
1. **Solo tests unitarios/integración**: rápidos, pero no recorren el servidor
   HTTP real ni el proveedor externo.
2. **E2E manual documentado**: evidencia débil y no reproducible.
3. **Smoke script que levanta el servidor real en proceso** (SQLite en memoria,
   puerto efímero) y recorre los flujos por HTTP, incluido el proveedor FX.

**Opción seleccionada.** `services/neobank_api/tool/smoke.dart`, expuesto como
`make smoke` y como job de CI. El chequeo de FX es tolerante a entornos sin
salida a Internet (advertencia, no fallo).

**Trade-offs.** El resultado del proveedor externo no es determinista; se
mitiga validando estructura y degradación en lugar de un valor fijo. A cambio:
un comando reproduce la evidencia completa en cualquier máquina.

**Impacto a largo plazo.** El mismo script sirve para validar *staging*
cambiando `FX_BASE_URL` y es la base para *contract tests* y *synthetic
monitoring* en producción (ver `operations.md`).