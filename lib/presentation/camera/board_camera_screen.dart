import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../data/repositories/board_camera_calibration_repository.dart';
import '../../domain/board/board_auto_calibrator.dart';
import '../../domain/board/board_camera_models.dart';
import '../../domain/board/board_hit_mapper.dart';
import '../../domain/board/dart_tip_detector.dart';
import '../../domain/x01/x01_rules.dart';

class BoardCameraScreen extends StatefulWidget {
  const BoardCameraScreen({
    required this.isBullOff,
    this.testerMode = false,
    super.key,
  });

  final bool isBullOff;
  final bool testerMode;

  @override
  State<BoardCameraScreen> createState() => _BoardCameraScreenState();
}

class _BoardCameraScreenState extends State<BoardCameraScreen> {
  final BoardCameraCalibrationRepository _calibrationRepository =
      BoardCameraCalibrationRepository.instance;
  final BoardAutoCalibrator _boardAutoCalibrator = const BoardAutoCalibrator();
  final DartTipDetector _dartTipDetector = const DartTipDetector();
  final BoardHitMapper _boardHitMapper = const BoardHitMapper();

  CameraController? _cameraController;
  BoardCameraCalibration _calibration = const BoardCameraCalibration.initial();
  BoardCalibrationDetection? _lastCalibrationDetection;
  _LiveCameraFrame? _latestLiveFrame;
  Uint8List? _referenceImageBytes;
  BoardCameraHitSuggestion? _suggestion;
  Timer? _liveRecognitionTimer;
  bool _initializing = true;
  bool _liveRecognitionBusy = false;
  bool _processing = false;
  String _status = 'Kamera wird vorbereitet.';

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCameraFlow());
  }

  @override
  void dispose() {
    _liveRecognitionTimer?.cancel();
    final controller = _cameraController;
    if (controller != null && controller.value.isStreamingImages) {
      unawaited(controller.stopImageStream());
    }
    unawaited(_cameraController?.dispose());
    super.dispose();
  }

  Future<void> _initializeCameraFlow() async {
    try {
      final storedCalibration = await _calibrationRepository.loadCalibration();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('Keine Kamera verfuegbar.');
      }
      final preferredCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        preferredCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (!kIsWeb) {
        await controller.startImageStream(_handleCameraImage);
      }
      if (!mounted) {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _calibration = storedCalibration;
        _initializing = false;
        _status =
            'Auto-Erkennung starten oder Board-Form kurz feinjustieren und dann ein Referenzbild speichern.';
      });
      _liveRecognitionTimer = Timer.periodic(
        const Duration(milliseconds: 850),
        (_) => unawaited(_runLiveRecognitionTick()),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _status = 'Kamera konnte nicht gestartet werden.';
      });
      _showSnack(error.toString());
    }
  }

  void _handleCameraImage(CameraImage image) {
    _latestLiveFrame = _LiveCameraFrame.fromCameraImage(image);
  }

  Future<void> _captureReference() async {
    final imageBytes = await _captureAnalysisImageBytes();
    if (imageBytes == null || !mounted) {
      return;
    }
      setState(() {
        _referenceImageBytes = imageBytes;
        _suggestion = null;
        _status = 'Referenzbild gespeichert. Jetzt den neuen Dart erkennen.';
    });
    unawaited(_calibrationRepository.saveCalibration(_calibration));
  }

  Future<void> _autoDetectBoard() async {
    final imageBytes = await _captureAnalysisImageBytes();
    if (imageBytes == null || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
      _status = 'Dartboard wird automatisch erkannt.';
    });

    try {
      final detection = await _boardAutoCalibrator.detectBoard(imageBytes);
      if (!mounted) {
        return;
      }
      if (detection == null) {
        setState(() {
          _processing = false;
          _status =
              'Kein klares Dartboard gefunden. Bitte Board zentraler ins Bild nehmen oder manuell nachjustieren.';
        });
        return;
      }

      setState(() {
        _processing = false;
        _calibration = _calibration.copyWith(
          centerXFraction: detection.calibration.centerXFraction,
          centerYFraction: detection.calibration.centerYFraction,
          boardRadiusFraction: detection.calibration.boardRadiusFraction,
          boardRadiusXFraction: detection.calibration.boardRadiusXFraction,
          boardRadiusYFraction: detection.calibration.boardRadiusYFraction,
          rotationDegrees: detection.calibration.rotationDegrees,
        );
        _lastCalibrationDetection = detection;
        _suggestion = null;
        _status =
            'Board erkannt mit ${(detection.confidence * 100).round()}% Sicherheit. Rotation automatisch auf ${detection.calibration.rotationDegrees.toStringAsFixed(1)} Grad gesetzt.';
      });
      unawaited(_calibrationRepository.saveCalibration(_calibration));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _processing = false;
        _status = 'Die automatische Board-Erkennung ist fehlgeschlagen.';
      });
      _showSnack(error.toString());
    }
  }

  Future<void> _detectHit() async {
    final referenceImageBytes = _referenceImageBytes;
    if (referenceImageBytes == null) {
      _showSnack('Bitte zuerst ein Referenzbild ohne neuen Dart speichern.');
      return;
    }

    final currentImageBytes = await _captureAnalysisImageBytes();
    if (currentImageBytes == null || !mounted) {
      return;
    }

    setState(() {
      _processing = true;
      _status = 'Treffer wird ausgewertet.';
    });

    try {
      final detection = await _dartTipDetector.detectHit(
        referenceImageBytes: referenceImageBytes,
        currentImageBytes: currentImageBytes,
        calibration: _calibration,
      );
      if (!mounted) {
        return;
      }
      if (detection == null) {
        setState(() {
          _processing = false;
          _suggestion = null;
          _status = 'Kein klarer neuer Dart erkannt. Bitte Referenz oder Kalibrierung pruefen.';
        });
        return;
      }

      final throwResult = _boardHitMapper.classifyImagePoint(
        imagePoint: detection.imagePoint,
        imageWidth: detection.imageWidth,
        imageHeight: detection.imageHeight,
        calibration: _calibration,
      );
      setState(() {
        _processing = false;
        _suggestion = BoardCameraHitSuggestion(
          calibration: _calibration,
          detection: detection,
          throwResult: throwResult,
        );
        _status =
            'Erkannt: ${throwResult.label} (${throwResult.scoredPoints}). Bitte pruefen und uebernehmen.';
      });
      unawaited(_calibrationRepository.saveCalibration(_calibration));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _processing = false;
        _status = 'Die Analyse ist fehlgeschlagen.';
      });
      _showSnack(error.toString());
    }
  }

  Future<void> _runLiveRecognitionTick() async {
    if (!mounted ||
        _initializing ||
        _processing ||
        _liveRecognitionBusy ||
        _latestLiveFrame == null) {
      return;
    }

    _liveRecognitionBusy = true;
    try {
      if (_referenceImageBytes == null) {
        if (_lastCalibrationDetection == null) {
          await _runBoardDetectionSilently();
        }
        return;
      }

      if (_lastCalibrationDetection == null) {
        await _runBoardDetectionSilently();
        return;
      }

      await _runHitDetectionSilently();
    } finally {
      _liveRecognitionBusy = false;
    }
  }

  Future<void> _runBoardDetectionSilently() async {
    final imageBytes = await _captureAnalysisImageBytes(showErrors: false);
    if (imageBytes == null || !mounted) {
      return;
    }
    try {
      final detection = await _boardAutoCalibrator.detectBoard(imageBytes);
      if (detection == null || !mounted) {
        return;
      }
      setState(() {
        _calibration = _calibration.copyWith(
          centerXFraction: detection.calibration.centerXFraction,
          centerYFraction: detection.calibration.centerYFraction,
          boardRadiusFraction: detection.calibration.boardRadiusFraction,
          boardRadiusXFraction: detection.calibration.boardRadiusXFraction,
          boardRadiusYFraction: detection.calibration.boardRadiusYFraction,
          rotationDegrees: detection.calibration.rotationDegrees,
        );
        _lastCalibrationDetection = detection;
      });
    } catch (_) {
      // Live recognition should fail quietly and keep the last stable overlay.
    }
  }

  Future<void> _runHitDetectionSilently() async {
    final referenceImageBytes = _referenceImageBytes;
    if (referenceImageBytes == null) {
      return;
    }
    final currentImageBytes = await _captureAnalysisImageBytes(showErrors: false);
    if (currentImageBytes == null || !mounted) {
      return;
    }
    try {
      final detection = await _dartTipDetector.detectHit(
        referenceImageBytes: referenceImageBytes,
        currentImageBytes: currentImageBytes,
        calibration: _calibration,
      );
      if (detection == null || !mounted) {
        return;
      }
      final throwResult = _boardHitMapper.classifyImagePoint(
        imagePoint: detection.imagePoint,
        imageWidth: detection.imageWidth,
        imageHeight: detection.imageHeight,
        calibration: _calibration,
      );
      setState(() {
        _suggestion = BoardCameraHitSuggestion(
          calibration: _calibration,
          detection: detection,
          throwResult: throwResult,
        );
      });
    } catch (_) {
      // Live recognition should fail quietly and keep the last stable overlay.
    }
  }

  Future<Uint8List?> _captureStillImage() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _processing) {
      return null;
    }
    setState(() {
      _processing = true;
    });
    try {
      final file = await controller.takePicture();
      return await file.readAsBytes();
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<Uint8List?> _captureAnalysisImageBytes({
    bool showErrors = true,
  }) async {
    final liveFrame = _latestLiveFrame;
    if (liveFrame != null) {
      final bytes = liveFrame.toPngBytes();
      if (bytes != null) {
        return bytes;
      }
      if (showErrors) {
        _showSnack('Live-Kameraframe konnte nicht umgewandelt werden.');
      }
    }
    return _captureStillImage();
  }

  void _updateCalibration(BoardCameraCalibration calibration) {
    setState(() {
      _calibration = calibration;
      _suggestion = null;
      _status = 'Kalibrierung aktualisiert.';
    });
    unawaited(_calibrationRepository.saveCalibration(calibration));
  }

  void _updateFieldRotation(double rotationDegrees) {
    final normalizedRotation = _normalizeRotation(rotationDegrees);
    final calibration = _calibration.copyWith(
      rotationDegrees: normalizedRotation,
    );
    setState(() {
      _calibration = calibration;
      _suggestion = null;
      _status =
          'Felder rotiert: ${normalizedRotation.toStringAsFixed(1)} Grad. Richte die 20-Markierung oben auf dem Board aus.';
    });
    unawaited(_calibrationRepository.saveCalibration(calibration));
  }

  double _normalizeRotation(double rotationDegrees) {
    var normalized = rotationDegrees;
    while (normalized > 180) {
      normalized -= 360;
    }
    while (normalized < -180) {
      normalized += 360;
    }
    return normalized;
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    final mediaSize = MediaQuery.sizeOf(context);
    final isPortrait = mediaSize.height >= mediaSize.width;
    final previewHeight = isPortrait
        ? (mediaSize.height * 0.56).clamp(360.0, 620.0).toDouble()
        : (mediaSize.height * 0.48).clamp(300.0, 420.0).toDouble();
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      appBar: AppBar(
        title: Text(
          widget.testerMode
              ? 'Erkennungs-Tester'
              : widget.isBullOff
                  ? 'Bull-Off Kamera'
                  : 'Board Kamera',
        ),
        backgroundColor: const Color(0xFFF2F5F8),
        elevation: 0,
      ),
      body: SafeArea(
        child: _initializing
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                child: ListView(
                  children: <Widget>[
                    _buildStatusCard(),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: previewHeight,
                      child: _buildLivePreview(
                        controller,
                        isPortrait: isPortrait,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildActionRow(stacked: isPortrait),
                    const SizedBox(height: 12),
                    _buildFieldAlignmentCard(),
                    const SizedBox(height: 12),
                    _buildCalibrationCard(),
                    if (_suggestion != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _buildSuggestionCard(_suggestion!),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.testerMode
                ? 'Teste hier nur die automatische Board- und Dartspitzen-Erkennung. Es wird kein Matchwert uebernommen.'
                : widget.isBullOff
                ? 'Kalibriere den Bull sauber und arbeite dann mit Referenzbild plus neuem Dart.'
                : 'Stationaere Kamera, Referenzbild ohne neuen Dart, danach nur den neuen Treffer erkennen. Leichte Seitenperspektive wird ueber die ovale Board-Form mit beruecksichtigt.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF4E5D6B),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _status,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF152C45),
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _buildStatusChip(
                label: _referenceImageBytes == null
                    ? 'Kein Referenzbild'
                    : 'Referenz bereit',
              ),
              _buildStatusChip(
                label: _suggestion == null
                    ? 'Noch kein Treffer'
                    : 'Treffer ${_suggestion!.throwResult.label}',
              ),
              if (_lastCalibrationDetection != null)
                _buildStatusChip(
                  label:
                      'Board ${(100 * _lastCalibrationDetection!.confidence).round()}%',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview(
    CameraController? controller, {
    required bool isPortrait,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: const Color(0xFF0E1B28),
        child: controller == null
            ? Center(
                child: Text(
                  'Keine Kamera verfuegbar.',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white),
                ),
              )
            : Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final previewAspectRatio = _previewAspectRatio(
                      controller,
                      isPortrait: isPortrait,
                    );
                    return SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: constraints.maxHeight * previewAspectRatio,
                          height: constraints.maxHeight,
                          child: Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              CameraPreview(controller),
                              CustomPaint(
                                painter: _BoardOverlayPainter(
                                  calibration: _calibration,
                                  calibrationDetection: _lastCalibrationDetection,
                                  suggestion: _suggestion,
                                ),
                              ),
                              Positioned(
                                left: 12,
                                right: 12,
                                top: 12,
                                child: _buildLiveOverlayBadge(),
                              ),
                              if (_processing)
                                const ColoredBox(
                                  color: Color(0x66000000),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  double _previewAspectRatio(
    CameraController controller, {
    required bool isPortrait,
  }) {
    final ratio = controller.value.aspectRatio;
    if (ratio <= 0) {
      return isPortrait ? 9 / 16 : 16 / 9;
    }
    return isPortrait ? (1 / ratio) : ratio;
  }

  Widget _buildLiveOverlayBadge() {
    final detection = _lastCalibrationDetection;
    final suggestion = _suggestion;
    final label = detection == null
        ? 'Live: noch keine Board-Erkennung'
        : suggestion == null
            ? 'Live: Board ${(detection.confidence * 100).round()}%'
            : 'Live: ${suggestion.throwResult.label} (${suggestion.throwResult.scoredPoints})';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xCC0E1B28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: detection == null
              ? Colors.white.withOpacity(0.36)
              : const Color(0xFF19C37D),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            detection == null
                ? Icons.center_focus_weak_rounded
                : Icons.center_focus_strong_rounded,
            color: detection == null ? Colors.white : const Color(0xFF19C37D),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EFF5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF35516E),
            ),
      ),
    );
  }

  Widget _buildActionRow({required bool stacked}) {
    final actions = <Widget>[
      FilledButton.tonalIcon(
        onPressed: _processing ? null : _autoDetectBoard,
        icon: const Icon(Icons.center_focus_strong_rounded),
        label: const Text('Board erkennen'),
      ),
      FilledButton.tonalIcon(
        onPressed: _processing ? null : _captureReference,
        icon: const Icon(Icons.photo_camera_back_rounded),
        label: const Text('Referenzbild'),
      ),
      FilledButton.icon(
        onPressed:
            _processing || _referenceImageBytes == null ? null : _detectHit,
        icon: const Icon(Icons.adjust_rounded),
        label: const Text('Dart erkennen'),
      ),
    ];

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: actions
            .map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: 48,
                  child: action,
                ),
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: actions
          .asMap()
          .entries
          .map(
            (entry) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: entry.key == actions.length - 1 ? 0 : 10,
                ),
                child: entry.value,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFieldAlignmentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.explore_rounded,
                color: Color(0xFF0B7A57),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Felder ausrichten',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF152C45),
                      ),
                ),
              ),
              Text(
                '${_calibration.rotationDegrees.toStringAsFixed(1)} Grad',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF35516E),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Die Rotation wird beim Board-Erkennen automatisch aus den Segmentgrenzen geschaetzt. Falls T20/S12 trotzdem danebenliegen, kannst du hier nur die Felder nachdrehen.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF4E5D6B),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _buildRotationButton('-18', -18),
              _buildRotationButton('-3', -3),
              OutlinedButton.icon(
                onPressed: _processing ? null : () => _updateFieldRotation(0),
                icon: const Icon(Icons.vertical_align_top_rounded),
                label: const Text('20 oben'),
              ),
              _buildRotationButton('+3', 3),
              _buildRotationButton('+18', 18),
            ],
          ),
          Slider(
            value: _calibration.rotationDegrees.clamp(-180.0, 180.0).toDouble(),
            min: -180,
            max: 180,
            divisions: 120,
            label: '${_calibration.rotationDegrees.toStringAsFixed(1)} Grad',
            onChanged: _processing ? null : _updateFieldRotation,
          ),
        ],
      ),
    );
  }

  Widget _buildRotationButton(String label, double deltaDegrees) {
    return OutlinedButton(
      onPressed: _processing
          ? null
          : () {
              _updateFieldRotation(
                _calibration.rotationDegrees + deltaDegrees,
              );
            },
      child: Text(label),
    );
  }

  Widget _buildCalibrationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Kalibrierung',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF152C45),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Center, Radius und Segmentrotation koennen automatisch erkannt werden. Die Regler bleiben als Korrektur, wenn Licht, Schatten oder Kamerawinkel die Automatik stoeren.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF4E5D6B),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 8),
          _buildSlider(
            label: 'Horizontal',
            value: _calibration.centerXFraction,
            min: 0.25,
            max: 0.75,
            onChanged: (value) {
              _updateCalibration(_calibration.copyWith(centerXFraction: value));
            },
          ),
          _buildSlider(
            label: 'Vertikal',
            value: _calibration.centerYFraction,
            min: 0.25,
            max: 0.75,
            onChanged: (value) {
              _updateCalibration(_calibration.copyWith(centerYFraction: value));
            },
          ),
          _buildSlider(
            label: 'Breite',
            value: _calibration.boardRadiusXFraction,
            min: 0.14,
            max: 0.48,
            onChanged: (value) {
              _updateCalibration(_calibration.copyWith(boardRadiusXFraction: value));
            },
          ),
          _buildSlider(
            label: 'Hoehe',
            value: _calibration.boardRadiusYFraction,
            min: 0.18,
            max: 0.50,
            onChanged: (value) {
              _updateCalibration(_calibration.copyWith(boardRadiusYFraction: value));
            },
          ),
          _buildSlider(
            label: 'Rotation',
            value: _calibration.rotationDegrees,
            min: -180,
            max: 180,
            onChanged: (value) {
              _updateFieldRotation(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$label: ${value.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF4E5D6B),
              ),
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(BoardCameraHitSuggestion suggestion) {
    final throwResult = suggestion.throwResult;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Treffervorschlag',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF152C45),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${throwResult.label} (${throwResult.scoredPoints} Punkte)',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B7A57),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Confidence ${(suggestion.detection.confidence * 100).round()}%  |  Veraenderte Pixel ${suggestion.detection.changedPixels}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5E6E7D),
                ),
          ),
          const SizedBox(height: 12),
          if (widget.testerMode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4EF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Testergebnis: Es wird kein Matchwert uebernommen.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF15563E),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(suggestion),
                child: Text(
                  widget.isBullOff
                      ? 'Bull-Off Ergebnis uebernehmen'
                      : 'Treffer uebernehmen',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BoardOverlayPainter extends CustomPainter {
  const _BoardOverlayPainter({
    required this.calibration,
    required this.calibrationDetection,
    required this.suggestion,
  });

  final BoardCameraCalibration calibration;
  final BoardCalibrationDetection? calibrationDetection;
  final BoardCameraHitSuggestion? suggestion;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width * calibration.centerXFraction,
      size.height * calibration.centerYFraction,
    );
    final minDimension = min(size.width, size.height);
    final hasDetection = calibrationDetection != null;
    final fallbackRadius = minDimension * calibration.boardRadiusFraction;
    final radiusX = hasDetection
        ? minDimension * calibration.boardRadiusXFraction
        : fallbackRadius;
    final radiusY = hasDetection
        ? minDimension * calibration.boardRadiusYFraction
        : fallbackRadius;
    final boardPaint = Paint()
      ..color =
          hasDetection ? const Color(0xFF19C37D) : Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = hasDetection ? 3.5 : 2.5;
    final crosshairPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radiusX * 2,
        height: radiusY * 2,
      ),
      boardPaint,
    );
    if (hasDetection) {
      final glowPaint = Paint()
        ..color = const Color(0x5519C37D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8;
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radiusX * 2,
          height: radiusY * 2,
        ),
        glowPaint,
      );
      _drawBoardFields(
        canvas: canvas,
        size: size,
        center: center,
        radiusX: radiusX,
        radiusY: radiusY,
        rotationRadians: calibration.rotationDegrees * pi / 180.0,
      );
    }
    canvas.drawLine(
      Offset(center.dx - 12, center.dy),
      Offset(center.dx + 12, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 12),
      Offset(center.dx, center.dy + 12),
      crosshairPaint,
    );
    _drawBoardDebugInfo(
      canvas: canvas,
      center: center,
      radiusX: radiusX,
      radiusY: radiusY,
      size: size,
      hasDetection: hasDetection,
    );

    final rotationRadians = calibration.rotationDegrees * pi / 180.0;
    final segmentPaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 1.0;
    final baseAngle = -pi / 2;
    for (var index = 0; index < 20; index += 1) {
      final angle = baseAngle + rotationRadians + (index * pi / 10);
      final end = Offset(
        center.dx + (cos(angle) * radiusX),
        center.dy + (sin(angle) * radiusY),
      );
      canvas.drawLine(center, end, segmentPaint);
    }

    final hit = suggestion;
    if (hit == null) {
      return;
    }

    _drawDartDebugMask(
      canvas: canvas,
      size: size,
      detection: hit.detection,
    );
    _drawDartDebugBounds(
      canvas: canvas,
      size: size,
      detection: hit.detection,
    );
    final normalizedX = hit.detection.imageXFraction;
    final normalizedY = hit.detection.imageYFraction;
    final markerCenter = Offset(size.width * normalizedX, size.height * normalizedY);
    final markerPaint = Paint()
      ..color = const Color(0xFF19C37D)
      ..style = PaintingStyle.fill;
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(markerCenter, 7, markerPaint);
    canvas.drawCircle(markerCenter, 12, ringPaint);
    for (final candidate in hit.detection.debugTipCandidates) {
      final candidateCenter = Offset(
        size.width * (candidate.x / hit.detection.imageWidth),
        size.height * (candidate.y / hit.detection.imageHeight),
      );
      canvas.drawCircle(
        candidateCenter,
        3,
        Paint()..color = const Color(0xFFFFD166),
      );
    }
    _drawHitLabel(
      canvas: canvas,
      size: size,
      markerCenter: markerCenter,
      label: hit.throwResult.label,
    );
  }

  void _drawBoardDebugInfo({
    required Canvas canvas,
    required Offset center,
    required double radiusX,
    required double radiusY,
    required Size size,
    required bool hasDetection,
  }) {
    final text = hasDetection
        ? 'Board cx ${calibration.centerXFraction.toStringAsFixed(3)}  cy ${calibration.centerYFraction.toStringAsFixed(3)}  rx ${calibration.boardRadiusXFraction.toStringAsFixed(3)}  ry ${calibration.boardRadiusYFraction.toStringAsFixed(3)}  rot ${calibration.rotationDegrees.toStringAsFixed(1)}'
        : 'Guide cx ${calibration.centerXFraction.toStringAsFixed(3)}  cy ${calibration.centerYFraction.toStringAsFixed(3)}  r ${calibration.boardRadiusFraction.toStringAsFixed(3)}';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      maxLines: 2,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 40);
    final rect = Rect.fromLTWH(
      12,
      size.height - painter.height - 18,
      painter.width + 16,
      painter.height + 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()..color = const Color(0xB0000000),
    );
    painter.paint(canvas, Offset(rect.left + 8, rect.top + 5));

    final axisPaint = Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - radiusX, center.dy),
      Offset(center.dx + radiusX, center.dy),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radiusY),
      Offset(center.dx, center.dy + radiusY),
      axisPaint,
    );
  }

  void _drawDartDebugMask({
    required Canvas canvas,
    required Size size,
    required BoardHitDetection detection,
  }) {
    final fillPaint = Paint()
      ..color = const Color(0x6636E3A5)
      ..style = PaintingStyle.fill;
    for (final point in detection.debugMaskPoints) {
      final center = Offset(
        size.width * (point.x / detection.imageWidth),
        size.height * (point.y / detection.imageHeight),
      );
      canvas.drawCircle(center, 4.5, fillPaint);
    }
  }

  void _drawDartDebugBounds({
    required Canvas canvas,
    required Size size,
    required BoardHitDetection detection,
  }) {
    final bounds = detection.debugBounds;
    final rect = Rect.fromLTRB(
      size.width * (bounds.left / detection.imageWidth),
      size.height * (bounds.top / detection.imageHeight),
      size.width * (bounds.right / detection.imageWidth),
      size.height * (bounds.bottom / detection.imageHeight),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()
        ..color = const Color(0x55FFD166)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()
        ..color = const Color(0xFFFFD166)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawBoardFields({
    required Canvas canvas,
    required Size size,
    required Offset center,
    required double radiusX,
    required double radiusY,
    required double rotationRadians,
  }) {
    final ringPaint = Paint()
      ..color = const Color(0xAA19C37D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final factor in <double>[
      12 / 240,
      28 / 240,
      105 / 240,
      123 / 240,
      188 / 240,
      206 / 240,
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: radiusX * factor * 2,
          height: radiusY * factor * 2,
        ),
        ringPaint,
      );
    }

    final segmentPaint = Paint()
      ..color = const Color(0x9919C37D)
      ..strokeWidth = 1.1;
    final baseAngle = -pi / 2;
    for (var index = 0; index < 20; index += 1) {
      final boundaryAngle = baseAngle + rotationRadians + ((index - 0.5) * pi / 10);
      canvas.drawLine(
        center,
        Offset(
          center.dx + (cos(boundaryAngle) * radiusX),
          center.dy + (sin(boundaryAngle) * radiusY),
        ),
        segmentPaint,
      );
    }

    _drawRingLabel(
      canvas: canvas,
      center: Offset(center.dx, center.dy - (radiusY * 0.06)),
      text: 'BULL',
      background: const Color(0xCC19C37D),
    );
    _drawRingLabel(
      canvas: canvas,
      center: Offset(center.dx, center.dy + (radiusY * 0.17)),
      text: '25',
      background: const Color(0xCC0E1B28),
    );
    _drawRingLabel(
      canvas: canvas,
      center: Offset(center.dx + (radiusX * 0.72), center.dy),
      text: 'T',
      background: const Color(0xCCB65A18),
    );
    _drawRingLabel(
      canvas: canvas,
      center: Offset(center.dx + (radiusX * 0.91), center.dy),
      text: 'D',
      background: const Color(0xCCB01818),
    );

    for (var index = 0; index < X01Rules.wheel.length; index += 1) {
      final value = X01Rules.wheel[index];
      final angle = baseAngle + rotationRadians + (index * pi / 10);
      final labelCenter = Offset(
        center.dx + (cos(angle) * radiusX * 0.78),
        center.dy + (sin(angle) * radiusY * 0.78),
      );
      _drawSegmentNumber(
        canvas: canvas,
        center: labelCenter,
        text: '$value',
        highlighted: value == 20,
      );
    }
  }

  void _drawSegmentNumber({
    required Canvas canvas,
    required Offset center,
    required String text,
    required bool highlighted,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: highlighted ? const Color(0xFF0E1B28) : Colors.white,
          fontSize: highlighted ? 14 : 12,
          fontWeight: FontWeight.w900,
          shadows: highlighted
              ? null
              : const <Shadow>[
                  Shadow(
                    color: Colors.black,
                    blurRadius: 4,
                  ),
                ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (highlighted) {
      final rect = Rect.fromCenter(
        center: center,
        width: painter.width + 12,
        height: painter.height + 8,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(999)),
        Paint()..color = const Color(0xFFFFD166),
      );
    }
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _drawRingLabel({
    required Canvas canvas,
    required Offset center,
    required String text,
    required Color background,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: center,
      width: painter.width + 12,
      height: painter.height + 6,
    );
    final paint = Paint()..color = background;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(999)),
      paint,
    );
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _drawHitLabel({
    required Canvas canvas,
    required Size size,
    required Offset markerCenter,
    required String label,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Pfeil: $label',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final labelCenter = Offset(
      markerCenter.dx.clamp(46.0, size.width - 46.0).toDouble(),
      (markerCenter.dy - 26).clamp(18.0, size.height - 18.0).toDouble(),
    );
    final rect = Rect.fromCenter(
      center: labelCenter,
      width: painter.width + 16,
      height: painter.height + 8,
    );
    final paint = Paint()..color = const Color(0xDD19C37D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(999)),
      paint,
    );
    painter.paint(
      canvas,
      labelCenter - Offset(painter.width / 2, painter.height / 2),
    );
    final linePaint = Paint()
      ..color = const Color(0xFF19C37D)
      ..strokeWidth = 2;
    canvas.drawLine(labelCenter, markerCenter, linePaint);
  }

  @override
  bool shouldRepaint(covariant _BoardOverlayPainter oldDelegate) {
    return oldDelegate.calibration != calibration ||
        oldDelegate.calibrationDetection != calibrationDetection ||
        oldDelegate.suggestion != suggestion;
  }
}

