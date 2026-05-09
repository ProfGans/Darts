import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class VoicePhraseLogEntry {
  const VoicePhraseLogEntry({
    required this.timestampIso,
    required this.mode,
    required this.status,
    required this.transcript,
    required this.alternatives,
    required this.confidence,
    required this.notes,
  });

  final String timestampIso;
  final String mode;
  final String status;
  final String transcript;
  final List<String> alternatives;
  final double? confidence;
  final String notes;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestampIso': timestampIso,
      'mode': mode,
      'status': status,
      'transcript': transcript,
      'alternatives': alternatives,
      'confidence': confidence,
      'notes': notes,
    };
  }
}

class VoicePhraseLogRepository {
  VoicePhraseLogRepository._();

  static final VoicePhraseLogRepository instance = VoicePhraseLogRepository._();

  static const int _maxEntries = 200;
  static const String _fileName = 'voice_phrase_log.json';

  Future<void> append(VoicePhraseLogEntry entry) async {
    try {
      final file = await _resolveFile();
      final existing = await _readEntries(file);
      final updated = <Map<String, Object?>>[
        ...existing,
        entry.toJson(),
      ];
      final trimmed = updated.length <= _maxEntries
          ? updated
          : updated.sublist(updated.length - _maxEntries);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(trimmed),
      );
    } catch (_) {
      // Logging should never break the match flow.
    }
  }

  Future<File> _resolveFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  Future<List<Map<String, Object?>>> _readEntries(File file) async {
    if (!await file.exists()) {
      return <Map<String, Object?>>[];
    }
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <Map<String, Object?>>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <Map<String, Object?>>[];
    }
    return decoded
        .whereType<Map>()
        .map((entry) => entry.cast<String, Object?>())
        .toList(growable: false);
  }
}
