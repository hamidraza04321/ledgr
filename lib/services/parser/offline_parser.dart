import 'dart:math' as math;

import '../../data/models/models.dart';
import 'date_detector.dart';
import 'parse_models.dart';

/// Rule-based parser for chat entries such as:
///   "100 ka petrol\n100 ka biscuit\naj ke din ka"
///   "Salary 85000 mili", "kal 2k ka ration aur 500 ki dawai"
/// Works fully offline. Low-confidence results are flagged so the
/// hybrid parser can ask Gemini when online.
class OfflineParser {
  const OfflineParser();

  static final _wordRe = RegExp(r'\p{L}+', unicode: true);

  static final _amountRe = RegExp(
    r'(?<![\p{L}\d.])(?:(rs|pkr|inr|usd|aed|sar|\$|₹)\s*)?(\d+(?:\.\d+)?)\s*'
    r'(k|hazar|hazaar|hzar|hajar|thousand|grand|lakh|lac|lacs|lakhs|crore|cr)?'
    r'(?![\p{L}\d.])(\s*/-)?',
    unicode: true,
  );

  static const _multipliers = {
    'k': 1e3, 'hazar': 1e3, 'hazaar': 1e3, 'hzar': 1e3, 'hajar': 1e3,
    'thousand': 1e3, 'grand': 1e3,
    'lakh': 1e5, 'lac': 1e5, 'lacs': 1e5, 'lakhs': 1e5,
    'crore': 1e7, 'cr': 1e7,
  };

  /// Words right after a number that mark it as money.
  static const _amountMarkers = {
    'ka', 'ki', 'ke', 'kay', 'ko', 'rs', 'rupay', 'rupaye', 'rupee',
    'rupees', 'rupya', 'rupaay', 'pkr', 'ru',
  };

  /// Words right after a number that mark it as a quantity, not money.
  static const _quantityUnits = {
    'kg', 'kgs', 'kilo', 'g', 'gm', 'gms', 'gram', 'grams', 'ltr', 'litre',
    'liter', 'litres', 'liters', 'l', 'ml', 'dozen', 'darjan', 'packet',
    'packets', 'pkt', 'pcs', 'pc', 'piece', 'pieces', 'box', 'boxes',
    'bottle', 'bottles', 'cup', 'cups', 'plate', 'plates', 'x', 'din',
    'days', 'day', 'mahine', 'month', 'months', 'saal', 'year', 'years',
    'hours', 'hour', 'ghante', 'ghanta', 'minute', 'minutes', 'min', 'km',
    'meter', 'feet', 'foot', 'inch', 'log', 'bande', 'items', 'item',
    'tickets', 'unit', 'units', 'nos', 'adad',
  };

  static const _incomeStrong = {
    'mila', 'mili', 'mile', 'milay', 'miley', 'mil', 'received', 'receive',
    'recieved', 'credited', 'credit', 'earned', 'earn', 'kamaye', 'kamaya',
    'kamai', 'kamaai', 'income', 'aamdani', 'amdani', 'aamdni',
  };

  static const _incomeWeak = {
    'aaye', 'aye', 'aaya', 'aya', 'ayi', 'aayi', 'got', 'agaye', 'agae',
  };

  static const _expenseWords = {
    'diya', 'diye', 'dia', 'diay', 'kharch', 'kharcha', 'kharchay', 'spent',
    'spend', 'paid', 'liya', 'liye', 'lia', 'li', 'khareeda', 'khareedi',
    'kharida', 'kharidi', 'bought', 'buy', 'bhara', 'bhari', 'bharay',
    'bhare', 'debit', 'debited', 'lagaye', 'lagay', 'lage',
  };

