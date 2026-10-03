import 'package:shelf/shelf.dart';

import '../../app.dart';
import '../../domain/errors.dart';
import '../http_helpers.dart';

/// Micro-app de conversión de divisas (integración externa real).
class FxHandler {
  const FxHandler(this.app);

  final AppContainer app;

  Future<Response> rates(Request request) async {
    final base = request.url.queryParameters['base'] ?? 'USD';
    final rates = await app.fx.rates(base);
    return jsonResponse(rates.toJson());
  }

  Future<Response> convert(Request request) async {
    final body = await readJson(request);
    final from = (body['from'] as String?)?.trim() ?? 'USD';
    final to = (body['to'] as String?)?.trim() ?? 'EUR';
    final amountMinor = (body['amountMinor'] as num?)?.toInt() ?? 0;
    if (amountMinor <= 0) {
      throw ApiException.badRequest('amountMinor debe ser mayor a cero');
    }
    final conversion = await app.fx.convert(
      from: from,
      to: to,
      amountMinor: amountMinor,
    );
    return jsonResponse(conversion.toJson());
  }
}