class _LiveCameraFrame {
  const _LiveCameraFrame({
    required this.width,
    required this.height,
    required this.formatGroup,
    required this.planes,
  });

  factory _LiveCameraFrame.fromCameraImage(CameraImage image) {
    return _LiveCameraFrame(
      width: image.width,
      height: image.height,
      formatGroup: image.format.group,
      planes: image.planes
          .map(
            (plane) => _LiveCameraPlane(
              bytes: Uint8List.fromList(plane.bytes),
              bytesPerRow: plane.bytesPerRow,
              bytesPerPixel: plane.bytesPerPixel,
            ),
          )
          .toList(growable: false),
    );
  }

  final int width;
  final int height;
  final ImageFormatGroup formatGroup;
  final List<_LiveCameraPlane> planes;

  Uint8List? toPngBytes() {
    final image = switch (formatGroup) {
      ImageFormatGroup.bgra8888 => _decodeBgra8888(),
      ImageFormatGroup.yuv420 => _decodeYuv420(),
      _ => null,
    };
    if (image == null) {
      return null;
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  img.Image? _decodeBgra8888() {
    if (planes.isEmpty) {
      return null;
    }
    final plane = planes.first;
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y += 1) {
      final rowStart = y * plane.bytesPerRow;
      for (var x = 0; x < width; x += 1) {
        final index = rowStart + (x * 4);
        if (index + 3 >= plane.bytes.length) {
          continue;
        }
        final b = plane.bytes[index];
        final g = plane.bytes[index + 1];
        final r = plane.bytes[index + 2];
        final a = plane.bytes[index + 3];
        image.setPixelRgba(x, y, r, g, b, a);
      }
    }
    return image;
  }

  img.Image? _decodeYuv420() {
    if (planes.length < 3) {
      return null;
    }
    final yPlane = planes[0];
    final uPlane = planes[1];
    final vPlane = planes[2];
    final image = img.Image(width: width, height: height);
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (var y = 0; y < height; y += 1) {
      final yRowStart = y * yPlane.bytesPerRow;
      final uvRowStart = (y >> 1) * uvRowStride;
      for (var x = 0; x < width; x += 1) {
        final yIndex = yRowStart + x;
        final uvIndex = uvRowStart + ((x >> 1) * uvPixelStride);
        if (yIndex >= yPlane.bytes.length ||
            uvIndex >= uPlane.bytes.length ||
            uvIndex >= vPlane.bytes.length) {
          continue;
        }
        final yp = yPlane.bytes[yIndex].toDouble();
        final up = uPlane.bytes[uvIndex].toDouble();
        final vp = vPlane.bytes[uvIndex].toDouble();
        final r = (yp + (1.402 * (vp - 128))).round().clamp(0, 255);
        final g =
            (yp - (0.344136 * (up - 128)) - (0.714136 * (vp - 128)))
                .round()
                .clamp(0, 255);
        final b = (yp + (1.772 * (up - 128))).round().clamp(0, 255);
        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    return img.copyRotate(image, angle: 90);
  }
}

class _LiveCameraPlane {
  const _LiveCameraPlane({
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
}
