import 'package:flutter_test/flutter_test.dart';
import 'package:toeic_coach/chat/retry_handler.dart';

void main() {
  test('retries a ScheduledAnswerMissingException then succeeds', () async {
    int attempts = 0;
    final result = await RetryHandler.retryHandler(
      () async {
        attempts++;
        if (attempts < 3) throw ScheduledAnswerMissingException('orientation');
        return 'ok';
      },
      5,
      baseDelay: Duration.zero,
    );
    expect(result, 'ok');
    expect(attempts, 3);
  });

  test('returns null when the scheduled word is never placed', () async {
    int attempts = 0;
    final result = await RetryHandler.retryHandler(
      () async {
        attempts++;
        throw ScheduledAnswerMissingException('orientation');
      },
      5,
      baseDelay: Duration.zero,
    );
    expect(result, isNull);
    expect(attempts, 5);
  });
}
