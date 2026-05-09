import '../../domain/board/board_camera_models.dart';
import '../storage/app_storage.dart';

class BoardCameraCalibrationRepository {
  BoardCameraCalibrationRepository._();

  static final BoardCameraCalibrationRepository instance =
      BoardCameraCalibrationRepository._();

  static const String _storageKey = 'board_camera_calibration';

  Future<BoardCameraCalibration> loadCalibration() async {
    final stored = await AppStorage.instance.readJsonMap(_storageKey);
    if (stored == null) {
      return const BoardCameraCalibration.initial();
    }
    return BoardCameraCalibration.fromJson(stored);
  }

  Future<void> saveCalibration(BoardCameraCalibration calibration) {
    return AppStorage.instance.writeJson(_storageKey, calibration.toJson());
  }
}
