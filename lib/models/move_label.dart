enum UserLabelCategory {
  tactical,
  strategic,
  pieceActivity,
  positional,
  gamePhase,
  riskProfile,
}

class UserLabel {
  final String id;
  final String name;
  final UserLabelCategory category;

  const UserLabel({
    required this.id,
    required this.name,
    required this.category,
  });
}

class UserLabels {
  // Tactical nature labels
  static const capture = UserLabel(
    id: 'capture',
    name: 'Capture',
    category: UserLabelCategory.tactical,
  );
  static const threat = UserLabel(
    id: 'threat',
    name: 'Threat',
    category: UserLabelCategory.tactical,
  );
  static const check = UserLabel(
    id: 'check',
    name: 'Check',
    category: UserLabelCategory.tactical,
  );
  static const checkmate = UserLabel(
    id: 'checkmate',
    name: 'Checkmate',
    category: UserLabelCategory.tactical,
  );
  static const sacrifice = UserLabel(
    id: 'sacrifice',
    name: 'Sacrifice',
    category: UserLabelCategory.tactical,
  );
  static const discoveredAttack = UserLabel(
    id: 'discovered_attack',
    name: 'Discovered attack',
    category: UserLabelCategory.tactical,
  );
  static const fork = UserLabel(
    id: 'fork',
    name: 'Fork',
    category: UserLabelCategory.tactical,
  );
  static const pin = UserLabel(
    id: 'pin',
    name: 'Pin',
    category: UserLabelCategory.tactical,
  );
  static const skewer = UserLabel(
    id: 'skewer',
    name: 'Skewer',
    category: UserLabelCategory.tactical,
  );
  static const deflection = UserLabel(
    id: 'deflection',
    name: 'Deflection',
    category: UserLabelCategory.tactical,
  );
  static const zwischenzug = UserLabel(
    id: 'zwischenzug',
    name: 'Zwischenzug',
    category: UserLabelCategory.tactical,
  );
  static const decoy = UserLabel(
    id: 'decoy',
    name: 'Decoy',
    category: UserLabelCategory.tactical,
  );
  static const overloading = UserLabel(
    id: 'overloading',
    name: 'Overloading',
    category: UserLabelCategory.tactical,
  );
  static const removingDefender = UserLabel(
    id: 'removing_defender',
    name: 'Removing defender',
    category: UserLabelCategory.tactical,
  );

  // Strategic purpose labels
  static const developing = UserLabel(
    id: 'developing',
    name: 'Developing',
    category: UserLabelCategory.strategic,
  );
  static const improvingPiece = UserLabel(
    id: 'improving_piece',
    name: 'Improving piece',
    category: UserLabelCategory.strategic,
  );
  static const centralization = UserLabel(
    id: 'centralization',
    name: 'Centralization',
    category: UserLabelCategory.strategic,
  );
  static const spaceGain = UserLabel(
    id: 'space_gain',
    name: 'Space gain',
    category: UserLabelCategory.strategic,
  );
  static const prophylaxis = UserLabel(
    id: 'prophylaxis',
    name: 'Prophylaxis',
    category: UserLabelCategory.strategic,
  );
  static const restriction = UserLabel(
    id: 'restriction',
    name: 'Restriction',
    category: UserLabelCategory.strategic,
  );
  static const outpost = UserLabel(
    id: 'outpost',
    name: 'Outpost',
    category: UserLabelCategory.strategic,
  );
  static const pawnBreak = UserLabel(
    id: 'pawn_break',
    name: 'Pawn break',
    category: UserLabelCategory.strategic,
  );
  static const weaknessCreation = UserLabel(
    id: 'weakness_creation',
    name: 'Weakness creation',
    category: UserLabelCategory.strategic,
  );
  static const endgameTransition = UserLabel(
    id: 'endgame_transition',
    name: 'Endgame transition',
    category: UserLabelCategory.strategic,
  );
  static const simplification = UserLabel(
    id: 'simplification',
    name: 'Simplification',
    category: UserLabelCategory.strategic,
  );
  static const complexification = UserLabel(
    id: 'complexification',
    name: 'Complexification',
    category: UserLabelCategory.strategic,
  );

  // Piece activity labels
  static const activation = UserLabel(
    id: 'activation',
    name: 'Activation',
    category: UserLabelCategory.pieceActivity,
  );
  static const retreat = UserLabel(
    id: 'retreat',
    name: 'Retreat',
    category: UserLabelCategory.pieceActivity,
  );
  static const repositioning = UserLabel(
    id: 'repositioning',
    name: 'Repositioning',
    category: UserLabelCategory.pieceActivity,
  );
  static const exchange = UserLabel(
    id: 'exchange',
    name: 'Exchange',
    category: UserLabelCategory.pieceActivity,
  );
  static const tradeDown = UserLabel(
    id: 'trade_down',
    name: 'Trade down',
    category: UserLabelCategory.pieceActivity,
  );
  static const invasion = UserLabel(
    id: 'invasion',
    name: 'Invasion',
    category: UserLabelCategory.pieceActivity,
  );
  static const blockade = UserLabel(
    id: 'blockade',
    name: 'Blockade',
    category: UserLabelCategory.pieceActivity,
  );
  static const defence = UserLabel(
    id: 'defence',
    name: 'Defence',
    category: UserLabelCategory.pieceActivity,
  );
  static const overprotection = UserLabel(
    id: 'overprotection',
    name: 'Overprotection',
    category: UserLabelCategory.pieceActivity,
  );

