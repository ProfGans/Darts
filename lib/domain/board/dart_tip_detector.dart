import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'board_camera_models.dart';
import 'board_hit_mapper.dart';
import 'board_geometry.dart';

class DartTipDetector {
  const DartTipDetector({
    this.mapper = const BoardHitMapper(),
  });

  final BoardHitMapper mapper;

  Future<BoardHitDetection?> detectHit({
    required Uint8List referenceImageBytes,
    required Uint8List currentImageBytes,
    required BoardCameraCalibration calibration,
  }) async {
    final referenceImage = _decode(referenceImageBytes);
    final currentImage = _decode(currentImageBytes);
    if (referenceImage == null || currentImage == null) {
      return null;
    }

    final normalizedWidth = min(referenceImage.width, currentImage.width);
    final normalizedHeight = min(referenceImage.height, currentImage.height);
    final analysisWidth = min(normalizedWidth, 960);
    final analysisHeight = max(
      1,
      (normalizedHeight * (analysisWidth / normalizedWidth)).round(),
    );

    final reference = img.copyResize(
      referenceImage,
      width: analysisWidth,
      height: analysisHeight,
      interpolation: img.Interpolation.average,
    );
    final current = img.copyResize(
      currentImage,
      width: analysisWidth,
      height: analysisHeight,
      interpolation: img.Interpolation.average,
    );

    final width = reference.width;
    final height = reference.height;
    final minDimension = min(width, height).toDouble();
    final centerX = width * calibration.centerXFraction;
    final centerY = height * calibration.centerYFraction;
    final boardRadiusX = minDimension * calibration.boardRadiusXFraction;
    final boardRadiusY = minDimension * calibration.boardRadiusYFraction;
    if (boardRadiusX <= 0 || boardRadiusY <= 0) {
      return null;
    }

    final darkThreshold = 22.0;
    final absoluteThreshold = 30.0;
    final candidateMask = List<bool>.filled(width * height, false);

    final minX = max(0, (centerX - boardRadiusX * 1.05).floor());
    final maxX = min(width - 1, (centerX + boardRadiusX * 1.05).ceil());
    final minY = max(0, (centerY - boardRadiusY * 1.05).floor());
    final maxY = min(height - 1, (centerY + boardRadiusY * 1.05).ceil());

    for (var y = minY; y <= maxY; y += 1) {
      for (var x = minX; x <= maxX; x += 1) {
        final normalizedX = (x - centerX) / boardRadiusX;
        final normalizedY = (y - centerY) / boardRadiusY;
        if ((normalizedX * normalizedX) + (normalizedY * normalizedY) > 1.0) {
          continue;
        }

        final referencePixel = reference.getPixel(x, y);
        final currentPixel = current.getPixel(x, y);
        final referenceLuminance = _luminance(referencePixel);
        final currentLuminance = _luminance(currentPixel);
        final darkDelta = referenceLuminance - currentLuminance;
        final absoluteDelta = (referenceLuminance - currentLuminance).abs();
        if (darkDelta >= darkThreshold && absoluteDelta >= absoluteThreshold) {
          candidateMask[(y * width) + x] = true;
        }
      }
    }

    final component = _largestLikelyComponent(
      candidateMask: candidateMask,
      width: width,
      height: height,
      centerX: centerX,
      centerY: centerY,
      currentImage: current,
      referenceImage: reference,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
    );
    if (component == null) {
      return null;
    }

    final imagePoint = BoardPoint(component.tipX.toDouble(), component.tipY.toDouble());
    final boardPoint = mapper.imagePointToBoardPoint(
      imagePoint: imagePoint,
      imageWidth: width.toDouble(),
      imageHeight: height.toDouble(),
      calibration: calibration,
    );

    return BoardHitDetection(
      imagePoint: imagePoint,
      imageXFraction: imagePoint.x / width,
      imageYFraction: imagePoint.y / height,
      boardPoint: boardPoint,
      imageWidth: width.toDouble(),
      imageHeight: height.toDouble(),
      confidence: component.confidence,
      changedPixels: component.pixelCount,
      debugBounds: BoardDetectionBounds(
        left: component.minX.toDouble(),
        top: component.minY.toDouble(),
        right: component.maxX.toDouble(),
        bottom: component.maxY.toDouble(),
      ),
      debugTipCandidates: component.closestPixels
          .map((point) => BoardPoint(point.x.toDouble(), point.y.toDouble()))
          .toList(growable: false),
      debugMaskPoints: component.maskPoints
          .map((point) => BoardPoint(point.x.toDouble(), point.y.toDouble()))
          .toList(growable: false),
    );
  }

