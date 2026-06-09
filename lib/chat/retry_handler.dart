import 'dart:async';
import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';

class RetryHandler {
  /// Retries [callback] on transient errors up to [maxTimes] with exponential
  /// backoff. Each attempt is bounded by [timeout]; exceeding it counts as a
  /// transient failure. Non-transient errors (bad/empty API key, permission
  /// denied, unsupported location, bad request) propagate immediately so the
  /// caller can fail fast. Returns null when retries are exhausted.
  static Future<String?> retryHandler(
    Future<String> Function() callback,
    int maxTimes, {
    void Function(int)? onRetry,
    Duration baseDelay = const Duration(milliseconds: 500),
    Duration timeout = const Duration(seconds: 15),
  }) async {
    for (int times = 0; times < maxTimes; ++times) {
      try {
        return await callback().timeout(timeout);
      } catch (error) {
        if (!_isRetryable(error)) rethrow; // permanent → fail fast
        await _backoff(times, error, maxTimes, onRetry, baseDelay);
      }
    }
    return null;
  }

  /// Whether [error] is worth retrying.
  ///
  /// The SDK's exception types are unreliable for this: it only tags
  /// [InvalidApiKey] when the error body literally carries
  /// `reason: API_KEY_INVALID`. An empty key returns a different
  /// error ("unregistered callers" / permission denied) that the SDK cannot
  /// categorise, so it falls through to the generic [ServerException]. Genuine
  /// 5xx server errors, by contrast, arrive as the *base* [GenerativeAIException]
  /// with a "Server Error [5xx]" message. So we classify by what we are
  /// confident is transient, and treat everything else as permanent.
  static bool _isRetryable(Object error) {
    // Network layer — almost always transient.
    if (error is SocketException || error is TimeoutException) return true;
    // 5xx server errors are transient; the bad-key / permission / bad-request
    // cases (InvalidApiKey, UnsupportedUserLocation, or a generic
    // ServerException like "unregistered callers") are not.
    if (error is InvalidApiKey || error is UnsupportedUserLocation) {
      return false;
    }
    if (error is GenerativeAIException) {
      return error.message.contains('Server Error [5');
    }
    return false;
  }

  static Future<void> _backoff(
    int times,
    Object error,
    int maxTimes,
    void Function(int)? onRetry,
    Duration baseDelay,
  ) async {
    onRetry?.call(times + 1);
    print('Retry ${times + 1}/$maxTimes after transient error: $error');
    if (times + 1 < maxTimes) {
      await Future.delayed(baseDelay * (1 << times));
    }
  }
}
