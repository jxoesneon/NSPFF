// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Event types emitted during network install operations.
abstract class NetworkInstallEvent {
  const NetworkInstallEvent();
}

class ServerStartedEvent extends NetworkInstallEvent {
  final int port;
  final String serverUrl;
  const ServerStartedEvent(this.port, this.serverUrl);
}

class ServerStoppedEvent extends NetworkInstallEvent {
  const ServerStoppedEvent();
}

class ClientConnectedEvent extends NetworkInstallEvent {
  final String clientIp;
  final String endpoint;
  const ClientConnectedEvent(this.clientIp, this.endpoint);
}

class TransferProgressEvent extends NetworkInstallEvent {
  final String filename;
  final int bytesSent;
  final int totalBytes;
  final double speedBytesPerSec;
  const TransferProgressEvent({
    required this.filename,
    required this.bytesSent,
    required this.totalBytes,
    required this.speedBytesPerSec,
  });

  double get progressFraction =>
      totalBytes > 0 ? (bytesSent / totalBytes).clamp(0.0, 1.0) : 0.0;
}

class TransferCompletedEvent extends NetworkInstallEvent {
  final String filename;
  final int totalBytes;
  const TransferCompletedEvent(this.filename, this.totalBytes);
}

class TransferFailedEvent extends NetworkInstallEvent {
  final String filename;
  final String error;
  const TransferFailedEvent(this.filename, this.error);
}

/// Abstraction for an NSP payload source.
///
/// Implementations may be backed by an in-memory [Uint8List] or by a file on
/// disk. This allows the installer to stream large packages without keeping
/// every generated NSP in heap memory.
abstract class NspSource {
  /// The total size, in bytes, of the NSP payload.
  int get length;

  /// The on-disk path for file-backed sources, or `null` for memory-backed
  /// sources.
  String? get filePath;

  /// Streams a contiguous byte range `[start, end]` (both inclusive).
  ///
  /// The returned chunks will not exceed [chunkSize] unless the source yields
  /// them in larger blocks.
  Stream<Uint8List> openRead(int start, int end, {int chunkSize});
}

class _MemoryNspSource implements NspSource {
  final Uint8List _bytes;

  _MemoryNspSource(this._bytes);

  @override
  int get length => _bytes.length;

  @override
  String? get filePath => null;

  @override
  Stream<Uint8List> openRead(int start, int end, {int chunkSize = 256 * 1024}) {
    final effectiveEnd = math.min(end, _bytes.length - 1);
    if (start < 0 || start > effectiveEnd || effectiveEnd < 0) {
      return const Stream<Uint8List>.empty();
    }
    return _memoryStream(start, effectiveEnd, chunkSize);
  }

  Stream<Uint8List> _memoryStream(int start, int end, int chunkSize) async* {
    for (int offset = start; offset <= end; offset += chunkSize) {
      final chunkEnd = math.min(offset + chunkSize, end + 1);
      yield Uint8List.sublistView(_bytes, offset, chunkEnd);
    }
  }
}

class _FileNspSource implements NspSource {
  final File _file;

  _FileNspSource(this._file);

  @override
  int get length {
    try {
      return _file.lengthSync();
    } on FileSystemException {
      return 0;
    }
  }

  @override
  String? get filePath => _file.path;

  @override
  Stream<Uint8List> openRead(int start, int end, {int chunkSize = 256 * 1024}) {
    return _fileStream(start, end, chunkSize);
  }

  Stream<Uint8List> _fileStream(int start, int end, int chunkSize) async* {
    // [File.openRead] treats [end] as exclusive, while our contract is
    // inclusive, so pass end + 1.
    final stream = _file.openRead(start, end + 1);
    Uint8List? carry;

    await for (final chunk in stream) {
      final Uint8List bytes =
          chunk is Uint8List ? chunk : Uint8List.fromList(chunk);

      if (carry == null) {
        carry = bytes;
      } else {
        final merged = Uint8List(carry.length + bytes.length);
        merged.setAll(0, carry);
        merged.setAll(carry.length, bytes);
        carry = merged;
      }

      while (carry != null && carry.length >= chunkSize) {
        yield Uint8List.sublistView(carry, 0, chunkSize);
        carry = carry.length > chunkSize
            ? Uint8List.sublistView(carry, chunkSize)
            : null;
      }
    }

    if (carry != null && carry.isNotEmpty) {
      yield carry;
    }
  }
}

