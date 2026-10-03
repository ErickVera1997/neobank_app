# Arquitectura — Neobank

> Documento vivo. Describe componentes, flujos, supuestos, riesgos y la
> estrategia de escalamiento. Las decisiones puntuales se registran en
> [`decisions.md`](decisions.md).

## 1. Objetivo y restricciones

Construir una plataforma financiera digital **sin atención física**, que pueda
evolucionar hacia **múltiples dominios** administrados por equipos
independientes y que **personalice dinámicamente** la experiencia sin requerir
publicar una nueva versión de la app.

Restricciones del reto:

- La app debe ser **Flutter** (Android/iOS en esta entrega).
- Debe existir **evidencia de interacción real** con servicios y procesamiento
  dinámico (no solo datos simulados).
- Obligatorio demostrar comportamiento ante **conectividad limitada, alta
  latencia e indisponibilidad parcial**.

## 2. Contexto del sistema

```mermaid
flowchart LR
    subgraph Dispositivo["📱 Dispositivo (Android/iOS)"]
        App["App Flutter\n(Riverpod + go_router)"]
        Secure["Almacenamiento seguro\n(tokens)"]
        Cache["Caché local\n(respuestas)"]
        LocalNotif["Notificaciones locales"]
    end

    subgraph Backend["⚙️ Backend Dart (shelf + SQLite)"]
        API["API HTTP\nJWT + JSON"]
        Config["Configuración remota\n(flags · SDUI · ofertas)"]
        NotifSvc["Servicio de notificaciones\n+ gateway push"]
    end

    FX["🌐 Proveedor FX real\n(Frankfurter)"]
    Push["🔔 Relay push\n(FCM/APNs)"]

    App -->|HTTPS + JSON| API
    App --- Secure
    App --- Cache
    API --> FX
    API --> NotifSvc
    NotifSvc -->|webhook| Push
    Push -.->|push remoto| LocalNotif
```

## 3. Estructura del repositorio (monorepo)

```text
neobank_app/
├── apps/neobank_mobile/      # App Flutter — arquitectura feature-first
├── services/neobank_api/     # Backend Dart — API, persistencia y servicios
├── packages/neobank_core/    # Contratos compartidos (DTOs, Money, Result)
├── docs/                     # Arquitectura, decisiones, operación, IA, pruebas
└── .github/workflows/        # CI
```

La regla de dependencias es estricta:

```mermaid
flowchart TD
    Mobile["apps/neobank_mobile"] --> Core["packages/neobank_core"]
    Api["services/neobank_api"] --> Core
```

`neobank_core` no depende de Flutter ni del backend, lo que permite reutilizar
los contratos y evita acoplar la app a detalles de infraestructura.

## 4. Componentes de la app Flutter

```mermaid
flowchart TB
    subgraph UI["Capa de presentación (features/*/presentation)"]
        Screens["Pantallas y módulos\nde home dinámicos"]
    end
    subgraph State["Capa de estado (features/*/application)"]
        Controllers["Riverpod\nAsyncNotifier / Notifier\nFutureProvider"]
    end
    subgraph Data["Capa de datos (features/*/data)"]
        Repos["Repositorios por feature"]
    end
    subgraph Core["Core transversal"]
        ApiClient["ApiClient\n(reintentos · refresh · caché)"]
        Stores["TokenStore · CacheStore"]
        Net["Conectividad +\nsimulador de red"]
        Theme["Tema dinámico"]
    end

    Screens --> Controllers --> Repos --> ApiClient
    ApiClient --> Stores
    ApiClient --> Net
    Screens --> Theme
    Theme --> Controllers
```

Cada feature es **autónoma**: `auth`, `config`, `home`, `accounts`, `fx`,
`transfers`, `notifications`, `insights`, `assistant`, `profile`, `settings`.
La comunicación entre features ocurre sólo a través de providers públicos, no
de imports cruzados de UI.

### Motor de analítica y copiloto (backend)

```mermaid
flowchart LR
    Tx["transacciones\n(SQLite)"] --> Insights["InsightsService\nagregados + mensajes"]
    Insights --> Offers["Ofertas por\ncomportamiento"]
    Insights --> Assistant["AssistantService"]
    Fx["FxService\n(proveedor real)"] --> Assistant
    Assistant --> API["/assistant"]
    Insights --> API2["/insights"]
```

