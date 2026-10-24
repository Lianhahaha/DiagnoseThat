import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/assistant/local_ai_chat.dart';
import 'package:pulse/assistant/local_ai_http.dart';
import 'package:pulse/assistant/providers/lm_studio_provider.dart';
import 'package:pulse/assistant/providers/ollama_provider.dart';

/// Replays a streamed body in the given network chunks.
class _ChunkedHttp implements LocalAiHttpClient {
  _ChunkedHttp(this.chunks);

  final List<String> chunks;

  @override
  Future<LocalAiHttpResponse> get(
    Uri uri, {
    Duration timeout = const Duration(seconds: 2),
    Map<String, String> headers = const {},
  }) async =>
      const LocalAiHttpResponse(statusCode: 404, body: '');

  @override
  Future<LocalAiHttpResponse> post(
    Uri uri, {
    required String body,
    Duration timeout = const Duration(seconds: 120),
    Map<String, String> headers = const {},
    void Function(String chunk)? onStreamChunk,
  }) async {
    chunks.forEach(onStreamChunk!);
    return LocalAiHttpResponse(statusCode: 200, body: chunks.join());
  }
}

/// Splits [body] into chunks of [size] characters, so lines straddle chunks.
List<String> _chunksOf(String body, int size) => [
      for (var i = 0; i < body.length; i += size)
        body.substring(i, (i + size).clamp(0, body.length)),
    ];

Future<(String content, String deltas)> _stream(
  Future<LocalAiChatTurn> Function(LocalAiChatRequest) chat,
) async {
  final deltas = StringBuffer();
  final turn = await chat(
    LocalAiChatRequest(
      modelId: 'm',
      messages: [LocalAiChatMessage.user('hi')],
      stream: true,
      onTextDelta: deltas.write,
    ),
  );
  return (turn.content ?? '', deltas.toString());
}

const _ollamaBody =
    '{"message":{"role":"assistant","content":"Hello"},"done":false}\n'
    '{"message":{"role":"assistant","content":"! I am"},"done":false}\n'
    '{"message":{"role":"assistant","content":" Pulse."},"done":false}\n'
    '{"message":{"role":"assistant","content":""},"done":true,'
    '"done_reason":"stop"}\n';

const _lmStudioBody =
    'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n'
    'data: {"choices":[{"delta":{"content":"! I am"}}]}\n\n'
    'data: {"choices":[{"delta":{"content":" Pulse."},'
    '"finish_reason":"stop"}]}\n\n'
    'data: [DONE]\n\n';

void main() {
  group('StreamedLines', () {
    test('returns each line once and keeps a partial line', () {
      final lines = StreamedLines();
      expect(lines.add('a\nb'), ['a']);
      expect(lines.add('c\nd\n'), ['bc', 'd']);
      expect(lines.add('e'), isEmpty);
      expect(lines.close(), ['e']);
      expect(lines.close(), isEmpty);
    });
  });

  // Chunk sizes from "whole body at once" down to a few characters, so lines
  // arrive split mid-JSON.
  for (final size in [1000, 64, 17, 5]) {
    test('Ollama stream in $size-char chunks yields the text once', () async {
      final provider = OllamaProvider(http: _ChunkedHttp(_chunksOf(_ollamaBody, size)));
      final (content, deltas) = await _stream(provider.chat);
      expect(content, 'Hello! I am Pulse.');
      expect(deltas, 'Hello! I am Pulse.');
    });

    test('LM Studio stream in $size-char chunks yields the text once',
        () async {
      final provider =
          LmStudioProvider(http: _ChunkedHttp(_chunksOf(_lmStudioBody, size)));
      final (content, deltas) = await _stream(provider.chat);
      expect(content, 'Hello! I am Pulse.');
      expect(deltas, 'Hello! I am Pulse.');
    });
  }

  test('Ollama stream without a trailing newline keeps the last line',
      () async {
    final provider = OllamaProvider(
      http: _ChunkedHttp([_ollamaBody.trimRight()]),
    );
    final (content, _) = await _stream(provider.chat);
    expect(content, 'Hello! I am Pulse.');
  });
}
