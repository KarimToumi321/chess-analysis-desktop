import 'dart:convert';

class SavedAnalysis {
  final String title;
  final DateTime savedAt;
  final String pgnText;
  final Map<String, dynamic> gameTree;
  final Map<String, dynamic>? gameAnalysis;
  final Map<String, List<String>>
  userLabelsByKey; // variationId_moveIndex -> labelIds
  final Map<String, String> commentsByFen;
  final Map<String, List<Map<String, dynamic>>> arrowsByFen;
  final Map<String, List<String>> highlightsByFen;

  SavedAnalysis({
    required this.title,
    required this.savedAt,
    required this.pgnText,
    required this.gameTree,
    this.gameAnalysis,
    required this.userLabelsByKey,
    required this.commentsByFen,
    required this.arrowsByFen,
    required this.highlightsByFen,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'savedAt': savedAt.toIso8601String(),
      'pgnText': pgnText,
      'gameTree': gameTree,
      'gameAnalysis': gameAnalysis,
      'userLabelsByKey': userLabelsByKey,
      'commentsByFen': commentsByFen,
      'arrowsByFen': arrowsByFen,
      'highlightsByFen': highlightsByFen,
    };
  }

  factory SavedAnalysis.fromJson(Map<String, dynamic> json) {
    return SavedAnalysis(
      title: json['title'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
      pgnText: json['pgnText'] as String,
      gameTree: json['gameTree'] as Map<String, dynamic>,
      gameAnalysis: json['gameAnalysis'] as Map<String, dynamic>?,
      userLabelsByKey: (json['userLabelsByKey'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<String>.from(value as List)),
      ),
      commentsByFen: (json['commentsByFen'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      ),
      arrowsByFen: (json['arrowsByFen'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          (value as List).map((e) => e as Map<String, dynamic>).toList(),
        ),
      ),
      highlightsByFen: (json['highlightsByFen'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<String>.from(value as List)),
      ),
    );
  }

  String toJsonString() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  factory SavedAnalysis.fromJsonString(String jsonString) {
    return SavedAnalysis.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}
