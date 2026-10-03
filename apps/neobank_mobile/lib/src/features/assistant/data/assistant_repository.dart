import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';

/// Cliente del copiloto financiero.
class AssistantRepository {
  AssistantRepository(this._client);

  final ApiClient _client;

  Future<AssistantAnswer> ask(String message) async {
    final data = await _client.postJson(
      ApiPaths.assistant,
      body: {'message': message},
    );
    return AssistantAnswer.fromJson(data);
  }
}

final assistantRepositoryProvider = Provider<AssistantRepository>(
  (ref) => AssistantRepository(ref.watch(apiClientProvider)),
);

/// Hilo de conversación con estado de "escribiendo…".
class AssistantThread {
  const AssistantThread({required this.messages, this.thinking = false});

  final List<AssistantMessage> messages;
  final bool thinking;

  AssistantThread copyWith({
    List<AssistantMessage>? messages,
    bool? thinking,
  }) =>
      AssistantThread(
        messages: messages ?? this.messages,
        thinking: thinking ?? this.thinking,
      );
}

class AssistantController extends Notifier<AssistantThread> {
  static const String greeting =
      '¡Hola! Soy tu copiloto financiero. Pregúntame por tu saldo, tus gastos, '
      'tus ahorros, tus movimientos o una conversión de divisas.';

  @override
  AssistantThread build() => AssistantThread(
        messages: [AssistantMessage(text: greeting, fromUser: false)],
      );

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.thinking) return;
    state = state.copyWith(
      messages: [
        ...state.messages,
        AssistantMessage(text: trimmed, fromUser: true),
      ],
      thinking: true,
    );
    try {
      final answer = await ref.read(assistantRepositoryProvider).ask(trimmed);
      state = state.copyWith(
        messages: [
          ...state.messages,
          AssistantMessage(
            text: answer.reply,
            fromUser: false,
            answer: answer,
          ),
        ],
        thinking: false,
      );
    } catch (error) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          AssistantMessage(
            text: 'No pude responder en este momento. Reintenta en un momento.',
            fromUser: false,
          ),
        ],
        thinking: false,
      );
    }
  }

  void reset() => state = build();
}

final assistantControllerProvider =
    NotifierProvider<AssistantController, AssistantThread>(
  AssistantController.new,
);