  static const _fillers = {
    'ka', 'ki', 'ke', 'kay', 'ko', 'pe', 'par', 'per', 'mein', 'me', 'main',
    'mai', 'mn', 'for', 'on', 'of', 'the', 'a', 'an', 'rs', 'pkr', 'rupay',
    'rupaye', 'rupees', 'rupee', 'rupya', 'rupaay', 'ru', 'kiya', 'kia',
    'kiye', 'kar', 'kr', 'karo', 'hua', 'hue', 'huay', 'gaya', 'gaye', 'gai',
    'gayi', 'pay', 'se', 'sy', 'from', 'via', 'by', 'with', 'to', 'and',
    'aur', 'or', 'bhi', 'hai', 'hain', 'tha', 'thi', 'thay', 'ho', 'is',
    'was', 'in', 'at', 'apna', 'apni', 'apne', 'mera', 'meri', 'mere', 'my',
    'sab', 'total', 'din', 'day', 'raat', 'subah', 'shaam', 'sham',
    'dopahar', 'kal', 'aj', 'aaj', 'today', 'yesterday', 'parson', 'abhi',
    'wala', 'wali', 'walay', 'wale', 'k', 'hazar', 'hazaar', 'lakh', 'ne',
    'maine', 'hum', 'humne', 'ye', 'yeh', 'wo', 'woh', 'kuch', 'ek', 'aik',
    'ap', 'aap', 'ab', 'pehle', 'pehlay', 'ago', 'days', 'dino', 'de', 'do',
    'dena', 'lena', 'tak', 'liay', 'lye', 'ky', 'kaa', 'kii', 'kee', 'payment',
    'hisaab', 'hisab', 'hesab', 'list', 'entry', 'entries', 'add', 'save',
    'likh', 'likho', 'likhna',
  };

  ParseResult parse(String input, ParseContext ctx) {
    final today = DateTime(ctx.now.year, ctx.now.month, ctx.now.day);
    final segments = _splitSegments(_normalize(input));
    final drafts = <_Draft>[];
    final skipped = <String>[];
    DateTime? dateOnlyLine;
    DateTime? firstSegmentDate;

    for (final seg in segments) {
      if (seg.trim().isEmpty) continue;
      final hit = DateDetector.detect(seg, today);
      final amounts = _findAmounts(hit.rest);

      if (amounts.isEmpty) {
        final content = _content(_words(hit.rest));
        if (content.isEmpty) {
          if (hit.date != null) dateOnlyLine ??= hit.date;
        } else {
          skipped.add(seg.trim());
        }
        continue;
      }

      if (hit.date != null) firstSegmentDate ??= hit.date;
      final strong = amounts.where((a) => a.strong).toList();
      final chosen = strong.isNotEmpty ? strong : amounts;
      final ambiguous = strong.isEmpty && amounts.length > 1;
      for (final chunk in _chunks(hit.rest, chosen)) {
        drafts.add(_Draft(chunk.$1, chunk.$2, hit.date, ambiguous));
      }
    }

    final messageDate = dateOnlyLine ?? firstSegmentDate ?? today;
    final entries = [
      for (final d in drafts) _build(d, d.date ?? messageDate, ctx),
    ];
    return ParseResult(entries: entries, skipped: skipped);
  }

  // ---------------------------------------------------------------------------

  static String _normalize(String s) {
    var t = s.toLowerCase().replaceAll('₨', ' rs ');
    t = t.replaceAll(RegExp(r'(?<=\d),(?=\d)'), ''); // 1,250 → 1250
    t = t.replaceAllMapped(RegExp(r'\b(rs|pkr)\.'), (m) => '${m[1]} ');
    return t;
  }

  static List<String> _splitSegments(String t) => t.split(RegExp(
        r'\n|;|,|(?<!\d)\.(?!\d)|\s+(?:aur|and|&|plus|\+|or phir|phir)\s+',
      ));

  static List<String> _words(String s) =>
      _wordRe.allMatches(s).map((m) => m[0]!).toList();

  static List<String> _content(List<String> words) => words
      .where((w) =>
          !_fillers.contains(w) &&
          !_incomeStrong.contains(w) &&
          !_incomeWeak.contains(w) &&
          !_expenseWords.contains(w))
      .toList();

