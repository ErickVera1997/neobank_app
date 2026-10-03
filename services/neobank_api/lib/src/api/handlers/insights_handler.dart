import 'package:shelf/shelf.dart';

import '../../app.dart';
import '../http_helpers.dart';
import '../middleware.dart';

/// Analítica de gasto generada a partir de los movimientos del usuario.
class InsightsHandler {
  const InsightsHandler(this.app);

  final AppContainer app;

  Future<Response> monthly(Request request) async {
    final user = currentUser(request);
    return jsonResponse(app.insights.monthly(user.id).toJson());
  }
}