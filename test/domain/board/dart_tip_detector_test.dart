import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:DartCore/domain/board/board_camera_models.dart';
import 'package:DartCore/domain/board/board_hit_mapper.dart';
import 'package:DartCore/domain/board/dart_tip_detector.dart';

void main() {
  test('detects a synthetic top hit from reference and current frame', () async {
    final reference = img.Image(width: 200, height: 200);
    img.fill(reference, color: img.ColorRgb8(185, 185, 185));

    final current = img.Image(width: 200, height: 200);
    img.fill(current, color: img.ColorRgb8(185, 185, 185));
    img.drawLine(
      current,
      x1: 100,
      y1: 8,
      x2: 100,
      y2: 32,
      color: img.ColorRgb8(0, 0, 0),
      thickness: 4,
    );

    final detector = const DartTipDetector();
    final calibration = const BoardCameraCalibration(
      centerXFraction: 0.5,
      centerYFraction: 0.5,
      boardRadiusFraction: 0.4,
      rotationDegrees: 0,
    );

    final detection = await detector.detectHit(
      referenceImageBytes: Uint8List.fromList(img.encodePng(reference)),
      currentImageBytes: Uint8List.fromList(img.encodePng(current)),
      calibration: calibration,
    );

    expect(detection, isNotNull);

    final hit = const BoardHitMapper().classifyImagePoint(
      imagePoint: detection!.imagePoint,
      imageWidth: detection.imageWidth,
      imageHeight: detection.imageHeight,
      calibration: calibration,
    );

    expect(hit.baseValue, 20);
    expect(hit.isDouble, isTrue);
  });

  test('maps hits correctly with elliptical board calibration', () async {
    final reference = img.Image(width: 240, height: 220);
    img.fill(reference, color: img.ColorRgb8(185, 185, 185));

    final current = img.Image(width: 240, height: 220);
    img.fill(current, color: img.ColorRgb8(185, 185, 185));
    img.drawLine(
      current,
      x1: 120,
      y1: 12,
      x2: 120,
      y2: 34,
      color: img.ColorRgb8(0, 0, 0),
      thickness: 4,
    );

    final calibration = const BoardCameraCalibration(
      centerXFraction: 0.5,
      centerYFraction: 0.5,
      boardRadiusFraction: 0.4,
      boardRadiusXFraction: 0.31,
      boardRadiusYFraction: 0.4,
      rotationDegrees: 0,
    );

    final detection = await const DartTipDetector().detectHit(
      referenceImageBytes: Uint8List.fromList(img.encodePng(reference)),
      currentImageBytes: Uint8List.fromList(img.encodePng(current)),
      calibration: calibration,
    );

    expect(detection, isNotNull);

    final hit = const BoardHitMapper().classifyImagePoint(
      imagePoint: detection!.imagePoint,
      imageWidth: detection.imageWidth,
      imageHeight: detection.imageHeight,
      calibration: calibration,
    );

    expect(hit.baseValue, 20);
    expect(hit.isDouble, isTrue);
  });
}