## 5. Flujos clave

### 5.1 Autenticación con refresh rotativo

```mermaid
sequenceDiagram
    participant U as Usuario
    participant App as App
    participant API as API

    U->>App: email + contraseña
    App->>API: POST /auth/login
    API-->>App: access (30 min) + refresh (30 días)
    App->>App: guarda tokens en Keychain/Keystore
    Note over App,API: Más tarde, el access expira
    App->>API: GET /accounts → 401
    App->>API: POST /auth/refresh (single-flight)
    API-->>App: nuevo par de tokens (rota el refresh)
    App->>API: reintenta GET /accounts
    API-->>App: 200 + datos
```

### 5.2 Home dirigido por el servidor (personalización)

```mermaid
sequenceDiagram
    participant App as App
    participant API as API
    App->>API: GET /config/bootstrap
    API->>API: segmento + feature flags
    API-->>App: flags + módulos (home) + ofertas + tema
    App->>App: renderiza módulos en el orden recibido
```

El backend decide **qué** se muestra y **en qué orden** (`heroBalance`,
`quickActions`, `fxWidget`, `promo`, `insights`, `offersCarousel`). Incorporar
una nueva experiencia = cambiar la configuración, no publicar la app.

### 5.3 Transferencia con notificación

```mermaid
sequenceDiagram
    participant App as App
    participant API as API
    participant DB as SQLite
    participant Push as Gateway push
    App->>API: POST /transfers
    API->>DB: BEGIN → débito + (crédito) + COMMIT
    API->>DB: inserta notificación
    API->>Push: envía push (best-effort)
    API-->>App: 201 + movimiento
    App->>App: invalida y refresca saldos/alertas
```

### 5.4 FX con degradación controlada

```mermaid
flowchart TD
    A["GET /fx/rates?base=USD"] --> B{"¿Caché vigente?"}
    B -->|sí| C["Responde (stale=false)"]
    B -->|no| D["Consulta proveedor real\n(timeout 8s)"]
    D -->|ok| E["Guarda caché y responde"]
    D -->|falla| F{"¿Hay caché previa?"}
    F -->|sí| G["Responde stale=true"]
    F -->|no| H["503 service_unavailable"]
```

### 5.5 Copiloto financiero

```mermaid
sequenceDiagram
    participant App as App
    participant API as API
    participant I as InsightsService
    participant FX as Proveedor FX
    App->>API: POST /assistant {"¿Cuánto gasté este mes?"}
    API->>I: agrega los movimientos del usuario
    I-->>API: totales y categorías reales
    API->>FX: (si el intent es conversión) tasas en vivo
    FX-->>API: tasas
    API-->>App: reply + tarjeta estructurada + sugerencias
```

## 6. Personalización y segmentación

| Mecanismo | Implementación | Sin publicar app |
| --- | --- | --- |
| Segmentos | `youth · standard · premium · pyme` en el usuario | ✅ |
| Feature flags | Tabla `feature_flags` filtrada por segmento | ✅ |
| Server-Driven UI | Lista ordenada de módulos de home | ✅ |
| Ofertas | Catálogo por segmento **+ generadas por comportamiento** | ✅ |
| Tema | Tokens de color/modo por segmento | ✅ |
| Experimentos | `experimentBucket` A/B en el bootstrap | ✅ |

## 7. Resiliencia ante red degradada

| Escenario | Comportamiento |
| --- | --- |
| Sin conexión (real o simulada) | Banner, lecturas desde caché con aviso, escrituras fallan con mensaje claro y son reintentables |
| Alta latencia | Timeouts configurables, skeletons/spinners, sin bloquear la UI |
| Fallos intermitentes | Reintentos con backoff exponencial (2 reintentos) para errores 5xx/red |
| Sesión expirada | Refresh automático *single-flight*; si falla, se limpia la sesión y se vuelve al login |
| Proveedor FX caído | Respuesta `stale=true` desde caché; la UI lo etiqueta |
| Backend caído | Datos cacheados visibles + acciones deshabilitadas con feedback |

