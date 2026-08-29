import 'dart:convert';
import 'dart:typed_data';

class NroMetadata {
  final String title;
  final String author;
  final String version;
  final Uint8List? iconBytes;

  NroMetadata({
    required this.title,
    required this.author,
    required this.version,
    this.iconBytes,
  });
}

class NroParser {
  /// Extract metadata and icon from `.nro` binary data.
  static NroMetadata? parseNro(Uint8List nroBytes) {
    if (nroBytes.length < 0x40) return null;

    final ByteData view = ByteData.sublistView(nroBytes);

    // Verify NRO0 magic at offset 0x10
    final String magic = String.fromCharCodes(nroBytes.sublist(0x10, 0x14));
    if (magic != 'NRO0') return null;

    // Check size of NRO file
    final int nroSize = view.getUint32(0x18, Endian.little);
    if (nroBytes.length < nroSize + 0x38) return null;

    // Look for ASET header at nroSize
    final int assetHeaderOffset = nroSize;
    if (assetHeaderOffset + 0x38 > nroBytes.length) return null;

    final String assetMagic = String.fromCharCodes(
      nroBytes.sublist(assetHeaderOffset, assetHeaderOffset + 0x04),
    );

    if (assetMagic != 'ASET') return null;

    // Extract Icon Section (Offset relative to ASET header)
    final int iconOffset = view.getUint64(assetHeaderOffset + 0x08, Endian.little).toInt();
    final int iconSize = view.getUint64(assetHeaderOffset + 0x10, Endian.little).toInt();

    Uint8List? iconBytes;
    if (iconSize > 0 && assetHeaderOffset + iconOffset + iconSize <= nroBytes.length) {
      iconBytes = nroBytes.sublist(assetHeaderOffset + iconOffset, assetHeaderOffset + iconOffset + iconSize);
    }

    // Extract NACP Section
    final int nacpOffset = view.getUint64(assetHeaderOffset + 0x18, Endian.little).toInt();
    final int nacpSize = view.getUint64(assetHeaderOffset + 0x20, Endian.little).toInt();

    String title = '';
    String author = '';
    String version = '1.0.0';

    if (nacpSize >= 0x4000 && assetHeaderOffset + nacpOffset + nacpSize <= nroBytes.length) {
      final int nacpStart = assetHeaderOffset + nacpOffset;

      // Extract Title (Language 0 - American English)
      final titleSub = nroBytes.sublist(nacpStart, nacpStart + 0x200);
      final int nullIdxTitle = titleSub.indexOf(0);
      final titleRaw = nullIdxTitle != -1 ? titleSub.sublist(0, nullIdxTitle) : titleSub;
      title = const Utf8Decoder(allowMalformed: true).convert(titleRaw).trim();

      // Extract Author (Language 0)
      final authorSub = nroBytes.sublist(nacpStart + 0x200, nacpStart + 0x300);
      final int nullIdxAuthor = authorSub.indexOf(0);
      final authorRaw = nullIdxAuthor != -1 ? authorSub.sublist(0, nullIdxAuthor) : authorSub;
      author = const Utf8Decoder(allowMalformed: true).convert(authorRaw).trim();

      // Extract Version
      final verSub = nroBytes.sublist(nacpStart + 0x3060, nacpStart + 0x3070);
      final int nullIdxVer = verSub.indexOf(0);
      final verRaw = nullIdxVer != -1 ? verSub.sublist(0, nullIdxVer) : verSub;
      final parsedVer = const Utf8Decoder(allowMalformed: true).convert(verRaw).trim();
      if (parsedVer.isNotEmpty) {
        version = parsedVer;
      }
    }

    return NroMetadata(
      title: title.isNotEmpty ? title : 'Homebrew App',
      author: author.isNotEmpty ? author : 'Homebrew Dev',
      version: version,
      iconBytes: iconBytes,
    );
  }
}
