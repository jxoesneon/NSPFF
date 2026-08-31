import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../theme/switch_theme.dart';

/// Resizes [bytes] so that its largest dimension is at most [maxDimension]
/// while preserving aspect ratio.
///
/// If the image is already within bounds, the original bytes are returned.
/// If decoding fails, [bytes] is also returned unchanged.
///
/// The resize runs in an isolate to avoid blocking the UI thread.
Future<Uint8List> resizeIconBytes(Uint8List bytes,
    {int maxDimension = 512}) async {
  return compute(
    _resizeIconBytesSync,
    {'bytes': bytes, 'maxDimension': maxDimension},
  );
}

Uint8List _resizeIconBytesSync(Map<String, Object> message) {
  final bytes = message['bytes'] as Uint8List;
  final maxDimension = message['maxDimension'] as int;

  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  if (decoded.width <= maxDimension && decoded.height <= maxDimension) {
    return bytes;
  }

  final int targetWidth;
  final int targetHeight;
  if (decoded.width > decoded.height) {
    targetWidth = maxDimension;
    targetHeight = (maxDimension * decoded.height / decoded.width).round();
  } else {
    targetHeight = maxDimension;
    targetWidth = (maxDimension * decoded.width / decoded.height).round();
  }

  final resized = img.copyResize(
    decoded,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.cubic,
  );

  return img.encodePng(resized);
}

class IconPreviewPicker extends StatelessWidget {
  final Uint8List? imageBytes;
  final ValueChanged<Uint8List?> onImageSelected;

  const IconPreviewPicker({
    super.key,
    this.imageBytes,
    required this.onImageSelected,
  });

  Future<void> _pickImage() async {
    final file = await FilePicker.pickFile(
      type: FileType.image,
    );

    if (file != null) {
      final bytes = await file.readAsBytes();
      final resized = await resizeIconBytes(bytes);
      onImageSelected(resized);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Icon Image (256x256)',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Switch Icon Frame Preview
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.inputBackground,
                borderRadius: BorderRadius.circular(
                    20), // Switch home menu rounded square
                border: Border.all(
                  color: imageBytes != null
                      ? AppTheme.switchCyan
                      : AppTheme.cardBorder,
                  width: 2,
                ),
                boxShadow: [
                  if (imageBytes != null)
                    BoxShadow(
                      color: AppTheme.switchCyan.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: imageBytes != null
                    ? Image.memory(
                        imageBytes!,
                        fit: BoxFit.cover,
                        cacheWidth: 256,
                        cacheHeight: 256,
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            color: AppTheme.textMuted,
                            size: 32,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '256 x 256',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.switchCyan,
                      side: const BorderSide(color: AppTheme.switchCyan),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text(
                        imageBytes == null ? 'Select Icon' : 'Change Icon'),
                    onPressed: _pickImage,
                  ),
                  if (imageBytes != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.switchRed,
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Remove Icon',
                          style: TextStyle(fontSize: 12)),
                      onPressed: () => onImageSelected(null),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
