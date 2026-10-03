import 'package:shelf/shelf.dart';

import '../../app.dart';
import '../../domain/errors.dart';
import '../http_helpers.dart';
import '../middleware.dart';

/// Copiloto financiero conversacional.
class AssistantHandler {
  const AssistantHandler(this.app);

  final AppContainer app;

  Future<Response> ask(Request request) async {
    final user = currentUser(request);
    final body = await readJson(request);
    final message = (body['message'] as String?)?.trim() ?? '';
    if (message.isEmpty) {
      throw ApiException.badRequest('El mensaje es obligatorio');
    }
    final answer = await app.assistant.ask(user.id, message);
    return jsonResponse(answer.toJson());
  }
}