/// HTTP Range request representation.
class _HttpByteRange {
  final int start;
  final int end;
  const _HttpByteRange(this.start, this.end);
  int get length => end - start + 1;
}

/// Embedded HTTP server service for 1-tap direct wireless installation
/// of generated .nsp packages to Nintendo Switch title managers (DBI / Tinfoil).
class NetworkInstallService extends ChangeNotifier {
  static final NetworkInstallService _instance =
      NetworkInstallService._internal();

  factory NetworkInstallService() => _instance;
  static NetworkInstallService get instance => _instance;

  NetworkInstallService._internal();

  HttpServer? _server;
  int _port = 8080;
  String? _localIp;
  String? _sessionToken;

  final Map<String, NspSource> _registeredNsps = <String, NspSource>{};
  final StreamController<NetworkInstallEvent> _eventController =
      StreamController<NetworkInstallEvent>.broadcast();

  // Active transfer state
  String? _activeFilename;
  int _activeBytesSent = 0;
  int _activeTotalBytes = 0;
  double _activeSpeed = 0.0;
  String? _activeClientIp;

  // Throughput / throttling configuration
  static const int _chunkSize = 256 * 1024;
  static const double _emaAlpha = 0.3;
  static const Duration _progressThrottle = Duration(milliseconds: 100);
  static const Duration _idleTimeout = Duration(seconds: 30);
  static final RegExp _safeFilenameRegex = RegExp(r'^[\w.\-+\[\]\(\) ]+$');

  /// Maximum number of bytes the server will agree to serve in a single
  /// response. Requests with a computed content length above this value will
  /// receive a 413 status. The default is 16 GB.
  int maxContentLength = 16 * 1024 * 1024 * 1024;

  /// Maximum size allowed for an HTTP `Range` request. Larger ranges will
  /// receive a 416 status. The default is 1 GB.
  int maxRangeSize = 1024 * 1024 * 1024;

  /// Whether to set a finite idle timeout on the underlying [HttpServer].
  ///
  /// Should remain `true` in production. Widget tests can set this to `false`
  /// because [HttpServer]'s periodic idle timer is not compatible with
  /// `testWidgets`' FakeAsync invariants.
  bool enableIdleTimeout = true;

  bool get isRunning => _server != null;
  int get port => _port;
  String? get localIp => _localIp;

  /// The idle timeout applied to the underlying [HttpServer], or `null` when
  /// the server is not running.
  Duration? get idleTimeout => _server?.idleTimeout;

  Map<String, NspSource> get registeredNsps =>
      Map<String, NspSource>.unmodifiable(_registeredNsps);

  String? get serverUrl =>
      isRunning && _localIp != null ? 'http://$_localIp:$_port' : null;

  Stream<NetworkInstallEvent> get events => _eventController.stream;

  // Active transfer getters
  bool get isTransferring => _activeFilename != null;
  String? get activeFilename => _activeFilename;
  int get activeBytesSent => _activeBytesSent;
  int get activeTotalBytes => _activeTotalBytes;
  double get activeSpeedBytesPerSec => _activeSpeed;
  String? get activeClientIp => _activeClientIp;

  double get activeProgressFraction => _activeTotalBytes > 0
      ? (_activeBytesSent / _activeTotalBytes).clamp(0.0, 1.0)
      : 0.0;

