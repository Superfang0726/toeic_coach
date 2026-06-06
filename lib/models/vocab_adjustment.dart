enum Adjustment { upgrade, downgrade }

class VocabAdjustment {
  final String _word;
  final String _mean;
  final Adjustment _adjustment;

  String get word => _word;
  String get mean => _mean;
  Adjustment get adjustment => _adjustment;

  const VocabAdjustment({
    required this._word,
    required this._mean,
    required this._adjustment,
  });
}
