/// Backend de Neobank expuesto como librería para pruebas e integración.
library;

export 'src/api/router.dart' show buildHandler;
export 'src/app.dart';
export 'src/config.dart';
export 'src/data/database.dart';
export 'src/data/seed.dart';
export 'src/data/store.dart';
export 'src/domain/errors.dart';
export 'src/security/password_hasher.dart';
export 'src/security/token_service.dart';
export 'src/services/assistant_service.dart';
export 'src/services/fx_service.dart';
export 'src/services/insights_service.dart';
export 'src/services/notification_service.dart';
