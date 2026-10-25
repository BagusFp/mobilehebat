import '../models/detected_nature_object.dart';

/// Telemetri performa dan diagnostik Computer Vision untuk Developer Debug Overlay
class ScannerDebugInfo {
  final double fps;
  final int latencyMs;
  final String resolution;
  final String formatGroup;
  final int sensorOrientation;
  final String engineName;
  final int rawDetectionCount;
  final List<DetectedNatureObject> detections;
  final Map<String, double> featureScores;
  final String? lastError;

  const ScannerDebugInfo({
    this.fps = 0.0,
    this.latencyMs = 0,
    this.resolution = '-',
    this.formatGroup = 'YUV420',
    this.sensorOrientation = 90,
    this.engineName = 'On-Device Spatial-Chroma CV Engine',
    this.rawDetectionCount = 0,
    this.detections = const [],
    this.featureScores = const {},
    this.lastError,
  });

  ScannerDebugInfo copyWith({
    double? fps,
    int? latencyMs,
    String? resolution,
    String? formatGroup,
    int? sensorOrientation,
    String? engineName,
    int? rawDetectionCount,
    List<DetectedNatureObject>? detections,
    Map<String, double>? featureScores,
    String? lastError,
  }) {
    return ScannerDebugInfo(
      fps: fps ?? this.fps,
      latencyMs: latencyMs ?? this.latencyMs,
      resolution: resolution ?? this.resolution,
      formatGroup: formatGroup ?? this.formatGroup,
      sensorOrientation: sensorOrientation ?? this.sensorOrientation,
      engineName: engineName ?? this.engineName,
      rawDetectionCount: rawDetectionCount ?? this.rawDetectionCount,
      detections: detections ?? this.detections,
      featureScores: featureScores ?? this.featureScores,
      lastError: lastError ?? this.lastError,
    );
  }
}
