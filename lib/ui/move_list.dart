import 'package:flutter/material.dart';
import '../models/move_analysis.dart';

class MoveList extends StatelessWidget {
  const MoveList({
    super.key,
    required this.moves,
    required this.currentIndex,
    required this.onSelect,
    this.onCreateVariation,
    this.gameAnalysis,
  });

  final List<String> moves;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback? onCreateVariation;
  final GameAnalysis? gameAnalysis;

  @override
  Widget build(BuildContext context) {
    if (moves.isEmpty) {
      return const Center(child: Text('No moves loaded.'));
    }

    return Column(
      children: [
        if (gameAnalysis != null) ...[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _AccuracyCard(
                    label: 'White',
                    accuracy: gameAnalysis!.whiteAccuracy,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AccuracyCard(
                    label: 'Black',
                    accuracy: gameAnalysis!.blackAccuracy,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (onCreateVariation != null && currentIndex > 0)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onCreateVariation,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Create Variation'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: moves.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final isActive = index == currentIndex - 1;
              final moveNo = (index ~/ 2) + 1;
              final prefix = index.isEven ? '$moveNo.' : '...';

              // Get move analysis if available
              final moveAnalysis = gameAnalysis?.getMoveAnalysis(index);

              return ListTile(
                dense: true,
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text('$prefix ${moves[index]}'),
                    if (moveAnalysis != null) ...[
                      _ClassificationBadge(
                        classification: moveAnalysis.classification,
                      ),
                      ...moveAnalysis.tags.map((t) => _TagChip(tag: t)),
                    ],
                  ],
                ),
                selected: isActive,
                selectedTileColor: const Color(0xFFE6EEF9),
                onTap: () => onSelect(index + 1),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AccuracyCard extends StatelessWidget {
  final String label;
  final double accuracy;

  const _AccuracyCard({required this.label, required this.accuracy});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              '${accuracy.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: _getAccuracyColor(accuracy),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 90) return Colors.green;
    if (accuracy >= 80) return Colors.lightGreen;
    if (accuracy >= 70) return Colors.orange;
    return Colors.red;
  }
}

class _ClassificationBadge extends StatelessWidget {
  final MoveClassification classification;

  const _ClassificationBadge({required this.classification});

  @override
  Widget build(BuildContext context) {
    final config = _getClassificationConfig();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: config.color, width: 1),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: config.color,
        ),
      ),
    );
  }

  _BadgeConfig _getClassificationConfig() {
    switch (classification) {
      case MoveClassification.best:
        return _BadgeConfig('Best', Colors.green.shade700);
      case MoveClassification.great:
        return _BadgeConfig('Great', Colors.purple.shade700);
      case MoveClassification.excellent:
        return _BadgeConfig('Exc', Colors.green.shade600);
      case MoveClassification.good:
        return _BadgeConfig('Good', Colors.lightGreen.shade700);
      case MoveClassification.inaccuracy:
        return _BadgeConfig('?!', Colors.orange.shade700);
      case MoveClassification.mistake:
        return _BadgeConfig('?', Colors.deepOrange.shade700);
      case MoveClassification.miss:
        return _BadgeConfig('Miss', Colors.blueGrey.shade700);
      case MoveClassification.blunder:
        return _BadgeConfig('??', Colors.red.shade700);
      case MoveClassification.brilliant:
        return _BadgeConfig('!!', Colors.cyan.shade700);
    }
  }
}

class _TagChip extends StatelessWidget {
  final MoveTag tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final config = _getTagConfig();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: config.color, width: 1),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: config.color,
        ),
      ),
    );
  }

  _BadgeConfig _getTagConfig() {
    switch (tag) {
      case MoveTag.forced:
        return _BadgeConfig('Forced', Colors.indigo.shade700);
      case MoveTag.onlyMove:
        return _BadgeConfig('Only move', Colors.teal.shade700);
    }
  }
}

class _BadgeConfig {
  final String label;
  final Color color;

  _BadgeConfig(this.label, this.color);
}
