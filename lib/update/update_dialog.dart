import 'package:flutter/material.dart';
import 'package:toeic_coach/theme/app_theme.dart';
import 'package:toeic_coach/update/update_viewmodel.dart';

/// The update dialog, driven entirely by [UpdateViewModel].
///
/// Rebuilds on every `notifyListeners()` via [ListenableBuilder] — the same
/// pattern `ChatUi` uses for `ChatViewModel`. Render varies by status:
///   available   -> version + notes + "Update now / Later"
///   downloading -> progress bar
///   error       -> message + Close
///   (other)     -> nothing meaningful; callers only open it when `available`.
class UpdateDialog extends StatelessWidget {
  final UpdateViewModel viewModel;

  const UpdateDialog({super.key, required this.viewModel});

  /// Convenience opener. Use when there's a known available update.
  static Future<void> show(BuildContext context, UpdateViewModel viewModel) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(viewModel: viewModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return AlertDialog(
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            _titleFor(viewModel.status),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
          content: SizedBox(width: 380, child: _content(context)),
          actions: _actions(context),
        );
      },
    );
  }

  String _titleFor(UpdateStatus status) {
    switch (status) {
      case UpdateStatus.downloading:
        return '正在下載更新…';
      case UpdateStatus.error:
        return '更新失敗';
      default:
        return '有新版本可用';
    }
  }

  Widget _content(BuildContext context) {
    switch (viewModel.status) {
      case UpdateStatus.downloading:
        final p = viewModel.progress;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              // Indeterminate when total size is unknown (-1).
              value: p >= 0 ? p : null,
              backgroundColor: kPrimaryLight,
              color: kPrimary,
            ),
            const SizedBox(height: 12),
            Text(
              p >= 0 ? '${(p * 100).toStringAsFixed(0)}%' : '下載中…',
              style: const TextStyle(color: kTextSecondary, fontSize: 13),
            ),
          ],
        );

      case UpdateStatus.error:
        return Text(
          viewModel.errorMessage ?? '發生未知錯誤。',
          style: const TextStyle(color: kError),
        );

      default:
        final latest = viewModel.latest;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '目前版本 ${viewModel.currentVersion} → 新版本 ${latest?.version ?? ''}',
              style: const TextStyle(color: kTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            if ((latest?.notes ?? '').isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    latest!.notes,
                    style: const TextStyle(
                      color: kTextPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
          ],
        );
    }
  }

  List<Widget> _actions(BuildContext context) {
    switch (viewModel.status) {
      case UpdateStatus.downloading:
        return const []; // no buttons mid-download

      case UpdateStatus.error:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('關閉', style: TextStyle(color: kTextSecondary)),
          ),
        ];

      default:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍後', style: TextStyle(color: kTextSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // Fire-and-forget: startUpdate flips status to downloading (which
            // re-renders this dialog) and, on success, exits the app.
            onPressed: () => viewModel.startUpdate(),
            child: const Text('立即更新'),
          ),
        ];
    }
  }
}