  List<_Amount> _findAmounts(String text) {
    final out = <_Amount>[];
    for (final m in _amountRe.allMatches(text)) {
      final prefix = m[1];
      final unit = m[3];
      final slash = m[4];
      var value = double.tryParse(m[2]!) ?? 0;
      if (unit != null) value *= _multipliers[unit] ?? 1;
      if (value <= 0) continue;

      final after = text.substring(m.end).trimLeft();
      final next = _wordRe.matchAsPrefix(after)?[0];
      if (prefix == null && unit == null && slash == null &&
          _quantityUnits.contains(next)) {
        continue;
      }
      final before = text.substring(0, m.start).trimRight();
      final prevWords = _words(before);
      final prev = prevWords.isEmpty ? null : prevWords.last;
      final strong = prefix != null ||
          unit != null ||
          slash != null ||
          _amountMarkers.contains(next) ||
          prev == 'rs' ||
          prev == 'pkr';
      out.add(_Amount(m.start, m.end, value, strong, before.endsWith('+')));
    }
    return out;
  }

  /// Splits a segment that holds several amounts, e.g.
  /// "100 ka petrol 50 ki chai" (amount first) or "petrol 100 chai 50".
  List<(String, _Amount)> _chunks(String seg, List<_Amount> amounts) {
    String cut(int from, int to, _Amount a) =>
        seg.substring(from, to).replaceRange(a.start - from, a.end - from, ' ');

    if (amounts.length == 1) {
      final a = amounts.first;
      return [(cut(0, seg.length, a), a)];
    }
    final amountFirst =
        _content(_words(seg.substring(0, amounts.first.start))).isEmpty;
    final out = <(String, _Amount)>[];
    for (var i = 0; i < amounts.length; i++) {
      final a = amounts[i];
      final last = i == amounts.length - 1;
      final int from, to;
      if (amountFirst) {
        from = i == 0 ? 0 : a.start;
        to = last ? seg.length : amounts[i + 1].start;
      } else {
        from = i == 0 ? 0 : amounts[i - 1].end;
        to = last ? seg.length : a.end;
      }
      out.add((cut(from, to, a), a));
    }
    return out;
  }

  ParsedEntry _build(_Draft d, DateTime date, ParseContext ctx) {
    final words = _words(d.text);
    final plusSign = d.amount.plus;

    // Wallet mentioned by name ("cash se", "bank", "jazzcash").
    Wallet? wallet;
    var walletWords = <String>{};
    final joined = ' ${words.join(' ')} ';
    var bestLen = 0;
    for (final w in ctx.wallets) {
      final nameWords = _words(w.name.toLowerCase());
      if (nameWords.isEmpty) continue;
      final glued = nameWords.join();
      if ((joined.contains(' ${nameWords.join(' ')} ') ||
              words.contains(glued)) &&
          glued.length > bestLen) {
        wallet = w;
        bestLen = glued.length;
        walletWords = {...nameWords, glued};
      }
    }

    final strongIncome = plusSign || words.any(_incomeStrong.contains);
    final weakIncome = words.any(_incomeWeak.contains);
    final expenseHint = words.any(_expenseWords.contains);
    final content =
        _content(words).where((w) => !walletWords.contains(w)).toList();

    final scores = _score(content, ctx);
    final byId = {for (final c in ctx.categories) c.id: c};
    final ranked = scores.entries.toList()
      ..sort((a, b) {
        final s = b.value.compareTo(a.value);
        if (s != 0) return s;
        final ta = byId[a.key]!.type, tb = byId[b.key]!.type;
        if (ta != tb) return ta == TxnType.expense ? -1 : 1;
        return byId[a.key]!.sortOrder.compareTo(byId[b.key]!.sortOrder);
      });

    TxnType? preferred;
    if (strongIncome && !expenseHint) {
      preferred = TxnType.income;
    } else if (expenseHint && !strongIncome) {
      preferred = TxnType.expense;
    }

    MapEntry<String, double>? pick;
    if (preferred != null) {
      pick = ranked.where((e) => byId[e.key]!.type == preferred).firstOrNull;
    } else if (weakIncome) {
      pick = ranked
              .where((e) => byId[e.key]!.type == TxnType.income)
              .firstOrNull ??
          ranked.firstOrNull;
      preferred = pick == null ? TxnType.income : null;
    } else {
      pick = ranked.firstOrNull;
    }

    final Category category;
    if (pick != null) {
      category = byId[pick.key]!;
    } else {
      final type = preferred ?? TxnType.expense;
      category = _fallback(type, ctx);
    }

    final confident = pick != null && pick.value >= 2 && !d.ambiguous;
    final note = content.isEmpty
        ? ''
        : content.join(' ').replaceFirstMapped(
            RegExp(r'^\p{L}', unicode: true), (m) => m[0]!.toUpperCase());

    return ParsedEntry(
      amount: d.amount.value,
      type: category.type,
      categoryId: category.id,
      walletId: wallet?.id ?? ctx.defaultWalletId,
      note: note,
      date: date,
      confident: confident,
    );
  }

