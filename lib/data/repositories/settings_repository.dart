import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/x01/x01_models.dart';
import '../models/app_settings.dart';
import '../storage/app_storage.dart';

class SettingsRepository extends ChangeNotifier {
  SettingsRepository._();

  static const int _legacyRadiusBaselinePercent = 92;
  static const int _legacySimulationSpreadBaselinePercent = 115;
  static const int _radiusDisplayNeutralPercent = 97;
  static const int minRadiusCalibrationPercent = 65;
  static const int maxRadiusCalibrationPercent = 152;
  static const int minSimulationSpreadPercent = 70;
  static const int maxSimulationSpreadPercent = 140;

  static final SettingsRepository instance = SettingsRepository._();

  static const _storageKey = 'app_settings';

  AppSettings _settings = AppSettings.defaults;

  AppSettings get settings => _settings;

  BotProfile createBotProfile({
    required int skill,
    required int finishingSkill,
  }) {
    final effectiveRadius =
        (_settings.radiusCalibrationPercent *
                _radiusDisplayNeutralPercent *
                _legacyRadiusBaselinePercent /
                10000)
            .round();
    final effectiveSpread =
        (_settings.simulationSpreadPercent *
                _legacySimulationSpreadBaselinePercent /
                100)
            .round();

    return BotProfile(
      skill: skill,
      finishingSkill: finishingSkill,
      radiusCalibrationPercent: effectiveRadius,
      simulationSpreadPercent: effectiveSpread,
    );
  }

  Future<void> initialize() async {
    final json = await AppStorage.instance.readJsonMap(_storageKey);
    if (json == null) {
      return;
    }
    _settings = _normalizeSettings(AppSettings.fromJson(json));
    notifyListeners();
    unawaited(_persist());
  }

  void update(AppSettings nextSettings) {
    _settings = _normalizeSettings(nextSettings);
    notifyListeners();
    unawaited(_persist());
  }

  void reset() {
    _settings = AppSettings.defaults;
    notifyListeners();
    unawaited(_persist());
  }

  AppSettings _normalizeSettings(AppSettings settings) {
    final normalizedRadius = settings.settingsVersion <
            AppSettings.currentSettingsVersion
        ? (settings.radiusCalibrationPercent * 100 / _radiusDisplayNeutralPercent)
            .round()
        : settings.radiusCalibrationPercent;

    return settings.copyWith(
      settingsVersion: AppSettings.currentSettingsVersion,
      radiusCalibrationPercent: normalizedRadius.clamp(
        minRadiusCalibrationPercent,
        maxRadiusCalibrationPercent,
      ),
      simulationSpreadPercent: settings.simulationSpreadPercent.clamp(
        minSimulationSpreadPercent,
        maxSimulationSpreadPercent,
      ),
      x01QuickScores: List<int>.generate(6, (index) {
        final value = index < settings.x01QuickScores.length
            ? settings.x01QuickScores[index]
            : AppSettings.defaultX01QuickScores[index];
        return value.clamp(0, 180);
      }),
    );
  }

  Future<void> _persist() {
    return AppStorage.instance.writeJson(_storageKey, _settings.toJson());
  }
}