  // Positional domain labels
  static const kingsideAttack = UserLabel(
    id: 'kingside_attack',
    name: 'Kingside attack',
    category: UserLabelCategory.positional,
  );
  static const queensideExpansion = UserLabel(
    id: 'queenside_expansion',
    name: 'Queenside expansion',
    category: UserLabelCategory.positional,
  );
  static const centralPlay = UserLabel(
    id: 'central_play',
    name: 'Central play',
    category: UserLabelCategory.positional,
  );
  static const backRank = UserLabel(
    id: 'back_rank',
    name: 'Back rank',
    category: UserLabelCategory.positional,
  );
  static const openFileControl = UserLabel(
    id: 'open_file_control',
    name: 'Open file control',
    category: UserLabelCategory.positional,
  );
  static const diagonalControl = UserLabel(
    id: 'diagonal_control',
    name: 'Diagonal control',
    category: UserLabelCategory.positional,
  );
  static const seventhRank = UserLabel(
    id: 'seventh_rank',
    name: '7th rank invasion',
    category: UserLabelCategory.positional,
  );

  // Game phase labels
  static const openingMove = UserLabel(
    id: 'opening_move',
    name: 'Opening move',
    category: UserLabelCategory.gamePhase,
  );
  static const theoretical = UserLabel(
    id: 'theoretical',
    name: 'Theoretical',
    category: UserLabelCategory.gamePhase,
  );
  static const novelty = UserLabel(
    id: 'novelty',
    name: 'Novelty',
    category: UserLabelCategory.gamePhase,
  );
  static const middlegame = UserLabel(
    id: 'middlegame',
    name: 'Middlegame',
    category: UserLabelCategory.gamePhase,
  );
  static const endgameTechnique = UserLabel(
    id: 'endgame_technique',
    name: 'Endgame technique',
    category: UserLabelCategory.gamePhase,
  );
  static const timeScramble = UserLabel(
    id: 'time_scramble',
    name: 'Time scramble',
    category: UserLabelCategory.gamePhase,
  );
  static const practical = UserLabel(
    id: 'practical',
    name: 'Practical',
    category: UserLabelCategory.gamePhase,
  );

  // Risk profile labels
  static const forcing = UserLabel(
    id: 'forcing',
    name: 'Forcing',
    category: UserLabelCategory.riskProfile,
  );
  static const quiet = UserLabel(
    id: 'quiet',
    name: 'Quiet',
    category: UserLabelCategory.riskProfile,
  );
  static const sharp = UserLabel(
    id: 'sharp',
    name: 'Sharp',
    category: UserLabelCategory.riskProfile,
  );
  static const solid = UserLabel(
    id: 'solid',
    name: 'Solid',
    category: UserLabelCategory.riskProfile,
  );
  static const risky = UserLabel(
    id: 'risky',
    name: 'Risky',
    category: UserLabelCategory.riskProfile,
  );
  static const speculative = UserLabel(
    id: 'speculative',
    name: 'Speculative',
    category: UserLabelCategory.riskProfile,
  );
  static const safe = UserLabel(
    id: 'safe',
    name: 'Safe',
    category: UserLabelCategory.riskProfile,
  );
  static const desperation = UserLabel(
    id: 'desperation',
    name: 'Desperation',
    category: UserLabelCategory.riskProfile,
  );

  // Get all labels
  static List<UserLabel> get allLabels => [
    // Tactical
    capture,
    threat,
    check,
    checkmate,
    sacrifice,
    discoveredAttack,
    fork,
    pin,
    skewer,
    deflection,
    zwischenzug,
    decoy,
    overloading,
    removingDefender,
    // Strategic
    developing,
    improvingPiece,
    centralization,
    spaceGain,
    prophylaxis,
    restriction,
    outpost,
    pawnBreak,
    weaknessCreation,
    endgameTransition,
    simplification,
    complexification,
    // Piece activity
    activation,
    retreat,
    repositioning,
    exchange,
    tradeDown,
    invasion,
    blockade,
    defence,
    overprotection,
    // Positional
    kingsideAttack,
    queensideExpansion,
    centralPlay,
    backRank,
    openFileControl,
    diagonalControl,
    seventhRank,
    // Game phase
    openingMove,
    theoretical,
    novelty,
    middlegame,
    endgameTechnique,
    timeScramble,
    practical,
    // Risk profile
    forcing,
    quiet,
    sharp,
    solid,
    risky,
    speculative,
    safe,
    desperation,
  ];

  static List<UserLabel> getByCategory(UserLabelCategory category) {
    return allLabels.where((label) => label.category == category).toList();
  }

  static UserLabel? getById(String id) {
    try {
      return allLabels.firstWhere((label) => label.id == id);
    } catch (_) {
      return null;
    }
  }

  static String getCategoryName(UserLabelCategory category) {
    switch (category) {
      case UserLabelCategory.tactical:
        return 'Tactical';
      case UserLabelCategory.strategic:
        return 'Strategic';
      case UserLabelCategory.pieceActivity:
        return 'Piece Activity';
      case UserLabelCategory.positional:
        return 'Positional';
      case UserLabelCategory.gamePhase:
        return 'Game Phase';
      case UserLabelCategory.riskProfile:
        return 'Risk Profile';
    }
  }
}

// Store user labels for a specific move
class MoveUserLabels {
  final int moveIndex;
  final List<String> labelIds; // Store IDs for serialization
  final String? comment;

  MoveUserLabels({
    required this.moveIndex,
    required this.labelIds,
    this.comment,
  });

  List<UserLabel> get labels {
    return labelIds
        .map((id) => UserLabels.getById(id))
        .whereType<UserLabel>()
        .toList();
  }

  MoveUserLabels copyWith({
    int? moveIndex,
    List<String>? labelIds,
    String? comment,
  }) {
    return MoveUserLabels(
      moveIndex: moveIndex ?? this.moveIndex,
      labelIds: labelIds ?? this.labelIds,
      comment: comment ?? this.comment,
    );
  }
}
