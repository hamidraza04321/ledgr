import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ai_parser.dart';
import 'offline_parser.dart';
import 'parse_models.dart';

/// Hybrid: the offline parser always runs first; Gemini is asked only
/// when the offline result is unsure and AI is allowed (online + enabled).
class EntryParser {
  EntryParser({this.ai});

  final OfflineParser _offline = const OfflineParser();
  final AiParser? ai;

  Future<ParseResult> parse(
    String message,
    ParseContext ctx, {
    required Future<bool> Function() aiAllowed,
  }) async {
    final offline = _offline.parse(message, ctx);
    final ai = this.ai;
    if (!offline.needsAi || ai == null) return offline;
    if (!await aiAllowed()) return offline;
    try {
      final result =
          await ai.parse(message, ctx).timeout(const Duration(seconds: 12));
      if (result.entries.isNotEmpty) return result;
    } catch (e) {
      debugPrint('AI parse failed, using offline result: $e');
    }
    return offline;
  }
}
