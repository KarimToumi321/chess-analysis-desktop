List<String> parseSanMovesFromPgn(String pgn) {
  var content = pgn;

  // Remove header tags
  content = content.replaceAll(RegExp(r'^\s*\[.*?\]\s*$', multiLine: true), '');

  // Remove comments {...}
  content = content.replaceAll(RegExp(r'\{[^}]*\}'), '');

  // Remove ; comments to end of line
  content = content.replaceAll(RegExp(r';[^\n]*'), '');

  // Remove NAGs like $1
  content = content.replaceAll(RegExp(r'\$\d+'), '');

  // Remove variations (...) using a stack approach
  content = _stripParentheses(content);

  // Remove move numbers like 1. or 1...
  content = content.replaceAll(RegExp(r'\b\d+\.\.\.|\b\d+\.'), '');

  // Remove results
  content = content.replaceAll(RegExp(r'1-0|0-1|1/2-1/2|\*'), '');

  // Normalize whitespace
  content = content.replaceAll(RegExp(r'\s+'), ' ').trim();

  if (content.isEmpty) return <String>[];

  // Split into tokens and filter out invalid moves
  final tokens = content.split(' ').where((token) => token.isNotEmpty).toList();

  // Filter to only keep valid chess move patterns (basic validation)
  return tokens.where((move) {
    // Must not be empty
    if (move.isEmpty) return false;

    // Must not contain error-related keywords
    if (move.contains('Error') ||
        move.contains('throw') ||
        move.contains('Handle') ||
        move.contains('_') ||
        move.contains('.dart') ||
        move.contains('async') ||
        move.contains('closure') ||
        move.contains('Loop')) {
      return false;
    }

    // Chess moves typically contain letters and numbers, possibly +, #, =, x
    // and should be reasonably short
    if (move.length > 10) return false;

    // Should contain at least one letter (for piece or file)
    if (!RegExp(r'[a-hA-HKQRBNOx]').hasMatch(move)) return false;

    return true;
  }).toList();
}

String _stripParentheses(String input) {
  final buffer = StringBuffer();
  var depth = 0;
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == '(') {
      depth += 1;
      continue;
    }
    if (ch == ')') {
      if (depth > 0) depth -= 1;
      continue;
    }
    if (depth == 0) buffer.write(ch);
  }
  return buffer.toString();
}
