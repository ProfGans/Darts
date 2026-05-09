class SpeechRecognitionSnapshot {
  const SpeechRecognitionSnapshot({
    required this.primaryText,
    required this.isFinal,
    this.confidence,
    this.alternatives = const <String>[],
  });

  final String primaryText;
  final bool isFinal;
  final double? confidence;
  final List<String> alternatives;
}
