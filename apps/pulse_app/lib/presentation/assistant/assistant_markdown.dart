import 'package:flutter/material.dart';

import '../../app/theme/pulse_theme.dart';

/// Renders the small Markdown subset local models use in replies:
/// **bold**, *italic*, `code`, # headings, bullet and numbered lists and
/// ``` code blocks. Anything else stays plain text.
///
/// Links are deliberately not made clickable: a reply must not lead the
/// user off this PC with one click.
class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final blocks = parseAssistantMarkdown(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, block) in blocks.indexed) ...[
          if (index > 0) SizedBox(height: block.kind == MarkdownBlockKind.listItem ? 4 : 8),
          _buildBlock(block),
        ],
      ],
    );
  }

  Widget _buildBlock(MarkdownBlock block) {
    final mono = style.copyWith(
      fontFamily: PulseTheme.monoFont,
      fontFamilyFallback: PulseTheme.monoFallback,
      fontSize: (style.fontSize ?? 14) - 1,
    );
    switch (block.kind) {
      case MarkdownBlockKind.code:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: PulseTokens.card,
            borderRadius: BorderRadius.circular(PulseTokens.radiusMd),
            border: Border.all(color: PulseTokens.stroke),
          ),
          child: Text(block.text, style: mono.copyWith(height: 1.4)),
        );
      case MarkdownBlockKind.heading:
        return Text.rich(
          TextSpan(children: inlineSpans(block.text, style, mono)),
          style: style.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: (style.fontSize ?? 14) + (block.level == 1 ? 2 : 1),
          ),
        );
      case MarkdownBlockKind.listItem:
        return Padding(
          padding: EdgeInsets.only(left: 4.0 + block.level * 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: block.marker.length > 1 ? 24 : 14,
                child: Text(block.marker, style: style),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: inlineSpans(block.text, style, mono)),
                  style: style,
                ),
              ),
            ],
          ),
        );
      case MarkdownBlockKind.paragraph:
        return Text.rich(
          TextSpan(children: inlineSpans(block.text, style, mono)),
          style: style,
        );
    }
  }
}

enum MarkdownBlockKind { paragraph, heading, listItem, code }

class MarkdownBlock {
  const MarkdownBlock(
    this.kind,
    this.text, {
    this.level = 0,
    this.marker = '',
  });

  final MarkdownBlockKind kind;
  final String text;

  /// Heading level (1-3) or list nesting depth (0 = top level).
  final int level;

  /// "•" or "1." for list items.
  final String marker;
}

final _heading = RegExp(r'^(#{1,3})\s+(.*)$');
final _bullet = RegExp(r'^(\s*)[-*•]\s+(.*)$');
final _numbered = RegExp(r'^(\s*)(\d{1,3})[.)]\s+(.*)$');

/// Splits a reply into blocks. Unclosed code fences (while a reply is still
/// streaming) run to the end of the text.
List<MarkdownBlock> parseAssistantMarkdown(String text) {
  final blocks = <MarkdownBlock>[];
  final paragraph = <String>[];
  final code = <String>[];
  var inCode = false;

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(MarkdownBlock(MarkdownBlockKind.paragraph, paragraph.join('\n')));
    paragraph.clear();
  }

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trimRight();
    if (line.trimLeft().startsWith('```')) {
      if (inCode) {
        blocks.add(MarkdownBlock(MarkdownBlockKind.code, code.join('\n')));
        code.clear();
        inCode = false;
      } else {
        flushParagraph();
        inCode = true;
      }
      continue;
    }
    if (inCode) {
      code.add(rawLine);
      continue;
    }
    if (line.trim().isEmpty) {
      flushParagraph();
      continue;
    }
    final heading = _heading.firstMatch(line);
    if (heading != null) {
      flushParagraph();
      blocks.add(MarkdownBlock(
        MarkdownBlockKind.heading,
        heading.group(2)!,
        level: heading.group(1)!.length,
      ));
      continue;
    }
    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      flushParagraph();
      blocks.add(MarkdownBlock(
        MarkdownBlockKind.listItem,
        bullet.group(2)!,
        level: bullet.group(1)!.length ~/ 2,
        marker: '•',
      ));
      continue;
    }
    final numbered = _numbered.firstMatch(line);
    if (numbered != null) {
      flushParagraph();
      blocks.add(MarkdownBlock(
        MarkdownBlockKind.listItem,
        numbered.group(3)!,
        level: numbered.group(1)!.length ~/ 2,
        marker: '${numbered.group(2)}.',
      ));
      continue;
    }
    paragraph.add(line);
  }
  if (inCode) {
    blocks.add(MarkdownBlock(MarkdownBlockKind.code, code.join('\n')));
  }
  flushParagraph();
  return blocks;
}

/// `code`, **bold** / __bold__ and *italic*. Underscore italics are left
/// alone so identifiers such as file_name_here stay intact.
final _inline = RegExp(r'`([^`]+)`|\*\*(.+?)\*\*|__(.+?)__|\*([^*\s][^*]*?)\*');

List<InlineSpan> inlineSpans(String text, TextStyle style, TextStyle mono) {
  final spans = <InlineSpan>[];
  var position = 0;
  for (final match in _inline.allMatches(text)) {
    if (match.start > position) {
      spans.add(TextSpan(text: text.substring(position, match.start)));
    }
    if (match.group(1) != null) {
      spans.add(TextSpan(text: match.group(1), style: mono));
    } else if (match.group(2) != null || match.group(3) != null) {
      spans.add(TextSpan(
        text: match.group(2) ?? match.group(3),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
    } else {
      spans.add(TextSpan(
        text: match.group(4),
        style: const TextStyle(fontStyle: FontStyle.italic),
      ));
    }
    position = match.end;
  }
  if (position < text.length) {
    spans.add(TextSpan(text: text.substring(position)));
  }
  return spans;
}
