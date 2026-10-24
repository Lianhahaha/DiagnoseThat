import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app/theme/pulse_theme.dart';
import 'package:pulse/presentation/assistant/assistant_markdown.dart';

/// A reply shaped like the one in the 1.4.1 test, where the asterisks showed.
const _reply = '''En çok özel bellek kullanan süreçler:

1. **llama-server.exe**: ~20.09 GB
2. **chrome.exe**: ~1.79 GB
- `MsMpEng.exe` (*Windows Defender*)

## Notes
```
Get-Process | Sort PrivateMemorySize
```''';

String _plain(List<InlineSpan> spans) =>
    spans.map((s) => (s as TextSpan).text ?? '').join();

void main() {
  test('blocks: paragraph, numbered and bullet items, heading, code', () {
    final blocks = parseAssistantMarkdown(_reply);
    expect(blocks.map((b) => b.kind), [
      MarkdownBlockKind.paragraph,
      MarkdownBlockKind.listItem,
      MarkdownBlockKind.listItem,
      MarkdownBlockKind.listItem,
      MarkdownBlockKind.heading,
      MarkdownBlockKind.code,
    ]);
    expect(blocks[1].marker, '1.');
    expect(blocks[3].marker, '•');
    expect(blocks[4].text, 'Notes');
    expect(blocks[5].text, 'Get-Process | Sort PrivateMemorySize');
  });

  test('inline markers are removed and styled', () {
    const style = TextStyle();
    const mono = TextStyle(fontFamily: 'mono');
    final spans = inlineSpans('**llama-server.exe**: ~20 GB', style, mono);
    expect(_plain(spans), 'llama-server.exe: ~20 GB');
    expect((spans.first as TextSpan).style?.fontWeight, FontWeight.w700);

    final code = inlineSpans('run `powercfg /a` now', style, mono);
    expect(_plain(code), 'run powercfg /a now');
    expect((code[1] as TextSpan).style?.fontFamily, 'mono');
  });

  test('identifiers with underscores and lone asterisks stay as written', () {
    const style = TextStyle();
    expect(
      _plain(inlineSpans('my_file_name and 5 * 3 = 15', style, style)),
      'my_file_name and 5 * 3 = 15',
    );
  });

  test('a code fence still streaming runs to the end', () {
    final blocks = parseAssistantMarkdown('Try:\n```\npowercfg /lastwake');
    expect(blocks.last.kind, MarkdownBlockKind.code);
    expect(blocks.last.text, 'powercfg /lastwake');
  });

  testWidgets('renders without the asterisks', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PulseTheme.dark(),
        home: const Scaffold(
          body: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: AssistantMarkdown(text: _reply, style: TextStyle()),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('llama-server.exe', findRichText: true),
        findsOneWidget);
  });
}
