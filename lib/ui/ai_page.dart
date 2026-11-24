import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/l10n.dart';

import '../services/ai_service.dart';

class AiPage extends StatefulWidget {
  final AiService service;
  const AiPage({super.key, required this.service});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final _prompt = TextEditingController();
  final List<AiChatMessage> _messages = [];
  bool _busy = false;

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _prompt.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _messages.add(AiChatMessage('user', text));
      _prompt.clear();
      _busy = true;
    });
    final reply = await widget.service.send(text);
    if (!mounted) return;
    setState(() {
      _messages.add(AiChatMessage('assistant', reply.text));
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${context.t('aiAssistant')} · ${widget.service.activeProvider.name}',
        ),
      ),
      body: Column(
        children: [
          if (!widget.service.activeProvider.isConfigured)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                context.t('aiNotConfigured'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.role == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(message.content),
                  ),
                );
              },
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _prompt,
                      decoration: InputDecoration(
                        hintText: context.t('send'),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => unawaited(_send()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : () => unawaited(_send()),
                    icon: const Icon(Icons.send),
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
