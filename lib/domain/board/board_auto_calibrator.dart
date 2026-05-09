import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'board_camera_models.dart';

class BoardAutoCalibrator {
  const BoardAutoCalibrator();

  Future<BoardCalibrationDetection?> detectBoard(Uint8List imageBytes) async {
    final values = kIsWeb
        ? _detectBoardCalibrationValues(imageBytes)
        : await compute(_detectBoardCalibrationValues, imageBytes);
    if (values == null) {
      return null;
    }

    return BoardCalibrationDetection(
      calibration: BoardCameraCalibration(
        centerXFraction: values['centerXFraction']!,
        centerYFraction: values['centerYFraction']!,
        boardRadiusFraction: values['boardRadiusFraction']!,
        boardRadiusXFraction: values['boardRadiusXFraction']!,
        boardRadiusYFraction: values['boardRadiusYFraction']!,
        rotationDegrees: values['rotationDegrees']!,
      ),
      confidence: values['confidence']!,
      imageWidth: values['imageWidth']!,
      imageHeight: values['imageHeight']!,
    );
  }
}

Map<String, double>? _detectBoardCalibrationValues(Uint8List imageBytes) {
  return const _BoardAutoCalibrationWorker().detectBoard(imageBytes);
}

class _BoardAutoCalibrationWorker {
  const _BoardAutoCalibrationWorker();

  Map<String, double>? detectBoard(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return null;
    }

    final source = img.bakeOrientation(decoded);
    final analysisWidth = min(source.width, 480);
    final analysisHeight = max(
      1,
      (source.height * (analysisWidth / source.width)).round(),
    );
    final frame = img.copyResize(
      source,
      width: analysisWidth,
      height: analysisHeight,
      interpolation: img.Interpolation.average,
    );

    final width = frame.width;
    final height = frame.height;
    final minDimension = min(width, height).toDouble();
    final luminance = List<double>.filled(width * height, 0);
    for (var y = 0; y < height; y += 1) {
      for (var x = 0; x < width; x += 1) {
        final pixel = frame.getPixel(x, y);
        luminance[(y * width) + x] =
            (0.299 * pixel.r) + (0.587 * pixel.g) + (0.114 * pixel.b);
      }
    }

    final centerXStart = (width * 0.30).round();
    final centerXEnd = (width * 0.70).round();
    final centerYStart = (height * 0.25).round();
    final centerYEnd = (height * 0.75).round();
    final radiusXStart = (minDimension * 0.18).round();
    final radiusXEnd = (minDimension * 0.48).round();
    final radiusYStart = (minDimension * 0.20).round();
    final radiusYEnd = (minDimension * 0.50).round();

    _CalibrationCandidate? best;

    for (var centerY = centerYStart; centerY <= centerYEnd; centerY += 18) {
      for (var centerX = centerXStart; centerX <= centerXEnd; centerX += 18) {
        for (var radiusY = radiusYStart; radiusY <= radiusYEnd; radiusY += 14) {
          for (var radiusX = radiusXStart; radiusX <= radiusXEnd; radiusX += 14) {
            if (radiusX > radiusY * 1.08) {
              continue;
            }
            if (radiusX < radiusY * 0.62) {
              continue;
            }
            final candidate = _scoreEllipseCandidate(
              luminance: luminance,
              width: width,
              height: height,
              centerX: centerX.toDouble(),
              centerY: centerY.toDouble(),
              radiusX: radiusX.toDouble(),
              radiusY: radiusY.toDouble(),
            );
            if (candidate == null) {
              continue;
            }
            if (best == null || candidate.score > best.score) {
              best = candidate;
            }
          }
        }
      }
    }

    if (best == null) {
      return null;
    }

    var refined = best;
    for (var pass = 0; pass < 2; pass += 1) {
      _CalibrationCandidate? localBest = refined;
      for (var centerY = refined.centerY.round() - 12;
          centerY <= refined.centerY.round() + 12;
          centerY += 4) {
        for (var centerX = refined.centerX.round() - 12;
            centerX <= refined.centerX.round() + 12;
            centerX += 4) {
          for (var radiusY = refined.radiusY.round() - 12;
              radiusY <= refined.radiusY.round() + 12;
              radiusY += 4) {
            for (var radiusX = refined.radiusX.round() - 12;
                radiusX <= refined.radiusX.round() + 12;
                radiusX += 4) {
              if (radiusX > radiusY * 1.08) {
                continue;
              }
              if (radiusX < radiusY * 0.62) {
                continue;
              }
              final candidate = _scoreEllipseCandidate(
                luminance: luminance,
                width: width,
                height: height,
                centerX: centerX.toDouble(),
                centerY: centerY.toDouble(),
                radiusX: radiusX.toDouble(),
                radiusY: radiusY.toDouble(),
              );
              if (candidate == null) {
                continue;
              }
              if (localBest == null || candidate.score > localBest.score) {
                localBest = candidate;
              }
            }
          }
        }
      }
      if (localBest != null) {
        refined = localBest;
      }
    }

