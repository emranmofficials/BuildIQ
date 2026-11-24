import 'dart:convert';

import 'package:engine/engine.dart';
import 'package:http/http.dart' as http;

import '../core/app_state.dart';
import '../core/logger.dart';

/// AI is an optional, modular layer. Default provider never calls the network
/// and never fabricates a result. All outputs carry a verification status.
abstract class AiProvider {
  String get name;
  bool get isConfigured;
  Future<AiAnalysis> analyzeFloorPlan({
    required String imagePath,
    required String projectId,
  });
  Future<AiChatReply> chat({
    required String prompt,
    required List<AiChatMessage> history,
  });
}

class AiAnalysis {
  final String id;
  final String provider;
  final String model;
  final VerificationStatus status;
  final double confidence;
  final Map<String, dynamic>? draftFloorPlan;
  final String summary;
  final DateTime createdAt;

  const AiAnalysis({
    required this.id,
    required this.provider,
    required this.model,
    required this.status,
    required this.confidence,
    this.draftFloorPlan,
    required this.summary,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider,
    'model': model,
    'status': status.name,
    'confidence': confidence,
    'draftFloorPlan': draftFloorPlan,
    'summary': summary,
    'createdAt': createdAt.toIso8601String(),
  };
}

class AiChatMessage {
  final String role;
  final String content;
  const AiChatMessage(this.role, this.content);
}

class AiChatReply {
  final String text;
  final bool usedNetwork;
  const AiChatReply(this.text, {this.usedNetwork = false});
}

/// Default provider. Always honest about being unconfigured.
class NoOpAiProvider implements AiProvider {
  @override
  String get name => 'none';

  @override
  bool get isConfigured => false;

  @override
  Future<AiAnalysis> analyzeFloorPlan({
    required String imagePath,
    required String projectId,
  }) async {
    return AiAnalysis(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      provider: name,
      model: 'none',
      status: VerificationStatus.uncertain,
      confidence: 0,
      summary: 'AI provider is not configured. No analysis was performed.',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<AiChatReply> chat({
    required String prompt,
    required List<AiChatMessage> history,
  }) async {
    return const AiChatReply(
      'AI provider is not configured. Core calculators and floor-plan '
      'tools work fully offline. Configure an OpenAI-compatible endpoint '
      'in Settings to enable assistant features.',
    );
  }
}

/// OpenAI-compatible HTTP provider. Only used when the user explicitly
/// configures an endpoint and supplies a key. No secret is hardcoded.
class OpenAiCompatibleProvider implements AiProvider {
  final AppState state;
  final http.Client _client;

  OpenAiCompatibleProvider(this.state, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get name => 'openai-compatible';

  @override
  bool get isConfigured => state.aiConfigured;

  @override
  Future<AiAnalysis> analyzeFloorPlan({
    required String imagePath,
    required String projectId,
  }) async {
    // Image analysis requires multipart upload and a vision-capable model.
    // The provider is intentionally conservative: without a verified model
    // response it returns an UNCERTAIN analysis rather than guessing rooms.
    return AiAnalysis(
      id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
      provider: name,
      model: state.aiModel ?? 'unknown',
      status: VerificationStatus.uncertain,
      confidence: 0,
      summary:
          'Image analysis requires a vision-capable model and a '
          'user-verified draft. No geometry was auto-committed.',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<AiChatReply> chat({
    required String prompt,
    required List<AiChatMessage> history,
  }) async {
    if (!isConfigured) {
      return const AiChatReply(
        'Provider is not configured.',
        usedNetwork: false,
      );
    }
    try {
      final response = await _client
          .post(
            Uri.parse(state.aiEndpoint!),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${state.aiKey}',
            },
            body: jsonEncode({
              'model': state.aiModel,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a construction estimation assistant. '
                      'Give conservative, engineering-safe guidance. Never '
                      'replace a structural engineer. Reply in the language '
                      'of the user.',
                },
                ...history.map((m) => {'role': m.role, 'content': m.content}),
                {'role': 'user', 'content': prompt},
              ],
              'temperature': 0.2,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        AppLogger.error('AI request failed', response.statusCode);
        return AiChatReply(
          'AI request failed (HTTP ${response.statusCode}).',
          usedNetwork: true,
        );
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = body['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        return const AiChatReply('AI returned no choices.', usedNetwork: true);
      }
      final message = choices.first['message'] as Map<String, dynamic>;
      return AiChatReply(
        message['content']?.toString() ?? '(empty reply)',
        usedNetwork: true,
      );
    } catch (error) {
      AppLogger.error('AI request error', error);
      return AiChatReply('AI request failed: $error', usedNetwork: true);
    }
  }

  void dispose() => _client.close();
}

class AiService {
  final AppState state;
  late AiProvider activeProvider;
  final NoOpAiProvider _noOp = NoOpAiProvider();
  OpenAiCompatibleProvider? _httpProvider;

  AiService(this.state) {
    _selectProvider();
  }

  void refresh() {
    _httpProvider?.dispose();
    _httpProvider = null;
    _selectProvider();
  }

  void _selectProvider() {
    activeProvider = state.aiConfigured
        ? (_httpProvider ??= OpenAiCompatibleProvider(state))
        : _noOp;
  }

  List<AiChatMessage> chatHistory = <AiChatMessage>[];

  Future<AiChatReply> send(String prompt) async {
    final reply = await activeProvider.chat(
      prompt: prompt,
      history: List.unmodifiable(chatHistory),
    );
    chatHistory.add(AiChatMessage('user', prompt));
    chatHistory.add(AiChatMessage('assistant', reply.text));
    if (chatHistory.length > 40) {
      chatHistory = chatHistory.sublist(chatHistory.length - 40);
    }
    return reply;
  }

  void dispose() => _httpProvider?.dispose();
}
