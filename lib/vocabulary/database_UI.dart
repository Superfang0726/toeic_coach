import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:toeic_coach/models/vocab.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'package:toeic_coach/vocabulary/excel_repository.dart';
import 'package:toeic_coach/vocabulary/vocabulary_viewmodel.dart';

class DatabaseUi extends StatefulWidget {
  const DatabaseUi({super.key});

  @override
  State<DatabaseUi> createState() => _DatabaseUiState();
}

class _DatabaseUiState extends State<DatabaseUi> {
  late VocabularyViewmodel _vocabularyViewmodel;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _meanController = TextEditingController();
  Level _selectedLevel = Level.red;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _vocabularyViewmodel = VocabularyViewmodel(
      store: context.read<Store>(),
      excelRepository: context.read<ExcelRepository>(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _meanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Vocab> vocabs = context.watch<Store>().vocabulary;

    if (!_isVisible) {
      return IconButton(
        onPressed: () => setState(() => _isVisible = true),
        icon: Icon(Icons.chevron_right),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: height / 2,
              child: IconButton(
                onPressed: () => setState(() {
                  _isVisible = false;
                }),
                icon: Icon(Icons.chevron_right),
              ),
            ),
            Column(
              children: [
                //This Row is where user enter a word
                Row(
                  children: [
                    Expanded(child: TextField(controller: _nameController)),
                    Expanded(child: TextField(controller: _meanController)),
                    DropdownButton<Level>(
                      value: _selectedLevel,
                      items: [
                        DropdownMenuItem(value: Level.red, child: Text('Red')),
                        DropdownMenuItem(
                          value: Level.yellow,
                          child: Text('Yellow'),
                        ),
                        DropdownMenuItem(
                          value: Level.green,
                          child: Text('Green'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedLevel = value);
                        }
                      },
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _vocabularyViewmodel.addVocab(
                          word: _nameController.text,
                          mean: _meanController.text,
                          level: _selectedLevel,
                        );
                        _nameController.clear();
                        _meanController.clear();
                      },
                      child: Icon(Icons.add),
                    ),
                  ],
                ),

                //This is where vocabs list at
                Expanded(
                  child: ListView.builder(
                    itemCount: vocabs.length,
                    itemBuilder: (context, index) {
                      return VocabListItem(
                        vocab: vocabs[index],
                        onDelete: () =>
                            _vocabularyViewmodel.deleteVocab(vocabs[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Row(
        children: [
          Text(widget.vocab.word),
          Text(widget.vocab.mean),
          if (_isHovered)
            IconButton(icon: Icon(Icons.delete), onPressed: widget.onDelete),
        ],
      ),
    );
  }
}
