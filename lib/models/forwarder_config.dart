import 'dart:typed_data';
import 'retroarch_core.dart';

enum LogoType {
  nintendo(0, 'Nintendo'),
  licensedByNintendo(1, 'Licensed by Nintendo'),
  distributedByNintendo(2, 'Distributed by Nintendo');

  final int value;
  final String label;
  const LogoType(this.value, this.label);
}

class ForwarderConfig {
  String id;
  String title;
  String publisher;
  String version;
  String nroPath;
  String romPath;
  bool isRetroArch;
  RetroArchCore? selectedCore;
  Uint8List? imageBytes;
  Uint8List? logoBytes;
  Uint8List? startupMovieBytes;

  // Advanced options (1:1 parity with original project)
  bool startupUserAccount;
  bool screenshot;
  bool videoCapture;
  bool enableSvcDebug;
  LogoType logoType;

  ForwarderConfig({
    required this.id,
    required this.title,
    required this.publisher,
    this.version = '1.0.0',
    required this.nroPath,
    this.romPath = '',
    this.isRetroArch = false,
    this.selectedCore,
    this.imageBytes,
    this.logoBytes,
    this.startupMovieBytes,
    this.startupUserAccount = true,
    this.screenshot = true,
    this.videoCapture = true,
    this.enableSvcDebug = false,
    this.logoType = LogoType.nintendo,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'publisher': publisher,
      'version': version,
      'nroPath': nroPath,
      'romPath': romPath,
      'isRetroArch': isRetroArch,
      'coreId': selectedCore?.id,
      'startupUserAccount': startupUserAccount,
      'screenshot': screenshot,
      'videoCapture': videoCapture,
      'enableSvcDebug': enableSvcDebug,
      'logoType': logoType.value,
    };
  }

  factory ForwarderConfig.fromJson(Map<String, dynamic> json) {
    RetroArchCore? core;
    if (json['coreId'] != null) {
      try {
        core = RetroArchCore.builtInCores.firstWhere((c) => c.id == json['coreId']);
      } catch (_) {}
    }

    return ForwarderConfig(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      publisher: json['publisher'] ?? '',
      version: json['version'] ?? '1.0.0',
      nroPath: json['nroPath'] ?? '',
      romPath: json['romPath'] ?? '',
      isRetroArch: json['isRetroArch'] ?? false,
      selectedCore: core,
      startupUserAccount: json['startupUserAccount'] ?? true,
      screenshot: json['screenshot'] ?? true,
      videoCapture: json['videoCapture'] ?? true,
      enableSvcDebug: json['enableSvcDebug'] ?? false,
      logoType: LogoType.values.firstWhere(
        (l) => l.value == (json['logoType'] ?? 0),
        orElse: () => LogoType.nintendo,
      ),
    );
  }
}