  img.Image? _decode(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return null;
    }
    return img.bakeOrientation(decoded);
  }

  double _luminance(img.Pixel pixel) {
    return (0.299 * pixel.r) + (0.587 * pixel.g) + (0.114 * pixel.b);
  }

  _DetectedComponent? _largestLikelyComponent({
    required List<bool> candidateMask,
    required int width,
    required int height,
    required double centerX,
    required double centerY,
    required img.Image currentImage,
    required img.Image referenceImage,
    required int minX,
    required int maxX,
    required int minY,
    required int maxY,
  }) {
    final visited = List<bool>.filled(candidateMask.length, false);
    _DetectedComponent? bestComponent;
    var bestScore = 0.0;

    for (var y = minY; y <= maxY; y += 1) {
      for (var x = minX; x <= maxX; x += 1) {
        final index = (y * width) + x;
        if (!candidateMask[index] || visited[index]) {
          continue;
        }

        final component = _collectComponent(
          startX: x,
          startY: y,
          candidateMask: candidateMask,
          visited: visited,
          width: width,
          height: height,
          centerX: centerX,
          centerY: centerY,
          currentImage: currentImage,
          referenceImage: referenceImage,
        );
        if (component == null) {
          continue;
        }

        final score = component.score;
        if (score > bestScore) {
          bestScore = score;
          bestComponent = component;
        }
      }
    }

    return bestComponent;
  }

  _DetectedComponent? _collectComponent({
    required int startX,
    required int startY,
    required List<bool> candidateMask,
    required List<bool> visited,
    required int width,
    required int height,
    required double centerX,
    required double centerY,
    required img.Image currentImage,
    required img.Image referenceImage,
  }) {
    final queue = <int>[(startY * width) + startX];
    visited[(startY * width) + startX] = true;
    var queueIndex = 0;
    var pixelCount = 0;
    var darknessSum = 0.0;
    var minDistanceSquared = double.infinity;
    var maxDistanceSquared = 0.0;
    var minX = startX;
    var maxX = startX;
    var minY = startY;
    var maxY = startY;
    final closestPixels = <_PointDistance>[];
    final maskPoints = <_PointDistance>[];

    while (queueIndex < queue.length) {
      final index = queue[queueIndex];
      queueIndex += 1;
      final x = index % width;
      final y = index ~/ width;
      pixelCount += 1;
      minX = min(minX, x);
      maxX = max(maxX, x);
      minY = min(minY, y);
      maxY = max(maxY, y);

      final currentPixel = currentImage.getPixel(x, y);
      final referencePixel = referenceImage.getPixel(x, y);
      final darkness =
          _luminance(referencePixel) - _luminance(currentPixel);
      darknessSum += max(0.0, darkness);

      final dx = x - centerX;
      final dy = y - centerY;
      final distanceSquared = (dx * dx) + (dy * dy);
      if (distanceSquared < minDistanceSquared) {
        minDistanceSquared = distanceSquared;
      }
      if (distanceSquared > maxDistanceSquared) {
        maxDistanceSquared = distanceSquared;
      }
      _rememberClosestPixel(
        closestPixels: closestPixels,
        point: _PointDistance(
          x: x,
          y: y,
          distanceSquared: distanceSquared,
        ),
      );
      _rememberMaskPoint(
        maskPoints: maskPoints,
        point: _PointDistance(
          x: x,
          y: y,
          distanceSquared: distanceSquared,
        ),
      );

      for (var offsetY = -1; offsetY <= 1; offsetY += 1) {
        for (var offsetX = -1; offsetX <= 1; offsetX += 1) {
          if (offsetX == 0 && offsetY == 0) {
            continue;
          }
          final neighborX = x + offsetX;
          final neighborY = y + offsetY;
          if (neighborX < 0 ||
              neighborX >= width ||
              neighborY < 0 ||
              neighborY >= height) {
            continue;
          }
          final neighborIndex = (neighborY * width) + neighborX;
          if (!candidateMask[neighborIndex] || visited[neighborIndex]) {
            continue;
          }
          visited[neighborIndex] = true;
          queue.add(neighborIndex);
        }
      }
    }

    if (pixelCount < 12) {
      return null;
    }

    final averageDarkness = darknessSum / pixelCount;
    if (averageDarkness < 12) {
      return null;
    }

    final boundsWidth = maxX - minX + 1;
    final boundsHeight = maxY - minY + 1;
    final boundsArea = boundsWidth * boundsHeight;
    final fillRatio = boundsArea == 0 ? 1.0 : pixelCount / boundsArea;
    final longSide = max(boundsWidth, boundsHeight).toDouble();
    final shortSide = max(1, min(boundsWidth, boundsHeight)).toDouble();
    final slenderness = (longSide / shortSide).clamp(1.0, 8.0).toDouble();
    if (pixelCount > 2600 && fillRatio > 0.34) {
      return null;
    }
    if (boundsArea > width * height * 0.08) {
      return null;
    }

    closestPixels.sort(
      (left, right) => left.distanceSquared.compareTo(right.distanceSquared),
    );
    final tipSampleCount = min(closestPixels.length, 9);
    var tipXSum = 0.0;
    var tipYSum = 0.0;
    for (var index = 0; index < tipSampleCount; index += 1) {
      tipXSum += closestPixels[index].x;
      tipYSum += closestPixels[index].y;
    }
    final tipX = tipSampleCount == 0 ? startX : (tipXSum / tipSampleCount).round();
    final tipY = tipSampleCount == 0 ? startY : (tipYSum / tipSampleCount).round();

    final radialSpan = sqrt(maxDistanceSquared) - sqrt(minDistanceSquared);
    final normalizedSpan = (radialSpan / 55.0).clamp(0.0, 1.0).toDouble();
    final normalizedSize = (pixelCount / 180.0).clamp(0.0, 1.0).toDouble();
    final normalizedDarkness =
        (averageDarkness / 70.0).clamp(0.0, 1.0).toDouble();
    final dartShapeScore =
        ((slenderness - 1.0) / 4.0).clamp(0.0, 1.0).toDouble();
    final compactnessPenalty = fillRatio > 0.48 ? 0.55 : 1.0;
    final oversizePenalty =
        pixelCount > 1200 ? (1200 / pixelCount).clamp(0.35, 1.0).toDouble() : 1.0;
    final score = pixelCount *
        averageDarkness *
        (0.55 + normalizedSpan) *
        (0.65 + (dartShapeScore * 0.45)) *
        compactnessPenalty *
        oversizePenalty;
    final confidence =
        (0.25 * normalizedSize) +
        (0.30 * normalizedDarkness) +
        (0.25 * normalizedSpan) +
        (0.20 * dartShapeScore);

    return _DetectedComponent(
      tipX: tipX,
      tipY: tipY,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      pixelCount: pixelCount,
      averageDarkness: averageDarkness,
      radialSpan: normalizedSpan,
      score: score,
      closestPixels: List<_PointDistance>.from(closestPixels, growable: false),
      maskPoints: List<_PointDistance>.from(maskPoints, growable: false),
      confidence: confidence.clamp(0.0, 0.99).toDouble(),
    );
  }

  void _rememberClosestPixel({
    required List<_PointDistance> closestPixels,
    required _PointDistance point,
  }) {
    closestPixels.add(point);
    if (closestPixels.length <= 16) {
      return;
    }
    var farthestIndex = 0;
    var farthestDistance = closestPixels.first.distanceSquared;
    for (var index = 1; index < closestPixels.length; index += 1) {
      if (closestPixels[index].distanceSquared > farthestDistance) {
        farthestDistance = closestPixels[index].distanceSquared;
        farthestIndex = index;
      }
    }
    closestPixels.removeAt(farthestIndex);
  }

  void _rememberMaskPoint({
    required List<_PointDistance> maskPoints,
    required _PointDistance point,
  }) {
    if (maskPoints.length < 280) {
      maskPoints.add(point);
      return;
    }
    final stride = max(1, maskPoints.length ~/ 140);
    if (((point.x + point.y) % stride) == 0) {
      maskPoints.add(point);
      if (maskPoints.length > 420) {
        maskPoints.removeAt(0);
      }
    }
  }
}

class _DetectedComponent {
  const _DetectedComponent({
    required this.tipX,
    required this.tipY,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.pixelCount,
    required this.averageDarkness,
    required this.radialSpan,
    required this.score,
    required this.closestPixels,
    required this.maskPoints,
    required this.confidence,
  });

  final int tipX;
  final int tipY;
  final int minX;
  final int maxX;
  final int minY;
  final int maxY;
  final int pixelCount;
  final double averageDarkness;
  final double radialSpan;
  final double score;
  final List<_PointDistance> closestPixels;
  final List<_PointDistance> maskPoints;
  final double confidence;
}

class _PointDistance {
  const _PointDistance({
    required this.x,
    required this.y,
    required this.distanceSquared,
  });

  final int x;
  final int y;
  final double distanceSquared;
}