  /// Validates and normalizes a registered filename.
  ///
  /// Returns the safe basename if valid, or `null` if the name contains
  /// path separators, traversal components, absolute paths, or disallowed
  /// characters.
  static String? _validateAndNormalizeFilename(String filename) {
    if (filename.isEmpty || filename.length > 200) return null;
    // Reject backslash and Windows drive-letter separators immediately.
    if (filename.contains(r'\') || filename.contains(':')) return null;

    final base = p.basename(filename);
    // If [p.basename] changed the value, the input contained a path separator
    // or an absolute path prefix.
    if (base != filename) return null;

    if (base.isEmpty || base == '.' || base == '..') return null;
    if (!_safeFilenameRegex.hasMatch(base)) return null;
    return base;
  }

  /// Registers an in-memory NSP file for serving.
  void registerNsp(String filename, Uint8List nspBytes) {
    final safeName = _validateAndNormalizeFilename(filename);
    if (safeName == null) {
      throw ArgumentError.value(filename, 'filename', 'Unsafe filename');
    }
    _registeredNsps[safeName] = _MemoryNspSource(nspBytes);
    notifyListeners();
  }

  /// Registers a file-backed NSP source for serving.
  void registerNspFile(String filename, String filePath) {
    final safeName = _validateAndNormalizeFilename(filename);
    if (safeName == null) {
      throw ArgumentError.value(filename, 'filename', 'Unsafe filename');
    }
    final file = File(filePath);
    if (!file.existsSync()) {
      throw ArgumentError.value(filePath, 'filePath', 'File does not exist');
    }
    _registeredNsps[safeName] = _FileNspSource(file);
    notifyListeners();
  }

  /// Unregisters an NSP file.
  void unregisterNsp(String filename) {
    final safeName = _validateAndNormalizeFilename(filename) ?? filename;
    if (_registeredNsps.remove(safeName) != null) {
      notifyListeners();
    }
  }

  /// Clears all registered NSPs.
  void clearNsps() {
    _registeredNsps.clear();
    notifyListeners();
  }

  /// Returns direct installation URL for a specific NSP file.
  ///
  /// The URL includes a per-session random token that must be presented when
  /// the file is requested.
  String? getDirectInstallUrl(String filename) {
    final base = serverUrl;
    final token = _sessionToken;
    if (base == null || token == null) return null;
    return '$base/nsp/$token/${Uri.encodeComponent(filename)}';
  }

  /// Detects the local LAN IPv4 address of the host device.
  Future<String?> detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      ).timeout(const Duration(seconds: 1),
          onTimeout: () => <NetworkInterface>[]);

      // Prioritize Wi-Fi and Ethernet adapters
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('wlan') ||
            name.contains('wifi') ||
            name.contains('wi-fi') ||
            name.contains('eth') ||
            name.contains('en')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              return addr.address;
            }
          }
        }
      }

      // Fallback to any non-loopback IPv4 address
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('NetworkInstallService: error detecting IP: $e');
    }
    return null;
  }

  /// Starts the embedded HTTP server on the specified port.
  ///
  /// Binds to the selected LAN IPv4 address (or loopback if none is detected)
  /// rather than [InternetAddress.anyIPv4]. A per-session random token is
  /// generated for NSP download URLs.
  Future<String?> startServer({int port = 8080, String? overrideIp}) async {
    if (_server != null) {
      if (_port == port && _localIp != null) {
        return serverUrl;
      }
      await stopServer();
    }

    _port = port;
    _localIp = overrideIp ?? await detectLocalIp() ?? '127.0.0.1';
    // Never bind to the catch-all 0.0.0.0 address.
    if (_localIp == '0.0.0.0') {
      _localIp = '127.0.0.1';
    }

    _sessionToken = _generateSessionToken();

    try {
      final address =
          InternetAddress.tryParse(_localIp!) ?? InternetAddress.loopbackIPv4;
      _server = await HttpServer.bind(address, port);
      _server!.idleTimeout = enableIdleTimeout ? _idleTimeout : null;
      _port = _server!.port; // Update in case port 0 (ephemeral) was requested

      _server!.listen(
        _handleRequest,
        onError: (Object error) {
          debugPrint('NetworkInstallService server error: $error');
        },
        cancelOnError: false,
      );

      final url = serverUrl;
      if (url != null && !_eventController.isClosed) {
        _eventController.add(ServerStartedEvent(_port, url));
      }
      notifyListeners();
      return url;
    } catch (e) {
      debugPrint('NetworkInstallService failed to bind server: $e');
      _server = null;
      _sessionToken = null;
      notifyListeners();
      rethrow;
    }
  }

  String _generateSessionToken() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Stops the embedded HTTP server.
  Future<void> stopServer() async {
    if (_server != null) {
      try {
        await _server!.close(force: true);
      } catch (e) {
        debugPrint('NetworkInstallService error closing server: $e');
      }
      _server = null;
    }

    _sessionToken = null;
    _resetTransferState();
    if (!_eventController.isClosed) {
      _eventController.add(const ServerStoppedEvent());
    }
    notifyListeners();
  }

  void _resetTransferState() {
    _activeFilename = null;
    _activeBytesSent = 0;
    _activeTotalBytes = 0;
    _activeSpeed = 0.0;
    _activeClientIp = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final clientIp = request.connectionInfo?.remoteAddress.address ?? 'unknown';
    final path = request.uri.path;

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (request.method != 'GET' && request.method != 'HEAD') {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }

    if (!_eventController.isClosed) {
      _eventController.add(ClientConnectedEvent(clientIp, path));
    }

    if (path == '/' || path == '/index.json') {
      await _serveJsonIndex(request);
    } else if (path == '/index.html') {
      await _serveHtmlIndex(request);
    } else if (path.startsWith('/nsp/')) {
      await _serveNsp(request, clientIp);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, dynamic>{
        'error': 'Endpoint not found',
        'path': path,
      }));
      await request.response.close();
    }
  }

  /// Serves the JSON directory index compatible with DBI and Tinfoil network indexes.
  Future<void> _serveJsonIndex(HttpRequest request) async {
    final token = _sessionToken;
    final filesList = _registeredNsps.entries.map((e) {
      return <String, dynamic>{
        'name': e.key,
        'size': e.value.length,
        'url': token == null
            ? '/nsp/${Uri.encodeComponent(e.key)}'
            : '/nsp/$token/${Uri.encodeComponent(e.key)}',
      };
    }).toList();

    final responseMap = <String, dynamic>{
      'files': filesList,
      'directories': <String>[],
      'success': true,
      'server': 'NSPFF Direct Wireless Installer',
    };

    final jsonString = jsonEncode(responseMap);
    final utf8Bytes = utf8.encode(jsonString);

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType =
        ContentType('application', 'json', charset: 'utf-8');
    request.response.headers.contentLength = utf8Bytes.length;

    if (request.method != 'HEAD') {
      request.response.add(utf8Bytes);
    }
    await request.response.close();
  }

  /// Serves a clean Horizon OS styled HTML page with file listings and download links.
  Future<void> _serveHtmlIndex(HttpRequest request) async {
    final host = _localIp ?? '127.0.0.1';
    final currentServerUrl = 'http://$host:$_port';
    final token = _sessionToken;

    final itemsHtml = StringBuffer();
    if (_registeredNsps.isEmpty) {
      itemsHtml.writeln(
          '<div class="empty">No NSP files currently registered. Generate forwarders in NSPFF to install!</div>');
    } else {
      for (final entry in _registeredNsps.entries) {
        final filename = entry.key;
        final sizeKb = (entry.value.length / 1024).toStringAsFixed(1);
        final downloadUrl = token == null
            ? '/nsp/${Uri.encodeComponent(filename)}'
            : '/nsp/$token/${Uri.encodeComponent(filename)}';
        itemsHtml.writeln('''
          <div class="card">
            <div class="file-info">
              <div class="file-name">$filename</div>
              <div class="file-size">$sizeKb KB (${entry.value.length} bytes)</div>
            </div>
            <a href="$downloadUrl" class="btn" download="$filename">DOWNLOAD NSP</a>
          </div>
        ''');
      }
    }

    final html = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NSPFF - Wireless Switch Installer</title>
  <style>
    :root {
      --bg: #121216;
      --card-bg: #1B1D26;
      --border: #2E3245;
      --cyan: #00C4EF;
      --red: #FF3655;
      --green: #00E676;
      --text: #F3F4F6;
      --text-muted: #9CA3AF;
    }
    body {
      margin: 0;
      padding: 24px 16px;
      background: var(--bg);
      color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex;
      justify-content: center;
    }
    .container {
      max-width: 640px;
      width: 100%;
    }
    header {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 24px;
      padding-bottom: 16px;
      border-bottom: 2px solid var(--border);
    }
    .pill {
      background: var(--cyan);
      color: #000;
      font-weight: 800;
      font-size: 11px;
      padding: 4px 8px;
      border-radius: 999px;
      letter-spacing: 0.5px;
    }
    h1 {
      margin: 0;
      font-size: 22px;
      font-weight: 800;
      letter-spacing: 0.5px;
    }
    .instructions {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 16px;
      margin-bottom: 24px;
    }
    .instructions h2 {
      margin-top: 0;
      font-size: 15px;
      color: var(--cyan);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .instructions ol {
      margin: 8px 0 0 18px;
      padding: 0;
      color: var(--text-muted);
      font-size: 14px;
      line-height: 1.6;
    }
    .instructions code {
      background: #161820;
      color: var(--cyan);
      padding: 2px 6px;
      border-radius: 4px;
      font-size: 13px;
    }
    .card {
      background: var(--card-bg);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 16px;
      margin-bottom: 12px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
    }
    .file-name {
      font-weight: 700;
      font-size: 15px;
      word-break: break-all;
    }
    .file-size {
      color: var(--text-muted);
      font-size: 12px;
      margin-top: 4px;
    }
    .btn {
      background: var(--cyan);
      color: #000;
      text-decoration: none;
      padding: 10px 16px;
      border-radius: 8px;
      font-weight: 700;
      font-size: 13px;
      white-space: nowrap;
      transition: opacity 0.2s;
    }
    .btn:hover {
      opacity: 0.9;
    }
    .empty {
      text-align: center;
      padding: 32px 16px;
      color: var(--text-muted);
      font-size: 14px;
      background: var(--card-bg);
      border: 1px dashed var(--border);
      border-radius: 12px;
    }
    footer {
      text-align: center;
      margin-top: 32px;
      font-size: 12px;
      color: var(--text-muted);
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>NSPFF Direct Wireless Installer</h1>
      <span class="pill">ONLINE</span>
    </header>

    <div class="instructions">
      <h2>Install on Nintendo Switch via DBI:</h2>
      <ol>
        <li>Open <strong>DBI</strong> on your Nintendo Switch.</li>
        <li>Select <strong>Install title from DBI backend / URL</strong>.</li>
        <li>Enter server URL: <code>$currentServerUrl</code></li>
      </ol>
    </div>

    <h2 style="font-size: 16px; margin: 0 0 12px 0;">Available NSP Packages</h2>
    $itemsHtml

    <footer>NSP Fast Forward (NSPFF) &bull; Embedded Stream Server</footer>
  </div>
</body>
</html>
''';

    final bytes = utf8.encode(html);
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType =
        ContentType('text', 'html', charset: 'utf-8');
    request.response.headers.contentLength = bytes.length;

    if (request.method != 'HEAD') {
      request.response.add(bytes);
    }
    await request.response.close();
  }

  /// Streams the requested NSP file with range request support and live progress events.
  Future<void> _serveNsp(HttpRequest request, String clientIp) async {
    final segments = request.uri.pathSegments;
    if (segments.length != 3 || segments[0] != 'nsp') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final token = segments[1];
    if (_sessionToken == null || token != _sessionToken) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    final filename = segments[2];
    final safeName = _validateAndNormalizeFilename(filename);
    if (safeName == null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, dynamic>{
        'error': 'Invalid filename',
        'filename': filename,
      }));
      await request.response.close();
      return;
    }

    final source = _registeredNsps[safeName];
    if (source == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, dynamic>{
        'error': 'NSP not found',
        'filename': safeName,
      }));
      await request.response.close();
      return;
    }

    final totalSize = source.length;
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

    _HttpByteRange? range;
    if (rangeHeader != null) {
      range = _parseRangeHeader(rangeHeader, totalSize);
      if (range == null) {
        request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        request.response.headers.set('Content-Range', 'bytes */$totalSize');
        await request.response.close();
        return;
      }
    }

    final int start = range?.start ?? 0;
    final int end = range?.end ?? (totalSize - 1);
    if (start < 0 || end < start || start >= totalSize) {
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      request.response.headers.set('Content-Range', 'bytes */$totalSize');
      await request.response.close();
      return;
    }

    final int contentLength = end - start + 1;
    if (contentLength > maxContentLength) {
      request.response.statusCode = HttpStatus.requestEntityTooLarge;
      await request.response.close();
      return;
    }

    request.response.statusCode =
        range != null ? HttpStatus.partialContent : HttpStatus.ok;
    request.response.headers.set('Content-Type', 'application/x-nsp');
    request.response.headers.set('Accept-Ranges', 'bytes');
    request.response.headers.set(
      'Content-Disposition',
      'attachment; filename="${Uri.encodeComponent(safeName)}"',
    );
    request.response.headers.contentLength = contentLength;

    if (range != null) {
      request.response.headers
          .set('Content-Range', 'bytes $start-$end/$totalSize');
    }

    if (request.method == 'HEAD') {
      await request.response.close();
      return;
    }

    // Initialize active transfer state
    _activeFilename = safeName;
    _activeBytesSent = 0;
    _activeTotalBytes = contentLength;
    _activeSpeed = 0.0;
    _activeClientIp = clientIp;
    notifyListeners();

    final stopwatch = Stopwatch()..start();
    var lastSampleTime = Duration.zero;
    var lastEmitTime = Duration.zero;

    void emitProgress() {
      if (!_eventController.isClosed) {
        _eventController.add(TransferProgressEvent(
          filename: safeName,
          bytesSent: _activeBytesSent,
          totalBytes: _activeTotalBytes,
          speedBytesPerSec: _activeSpeed,
        ));
      }
      notifyListeners();
    }

    try {
      await for (final chunk
          in source.openRead(start, end, chunkSize: _chunkSize)) {
        request.response.add(chunk);

        _activeBytesSent += chunk.length;

        final now = stopwatch.elapsed;
        final delta = now - lastSampleTime;
        if (delta > const Duration(microseconds: 1)) {
          final instant = chunk.length / (delta.inMicroseconds / 1e6);
          _activeSpeed = _activeSpeed == 0.0
              ? instant
              : _emaAlpha * instant + (1 - _emaAlpha) * _activeSpeed;
        }
        lastSampleTime = now;

        if (now - lastEmitTime >= _progressThrottle) {
          lastEmitTime = now;
          emitProgress();
        }
      }

      await request.response.close();
      emitProgress();
      _eventController.add(TransferCompletedEvent(safeName, contentLength));
    } catch (e) {
      _eventController.add(TransferFailedEvent(safeName, e.toString()));
      debugPrint('NetworkInstallService client streaming cancelled/error: $e');
      try {
        await request.response.close();
      } catch (_) {
        // Already closed or broken pipe; ignore.
      }
    } finally {
      _resetTransferState();
      notifyListeners();
    }
  }

  /// Parses an RFC 7233 HTTP Range header.
  _HttpByteRange? _parseRangeHeader(String header, int totalLength) {
    final trimmed = header.trim();
    if (!trimmed.startsWith('bytes=')) return null;

    final spec = trimmed.substring(6).trim();
    // Only single range is supported for streaming NSPs
    if (spec.contains(',')) return null;

    final dashIdx = spec.indexOf('-');
    if (dashIdx == -1) return null;

    final startStr = spec.substring(0, dashIdx).trim();
    final endStr = spec.substring(dashIdx + 1).trim();

    int start;
    int end;

    if (startStr.isEmpty) {
      // Suffix range: "-500" -> last 500 bytes
      final suffixLen = int.tryParse(endStr);
      if (suffixLen == null || suffixLen <= 0) return null;
      start = (totalLength - suffixLen).clamp(0, totalLength);
      end = totalLength - 1;
    } else {
      final parsedStart = int.tryParse(startStr);
      if (parsedStart == null || parsedStart < 0) return null;
      start = parsedStart;
      if (endStr.isEmpty) {
        end = totalLength - 1;
      } else {
        final parsedEnd = int.tryParse(endStr);
        if (parsedEnd == null || parsedEnd < start) return null;
        end = parsedEnd.clamp(0, totalLength - 1);
      }
    }

    if (start >= totalLength) return null;

    final length = end - start + 1;
    if (length > maxRangeSize) return null;

    return _HttpByteRange(start, end);
  }

  @override
  void dispose() {
    stopServer();
    _eventController.close();
    super.dispose();
  }
}
