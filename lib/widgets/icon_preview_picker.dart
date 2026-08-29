import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme/switch_theme.dart';

class IconPreviewPicker extends StatelessWidget {
  final Uint8List? imageBytes;
  final ValueChanged<Uint8List?> onImageSelected;

  const IconPreviewPicker({
    Key? key,
    this.imageBytes,
    required this.onImageSelected,
  }) : super(key: key);

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,

    );

    if (result != null && result.files.single.bytes != null) {
      onImageSelected(result.files.single.bytes);
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
            fontSize: 13,
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
                borderRadius: BorderRadius.circular(20), // Switch home menu rounded square
                border: Border.all(
                  color: imageBytes != null ? AppTheme.switchCyan : AppTheme.cardBorder,
                  width: 2,
                ),
                boxShadow: [
                  if (imageBytes != null)
                    BoxShadow(
                      color: AppTheme.switchCyan.withOpacity(0.3),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text(imageBytes == null ? 'Select Icon' : 'Change Icon'),
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
                      label: const Text('Remove Icon', style: TextStyle(fontSize: 12)),
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
