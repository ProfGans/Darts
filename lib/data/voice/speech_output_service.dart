class SpeechOutputService {
  const SpeechOutputService();

  bool get supportsTextToSpeech => true;

  Future<void> initialize() async {}

  Future<void> speak(String text) async {}

  Future<void> speakWithoutWaiting(String text) async {}

  Future<void> stop() async {}
}
