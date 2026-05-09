import 'dart:math';

import '../x01/x01_models.dart';
import '../x01/x01_rules.dart';
import 'board_camera_models.dart';
import 'board_geometry.dart';

class BoardHitMapper {
  const BoardHitMapper({
    this.geometry = const BoardGeometry(),
    this.rules = const X01Rules(),
  });

  final BoardGeometry geometry;
  final X01Rules rules;

  BoardPoint imagePointToBoardPoint({
    required BoardPoint imagePoint,
    required double imageWidth,
    required double imageHeight,
    required BoardCameraCalibration calibration,
  }) {
    final minDimension = min(imageWidth, imageHeight);
    final boardRadiusXPixels =
        minDimension * calibration.boardRadiusXFraction;
    final boardRadiusYPixels =
        minDimension * calibration.boardRadiusYFraction;
    final centerX = imageWidth * calibration.centerXFraction;
    final centerY = imageHeight * calibration.centerYFraction;
    final dx = imagePoint.x - centerX;
    final dy = imagePoint.y - centerY;
    final radians = -(calibration.rotationDegrees * pi / 180.0);
    final unrotatedX = (dx * cos(radians)) - (dy * sin(radians));
    final unrotatedY = (dx * sin(radians)) + (dy * cos(radians));
    final normalizedX = unrotatedX / boardRadiusXPixels;
    final normalizedY = unrotatedY / boardRadiusYPixels;
    final scale = geometry.radii.boardOuter;
    return BoardPoint(
      geometry.center.x + (normalizedX * scale),
      geometry.center.y + (normalizedY * scale),
    );
  }

  DartThrowResult classifyImagePoint({
    required BoardPoint imagePoint,
    required double imageWidth,
    required double imageHeight,
    required BoardCameraCalibration calibration,
  }) {
    final boardPoint = imagePointToBoardPoint(
      imagePoint: imagePoint,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      calibration: calibration,
    );
    return geometry.classifyBoardPoint(
      boardPoint.x,
      boardPoint.y,
      rules: rules,
    );
  }
}
