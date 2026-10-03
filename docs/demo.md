# Guion de demostración

Guía paso a paso para probar la app y verificar los criterios del reto.

## 0. Preparación

```bash
# Terminal 1 — backend
make api              # → http://localhost:8080

# Terminal 2 — app
make app              # la URL del backend se detecta por plataforma
# Android emulator → 10.0.2.2 · iOS/macOS → localhost
# Opcional: flutter run --dart-define=API_BASE_URL=http://host:8080
```

Usuario demo: **ana@neobank.com / Password123** (segmento *premium*).
También puedes crear una cuenta nueva desde *Crear cuenta* para ver la
experiencia de onboarding y elegir otro segmento.

Verificación técnica rápida (sin levantar nada): `make ci`
(analyze + 47 tests + smoke test con FX en vivo).

---

## 1. Onboarding y autenticación

1. Abre la app → pantalla de login.
2. Prueba **Crear cuenta** (nombre, email, contraseña ≥ 8 caracteres, segmento).
   - ✅ Se crea la cuenta con **bono de bienvenida** y entra directo al home.
3. Cierra sesión (Perfil → Cerrar sesión) y entra con el usuario demo.
4. Alternativa: **Ingresar con código OTP** → "Enviar código" muestra el
   `devCode` (solo en entorno development) y permite verificar.

**Criterio:** onboarding funcional, validaciones visibles, sesión persistida
(cierra y reabre la app: sigue logueado).

## 2. Home personalizado (Server-Driven UI)

Observa el orden de los módulos: **saldo → acciones rápidas → copiloto →
promoción → divisas → portafolio → insights → ofertas**.

- El módulo *Adelanta tu salario* solo aparece para segmento **premium**.
- Registra un usuario **joven** o **pyme** y compara: cambian módulos, ofertas y
  color de tema (todo definido por el backend).
- Pull-to-refresh para recargar la configuración.

**Criterio:** la experiencia se compone dinámicamente según segmento, sin
publicar nueva versión de la app.

## 3. Copiloto financiero (bonus de asistencia)

Entra desde el módulo del copiloto, el tab de acciones rápidas o el chip de una
oferta. Prueba:

| Pregunta | Qué responde |
| --- | --- |
| *¿Cuál es mi saldo?* | Saldo consolidado real + tarjeta |
| *¿Cuánto gasté este mes?* | Gasto, ingreso y balance del mes |
| *¿Cuánto gasté en supermercado?* | Gasto por categoría con % real |
| *¿Cuánto es 100 USD en EUR?* | Conversión con tasa **en vivo** |
| *Muéstrame mis últimos movimientos* | Últimos 5 movimientos reales |
| *¿Cómo van mis ahorros?* | Saldo de cuentas de ahorro |
| *Muéstrame mi análisis del mes* | Resumen de insights |

**Criterio:** las respuestas se calculan con los movimientos reales del usuario
y con el proveedor FX; no hay respuestas predefinidas.

## 4. Análisis generado dinámicamente (bonus)

Desde *Insights del mes* → **Ver análisis completo** (o pestaña del copiloto →
"Ver análisis"):

- Gasto del mes, ingresos, balance y **tasa de ahorro**.
- **Descubrimientos** generados (mayor gasto, tendencia vs. mes anterior, tasa
  de ahorro, comercio frecuente) con CTA que abre el copiloto.
- **Gasto por categoría** con barras y **comercios frecuentes**.

**Criterio:** los textos y métricas se generan del comportamiento real; si
haces una transferencia y refrescas, cambian.

## 5. Micro-app de divisas (integración externa)

- Tab **Divisas** → convierte 100 USD → EUR (tasa real de Frankfurter).
- Abre el widget del home para ver la tasa del día.
- Con el proveedor caído (simulador de red al 100% de fallos) la tarjeta de
  tasas muestra "desactualizado" si había caché, o un mensaje claro si no.

**Criterio:** integración real + degradación controlada con caché.

## 6. Cuentas, movimientos y transferencia

1. Tab **Cuentas** → abre *Cuenta principal*.
2. Desplázate y usa **Cargar más** (paginación por cursor).
3. **Transferir** (acción rápida o botón del detalle):
   - Interna: de *Cuenta principal* a *Ahorros viaje*.
   - A terceros: escribe un beneficiario.
4. ✅ Verás un snackbar de éxito; el saldo se actualiza y aparece una
   **notificación** en el tab *Alertas*.

**Criterio:** flujo transaccional real, actualización de estado y notificación.

## 7. Resiliencia ante red degradada (demostración clave)

Perfil → **Simulador de red**:

1. **Modo offline** → vuelve al home: banner superior y datos desde caché
   (etiqueta "Mostrando datos guardados"). Intenta transferir → error claro.
2. **Latencia 3 s** → aparecen estados de carga sin bloquear la UI.
3. **Fallos 50%** → observa reintentos automáticos (las pantallas se recuperan).
4. **Restaurar red** → todo vuelve a la normalidad sin reiniciar la app.

**Criterio:** estados de carga, reintentos, caché y recuperación demostrables.

## 8. Notificaciones, perfil y cierre

- Tab **Alertas**: marca como leídas (el badge del home se actualiza).
- Perfil: segmento, experimento A/B, limpiar caché, cerrar sesión.
- El backend registra el dispositivo al entrar (`POST /devices`) y genera una
  notificación por cada transferencia.

---

## Cambios acotados que pueden pedirse en la demo

| Petición | Dónde se resuelve |
| --- | --- |
| "Quita un módulo del home" | `config_handler.dart` → `_buildHome` o la feature flag en `seed.dart` |
| "Cambia el orden de los módulos" | `priority` del `HomeModule` |
| "Agrega una categoría al copiloto" | `_detectCategory` en `assistant_service.dart` |
| "Cambia la tasa de ahorro mínima" | umbral en `insights_service.dart` |
| "Apunta a otro proveedor FX" | `FX_BASE_URL` (env) |
| "Sube el timeout/reintentos" | `ApiClient._maxRetries` y `AppConfig.requestTimeout` |
| "Agrega una prueba del nuevo caso" | `*_test.dart` correspondiente |

## Verificación automatizada

```bash
make ci          # analyze + tests + smoke
# Smoke test por separado (levanta el servidor y llama al FX real):
cd services/neobank_api && dart run tool/smoke.dart
```