El **simulador de red** (perfil → Simulador de red) permite demostrar todos los
escenarios en vivo: offline, latencia hasta 5 s y tasa de fallos.

## 8. Seguridad

- **Contraseñas**: PBKDF2-HMAC-SHA256, 120 000 iteraciones, salt aleatorio.
- **Sesión**: JWT HS256 (access, 30 min) + refresh opaco de 48 bytes,
  almacenado **hasheado** (SHA-256) y **rotado** en cada refresh.
- **Almacenamiento en el dispositivo**: tokens en Keychain (iOS) / Keystore
  (Android) vía `flutter_secure_storage`.
- **Superficie**: validación de entrada en el backend, autorización por
  propietario de la cuenta, errores sin filtrar detalles internos.
- **Producción** (fuera del alcance de la demo): TLS obligatorio, *certificate
  pinning*, rotación de `JWT_SECRET` por entorno, WAF y rate limiting.

## 9. Observabilidad (resumen)

Detalle en [`operations.md`](operations.md). En la app: logs de red en debug,
errores tipados (`AppErrorKind`) listos para reportar a un backend de crashes.
En el backend: `GET /health`, logging estructurado por request y errores no
controlados registrados con stack trace.

## 10. Supuestos

1. El usuario tiene conectividad intermitente pero no nula de forma permanente.
2. La app se distribuye por tiendas; el backend puede desplegarse en cualquier
   contenedor (Docker) o VM.
3. El proveedor FX es informativo (no ejecuta operaciones cambiarias).
4. Los datos de demo son sintéticos y no representan clientes reales.
5. La demo corre en un entorno controlado; TLS y secretos se gestionan en el
   ambiente real.

## 11. Riesgos técnicos y mitigaciones

| Riesgo | Impacto | Mitigación |
| --- | --- | --- |
| Proveedor FX con límites/caídas | Medio | Caché + stale + timeout + reintentos |
| Crecimiento del backend único | Medio | Rutas por dominio y repositorios desacoplados; listo para dividir en servicios |
| Deriva entre contratos app/backend | Alto | DTOs compartidos en `neobank_core` + pruebas de integración |
| Token expuesto en dispositivo comprometido | Alto | Almacenamiento seguro + refresh rotativo + revocación |
| Configuración remota inválida | Medio | El frontend valida/parsea defensivamente y usa valores por defecto |
| Base de datos SQLite como cuello de botella | Medio | Migrar a PostgreSQL/Cloud SQL manteniendo la interfaz de `Store` |

## 12. Estrategia de escalamiento

1. **Escala horizontal del backend**: el estado vive en la base de datos; el
   servicio es sin estado (JWT) → N réplicas detrás de un balanceador.
2. **Base de datos**: migrar SQLite → PostgreSQL cuando haya concurrencia de
   escritura; `Store` ya encapsula el SQL.
3. **Dominios como servicios**: `accounts`, `transfers`, `config`, `fx` ya
   están separados por handlers/repositorios; extraer cada uno a un servicio
   con su propia base es mecánico.
4. **Config remota como producto**: mover `feature_flags`/SDUI a un servicio de
   configuración versionada con auditoría.
5. **Equipos independientes**: cada feature de la app se puede extraer a un
   paquete Dart (`packages/feature_x`) con su propio pipeline, manteniendo el
   `neobank_core` como contrato.
6. **CDN/edge** para contenido estático de ofertas e imágenes.

## 13. Pruebas

Estrategia y comandos en [`testing.md`](testing.md): pirámide con unitarias
(core/backend/app), widgets y un flujo **E2E** crítico que además cubre el
copiloto.

## 14. Automatizaciones

| Automatización | Comando | Qué hace |
| --- | --- | --- |
| Atajos de desarrollo | `make help` | Instala, analiza, prueba, levanta y formatea |
| Smoke E2E del backend | `make smoke` | Levanta el server real en un puerto efímero y recorre login, cuentas, transferencia, insights, copiloto, home y FX en vivo |
| CI | `.github/workflows/ci.yml` | `analyze` + `test` de los 3 paquetes + job de smoke |
| E2E de la app | `make e2e` | Flujo login → home → copiloto → cuentas → movimientos |

El smoke test es la evidencia reproducible del funcionamiento del sistema con
**dependencias externas reales**.