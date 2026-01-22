enum MoveLabelHarshness { easy, normal, harsh, extreme, crazyHarsh }

class MoveLabelingThresholds {
  final double greatMax;
  final double excellentMax;
  final double goodMax;
  final double inaccuracyMax;
  final double mistakeMax;

  /// When the position is already clearly decided, thresholds are multiplied by this.
  final double decidedScale;

  /// Absolute eval (in centipawns, player-perspective) above which the position is treated as decided.
  final double decidedAbsEvalThreshold;

  const MoveLabelingThresholds({
    required this.greatMax,
    required this.excellentMax,
    required this.goodMax,
    required this.inaccuracyMax,
    required this.mistakeMax,
    required this.decidedScale,
    required this.decidedAbsEvalThreshold,
  });

  static const MoveLabelingThresholds normal = MoveLabelingThresholds(
    greatMax: 10,
    excellentMax: 30,
    goodMax: 80,
    inaccuracyMax: 200,
    mistakeMax: 500,
    decidedScale: 1.10,
    decidedAbsEvalThreshold: 600,
  );

  static const Map<MoveLabelHarshness, MoveLabelingThresholds> byHarshness = {
    MoveLabelHarshness.easy: MoveLabelingThresholds(
      greatMax: 15,
      excellentMax: 45,
      goodMax: 110,
      inaccuracyMax: 260,
      mistakeMax: 650,
      decidedScale: 1.15,
      decidedAbsEvalThreshold: 600,
    ),
    MoveLabelHarshness.normal: normal,
    MoveLabelHarshness.harsh: MoveLabelingThresholds(
      greatMax: 8,
      excellentMax: 25,
      goodMax: 60,
      inaccuracyMax: 150,
      mistakeMax: 350,
      decidedScale: 1.0,
      decidedAbsEvalThreshold: 600,
    ),
    MoveLabelHarshness.extreme: MoveLabelingThresholds(
      greatMax: 5,
      excellentMax: 15,
      goodMax: 40,
      inaccuracyMax: 100,
      mistakeMax: 250,
      decidedScale: 0.95,
      decidedAbsEvalThreshold: 600,
    ),
    MoveLabelHarshness.crazyHarsh: MoveLabelingThresholds(
      greatMax: 2,
      excellentMax: 6,
      goodMax: 15,
      inaccuracyMax: 35,
      mistakeMax: 80,
      decidedScale: 0.85,
      decidedAbsEvalThreshold: 600,
    ),
  };
}

String moveLabelHarshnessLabel(MoveLabelHarshness h) {
  switch (h) {
    case MoveLabelHarshness.easy:
      return 'Easy';
    case MoveLabelHarshness.normal:
      return 'Normal';
    case MoveLabelHarshness.harsh:
      return 'Harsh';
    case MoveLabelHarshness.extreme:
      return 'Extreme';
    case MoveLabelHarshness.crazyHarsh:
      return 'Crazy harsh';
  }
}
