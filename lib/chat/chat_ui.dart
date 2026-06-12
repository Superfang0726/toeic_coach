import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toeic_coach/chat/chat_viewmodel.dart';
import 'package:toeic_coach/models/chat_state.dart';
import 'package:toeic_coach/models/option.dart';
import 'package:toeic_coach/store/app_store.dart';
import 'package:toeic_coach/theme/app_theme.dart';
import 'package:toeic_coach/vocabulary/vocabulary_viewmodel.dart';

class ChatUi extends StatefulWidget {
  //constructor
  const ChatUi({super.key});

  @override
  State<ChatUi> createState() => _ChatUiState();
}

class _ChatUiState extends State<ChatUi> {
  late ChatViewModel _chatViewModel;

  // Scrolls the review page to the bottom the first time it is shown so the
  // latest feedback is visible. Re-armed each time we leave the review state.
  final ScrollController _reviewScrollController = ScrollController();
  bool _reviewScrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    _chatViewModel = ChatViewModel(
      store: context.read<Store>(),
      vocabularyViewModel: context.read<VocabularyViewmodel>(),
    );
    _chatViewModel.initGenerativeModels();
  }

  @override
  void dispose() {
    _reviewScrollController.dispose();
    super.dispose();
  }

  // A page to wait user confirm question generation
  Widget _buildStartView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _ChatCard(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error banner — shown only when the last attempt failed
              // with a permanent error (e.g. invalid API key).
              if (_chatViewModel.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: kError.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: kError),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: kError, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _chatViewModel.errorMessage!,
                          style: const TextStyle(color: kError),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Circular icon badge.
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: kPrimaryLight,
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 40,
                  color: kPrimary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '準備好開始了嗎？',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '點擊下方按鈕，為你生成一題 TOEIC 練習。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: kTextSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 240,
                child: _ChatActionButton(
                  enabled: true,
                  icon: Icons.play_arrow_rounded,
                  label: '開始出題',
                  onPressed: () => _chatViewModel.startQuestion(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // display question and option
  Widget _buildQuestionView() {
    final bool hasSelection = _chatViewModel.selectedOption != null;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _ChatCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scrollable content; the submit button stays pinned below.
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Question sentence — soft blue gradient card with
                    // tappable word tokens.
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [kPrimaryLight, kSurface],
                        ),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _chatViewModel.sentence
                            .split(' ')
                            .map(
                              (word) => _WordToken(
                                word: word,
                                unfamiliar: _chatViewModel.unfamiliarWords
                                    .contains(word),
                                onTap: () =>
                                    _chatViewModel.toggleUnfamiliarWord(word),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Options — one card each, A/B/C/D badge.
                    ..._chatViewModel.options.map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildOptionCard(
                          option,
                          _chatViewModel.selectedOption == option,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ChatActionButton(
              enabled: hasSelection,
              icon: Icons.send_rounded,
              label: '送出',
              onPressed: () {
                if (hasSelection) _chatViewModel.submitAnswer();
              },
            ),
          ],
        ),
      ),
    );
  }

  // display review
  Widget _buildReviewView() {
    final String result = _chatViewModel.result ?? '';
    // Prefer the model's structured flag; fall back to the wrong-answer
    // message heuristic ("錯誤") only if the flag is missing.
    final bool isCorrect = _chatViewModel.isCorrect ?? !result.contains('錯誤');
    // Jump to the bottom once when the review first appears. If the content is
    // shorter than the viewport maxScrollExtent is 0, so this is a no-op and the
    // content simply fills from the top.
    if (!_reviewScrolledToBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_reviewScrollController.hasClients) {
          _reviewScrollController.jumpTo(
            _reviewScrollController.position.maxScrollExtent,
          );
          _reviewScrolledToBottom = true;
        }
      });
    }
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _ChatCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scrollable content; the next-question button stays pinned below.
            Expanded(
              child: SingleChildScrollView(
                controller: _reviewScrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [kPrimaryLight, kSurface],
                        ),
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: _chatViewModel.sentence
                            .split(' ')
                            .map(
                              (word) => Text(
                                word,
                                style: TextStyle(
                                  fontSize: 20,
                                  color: kTextPrimary,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Options — one card each, A/B/C/D badge.
                    ..._chatViewModel.options.map(
                      (option) => Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: kSurface,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: _chatViewModel.correctLabel == option.label
                                  ? kPrimary
                                  : kBorder,
                              width: _chatViewModel.correctLabel == option.label
                                  ? 2
                                  : 1,
                            ),
                          ),
                          padding: EdgeInsets.all(12),
                          child: _buildOptionShell(option: option),
                        ),
                      ),
                    ),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: kBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top result strip.
                          Container(
                            height: 4,
                            color: isCorrect ? kSuccess : kError,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 16.0,
                              children: [
                                // Result title + icon.
                                Row(
                                  children: [
                                    Icon(
                                      isCorrect
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: isCorrect ? kSuccess : kError,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '回答結果',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: kTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  result,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: kTextPrimary,
                                  ),
                                ),
                                // Review.
                                if (_chatViewModel.reviewItems.isNotEmpty) ...[
                                  const _ReviewHeading('檢討'),
                                  ..._chatViewModel.reviewItems.map(
                                    (e) => _buildReviewBullet(e),
                                  ),
                                ],
                                // Memory-state adjustments.
                                const _ReviewHeading('記憶狀態調整'),
                                ..._chatViewModel.memoryStateAdjustment.map(
                                  (e) => _buildAdjustmentRow(e),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ChatActionButton(
              enabled: true,
              icon: Icons.arrow_forward_rounded,
              label: '下一題',
              onPressed: () => _chatViewModel.startQuestion(),
            ),
          ],
        ),
      ),
    );
  }

  // A review line prefixed with a bullet.
  Widget _buildReviewBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '•  ',
          style: TextStyle(fontSize: 18, color: kTextSecondary),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, color: kTextSecondary),
          ),
        ),
      ],
    );
  }

  // A memory-state adjustment line: up arrow (green) for an upgrade, down
  // arrow (red) for a downgrade.
  Widget _buildAdjustmentRow(String text) {
    final bool isUpgrade = text.toLowerCase().contains('upgrade');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isUpgrade ? Icons.arrow_upward : Icons.arrow_downward,
          size: 20,
          color: isUpgrade ? kSuccess : kError,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, color: kTextPrimary),
          ),
        ),
      ],
    );
  }

  // A single answer option decorating shell
  Widget _buildOptionShell({
    required Option option,
    Color badgeColor = kPrimaryLight,
    Widget? trailing,
  }) {
    return Row(
      children: [
        // Circular label badge — kept white on a selected (tinted) card so
        // it stays legible.
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: badgeColor),
          child: Text(
            option.label,
            style: const TextStyle(
              color: kPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            option.word,
            style: const TextStyle(fontSize: 18, color: kTextPrimary),
          ),
        ),
        ?trailing,
      ],
    );
  }

  // A single answer option rendered as a card with an A/B/C/D badge.
  Widget _buildOptionCard(Option option, bool selected) {
    return GestureDetector(
      onTap: () => _chatViewModel.toggleOption(option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: selected ? kPrimaryLight : kSurface,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: selected ? kPrimary : kBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: _buildOptionShell(
          option: option,
          badgeColor: selected ? kSurface : kPrimaryLight,
          trailing: selected
              ? const Icon(Icons.check_circle, color: kPrimary)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _chatViewModel,
      builder: (context, _) {
        if (_chatViewModel.chatState == ChatState.waitingUserGenerateQuestion) {
          return _buildStartView();
        } else if (_chatViewModel.chatState == ChatState.generatingQuestion) {
          return _ChatLoading(
            label: 'Generating question…',
            retryTimes: _chatViewModel.retryTimes,
          );
        } else if (_chatViewModel.chatState == ChatState.displayingQuestion) {
          return _buildQuestionView();
        } else if (_chatViewModel.chatState == ChatState.generatingReview) {
          // Re-arm the one-shot scroll-to-bottom. This state always precedes
          // displayingReview, so the review opens scrolled to its latest entry.
          _reviewScrolledToBottom = false;
          return _ChatLoading(
            label: 'Reviewing…',
            retryTimes: _chatViewModel.retryTimes,
          );
        } else if (_chatViewModel.chatState == ChatState.displayingReview) {
          return _buildReviewView();
        } else if (_chatViewModel.chatState ==
            ChatState.failToGenerateQuestion) {
          return _FailureView(
            message: '題目生成失敗，請稍後再試',
            onRetry: () => _chatViewModel.startQuestion(),
          );
        } else if (_chatViewModel.chatState == ChatState.failToGenerateReview) {
          return _FailureView(
            message: '批改失敗，請稍後再試',
            onRetry: () => _chatViewModel.submitAnswer(),
          );
        }
        return Placeholder();
      },
    );
  }
}

/// Centered failure view shown when retries are exhausted. Displays a message
/// and a retry button; the caller wires [onRetry] to the matching action
/// (regenerate question / resubmit answer).
class _FailureView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FailureView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _ChatCard(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular icon badge.
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kError.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 40,
                  color: kError,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 240,
                child: _ChatActionButton(
                  enabled: true,
                  icon: Icons.refresh_rounded,
                  label: '重試',
                  onPressed: onRetry,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered loading view for the generating states. When [retryTimes] is
/// greater than 0 it also shows a "retrying…" hint with the attempt count.
class _ChatLoading extends StatelessWidget {
  final String label;
  final int retryTimes;

  const _ChatLoading({required this.label, this.retryTimes = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _ChatCard(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: kPrimary),
              const SizedBox(height: 16),
              Text(
                label,
                style: const TextStyle(fontSize: 16, color: kTextSecondary),
              ),
              if (retryTimes > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '連線不穩，重試中…（第 $retryTimes 次）',
                  style: const TextStyle(fontSize: 14, color: kWarning),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Section heading inside the review card.
class _ReviewHeading extends StatelessWidget {
  final String text;

  const _ReviewHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: kTextPrimary,
      ),
    );
  }
}

/// Shared elevated card that wraps every chat-state content area.
class _ChatCard extends StatelessWidget {
  final Widget child;

  const _ChatCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A tappable word token in the question sentence. Tapping flags the word as
/// unfamiliar (warm tint + warning underline); hovering an untapped word shows
/// a hint underline.
class _WordToken extends StatefulWidget {
  final String word;
  final bool unfamiliar;
  final VoidCallback onTap;

  const _WordToken({
    required this.word,
    required this.unfamiliar,
    required this.onTap,
  });

  @override
  State<_WordToken> createState() => _WordTokenState();
}

class _WordTokenState extends State<_WordToken> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool showUnderline = widget.unfamiliar || _hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: widget.unfamiliar ? kWarningLight : Colors.transparent,
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: Text(
            widget.word,
            style: TextStyle(
              fontSize: 20,
              color: kTextPrimary,
              decoration: showUnderline
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationColor: widget.unfamiliar ? kWarning : kTextHint,
              decorationThickness: 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width action button (submit / next) with a subtle press-scale.
class _ChatActionButton extends StatefulWidget {
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ChatActionButton({
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_ChatActionButton> createState() => _ChatActionButtonState();
}

class _ChatActionButtonState extends State<_ChatActionButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    // Listener drives the scale animation without consuming the tap, so the
    // FilledButton still handles the press itself.
    return Listener(
      onPointerDown: (_) {
        if (widget.enabled) setState(() => _scale = 0.97);
      },
      onPointerUp: (_) => setState(() => _scale = 1.0),
      onPointerCancel: (_) => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: widget.onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: widget.enabled ? kPrimary : kBorder,
              foregroundColor: widget.enabled ? Colors.white : kTextHint,
              disabledBackgroundColor: kBorder,
              disabledForegroundColor: kTextHint,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.0),
              ),
            ),
            icon: Icon(widget.icon),
            label: Text(widget.label, style: const TextStyle(fontSize: 18)),
          ),
        ),
      ),
    );
  }
}
