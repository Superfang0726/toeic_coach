import 'dart:async';

import 'package:google_generative_ai/google_generative_ai.dart';

class RetryHandler {
  static Future<String?> retryHandler(
    Future<String> Function() callback,
    int maxTimes, {
    void Function(int)? onRetry,
  }) async {
    int times = 0;
    String? response;
    for (; times < maxTimes; ++times) {
      try {
        response = await callback();
        return response;
      } on GenerativeAIException catch (error) {
        onRetry?.call(times + 1);
        print(error);
        continue;
      }
    }
    return null;
  }
}
