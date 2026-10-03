import 'dart:io';

import 'package:neobank_api/src/api/router.dart';
import 'package:neobank_api/src/app.dart';
import 'package:neobank_api/src/config.dart';
import 'package:neobank_api/src/data/seed.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main(List<String> args) async {
  final config = AppConfig.fromEnvironment();
  final app = AppContainer.create(config);
  final handler = buildHandler(app);

  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    config.port,
  );
  server.autoCompress = true;

  stdout
    ..writeln('Neobank API escuchando en '
        'http://${server.address.address}:${server.port} '
        '(env=${config.environment})')
    ..writeln('Usuario demo: ${SeedData.demoEmail} / ${SeedData.demoPassword}');

  Future<void> shutdown() async {
    stdout.writeln('Apagando...');
    await server.close(force: true);
    app.dispose();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) => shutdown());
  ProcessSignal.sigterm.watch().listen((_) => shutdown());
}
