import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:DartCore/domain/board/board_auto_calibrator.dart';

void main() {
  test('detects board center and radius from a synthetic circle', () async {
    final frame = img.Image(width: 320, height: 320);
    img.fill(frame, color: img.ColorRgb8(230, 230, 230));
    img.fillCircle(
      frame,
      x: 160,
      y: 150,
      radius: 92,
      color: img.ColorRgb8(80, 80, 80),
    );
    img.fillCircle(
      frame,
      x: 160,
      y: 150,
      radius: 14,
      color: img.ColorRgb8(170, 40, 40),
    );

    final detection = await const BoardAutoCalibrator().detectBoard(
      Uint8List.fromList(img.encodePng(frame)),
    );

    expect(detection, isNotNull);
    expect(detection!.calibration.centerXFraction, closeTo(0.5, 0.06));
    expect(detection.calibration.centerYFraction, closeTo(150 / 320, 0.06));
    expect(detection.calibration.boardRadiusFraction, closeTo(92 / 320, 0.07));
    expect(detection.calibration.boardRadiusXFraction, closeTo(92 / 320, 0.07));
    expect(detection.calibration.boardRadiusYFraction, closeTo(92 / 320, 0.07));
    expect(detection.confidence, greaterThan(0.2));
  });

  test('detects a horizontally squashed board for side perspective', () async {
    final frame = img.Image(width: 360, height: 320);
    img.fill(frame, color: img.ColorRgb8(230, 230, 230));
    _fillEllipse(
      frame,
      centerX: 180,
      centerY: 158,
      radiusX: 76,
      radiusY: 96,
      color: img.ColorRgb8(75, 75, 75),
    );
    _fillEllipse(
      frame,
      centerX: 180,
      centerY: 158,
      radiusX: 12,
      radiusY: 15,
      color: img.ColorRgb8(170, 40, 40),
    );

    final detection = await const BoardAutoCalibrator().detectBoard(
      Uint8List.fromList(img.encodePng(frame)),
    );

    expect(detection, isNotNull);
    expect(detection!.calibration.centerXFraction, closeTo(180 / 360, 0.07));
    expect(detection.calibration.centerYFraction, closeTo(158 / 320, 0.07));
    expect(detection.calibration.boardRadiusXFraction, closeTo(76 / 320, 0.08));
    expect(detection.calibration.boardRadiusYFraction, closeTo(96 / 320, 0.08));
    expect(detection.confidence, greaterThan(0.2));
  });
}

void _fillEllipse(
  img.Image image, {
  required int centerX,
  required int centerY,
  required int radiusX,
  required int radiusY,
  required img.Color color,
}) {
  for (var y = centerY - radiusY; y <= centerY + radiusY; y += 1) {
    if (y < 0 || y >= image.height) {
      continue;
    }
    for (var x = centerX - radiusX; x <= centerX + radiusX; x += 1) {
      if (x < 0 || x >= image.width) {
        continue;
      }
      final normalizedX = (x - centerX) / radiusX;
      final normalizedY = (y - centerY) / radiusY;
      if ((normalizedX * normalizedX) + (normalizedY * normalizedY) <= 1.0) {
        image.setPixel(x, y, color);
      }
    }
  }
}
