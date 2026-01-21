class Variation {
  final String id;
  final String name;
  final List<String> moves;
  final int
  startPosition; // Position in parent line where this variation branches
  final String? parentId; // null for main line

  Variation({
    required this.id,
    required this.name,
    required this.moves,
    required this.startPosition,
    this.parentId,
  });

  Variation copyWith({
    String? id,
    String? name,
    List<String>? moves,
    int? startPosition,
    String? parentId,
  }) {
    return Variation(
      id: id ?? this.id,
      name: name ?? this.name,
      moves: moves ?? List.from(this.moves),
      startPosition: startPosition ?? this.startPosition,
      parentId: parentId ?? this.parentId,
    );
  }
}

class GameTree {
  final Map<String, Variation> variations;
  final String currentVariationId;

  GameTree({required this.variations, required this.currentVariationId});

  Variation get currentVariation => variations[currentVariationId]!;

  Variation? getMainLine() {
    return variations.values.firstWhere(
      (v) => v.parentId == null,
      orElse: () => variations.values.first,
    );
  }

  List<Variation> getSideLines() {
    return variations.values.where((v) => v.parentId != null).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  GameTree copyWith({
    Map<String, Variation>? variations,
    String? currentVariationId,
  }) {
    return GameTree(
      variations: variations ?? Map.from(this.variations),
      currentVariationId: currentVariationId ?? this.currentVariationId,
    );
  }
}
