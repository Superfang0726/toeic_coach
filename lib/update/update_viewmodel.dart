import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:toeic_coach/models/release_info.dart';
import 'package:toeic_coach/update/update_repository.dart';

/// The phases the update flow can be in. The UI renders a different view for
/// each, mirroring how [ChatState] drives the chat UI.
enum UpdateStatus { idle, checking, upToDate, available, downloading, error }

/// Coordinates the update check/download, exposing state for the UI to render.
///
/// Middle layer in UI -> ViewModel -> Repository. A [ChangeNotifier] so the
/// dialog can listen via `ListenableBuilder`, the same pattern `ChatUi` uses
/// for `ChatViewModel`.
class UpdateViewModel extends ChangeNotifier {
  final UpdateRepository _repository;

  UpdateViewModel({UpdateRepository? repository})
    : _repository = repository ?? UpdateRepository();

  UpdateStatus _status = UpdateStatus.idle;
  ReleaseInfo? _latest;
  String _currentVersion = '';
  double _progress = 0; // 0..1, or -1 when total size is unknown
  String? _errorMessage;

  UpdateStatus get status => _status;
  ReleaseInfo? get latest => _latest;
  String get currentVersion => _currentVersion;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;

  void _set(UpdateStatus status) {
    _status = status;
    notifyListeners();
  }

  /// Checks GitHub for a newer release. Never throws — on any problem it ends
  /// in [UpdateStatus.upToDate] (silent) so a failed check never blocks the
  /// app. Sets [UpdateStatus.available] only when a strictly newer version with
  /// an installer asset exists.
  Future<void> checkForUpdate() async {
    _set(UpdateStatus.checking);

    final info = await PackageInfo.fromPlatform();
    _currentVersion = info.version;

    final latest = await _repository.fetchLatestRelease();
    if (latest != null && isVersionNewer(latest.version, _currentVersion)) {
      _latest = latest;
      _set(UpdateStatus.available);
    } else {
      _set(UpdateStatus.upToDate);
    }
  }

  /// Downloads the held release's installer and runs it (which exits the app).
  /// Requires [status] == available. On failure moves to [UpdateStatus.error].
  Future<void> startUpdate() async {
    final latest = _latest;
    if (latest == null) return;

    _progress = 0;
    _set(UpdateStatus.downloading);
    try {
      final installer = await _repository.downloadInstaller(
        latest.installerUrl,
        (p) {
          _progress = p;
          notifyListeners();
        },
      );
      await _repository.runInstallerAndExit(installer); // exits the process
    } catch (e) {
      _errorMessage = '更新失敗：$e';
      _set(UpdateStatus.error);
    }
  }
}

/// Returns true when [latest] is a strictly higher semantic version than
/// [current]. Pure and side-effect free so it can be unit-tested in isolation.
///
/// Rules: strip a leading `v`; drop any `-pre`/`+build` suffix; compare the
/// dot-separated numeric segments left-to-right; missing segments count as 0.
/// Any malformed (non-numeric) input is treated as "not newer".
bool isVersionNewer(String latest, String current) {
  final a = _segments(latest);
  final b = _segments(current);
  if (a == null || b == null) return false;

  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final ai = i < a.length ? a[i] : 0;
    final bi = i < b.length ? b[i] : 0;
    if (ai != bi) return ai > bi;
  }
  return false; // all segments equal
}

/// Parses `"v0.10.0+3"` -> `[0, 10, 0]`. Returns null if any core segment is
/// not a number.
List<int>? _segments(String version) {
  var v = version.trim();
  if (v.startsWith('v')) v = v.substring(1);
  // Cut off pre-release (`-beta`) and build metadata (`+5`) parts.
  v = v.split(RegExp(r'[-+]')).first;
  final parts = v.split('.');
  final result = <int>[];
  for (final part in parts) {
    final n = int.tryParse(part);
    if (n == null) return null;
    result.add(n);
  }
  return result.isEmpty ? null : result;
}
