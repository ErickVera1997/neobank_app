import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../shared/widgets/app_widgets.dart';
import '../data/assistant_repository.dart';

/// Chat del copiloto financiero.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({this.initialPrompt, super.key});

  final String? initialPrompt;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  static const List<String> _defaultSuggestions = [
    '¿Cuál es mi saldo?',
    '¿Cuánto gasté este mes?',
    '¿Cuánto gasté en supermercado?',
    '¿Cuánto es 100 USD en EUR?',
    'Muéstrame mis últimos movimientos',
  ];

  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sentInitial = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prompt = widget.initialPrompt;
      if (prompt != null && prompt.trim().isNotEmpty && !_sentInitial) {
        _sentInitial = true;
        _send(prompt);
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _input.clear();
    await ref.read(assistantControllerProvider.notifier).send(text);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<String> _suggestions(AssistantThread thread) {
    for (final message in thread.messages.reversed) {
      final suggestions = message.answer?.suggestions;
      if (suggestions != null && suggestions.isNotEmpty) return suggestions;
    }
    return _defaultSuggestions;
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(assistantControllerProvider);
    ref.listen(assistantControllerProvider, (previous, next) => _scrollToEnd());
    final suggestions = _suggestions(thread);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Copiloto financiero'),
        actions: [
          IconButton(
            tooltip: 'Nueva conversación',
            onPressed: () => ref.read(assistantControllerProvider.notifier).reset(),
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: thread.messages.length + (thread.thinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= thread.messages.length) {
                  return const _ThinkingBubble();
                }
                return _MessageBubble(message: thread.messages[index]);
              },
            ),
          ),
          if (!thread.thinking)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ActionChip(
                  label: Text(suggestions[index]),
                  onPressed: () => _send(suggestions[index]),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: const InputDecoration(
                        hintText: 'Escribe tu pregunta…',
                        prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _send(_input.text),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.fromUser;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.82,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUser ? scheme.primary : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
      ),
      child: SelectableText(
        message.text,
        style: TextStyle(
          color: isUser ? scheme.onPrimary : scheme.onSurface,
          height: 1.35,
        ),
      ),
    );
    final card = message.answer?.card;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          bubble,
          if (card != null) ...[
            const SizedBox(height: 8),
            _AssistantCardView(card: card),
          ],
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const SizedBox(
            width: 120,
            child: LinearProgressIndicator(),
          ),
        ),
      );
}

class _AssistantCardView extends StatelessWidget {
  const _AssistantCardView({required this.card});

  final AssistantCard card;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: MediaQuery.sizeOf(context).width * 0.82,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            ),
          ),
          if (card.subtitle != null)
            Text(
              card.subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
          const SizedBox(height: 8),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (card.type) {
      case 'balance':
        return Text(
          card.amount?.format() ?? '',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: scheme.onPrimaryContainer,
          ),
        );
      case 'conversion':
        return Row(
          children: [
            Expanded(
              child: Text(
                card.conversion?.amount.format() ?? '',
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 16),
            const SizedBox(width: 8),
            Text(
              card.conversion?.result.format() ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        );
      case 'transactions':
        return Column(
          children: (card.transactions ?? const <BankTransaction>[])
              .map(
                (transaction) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          transaction.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        ),
                      ),
                      Text(
                        transaction.amount.format(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        );
      case 'insights':
        final insights = card.insights;
        if (insights == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gastos: ${insights.expenses.format()}',
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
            Text(
              'Ingresos: ${insights.income.format()}',
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
            if (insights.byCategory.isNotEmpty)
              Text(
                'Top: ${insights.byCategory.first.category} '
                '(${(insights.byCategory.first.share * 100).round()}%)',
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
          ],
        );
      default:
        return MoneyText(money: card.amount ?? Money.zero());
    }
  }
}