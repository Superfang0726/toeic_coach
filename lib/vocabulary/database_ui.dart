import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'package:toeic_coach/theme/app_theme.dart';
import 'package:toeic_coach/vocabulary/vocabulary_viewmodel.dart';

class DatabaseUi extends StatefulWidget {
  final ValueChanged<bool> onToggle;
  final bool isVisible;

  //constructor
  const DatabaseUi({
    super.key,
    required this.isVisible,
    required this.onToggle,
  });

  @override
  State<DatabaseUi> createState() => _DatabaseUiState();
}

class _DatabaseUiState extends State<DatabaseUi> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _meanController = TextEditingController();
  Level _selectedLevel = Level.red;

  @override
  void initState() {
    super.initState();
    // Rebuild whenever either field changes so the Add button can enable /
    // disable itself based on whether both fields have input.
    _nameController.addListener(_onInputChanged);
    _meanController.addListener(_onInputChanged);
  }

  void _onInputChanged() => setState(() {});

  // Add is only allowed when both Word and Meaning have non-whitespace input.
  bool get _canAdd =>
      _nameController.text.trim().isNotEmpty &&
      _meanController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _meanController.dispose();
    super.dispose();
  }

  // Outlined input box for the word / mean fields. Each field gets its own
  // border so the two inputs read as clearly separate boxes.
  InputDecoration _inputDecoration(String label) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: kSurface,
      labelStyle: const TextStyle(color: kTextSecondary),
      border: border(kBorder, 1),
      enabledBorder: border(kBorder, 1),
      focusedBorder: border(kPrimary, 2),
    );
  }

  // A ChoiceChip for the level selector, tinted with the level's own color
  // when selected.
  Widget _levelChip(Level level, String label, Color color) {
    final bool selected = _selectedLevel == level;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      backgroundColor: kSurface,
      selectedColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: selected ? color : kBorder),
      labelStyle: TextStyle(
        color: selected ? kTextPrimary : kTextSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      onSelected: (_) => setState(() => _selectedLevel = level),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Vocab> vocabs = context.watch<Store>().vocabulary;

    // Collapsed rail: a small FAB to expand the panel.
    if (!widget.isVisible) {
      return Center(
        child: FloatingActionButton.small(
          heroTag: 'expandDatabase',
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          onPressed: () => widget.onToggle(true),
          child: const Icon(Icons.chevron_left),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      // Panel frame — mirrors the left chat pane: surface fill, rounded
      // corners, 1px border.
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Input area card.
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Word + mean: two separately outlined boxes.
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  decoration: _inputDecoration('Word'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _meanController,
                                  decoration: _inputDecoration('Meaning'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Level chips + add button.
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    _levelChip(Level.red, '🔴 Red', kError),
                                    _levelChip(
                                      Level.yellow,
                                      '🟡 Yellow',
                                      kWarning,
                                    ),
                                    _levelChip(
                                      Level.green,
                                      '🟢 Green',
                                      kSuccess,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: _canAdd
                                    ? () {
                                        context
                                            .read<VocabularyViewmodel>()
                                            .addVocab(
                                              word: _nameController.text.trim(),
                                              mean: _meanController.text.trim(),
                                              level: _selectedLevel,
                                            );
                                        _nameController.clear();
                                        _meanController.clear();
                                      }
                                    : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: kPrimary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Add'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  //This is where vocabs list at
                  Expanded(
                    child: ListView.builder(
                      itemCount: vocabs.length,
                      itemBuilder: (context, index) {
                        return VocabListItem(
                          vocab: vocabs[index],
                          onDelete: () => context
                              .read<VocabularyViewmodel>()
                              .deleteVocab(vocabs[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            //DatabaseUI fold Button
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: FloatingActionButton.small(
                  heroTag: 'collapseDatabase',
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  onPressed: () => widget.onToggle(false),
                  child: const Icon(Icons.chevron_right),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

///
///VocabListItem is every vocab object displays on databaseUI
///
class VocabListItem extends StatefulWidget {
  final Vocab vocab;
  final VoidCallback onDelete;

  const VocabListItem({super.key, required this.vocab, required this.onDelete});

  @override
  State<VocabListItem> createState() => _VocabListItemState();
}

class _VocabListItemState extends State<VocabListItem> {
  bool _isHovered = false;

  Color get _levelColor {
    switch (widget.vocab.level) {
      case Level.red:
        return kError;
      case Level.yellow:
        return kWarning;
      case Level.green:
        return kSuccess;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _isHovered ? kPrimaryLight : kSurface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left 4px color strip based on level.
              Container(width: 4, color: _levelColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.vocab.word,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.vocab.mean,
                          style: const TextStyle(color: kTextSecondary),
                        ),
                      ),
                      // Right-side memory-state dot (gradient low -> high).
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kMemoryStateGradient[widget
                              .vocab
                              .memoryState
                              .index],
                        ),
                      ),
                      // Reserve width so the row doesn't jump on hover.
                      SizedBox(
                        width: 40,
                        child: _isHovered
                            ? IconButton(
                                icon: const Icon(Icons.delete, color: kError),
                                onPressed: widget.onDelete,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
