import 'dart:convert';

/// Cealing-Host rule ingestion.
///
/// A published rule file is a JSON array of triples:
///
///     [ [ "*domain.com", "exact.com" ], "fake.sni", "1.2.3.4" ]
///
/// which binds a set of domain globs to a fake SNI *and* to the address the
/// connection must be dialled to. Domain tokens keep their upstream markers so
/// the mihomo core applies the same matching:
///
///     *      matches any run of characters, including dots
///     ^      excludes a pattern from a match expression
///     ^x     leading caret disables the entry
///     #x     leading hash marks a browser-only rule (ignored, mihomo is global)
///     $x     leading dollar marks a global-only rule (kept)
///
/// The fake SNI element may be a string, an empty string (generate a fresh
/// random host name) or null (remove the server_name extension entirely). An
/// empty address element means 127.0.0.1 upstream, which the core maps to a
/// local stop.

/// Normalizes one Cealing-Host entry, `[domains, fakeSNI, ip]`. Returns null
/// when the entry is unusable.
List<Object?>? normalizeCealingRule(Object? raw) {
  if (raw is! List || raw.length < 3) {
    return null;
  }
  final domainList = raw[0];
  if (domainList is! List) {
    return null;
  }
  final domains = domainList
      .whereType<String>()
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (domains.isEmpty) {
    return null;
  }
  final sni = raw[1];
  if (sni != null && sni is! String) {
    return null;
  }
  final ip = raw[2];
  if (ip != null && ip is! String) {
    return null;
  }
  return [domains, sni, (ip ?? '').trim()];
}

/// Drops `//` and `/* */` comments and trailing commas, both of which upstream
/// tolerates in published rule files.
String stripJsonComments(String source) {
  final buffer = StringBuffer();
  var inString = false;
  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (inString) {
      buffer.write(char);
      if (char == r'\' && i + 1 < source.length) {
        i++;
        buffer.write(source[i]);
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
      buffer.write(char);
      continue;
    }
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (char == '/' && next == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      buffer.write('\n');
      continue;
    }
    if (char == '/' && next == '*') {
      i += 2;
      while (i + 1 < source.length &&
          !(source[i] == '*' && source[i + 1] == '/')) {
        i++;
      }
      i++;
      continue;
    }
    if (char == ',') {
      var j = i + 1;
      while (j < source.length && ' \t\r\n'.contains(source[j])) {
        j++;
      }
      if (j < source.length && (source[j] == ']' || source[j] == '}')) {
        continue;
      }
    }
    buffer.write(char);
  }
  return buffer.toString();
}

/// Parses a Cealing-Host document into the normalized form the core expects.
/// Returns null when the text holds no usable rule.
List<Object?>? parseCealingRules(String text) {
  final candidates = <String>{text, stripJsonComments(text)};
  Object? decoded;
  for (final candidate in candidates) {
    try {
      decoded = jsonDecode(candidate);
      break;
    } catch (_) {
      decoded = null;
    }
  }
  if (decoded is! List || decoded.isEmpty) {
    return null;
  }
  final rules = <Object?>[];
  for (final entry in decoded) {
    final rule = normalizeCealingRule(entry);
    if (rule != null) {
      rules.add(rule);
    }
  }
  return rules.isEmpty ? null : rules;
}

/// Collapses imported [incoming] into [existing], replacing entries whose
/// domain set already appears in the table. Order follows first appearance.
List<Object?> mergeCealingRules(
  List<Object?> existing,
  List<Object?> incoming,
) {
  final merged = <String, List<Object?>>{};
  for (final entry in [...existing, ...incoming]) {
    final rule = normalizeCealingRule(entry);
    if (rule == null) {
      continue;
    }
    merged[(rule[0] as List).join(',')] = rule;
  }
  return merged.values.toList();
}

/// Renders [rules] as an indented JSON document for the editor.
String encodeCealingRules(List<Object?> rules) {
  return const JsonEncoder.withIndent('  ').convert(rules);
}
