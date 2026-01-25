import 'package:flutter/material.dart';
import '../models/move_label.dart';

class MoveLabelSelector extends StatefulWidget {
  final List<String> selectedLabelIds;
  final int maxLabels;
  final ValueChanged<List<String>> onLabelsChanged;

  const MoveLabelSelector({
    super.key,
    required this.selectedLabelIds,
    required this.maxLabels,
    required this.onLabelsChanged,
  });

  @override
  State<MoveLabelSelector> createState() => _MoveLabelSelectorState();
}

class _MoveLabelSelectorState extends State<MoveLabelSelector> {
  UserLabelCategory? _expandedCategory;
  late List<String> _selectedLabelIds;

  @override
  void initState() {
    super.initState();
    _selectedLabelIds = List.from(widget.selectedLabelIds);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.label_outline,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Move Labels',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_selectedLabelIds.length}/${widget.maxLabels}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            // Selected labels
            if (_selectedLabelIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedLabelIds.map((id) {
                    final label = UserLabels.getById(id);
                    if (label == null) return const SizedBox.shrink();
                    return Chip(
                      label: Text(label.name),
                      onDeleted: () {
                        setState(() {
                          _selectedLabelIds.remove(id);
                        });
                        widget.onLabelsChanged(_selectedLabelIds);
                      },
                      backgroundColor: _getCategoryColor(label.category),
                    );
                  }).toList(),
                ),
              ),
            const Divider(height: 1),
            // Categories
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: UserLabelCategory.values.map((category) {
                  return _buildCategorySection(category);
                }).toList(),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedLabelIds.clear();
                      });
                      widget.onLabelsChanged(_selectedLabelIds);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Clear All'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(UserLabelCategory category) {
    final labels = UserLabels.getByCategory(category);
    final isExpanded = _expandedCategory == category;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Icon(
              _getCategoryIcon(category),
              color: _getCategoryColor(category),
            ),
            title: Text(
              UserLabels.getCategoryName(category),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: () {
              setState(() {
                _expandedCategory = isExpanded ? null : category;
              });
            },
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: labels.map((label) {
                  final isSelected = _selectedLabelIds.contains(label.id);
                  final canAdd = _selectedLabelIds.length < widget.maxLabels;

                  return FilterChip(
                    label: Text(label.name),
                    selected: isSelected,
                    onSelected: (canAdd || isSelected)
                        ? (selected) {
                            setState(() {
                              if (selected) {
                                _selectedLabelIds.add(label.id);
                              } else {
                                _selectedLabelIds.remove(label.id);
                              }
                            });
                            widget.onLabelsChanged(_selectedLabelIds);
                          }
                        : null,
                    backgroundColor: _getCategoryColor(
                      category,
                    ).withOpacity(0.1),
                    selectedColor: _getCategoryColor(category),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Color _getCategoryColor(UserLabelCategory category) {
    switch (category) {
      case UserLabelCategory.tactical:
        return Colors.red.shade700;
      case UserLabelCategory.strategic:
        return Colors.blue.shade700;
      case UserLabelCategory.pieceActivity:
        return Colors.green.shade700;
      case UserLabelCategory.positional:
        return Colors.purple.shade700;
      case UserLabelCategory.gamePhase:
        return Colors.orange.shade700;
      case UserLabelCategory.riskProfile:
        return Colors.teal.shade700;
    }
  }

  IconData _getCategoryIcon(UserLabelCategory category) {
    switch (category) {
      case UserLabelCategory.tactical:
        return Icons.flash_on;
      case UserLabelCategory.strategic:
        return Icons.psychology;
      case UserLabelCategory.pieceActivity:
        return Icons.trending_up;
      case UserLabelCategory.positional:
        return Icons.grid_on;
      case UserLabelCategory.gamePhase:
        return Icons.timeline;
      case UserLabelCategory.riskProfile:
        return Icons.warning_amber;
    }
  }
}
