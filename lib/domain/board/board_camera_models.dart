import 'board_geometry.dart';
import '../x01/x01_models.dart';

class BoardCameraCalibration {
  const BoardCameraCalibration({
    required this.centerXFraction,
    required this.centerYFraction,
    required this.boardRadiusFraction,
    double? boardRadiusXFraction,
    double? boardRadiusYFraction,
    required this.rotationDegrees,
  }) : boardRadiusXFraction = boardRadiusXFraction ?? boardRadiusFraction,
       boardRadiusYFraction = boardRadiusYFraction ?? boardRadiusFraction;

  const BoardCameraCalibration.initial()
      : centerXFraction = 0.5,
        centerYFraction = 0.5,
        boardRadiusFraction = 0.38,
        boardRadiusXFraction = 0.38,
        boardRadiusYFraction = 0.38,
        rotationDegrees = 0;

  final double centerXFraction;
  final double centerYFraction;
  final double boardRadiusFraction;
  final double boardRadiusXFraction;
  final double boardRadiusYFraction;
  final double rotationDegrees;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'centerXFraction': centerXFraction,
      'centerYFraction': centerYFraction,
      'boardRadiusFraction': boardRadiusFraction,
      'boardRadiusXFraction': boardRadiusXFraction,
      'boardRadiusYFraction': boardRadiusYFraction,
      'rotationDegrees': rotationDegrees,
    };
  }

  static BoardCameraCalibration fromJson(Map<String, dynamic> json) {
    return BoardCameraCalibration(
      centerXFraction: (json['centerXFraction'] as num?)?.toDouble() ?? 0.5,
      centerYFraction: (json['centerYFraction'] as num?)?.toDouble() ?? 0.5,
      boardRadiusFraction:
          (json['boardRadiusFraction'] as num?)?.toDouble() ?? 0.38,
      boardRadiusXFraction:
          (json['boardRadiusXFraction'] as num?)?.toDouble(),
      boardRadiusYFraction:
          (json['boardRadiusYFraction'] as num?)?.toDouble(),
      rotationDegrees: (json['rotationDegrees'] as num?)?.toDouble() ?? 0,
    );
  }

  BoardCameraCalibration copyWith({
    double? centerXFraction,
    double? centerYFraction,
    double? boardRadiusFraction,
    double? boardRadiusXFraction,
    double? boardRadiusYFraction,
    double? rotationDegrees,
  }) {
    final nextRadiusFraction = boardRadiusFraction ?? this.boardRadiusFraction;
    return BoardCameraCalibration(
      centerXFraction: centerXFraction ?? this.centerXFraction,
      centerYFraction: centerYFraction ?? this.centerYFraction,
      boardRadiusFraction: nextRadiusFraction,
      boardRadiusXFraction:
          boardRadiusXFraction ??
          (boardRadiusFraction != null
              ? nextRadiusFraction
              : this.boardRadiusXFraction),
      boardRadiusYFraction:
          boardRadiusYFraction ??
          (boardRadiusFraction != null
              ? nextRadiusFraction
              : this.boardRadiusYFraction),
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
    );
  }
}

class BoardHitDetection {
  const BoardHitDetection({
    required this.imagePoint,
    required this.imageXFraction,
    required this.imageYFraction,
    required this.boardPoint,
    required this.imageWidth,
    required this.imageHeight,
    required this.confidence,
    required this.changedPixels,
    required this.debugBounds,
    required this.debugTipCandidates,
    required this.debugMaskPoints,
  });

  final BoardPoint imagePoint;
  final double imageXFraction;
  final double imageYFraction;
  final BoardPoint boardPoint;
  final double imageWidth;
  final double imageHeight;
  final double confidence;
  final int changedPixels;
  final BoardDetectionBounds debugBounds;
  final List<BoardPoint> debugTipCandidates;
  final List<BoardPoint> debugMaskPoints;
}

class BoardDetectionBounds {
  const BoardDetectionBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

class BoardCameraHitSuggestion {
  const BoardCameraHitSuggestion({
    required this.calibration,
    required this.detection,
    required this.throwResult,
  });

  final BoardCameraCalibration calibration;
  final BoardHitDetection detection;
  final DartThrowResult throwResult;
}

class BoardCalibrationDetection {
  const BoardCalibrationDetection({
    required this.calibration,
    required this.confidence,
    required this.imageWidth,
    required this.imageHeight,
  });

  final BoardCameraCalibration calibration;
  final double confidence;
  final double imageWidth;
  final double imageHeight;
}