  Map<String, double> _score(List<String> content, ParseContext ctx) {
    final scores = <String, double>{};
    if (content.isEmpty) return scores;
    final ids = {for (final c in ctx.categories) c.id};

    for (final w in content) {
      final id = ctx.learned[w] ?? ctx.learned[_singular(w)];
      if (id != null && ids.contains(id)) scores[id] = 10;
    }

    final phrase = ' ${content.join(' ')} ';
    for (final c in ctx.categories) {
      var best = scores[c.id] ?? 0;
      final keywords = {
        ...c.keywords,
        ..._words(c.name.toLowerCase())
            .where((w) => w.length >= 3 && !_fillers.contains(w)),
      };
      for (final kw in keywords) {
        if (kw.contains(' ')) {
          if (phrase.contains(' $kw ')) {
            best = math.max(best, 3.0 + kw.split(' ').length);
          }
          continue;
        }
        for (final w in content) {
          if (w == kw || _singular(w) == kw) {
            best = math.max(best, 3);
          } else if (_squash(w) == _squash(kw)) {
            best = math.max(best, 2.5);
          } else if (w.length >= 5 &&
              kw.length >= 5 &&
              _levenshtein(_squash(w), _squash(kw)) <= 1) {
            best = math.max(best, 1);
          }
        }
      }
      if (best > 0) scores[c.id] = best;
    }
    return scores;
  }

  static Category _fallback(TxnType type, ParseContext ctx) {
    final id = type == TxnType.income ? kOtherIncomeId : kOtherExpenseId;
    return ctx.categories.firstWhere(
      (c) => c.id == id,
      orElse: () => ctx.categories.firstWhere(
        (c) => c.type == type,
        orElse: () => ctx.categories.first,
      ),
    );
  }

  /// Words worth remembering when the user re-categorises an entry.
  static List<String> learnableWords(String note) => _content(_words(
        note.toLowerCase(),
      )).where((w) => w.length >= 3).toList();

  static String _singular(String w) =>
      w.length > 3 && w.endsWith('s') ? w.substring(0, w.length - 1) : w;

  static String _squash(String w) =>
      w.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m[1]!);

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if ((a.length - b.length).abs() > 1) return 2;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = math.min(
            math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      prev = cur;
    }
    return prev[b.length];
  }
}

class _Amount {
  const _Amount(this.start, this.end, this.value, this.strong, this.plus);

  final int start;
  final int end;
  final double value;
  final bool strong;

  /// Written as "+5000" (income).
  final bool plus;
}

class _Draft {
  const _Draft(this.text, this.amount, this.date, this.ambiguous);

  final String text;
  final _Amount amount;
  final DateTime? date;
  final bool ambiguous;
}
