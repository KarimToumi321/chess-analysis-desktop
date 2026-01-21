import 'package:flutter/material.dart';

class MoveList extends StatelessWidget {
  const MoveList({
    super.key,
    required this.moves,
    required this.currentIndex,
    required this.onSelect,
    this.onCreateVariation,
  });

  final List<String> moves;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback? onCreateVariation;

  @override
  Widget build(BuildContext context) {
    if (moves.isEmpty) {
      return const Center(child: Text('No moves loaded.'));
    }

    return Column(
      children: [
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

              return ListTile(
                dense: true,
                title: Text('$prefix ${moves[index]}'),
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
