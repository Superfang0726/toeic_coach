import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/update/update_viewmodel.dart';

void main() {
  group('isVersionNewer', () {
    test('a higher patch is newer', () {
      expect(isVersionNewer('0.2.0', '0.1.0'), isTrue);
    });

    test('equal versions are not newer', () {
      expect(isVersionNewer('0.1.0', '0.1.0'), isFalse);
    });

    test('an older version is not newer', () {
      expect(isVersionNewer('0.1.0', '0.2.0'), isFalse);
    });

    test('compares numerically, not lexically (0.10.0 > 0.9.0)', () {
      expect(isVersionNewer('0.10.0', '0.9.0'), isTrue);
    });

    test('strips a leading v on either side', () {
      expect(isVersionNewer('v0.2.0', '0.1.0'), isTrue);
      expect(isVersionNewer('0.2.0', 'v0.1.0'), isTrue);
    });

    test('ignores build/pre-release suffixes after a dash or plus', () {
      expect(isVersionNewer('0.2.0+5', '0.2.0+1'), isFalse);
      expect(isVersionNewer('0.2.0', '0.2.0-beta'), isFalse);
    });

    test('handles differing segment counts (0.2 vs 0.2.0)', () {
      expect(isVersionNewer('0.2.1', '0.2'), isTrue);
      expect(isVersionNewer('0.2', '0.2.0'), isFalse);
    });

    test('malformed input is treated as not newer', () {
      expect(isVersionNewer('abc', '0.1.0'), isFalse);
    });
  });
}
