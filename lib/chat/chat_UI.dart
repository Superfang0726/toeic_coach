import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toeic_coach/chat/chat_viewmodel.dart';
import 'package:toeic_coach/models/chat_state.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'package:toeic_coach/vocabulary/vocabulary_viewmodel.dart';

class ChatUi extends StatefulWidget {
  //constructor
  const ChatUi({super.key});

  @override
  State<ChatUi> createState() => _ChatUiState();
}

class _ChatUiState extends State<ChatUi> {
  late ChatViewModel _chatViewModel;

  @override
  void initState() {
    super.initState();
    _chatViewModel = ChatViewModel(
      store: context.read<Store>(),
      vocabularyViewModel: context.read<VocabularyViewmodel>(),
    );
    _chatViewModel.initGenerativeModels();
    _chatViewModel.startQuestion();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _chatViewModel,
      builder: (context, _) {
        if (_chatViewModel.chatState == ChatState.generatingQuestion) {
          return Container(
            alignment: AlignmentGeometry.center,
            child: Text('Generating Question'),
          );
        } else if (_chatViewModel.chatState == ChatState.displayingQuestion) {
          return Container(
            padding: EdgeInsets.all(16.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: BoxBorder.all(color: Colors.grey),
                borderRadius: BorderRadius.all(Radius.circular(16.0)),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 20.0,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.fromARGB(20, 16, 24, 40),
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Wrap(
                          spacing: 10.0,
                          children: _chatViewModel.sentence
                              .split(' ')
                              .map(
                                (word) => AnimatedContainer(
                                  duration: Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    color:
                                        _chatViewModel.unfamiliarWords.contains(
                                          word,
                                        )
                                        ? const Color.fromARGB(
                                            255,
                                            162,
                                            191,
                                            214,
                                          )
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: GestureDetector(
                                    onTap: () => _chatViewModel
                                        .toggleUnfamiliarWord(word),
                                    child: Text(
                                      word,
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.fromARGB(20, 16, 24, 40),
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          spacing: 20,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _chatViewModel.options
                              .map(
                                (option) => AnimatedContainer(
                                  duration: Duration(milliseconds: 300),
                                  decoration: BoxDecoration(
                                    color:
                                        _chatViewModel.selectedOption == option
                                        ? const Color.fromARGB(
                                            255,
                                            162,
                                            191,
                                            214,
                                          )
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: GestureDetector(
                                    onTap: () =>
                                        _chatViewModel.toggleOption(option),
                                    child: Text(
                                      '${option.label} ${option.word}',
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    Spacer(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: _chatViewModel.selectedOption == null
                            ? Color.fromARGB(20, 16, 24, 40)
                            : Colors.blueAccent,
                        border: BoxBorder.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: GestureDetector(
                        onTap: () {
                          if (_chatViewModel.selectedOption != null) {
                            _chatViewModel.submitAnswer();
                          }
                        },
                        child: Text(
                          '送出',
                          style: TextStyle(fontSize: 30.0),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (_chatViewModel.chatState == ChatState.generatingReview) {
          return Container(
            alignment: AlignmentGeometry.center,
            child: Text('Generating review'),
          );
        } else if (_chatViewModel.chatState == ChatState.displayingReview) {
          return Container(
            padding: EdgeInsets.all(16.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: BoxBorder.all(color: Colors.grey),
                borderRadius: BorderRadius.all(Radius.circular(16.0)),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 20.0,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.fromARGB(20, 16, 24, 40),
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 20.0,
                          children: [
                            Text('回答結果', style: TextStyle(fontSize: 30)),
                            Text(
                              _chatViewModel.result ?? '',
                              style: TextStyle(fontSize: 20),
                            ),
                            Text('檢討', style: TextStyle(fontSize: 30)),
                            ...(_chatViewModel.reviewItems)
                                .map(
                                  (e) => Text(
                                    e ?? '',
                                    style: TextStyle(fontSize: 20),
                                  ),
                                )
                                .toList(),
                            Text('記憶狀態調整', style: TextStyle(fontSize: 30)),
                            ...(_chatViewModel.memoryStateAdjustment).map(
                              (e) =>
                                  Text(e ?? '', style: TextStyle(fontSize: 20)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Spacer(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.fromARGB(20, 16, 24, 40),
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 20.0,
                          children: [
                            GestureDetector(
                              onTap: () => _chatViewModel.startQuestion(),
                              child: Text(
                                '下一題',
                                style: TextStyle(fontSize: 30.0),
                              ),
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
        return Placeholder();
      },
    );
  }
}
