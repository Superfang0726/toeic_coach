/// Describes the newest release published on GitHub, as needed by the updater.
///
/// Immutable value class — like [VocabAdjustment], it carries data from an
/// external source (the GitHub Releases API) into the app without behavior.
class ReleaseInfo {
  /// Version string with any leading `v` stripped, e.g. `0.2.0`.
  final String version;

  /// Human-readable release notes (the GitHub release body, may be empty).
  final String notes;

  /// Direct download URL of the Windows installer asset (`*-setup.exe`).
  final String installerUrl;

  const ReleaseInfo({
    required this.version,
    required this.notes,
    required this.installerUrl,
  });
}
