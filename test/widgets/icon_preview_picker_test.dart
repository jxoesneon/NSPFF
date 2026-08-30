// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nspff/theme/switch_theme.dart';
import 'package:nspff/widgets/icon_preview_picker.dart';

class _MockImageFilePicker extends FilePickerIO {
  final List<PlatformFile> _files;

  _MockImageFilePicker(this._files);

  @override
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    String? dialogTitle,
    String? initialDirectory,
    void Function(FilePickerStatus)? onFileLoading,
    bool? allowCompression = true,
    bool allowMultiple = false,
    bool? withData = false,
    int compressionQuality = 30,
    bool? withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return FilePickerResult(_files);
  }
}

void main() {
  group('IconPreviewPicker', () {
    Uint8List makePng() {
      final image = img.Image(width: 1, height: 1);
      return img.encodePng(image);
    }

    testWidgets('renders placeholder and select button when no image',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: IconPreviewPicker(
              onImageSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Select Icon'), findsOneWidget);
      expect(find.text('256 x 256'), findsOneWidget);
    });

    testWidgets('renders change/remove buttons when image is set',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: IconPreviewPicker(
              imageBytes: makePng(),
              onImageSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Change Icon'), findsOneWidget);
      expect(find.text('Remove Icon'), findsOneWidget);
    });

    testWidgets('remove button calls onImageSelected with null',
        (WidgetTester tester) async {
      Uint8List? selected;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: IconPreviewPicker(
              imageBytes: makePng(),
              onImageSelected: (bytes) => selected = bytes,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Remove Icon'));
      await tester.pump();

      expect(selected, isNull);
    });

    testWidgets('select button picks and resizes an image',
        (WidgetTester tester) async {
      final pngBytes = makePng();
      FilePicker.platform = _MockImageFilePicker([
        PlatformFile(
          name: 'icon.png',
          bytes: pngBytes,
          size: pngBytes.length,
        ),
      ]);
      addTearDown(FilePickerIO.registerWith);

      Uint8List? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: IconPreviewPicker(
              onImageSelected: (bytes) => selected = bytes,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Select Icon'));
      // Allow the real isolate-backed resize to complete.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.length, greaterThan(0));
    });
  });
}
