class AppSettings {
  static const int currentSettingsVersion = 3;
  static const int defaultComputerSpeedIndex = 1;
  static const int defaultRadiusCalibrationPercent = 100;
  static const int defaultSimulationSpreadPercent = 100;
  static const List<int> defaultX01QuickScores = <int>[26, 41, 60, 100];

  const AppSettings({
    this.settingsVersion = currentSettingsVersion,
    this.computerSpeedIndex = defaultComputerSpeedIndex,
    this.radiusCalibrationPercent = defaultRadiusCalibrationPercent,
    this.simulationSpreadPercent = defaultSimulationSpreadPercent,
    this.x01QuickScores = defaultX01QuickScores,
  });

  final int settingsVersion;
  final int computerSpeedIndex;
  final int radiusCalibrationPercent;
  final int simulationSpreadPercent;
  final List<int> x01QuickScores;

  static const AppSettings defaults = AppSettings();

  AppSettings copyWith({
    int? settingsVersion,
    int? computerSpeedIndex,
    int? radiusCalibrationPercent,
    int? simulationSpreadPercent,
    List<int>? x01QuickScores,
  }) {
    return AppSettings(
      settingsVersion: settingsVersion ?? this.settingsVersion,
      computerSpeedIndex: computerSpeedIndex ?? this.computerSpeedIndex,
      radiusCalibrationPercent:
          radiusCalibrationPercent ?? this.radiusCalibrationPercent,
      simulationSpreadPercent:
          simulationSpreadPercent ?? this.simulationSpreadPercent,
      x01QuickScores: x01QuickScores ?? this.x01QuickScores,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'settingsVersion': settingsVersion,
      'computerSpeedIndex': computerSpeedIndex,
      'radiusCalibrationPercent': radiusCalibrationPercent,
      'simulationSpreadPercent': simulationSpreadPercent,
      'x01QuickScores': x01QuickScores,
    };
  }

  static AppSettings fromJson(Map<String, dynamic> json) {
    return AppSettings(
      settingsVersion:
          (json['settingsVersion'] as num?)?.toInt() ?? 1,
      computerSpeedIndex:
          (json['computerSpeedIndex'] as num?)?.toInt() ??
          defaultComputerSpeedIndex,
      radiusCalibrationPercent:
          (json['radiusCalibrationPercent'] as num?)?.toInt() ??
          defaultRadiusCalibrationPercent,
      simulationSpreadPercent:
          (json['simulationSpreadPercent'] as num?)?.toInt() ??
          defaultSimulationSpreadPercent,
      x01QuickScores: (json['x01QuickScores'] as List<dynamic>?)
              ?.map((entry) => (entry as num).toInt())
              .toList() ??
          defaultX01QuickScores,
    );
  }
}
