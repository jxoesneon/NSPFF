import 'package:flutter/foundation.dart';

import 'retroarch_core.dart';

enum LogoType {
  nintendo(0, 'Nintendo'),
  licensedByNintendo(1, 'Licensed by Nintendo'),
  distributedByNintendo(2, 'Distributed by Nintendo');

  final int value;
  final String label;
  const LogoType(this.value, this.label);
}

/// Sentinel value used by [copyWith] to distinguish between a field that
/// should keep its current value and one that is intentionally set to `null`.
const Object _nullSentinel = Object();

class ForwarderConfig {
  final String id;
  final String title;
  final String publisher;
  final String version;
  final String nroPath;
  final String romPath;
  final bool isRetroArch;
  final RetroArchCore? selectedCore;
  final Uint8List? imageBytes;
  final Uint8List? logoBytes;
  final Uint8List? startupMovieBytes;

  // Advanced options (1:1 parity with original project)
  final bool startupUserAccount;
  final bool screenshot;
  final bool videoCapture;
  final bool enableSvcDebug;
  final LogoType logoType;

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

  /// Creates a copy of this config with the given fields replaced.
  ///
  /// Pass `null` for the nullable `imageBytes`, `logoBytes`,
  /// `startupMovieBytes`, or `selectedCore` fields to explicitly clear them.
  ForwarderConfig copyWith({
    String? id,
    String? title,
    String? publisher,
    String? version,
    String? nroPath,
    String? romPath,
    bool? isRetroArch,
    Object? selectedCore = _nullSentinel,
    Object? imageBytes = _nullSentinel,
    Object? logoBytes = _nullSentinel,
    Object? startupMovieBytes = _nullSentinel,
    bool? startupUserAccount,
    bool? screenshot,
    bool? videoCapture,
    bool? enableSvcDebug,
    LogoType? logoType,
  }) {
    return ForwarderConfig(
      id: id ?? this.id,
      title: title ?? this.title,
      publisher: publisher ?? this.publisher,
      version: version ?? this.version,
      nroPath: nroPath ?? this.nroPath,
      romPath: romPath ?? this.romPath,
      isRetroArch: isRetroArch ?? this.isRetroArch,
      selectedCore: selectedCore == _nullSentinel
          ? this.selectedCore
          : selectedCore as RetroArchCore?,
      imageBytes: imageBytes == _nullSentinel
          ? this.imageBytes
          : imageBytes as Uint8List?,
      logoBytes:
          logoBytes == _nullSentinel ? this.logoBytes : logoBytes as Uint8List?,
      startupMovieBytes: startupMovieBytes == _nullSentinel
          ? this.startupMovieBytes
          : startupMovieBytes as Uint8List?,
      startupUserAccount: startupUserAccount ?? this.startupUserAccount,
      screenshot: screenshot ?? this.screenshot,
      videoCapture: videoCapture ?? this.videoCapture,
      enableSvcDebug: enableSvcDebug ?? this.enableSvcDebug,
      logoType: logoType ?? this.logoType,
    );
  }

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
        core = RetroArchCore.builtInCores
            .firstWhere((c) => c.id == json['coreId']);
      } catch (_) {}
    }

    return ForwarderConfig(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      publisher: json['publisher'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      nroPath: json['nroPath'] as String? ?? '',
      romPath: json['romPath'] as String? ?? '',
      isRetroArch: json['isRetroArch'] as bool? ?? false,
      selectedCore: core,
      startupUserAccount: json['startupUserAccount'] as bool? ?? true,
      screenshot: json['screenshot'] as bool? ?? true,
      videoCapture: json['videoCapture'] as bool? ?? true,
      enableSvcDebug: json['enableSvcDebug'] as bool? ?? false,
      logoType: LogoType.values.firstWhere(
        (l) => l.value == (json['logoType'] as int? ?? 0),
        orElse: () => LogoType.nintendo,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ForwarderConfig &&
        other.id == id &&
        other.title == title &&
        other.publisher == publisher &&
        other.version == version &&
        other.nroPath == nroPath &&
        other.romPath == romPath &&
        other.isRetroArch == isRetroArch &&
        other.selectedCore?.id == selectedCore?.id &&
        listEquals(other.imageBytes, imageBytes) &&
        listEquals(other.logoBytes, logoBytes) &&
        listEquals(other.startupMovieBytes, startupMovieBytes) &&
        other.startupUserAccount == startupUserAccount &&
        other.screenshot == screenshot &&
        other.videoCapture == videoCapture &&
        other.enableSvcDebug == enableSvcDebug &&
        other.logoType == logoType;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        publisher,
        version,
        nroPath,
        romPath,
        isRetroArch,
        selectedCore?.id,
        _hashNullableBytes(imageBytes),
        _hashNullableBytes(logoBytes),
        _hashNullableBytes(startupMovieBytes),
        startupUserAccount,
        screenshot,
        videoCapture,
        enableSvcDebug,
        logoType,
      );

  static Object? _hashNullableBytes(Uint8List? bytes) {
    if (bytes == null) return null;
    return Object.hashAll(bytes);
  }
}
