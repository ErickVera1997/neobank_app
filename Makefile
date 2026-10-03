# Neobank — atajos de desarrollo
#
# Uso rápido:
#   make setup     # instala dependencias de los 3 paquetes
#   make api       # levanta el backend en :8080
#   make app       # ejecuta la app Flutter
#   make ci        # analyze + tests + smoke

.PHONY: help setup analyze test smoke api app e2e format ci

help:
	@echo "Neobank — objetivos disponibles:"
	@echo "  setup     Instala dependencias (core, api, app)"
	@echo "  analyze   Analiza los 3 paquetes"
	@echo "  test      Ejecuta todas las pruebas unitarias y de widgets"
	@echo "  smoke     Smoke test E2E del backend (incluye FX en vivo)"
	@echo "  api       Levanta el backend en http://localhost:8080"
	@echo "  app       Ejecuta la app Flutter"
	@echo "  e2e       Flujo E2E de la app (requiere dispositivo/emulador)"
	@echo "  format    Formatea el código Dart"
	@echo "  ci        analyze + test + smoke"

setup:
	cd packages/neobank_core && dart pub get
	cd services/neobank_api && dart pub get
	cd apps/neobank_mobile && flutter pub get

analyze:
	cd packages/neobank_core && dart analyze
	cd services/neobank_api && dart analyze
	cd apps/neobank_mobile && flutter analyze

test:
	cd packages/neobank_core && dart test
	cd services/neobank_api && dart test
	cd apps/neobank_mobile && flutter test

smoke:
	cd services/neobank_api && dart run tool/smoke.dart

api:
	cd services/neobank_api && dart run bin/server.dart

app:
	cd apps/neobank_mobile && flutter run

e2e:
	cd apps/neobank_mobile && flutter test integration_test/app_e2e_test.dart

format:
	dart format packages/neobank_core/lib packages/neobank_core/test \
		services/neobank_api/lib services/neobank_api/bin services/neobank_api/test services/neobank_api/tool \
		apps/neobank_mobile/lib apps/neobank_mobile/test apps/neobank_mobile/integration_test

ci: analyze test smoke