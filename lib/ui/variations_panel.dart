import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/variation.dart';
import '../state/chess_controller.dart';

class VariationsPanel extends StatelessWidget {
  const VariationsPanel({
    super.key,
    required this.gameTree,
    required this.onVariationSelected,
  });

  final GameTree gameTree;
  final ValueChanged<String> onVariationSelected;

  @override
  Widget build(BuildContext context) {
    final mainLine = gameTree.getMainLine();
    final sideLines = gameTree.getSideLines();

    if (mainLine == null && sideLines.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No variations yet.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mainLine != null)
          _buildVariationTile(
            context,
            mainLine,
            isMainLine: true,
            isSelected: gameTree.currentVariationId == mainLine.id,
          ),
        if (sideLines.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              'Side Lines',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          ...sideLines.map(
            (variation) => _buildVariationTile(
              context,
              variation,
              isMainLine: false,
              isSelected: gameTree.currentVariationId == variation.id,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVariationTile(
    BuildContext context,
    Variation variation, {
    required bool isMainLine,
    required bool isSelected,
  }) {
    final icon = isMainLine ? Icons.timeline : Icons.call_split;
    final subtitle = isMainLine
        ? '${variation.moves.length} moves'
        : 'From move ${variation.startPosition + 1} • ${variation.moves.length} moves';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: isSelected ? 3 : 1,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
        title: Text(
          variation.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isSelected
                ? Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer.withOpacity(0.7)
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        trailing: isMainLine
            ? (isSelected
                  ? Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    )
                  : null)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Delete variation',
                    onPressed: () {
                      _showDeleteConfirmation(context, variation);
                    },
                  ),
                ],
              ),
        onTap: () => onVariationSelected(variation.id),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Variation variation) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Variation'),
          content: Text(
            'Are you sure you want to delete "${variation.name}"?\n\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                final chess = context.read<ChessController>();
                final success = chess.deleteVariation(variation.id);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${variation.name} deleted'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
