import '../json_utils.dart';
import '../money.dart';
import 'fx.dart';
import 'insights.dart';
import 'transaction.dart';

/// Tarjeta estructurada que acompaña la respuesta del asistente.
///
/// `type` determina qué datos vienen informados:
/// `balance` | `conversion` | `transactions` | `insights`.
class AssistantCard {
  const AssistantCard({
    required this.type,
    required this.title,
    this.subtitle,
    this.amount,
    this.conversion,
    this.transactions,
    this.insights,
  });

  final String type;
  final String title;
  final String? subtitle;
  final Money? amount;
  final FxConversion? conversion;
  final List<BankTransaction>? transactions;
  final SpendingInsights? insights;

  factory AssistantCard.fromJson(Map<String, dynamic> json) => AssistantCard(
        type: jsonString(json, 'type'),
        title: jsonString(json, 'title'),
        subtitle: jsonStringOrNull(json, 'subtitle'),
        amount: json['amount'] is Map<String, dynamic>
            ? Money.fromJson(jsonMap(json, 'amount'))
            : null,
        conversion: json['conversion'] is Map<String, dynamic>
            ? FxConversion.fromJson(jsonMap(json, 'conversion'))
            : null,
        transactions: json['transactions'] is List
            ? jsonList(json, 'transactions')
                .map(BankTransaction.fromJson)
                .toList(growable: false)
            : null,
        insights: json['insights'] is Map<String, dynamic>
            ? SpendingInsights.fromJson(jsonMap(json, 'insights'))
            : null,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'title': title,
        'subtitle': subtitle,
        'amount': amount?.toJson(),
        'conversion': conversion?.toJson(),
        'transactions':
            transactions?.map((t) => t.toJson()).toList(growable: false),
        'insights': insights?.toJson(),
      };
}

/// Respuesta del copiloto financiero.
class AssistantAnswer {
  const AssistantAnswer({
    required this.reply,
    required this.intent,
    required this.suggestions,
    this.card,
  });

  final String reply;
  final String intent;
  final List<String> suggestions;
  final AssistantCard? card;

  factory AssistantAnswer.fromJson(Map<String, dynamic> json) =>
      AssistantAnswer(
        reply: jsonString(json, 'reply'),
        intent: jsonString(json, 'intent', fallback: 'unknown'),
        suggestions: (json['suggestions'] as List<dynamic>? ?? [])
            .map((value) => value.toString())
            .toList(growable: false),
        card: json['card'] is Map<String, dynamic>
            ? AssistantCard.fromJson(jsonMap(json, 'card'))
            : null,
      );

  Map<String, dynamic> toJson() => {
        'reply': reply,
        'intent': intent,
        'suggestions': suggestions,
        'card': card?.toJson(),
      };
}

/// Mensaje del hilo de conversación (uso local en la app).
class AssistantMessage {
  AssistantMessage({
    required this.text,
    required this.fromUser,
    this.answer,
  }) : sentAt = DateTime.now();

  final String text;
  final bool fromUser;
  final AssistantAnswer? answer;
  final DateTime sentAt;
}