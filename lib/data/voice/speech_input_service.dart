import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_recognition_snapshot.dart';

typedef SpeechRecognitionResultListener = void Function(
  SpeechRecognitionSnapshot result,
);

typedef SpeechRecognitionStatusListener = void Function(String status);
typedef SpeechRecognitionErrorListener = void Function(String errorMessage);

enum SpeechInputListenProfile {
  command,
  confirmation,
}

class SpeechInputService {
  SpeechInputService({
    SpeechToText? speechToText,
  }) : _speechToText = speechToText ?? SpeechToText();

  final SpeechToText _speechToText;

  bool get supportsSpeechRecognition {
    if (kIsWeb) {
      return true;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => true,
      TargetPlatform.macOS => true,
      TargetPlatform.windows => true,
      TargetPlatform.linux => false,
      TargetPlatform.fuchsia => false,
    };
  }

  bool get isAvailable => _speechToText.isAvailable;

  bool get isListening => _speechToText.isListening;

  Future<bool> initialize({
    required SpeechRecognitionStatusListener onStatus,
    required SpeechRecognitionErrorListener onError,
  }) {
    if (!supportsSpeechRecognition) {
      throw UnsupportedError(
        'Spracherkennung wird auf dieser Plattform nicht unterstuetzt.',
      );
    }
    return _speechToText.initialize(
      onStatus: onStatus,
      onError: (SpeechRecognitionError error) => onError(error.errorMsg),
      debugLogging: false,
    );
  }

  Future<String?> preferredGermanLocaleId() async {
    final locales = await _speechToText.locales();
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith('de')) {
        return locale.localeId;
      }
    }
    final systemLocale = await _speechToText.systemLocale();
    return systemLocale?.localeId;
  }

  Future<void> listen({
    required SpeechRecognitionResultListener onResult,
    required SpeechInputListenProfile profile,
    String? localeId,
  }) async {
    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(_snapshotFromResult(result));
      },
      localeId: localeId,
      partialResults: true,
      cancelOnError: true,
      listenFor: profile == SpeechInputListenProfile.command
          ? const Duration(seconds: 10)
          : const Duration(seconds: 5),
      pauseFor: profile == SpeechInputListenProfile.command
          ? const Duration(seconds: 4)
          : const Duration(seconds: 2),
      listenMode: profile == SpeechInputListenProfile.command
          ? ListenMode.dictation
          : ListenMode.confirmation,
    );
  }

  Future<void> stop() => _speechToText.stop();

  Future<void> cancel() => _speechToText.cancel();

  SpeechRecognitionSnapshot _snapshotFromResult(
    SpeechRecognitionResult result,
  ) {
    final dynamic raw = result;
    final alternatives = _extractAlternativeTexts(raw, result.recognizedWords);
    final confidence = _extractConfidence(raw);
    return SpeechRecognitionSnapshot(
      primaryText: result.recognizedWords,
      isFinal: result.finalResult,
      confidence: confidence,
      alternatives: alternatives,
    );
  }

  double? _extractConfidence(dynamic raw) {
    for (final property in <String>[
      'confidence',
      'confidenceRating',
      'confidenceScore',
    ]) {
      try {
        final dynamic value = _readDynamicProperty(raw, property);
        if (value is num) {
          return value.toDouble();
        }
        final parsed = double.tryParse(value?.toString() ?? '');
        if (parsed != null) {
          return parsed;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  List<String> _extractAlternativeTexts(dynamic raw, String primaryText) {
    final collected = <String>[];
    for (final property in <String>[
      'alternates',
      'alternateRecognitions',
      'alternateResults',
      'words',
    ]) {
      try {
        final dynamic candidates = _readDynamicProperty(raw, property);
        if (candidates is Iterable) {
          for (final candidate in candidates) {
            final text = _extractCandidateText(candidate);
            if (text != null && text.isNotEmpty) {
              collected.add(text);
            }
          }
        }
      } catch (_) {
        continue;
      }
    }
    final unique = <String>[];
    for (final value in collected) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == primaryText.trim()) {
        continue;
      }
      if (!unique.contains(trimmed)) {
        unique.add(trimmed);
      }
    }
    return unique;
  }

  String? _extractCandidateText(dynamic candidate) {
    if (candidate == null) {
      return null;
    }
    if (candidate is String) {
      return candidate;
    }
    for (final property in <String>[
      'recognizedWords',
      'words',
      'text',
      'value',
    ]) {
      try {
        final dynamic value = _readDynamicProperty(candidate, property);
        final asText = value?.toString();
        if (asText != null && asText.trim().isNotEmpty) {
          return asText;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  dynamic _readDynamicProperty(dynamic value, String property) {
    if (value is Map) {
      return value[property];
    }
    switch (property) {
      case 'confidence':
        return value.confidence;
      case 'confidenceRating':
        return value.confidenceRating;
      case 'confidenceScore':
        return value.confidenceScore;
      case 'alternates':
        return value.alternates;
      case 'alternateRecognitions':
        return value.alternateRecognitions;
      case 'alternateResults':
        return value.alternateResults;
      case 'words':
        return value.words;
      case 'recognizedWords':
        return value.recognizedWords;
      case 'text':
        return value.text;
      case 'value':
        return value.value;
      default:
        return null;
    }
  }
}
