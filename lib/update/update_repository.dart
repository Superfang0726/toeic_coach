import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:toeic_coach/models/release_info.dart';

/// Talks to GitHub Releases: fetches the latest release metadata, downloads the
/// Windows installer, and launches it.
///
/// External layer in the UI -> ViewModel -> Repository chain. All network/IO
/// failures surface as exceptions or a null result; the ViewModel decides how
/// to present them.
class UpdateRepository {
  // The public repo to check. Unauthenticated GitHub API calls are limited to
  // 60/hour per IP, which is plenty for occasional update checks.
  static const String _owner = 'Superfang0726';
  static const String _repo = 'toeic_coach';

  static final Uri _latestReleaseUri = Uri.parse(
    'https://api.github.com/repos/$_owner/$_repo/releases/latest',
  );

  /// Returns the newest published release, or `null` when it can't be reached
  /// (offline, no releases yet, or a malformed response). Updates are
  /// best-effort: the app must stay fully usable when this returns null.
  Future<ReleaseInfo?> fetchLatestRelease() async {
    try {
      final response = await http.get(
        _latestReleaseUri,
        headers: const {'Accept': 'application/vnd.github+json'},
      );
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      final tag = (json['tag_name'] as String?)?.trim();
      if (tag == null || tag.isEmpty) return null;

      // Find the installer asset by naming convention (see .claude/skills/releasing-toeic-coach).
      final assets = (json['assets'] as List<dynamic>? ?? []);
      String? installerUrl;
      for (final asset in assets) {
        final map = asset as Map<String, dynamic>;
        final name = (map['name'] as String?) ?? '';
        if (name.toLowerCase().endsWith('-setup.exe')) {
          installerUrl = map['browser_download_url'] as String?;
          break;
        }
      }
      if (installerUrl == null) return null;

      return ReleaseInfo(
        version: _stripV(tag),
        notes: (json['body'] as String?)?.trim() ?? '',
        installerUrl: installerUrl,
      );
    } catch (e) {
      // Swallow network/parse errors — treated as "no update available".
      print('UpdateRepository.fetchLatestRelease failed: $e');
      return null;
    }
  }

  /// Streams the installer to a temp file, reporting progress in the range
  /// 0.0..1.0. Reports -1 (indeterminate) when the server omits content-length.
  Future<File> downloadInstaller(
    String url,
    void Function(double progress) onProgress,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw HttpException('Download failed (HTTP ${response.statusCode})');
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = url.split('/').last;
      final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
      final sink = file.openWrite();

      final total = response.contentLength ?? -1;
      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(total > 0 ? received / total : -1);
      }
      await sink.flush();
      await sink.close();
      return file;
    } finally {
      client.close();
    }
  }

  /// Launches the downloaded installer detached, then exits the app so the
  /// installer can close/replace the running files. Inno Setup is configured
  /// with CloseApplications to close the running app; its [Run] section
  /// relaunches the new version.
  Future<void> runInstallerAndExit(File installer) async {
    await Process.start(
      installer.path,
      const ["/VERYSILENT", "/NORESTART", "/SUPPRESSMSGBOXES", "/SP-"],
      mode: ProcessStartMode.detached,
      runInShell: true,
    );
    exit(0);
  }

  String _stripV(String tag) => tag.startsWith('v') ? tag.substring(1) : tag;
}