    final rotationDegrees = _estimateSegmentRotationDegrees(
      luminance: luminance,
      width: width,
      height: height,
      centerX: refined.centerX,
      centerY: refined.centerY,
      radiusX: refined.radiusX,
      radiusY: refined.radiusY,
    );

    return <String, double>{
      'centerXFraction':
          (refined.centerX / width).clamp(0.0, 1.0).toDouble(),
      'centerYFraction':
          (refined.centerY / height).clamp(0.0, 1.0).toDouble(),
      'boardRadiusFraction':
          ((refined.radiusX + refined.radiusY) / 2 / minDimension).clamp(
                0.15,
                0.5,
              )
              .toDouble(),
      'boardRadiusXFraction':
          (refined.radiusX / minDimension).clamp(0.12, 0.5).toDouble(),
      'boardRadiusYFraction':
          (refined.radiusY / minDimension).clamp(0.12, 0.5).toDouble(),
      'rotationDegrees': rotationDegrees,
      'confidence': refined.confidence,
      'imageWidth': width.toDouble(),
      'imageHeight': height.toDouble(),
    };
  }

  double _estimateSegmentRotationDegrees({
    required List<double> luminance,
    required int width,
    required int height,
    required double centerX,
    required double centerY,
    required double radiusX,
    required double radiusY,
  }) {
    var bestRotation = 0.0;
    var bestScore = -1.0;

    for (var rotation = -90.0; rotation <= 90.0; rotation += 1.5) {
      final score = _scoreSegmentRotation(
        luminance: luminance,
        width: width,
        height: height,
        centerX: centerX,
        centerY: centerY,
        radiusX: radiusX,
        radiusY: radiusY,
        rotationRadians: rotation * pi / 180.0,
      );
      if (score > bestScore) {
        bestScore = score;
        bestRotation = rotation;
      }
    }

    if (bestScore < 6) {
      return 0;
    }
    return _normalizeSegmentRotation(bestRotation);
  }

  double _scoreSegmentRotation({
    required List<double> luminance,
    required int width,
    required int height,
    required double centerX,
    required double centerY,
    required double radiusX,
    required double radiusY,
    required double rotationRadians,
  }) {
    const baseAngle = -pi / 2;
    const boundaryOffset = pi / 180 * 2.8;
    const radialFactors = <double>[
      0.36,
      0.46,
      0.54,
      0.68,
      0.78,
      0.88,
    ];
    var score = 0.0;
    var samples = 0;

    for (var segment = 0; segment < 20; segment += 1) {
      final boundaryAngle =
          baseAngle + rotationRadians + ((segment - 0.5) * pi / 10);
      for (final factor in radialFactors) {
        final left = _sample(
          luminance: luminance,
          width: width,
          height: height,
          x: centerX + (cos(boundaryAngle - boundaryOffset) * radiusX * factor),
          y: centerY + (sin(boundaryAngle - boundaryOffset) * radiusY * factor),
        );
        final right = _sample(
          luminance: luminance,
          width: width,
          height: height,
          x: centerX + (cos(boundaryAngle + boundaryOffset) * radiusX * factor),
          y: centerY + (sin(boundaryAngle + boundaryOffset) * radiusY * factor),
        );
        if (left == null || right == null) {
          continue;
        }
        score += (left - right).abs();
        samples += 1;
      }
    }

    if (samples == 0) {
      return 0;
    }
    return score / samples;
  }

  double _normalizeSegmentRotation(double rotationDegrees) {
    var normalized = rotationDegrees;
    while (normalized > 9) {
      normalized -= 18;
    }
    while (normalized < -9) {
      normalized += 18;
    }
    return normalized;
  }

  _CalibrationCandidate? _scoreEllipseCandidate({
    required List<double> luminance,
    required int width,
    required int height,
    required double centerX,
    required double centerY,
    required double radiusX,
    required double radiusY,
  }) {
    if (radiusX < 32 || radiusY < 40) {
      return null;
    }
    final minDimension = min(width, height).toDouble();
    final radiusAverageFraction = ((radiusX + radiusY) / 2) / minDimension;
    if (radiusAverageFraction < 0.22) {
      return null;
    }
    if (centerX - radiusX < 2 ||
        centerX + radiusX >= width - 2 ||
        centerY - radiusY < 2 ||
        centerY + radiusY >= height - 2) {
      return null;
    }

    const sampleCount = 48;
    var boundaryContrast = 0.0;
    var validSamples = 0;
    var insideDarkerSamples = 0;
    var ringVariation = 0.0;

    for (var index = 0; index < sampleCount; index += 1) {
      final angle = (2 * pi * index) / sampleCount;
      final cosAngle = cos(angle);
      final sinAngle = sin(angle);
      final inner = _sample(
        luminance: luminance,
        width: width,
        height: height,
        x: centerX + (cosAngle * radiusX * 0.94),
        y: centerY + (sinAngle * radiusY * 0.94),
      );
      final boundary = _sample(
        luminance: luminance,
        width: width,
        height: height,
        x: centerX + (cosAngle * radiusX),
        y: centerY + (sinAngle * radiusY),
      );
      final outer = _sample(
        luminance: luminance,
        width: width,
        height: height,
        x: centerX + (cosAngle * radiusX * 1.06),
        y: centerY + (sinAngle * radiusY * 1.06),
      );
      if (inner == null || boundary == null || outer == null) {
        continue;
      }
      validSamples += 1;
      final innerOuterContrast = (inner - outer).abs();
      final boundaryEdge = ((inner - boundary).abs() + (boundary - outer).abs()) / 2;
      boundaryContrast += innerOuterContrast + boundaryEdge;
      if (inner < outer) {
        insideDarkerSamples += 1;
      }
      ringVariation += (inner - boundary).abs();
    }

    if (validSamples < sampleCount * 0.8) {
      return null;
    }

    final centerSample = _sample(
      luminance: luminance,
      width: width,
      height: height,
      x: centerX,
      y: centerY,
    );
    final midRingSamples = <double>[];
    for (var index = 0; index < sampleCount; index += 3) {
      final angle = (2 * pi * index) / sampleCount;
      final sample = _sample(
        luminance: luminance,
        width: width,
        height: height,
        x: centerX + (cos(angle) * radiusX * 0.55),
        y: centerY + (sin(angle) * radiusY * 0.55),
      );
      if (sample != null) {
        midRingSamples.add(sample);
      }
    }
    if (centerSample == null || midRingSamples.length < 8) {
      return null;
    }

    final midAverage =
        midRingSamples.reduce((left, right) => left + right) / midRingSamples.length;
    final centerContrast = (centerSample - midAverage).abs();
    final averageBoundaryContrast = boundaryContrast / validSamples;
    final averageRingVariation = ringVariation / validSamples;
    final darkerRatio = insideDarkerSamples / validSamples;
    final sizePrior =
        (1.0 - ((radiusAverageFraction - 0.38).abs() / 0.18))
            .clamp(0.0, 1.0)
            .toDouble();
    final outerBoardBias =
        radiusAverageFraction.clamp(0.0, 0.44).toDouble() / 0.44;

    final score = (averageBoundaryContrast * 1.6) +
        (averageRingVariation * 1.1) +
        (centerContrast * 0.7) +
        (darkerRatio * 30) +
        (sizePrior * 38) +
        (outerBoardBias * 18);

    final confidence = ((averageBoundaryContrast / 55.0) +
            (averageRingVariation / 45.0) +
            (centerContrast / 40.0) +
            darkerRatio +
            (sizePrior * 0.65)) /
        4.65;

    return _CalibrationCandidate(
      centerX: centerX,
      centerY: centerY,
      radiusX: radiusX,
      radiusY: radiusY,
      score: score,
      confidence: confidence.clamp(0.0, 0.99).toDouble(),
    );
  }

  double? _sample({
    required List<double> luminance,
    required int width,
    required int height,
    required double x,
    required double y,
  }) {
    final xi = x.round();
    final yi = y.round();
    if (xi < 0 || xi >= width || yi < 0 || yi >= height) {
      return null;
    }
    return luminance[(yi * width) + xi];
  }
}

class _CalibrationCandidate {
  const _CalibrationCandidate({
    required this.centerX,
    required this.centerY,
    required this.radiusX,
    required this.radiusY,
    required this.score,
    required this.confidence,
  });

  final double centerX;
  final double centerY;
  final double radiusX;
  final double radiusY;
  final double score;
  final double confidence;
}
