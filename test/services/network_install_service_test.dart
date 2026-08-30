// Copyright (c) 2026 NSPFF Project Contributors.
// SPDX-License-Identifier: MIT

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nspff/services/network_install_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = null;
  });

  late NetworkInstallService service;

  setUp(() async {
    service = NetworkInstallService.instance;
    await service.stopServer();
    service.clearNsps();
    service.maxRangeSize = 1024 * 1024 * 1024;
    service.maxContentLength = 16 * 1024 * 1024 * 1024;
  });

  tearDown(() async {
    await service.stopServer();
    service.clearNsps();
    service.maxRangeSize = 1024 * 1024 * 1024;
    service.maxContentLength = 16 * 1024 * 1024 * 1024;
  });

  group('NetworkInstallService - Server Lifecycle Tests', () {
    test('Server starts, reports correct port and stops cleanly', () async {
      expect(service.isRunning, isFalse);
      expect(service.serverUrl, isNull);

      // Start on ephemeral/dynamic port (port 0) for test isolation
      final url = await service.startServer(port: 0, overrideIp: '127.0.0.1');

      expect(service.isRunning, isTrue);
      expect(service.port, greaterThan(0));
      expect(url, equals('http://127.0.0.1:${service.port}'));
      expect(service.serverUrl, equals(url));
      expect(service.idleTimeout, equals(const Duration(seconds: 30)));

      // Emits ServerStoppedEvent on stop
      bool stoppedEmitted = false;
      final sub = service.events.listen((event) {
        if (event is ServerStoppedEvent) {
          stoppedEmitted = true;
        }
      });

      await service.stopServer();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(service.isRunning, isFalse);
      expect(service.serverUrl, isNull);
      expect(stoppedEmitted, isTrue);
      await sub.cancel();
    });

    test('Restarting or changing port stops previous instance gracefully',
        () async {
      await service.startServer(port: 0, overrideIp: '127.0.0.1');
      final firstPort = service.port;
      expect(firstPort, greaterThan(0));
      expect(service.isRunning, isTrue);

      // Start again on another ephemeral port
      await service.startServer(port: 0, overrideIp: '127.0.0.1');
      expect(service.isRunning, isTrue);
      expect(service.port, greaterThan(0));

      await service.stopServer();
      expect(service.isRunning, isFalse);
    });

    test('Binds to the selected IP, not 0.0.0.0', () async {
      await service.startServer(port: 0, overrideIp: '127.0.0.1');
      final url = service.serverUrl!;
      expect(url, startsWith('http://127.0.0.1'));

      final response = await http.get(Uri.parse(url));
      expect(response.statusCode, equals(200));
    });
  });

  group('NetworkInstallService - Security & Token Tests', () {
    test('Direct install URL contains a per-session token', () async {
      await service.startServer(port: 0, overrideIp: '127.0.0.1');

      const filename = 'SuperMario [0100000000010000].nsp';
      service.registerNsp(filename, Uint8List.fromList([1, 2, 3]));

      final directUrl = service.getDirectInstallUrl(filename);
      expect(directUrl, isNotNull);

      final uri = Uri.parse(directUrl!);
      expect(uri.pathSegments.length, equals(3));
      expect(uri.pathSegments[0], equals('nsp'));
      expect(uri.pathSegments[1], isNotEmpty);
      expect(uri.pathSegments[2], equals(filename));
    });

    test('Requests without a valid token are rejected', () async {
      await service.startServer(port: 0, overrideIp: '127.0.0.1');

      const filename = 'TokenTest.nsp';
      service.registerNsp(
          filename, Uint8List.fromList([0x50, 0x46, 0x53, 0x30]));

      final directUrl = service.getDirectInstallUrl(filename)!;
      final baseUri = Uri.parse(directUrl);

      // Missing token
      final noToken =
          baseUri.replace(path: '/nsp/${Uri.encodeComponent(filename)}');
      final noTokenRes = await http.get(noToken);
      expect(noTokenRes.statusCode, equals(404));

      // Wrong token
      final wrongToken = baseUri.replace(
        path: '/nsp/wrongtoken/${Uri.encodeComponent(filename)}',
      );
      final wrongTokenRes = await http.get(wrongToken);
      expect(wrongTokenRes.statusCode, equals(403));

      // Correct token
      final correctRes = await http.get(baseUri);
      expect(correctRes.statusCode, equals(200));
      expect(correctRes.bodyBytes,
          equals(Uint8List.fromList([0x50, 0x46, 0x53, 0x30])));
    });

    test('Rejects requests with path traversal or unsafe filenames', () async {
      await service.startServer(port: 0, overrideIp: '127.0.0.1');

      const filename = 'Safe.nsp';
      service.registerNsp(filename, Uint8List.fromList([1, 2, 3]));

      final token =
          Uri.parse(service.getDirectInstallUrl(filename)!).pathSegments[1];

      // Path with encoded separators is decoded to a single segment containing
      // traversal: e.g. ../../etc/passwd. The basename differs, so it is
      // rejected as an invalid filename before any lookup.
      final traversal = Uri.parse(
        '${service.serverUrl}/nsp/$token/..%2F..%2Fetc%2Fpasswd',
      );
      final traversalRes = await http.get(traversal);
      expect(traversalRes.statusCode, equals(400));

      // A filename containing a raw path separator is also rejected.
      final withSlash = Uri.parse(
        '${service.serverUrl}/nsp/$token/foo%2Fbar.nsp',
      );
      final withSlashRes = await http.get(withSlash);
      expect(withSlashRes.statusCode, equals(400));

      // Registration itself rejects traversal components.
      expect(
        () => service.registerNsp('..', Uint8List.fromList([1])),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Does not send wildcard CORS headers', () async {
      await service.startServer(port: 0, overrideIp: '127.0.0.1');
      service.registerNsp('CorsTest.nsp', Uint8List.fromList([1, 2, 3]));

      final directUrl = service.getDirectInstallUrl('CorsTest.nsp')!;
      final response = await http.get(Uri.parse(directUrl));

      expect(response.statusCode, equals(200));
      expect(response.headers['access-control-allow-origin'], isNull);
      expect(response.headers['access-control-allow-headers'], isNull);
    });
  });

  group('NetworkInstallService - NSP Registration & Index Endpoints', () {
    test('JSON index endpoint returns format compatible with DBI and Tinfoil',
        () async {
      await service.startServer(port: 0, overrideIp: '127.0.0.1');

      // Register sample NSPs
      final nsp1Bytes = Uint8List.fromList(List.generate(1024, (i) => i % 256));
      final nsp2Bytes =
          Uint8List.fromList(List.generate(2048, (i) => (i * 2) % 256));

      service.registerNsp('SuperMario [0100000000010000].nsp', nsp1Bytes);
      service.registerNsp('Zelda [0100000000020000].nsp', nsp2Bytes);

      expect(service.registeredNsps.length, equals(2));

      // Query GET /
      final rootUri = Uri.parse(service.serverUrl!);
      final response = await http.get(rootUri);

      expect(response.statusCode, equals(200));
      expect(response.headers['content-type'], contains('application/json'));

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data['success'], isTrue);
      expect(data['directories'], isEmpty);

      final files =
          (data['files'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(files.length, equals(2));

      final mario = files
          .firstWhere((f) => f['name'] == 'SuperMario [0100000000010000].nsp');
      expect(mario['size'], equals(1024));
      expect(mario['url'], contains('/nsp/'));

      final zelda =
          files.firstWhere((f) => f['name'] == 'Zelda [0100000000020000].nsp');
      expect(zelda['size'], equals(2048));

      // Also verify GET /index.json produces identical directory output
      final jsonIndexUri = Uri.parse('${service.serverUrl}/index.json');
      final jsonResponse = await http.get(jsonIndexUri);
      expect(jsonResponse.statusCode, equals(200));
      final jsonIndexData =
          jsonDecode(jsonResponse.body) as Map<String, dynamic>;
      expect(jsonIndexData['files'].length, equals(2));
    });

    test('HTML index endpoint serves styled browser page with download links',
        () async {
      await service.startServer(port: 0, overrideIp: '127.0.0.1');

      final sampleNsp = Uint8List.fromList([0x50, 0x46, 0x53, 0x30]); // PFS0
      service.registerNsp('TestGame [0100ABCDEF123456].nsp', sampleNsp);

      final htmlUri = Uri.parse('${service.serverUrl}/index.html');
      final response = await http.get(htmlUri);

      expect(response.statusCode, equals(200));
      expect(response.headers['content-type'], contains('text/html'));
      expect(response.body, contains('NSPFF Direct Wireless Installer'));
      expect(response.body, contains('TestGame [0100ABCDEF123456].nsp'));
      expect(response.body, contains('Install title from DBI backend / URL'));
    });

    test('Can register and serve file-backed NSP source', () async {
      await service.startServer(port: 0, overrideIp: '127.0.0.1');

      final tempDir = await Directory.systemTemp.createTemp('nspff_nis_');
      addTearDown(() async => tempDir.delete(recursive: true));

      final payload =
          Uint8List.fromList(List.generate(1024, (i) => (i * 3) % 256));
      const filename = 'FileBacked [0500000000000010].nsp';
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(payload);

      service.registerNspFile(filename, file.path);

      final source = service.registeredNsps[filename];
      expect(source, isNotNull);
      expect(source!.filePath, equals(file.path));
      expect(source.length, equals(payload.length));

      final directUrl = service.getDirectInstallUrl(filename);
      expect(directUrl, isNotNull);

      final response = await http.get(Uri.parse(directUrl!));
      expect(response.statusCode, equals(200));
      expect(response.bodyBytes, equals(payload));

      await service.stopServer();
    });
  });

  group('NetworkInstallService - Streaming & Range Requests', () {
    test(
        'Streams registered NSP payload with correct content-type, length, and headers',
        () async {
      await service.startServer(port: 0, overrideIp: '127.0.0.1');

      // Create a 64KB synthetic NSP file
      final payload = Uint8List.fromList(List.generate(65536, (i) => i % 251));
      const filename = 'Forwarder [0500000000000010].nsp';
      service.registerNsp(filename, payload);

      final directUrl = service.getDirectInstallUrl(filename);
      expect(directUrl, isNotNull);

      // Verify HEAD request
      final headResponse = await http.head(Uri.parse(directUrl!));
      expect(headResponse.statusCode, equals(200));
      expect(headResponse.headers['content-type'], equals('application/x-nsp'));
      expect(headResponse.headers['content-length'], equals('65536'));
      expect(headResponse.headers['accept-ranges'], equals('bytes'));
      expect(headResponse.bodyBytes, isEmpty);

      // Verify GET request
      final getResponse = await http.get(Uri.parse(directUrl));
      expect(getResponse.statusCode, equals(200));
      expect(getResponse.headers['content-type'], equals('application/x-nsp'));
      expect(getResponse.headers['content-length'], equals('65536'));
      expect(getResponse.headers['accept-ranges'], equals('bytes'));
      expect(getResponse.bodyBytes, equals(payload));
    });

    test('Handles RFC 7233 HTTP Range requests (Partial Content 206)',
        () async {
      await service.startServer(port: 0, overrideIp: '127.0.0.1');

      final payload = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      const filename = 'RangedTitle.nsp';
      service.registerNsp(filename, payload);

      final directUrl = service.getDirectInstallUrl(filename)!;

      // 1. Specific range: bytes=0-499 (500 bytes)
      final range1Res = await http.get(
        Uri.parse(directUrl),
        headers: {'Range': 'bytes=0-499'},
      );
      expect(range1Res.statusCode, equals(206));
      expect(range1Res.headers['content-range'], equals('bytes 0-499/1000'));
      expect(range1Res.headers['content-length'], equals('500'));
      expect(range1Res.bodyBytes, equals(payload.sublist(0, 500)));

      // 2. Open-ended range: bytes=500- (last 500 bytes)
      final range2Res = await http.get(
        Uri.parse(directUrl),
        headers: {'Range': 'bytes=500-'},
      );
      expect(range2Res.statusCode, equals(206));
      expect(range2Res.headers['content-range'], equals('bytes 500-999/1000'));
      expect(range2Res.headers['content-length'], equals('500'));
      expect(range2Res.bodyBytes, equals(payload.sublist(500, 1000)));

      // 3. Suffix range: bytes=-200 (last 200 bytes)
      final range3Res = await http.get(
        Uri.parse(directUrl),
        headers: {'Range': 'bytes=-200'},
      );
      expect(range3Res.statusCode, equals(206));
      expect(range3Res.headers['content-range'], equals('bytes 800-999/1000'));
      expect(range3Res.headers['content-length'], equals('200'));
      expect(range3Res.bodyBytes, equals(payload.sublist(800, 1000)));

      // 4. Unsatisfiable range: bytes=2000-3000 -> 416
      final invalidRangeRes = await http.get(
        Uri.parse(directUrl),
        headers: {'Range': 'bytes=2000-3000'},
      );
      expect(invalidRangeRes.statusCode, equals(416));
      expect(invalidRangeRes.headers['content-range'], equals('bytes */1000'));
    });

    test('Returns 404 for unknown endpoints and unregistered NSPs', () async {
      await service.startServer(port: 0, overrideIp: '127.0.0.1');

      final notFoundNsp = await http.get(
        Uri.parse('${service.serverUrl}/nsp/nonexistent.nsp'),
      );
      expect(notFoundNsp.statusCode, equals(404));

      final unknownRoute = await http.get(
        Uri.parse('${service.serverUrl}/unknown/route'),
      );
      expect(unknownRoute.statusCode, equals(404));
    });

    test('Emits transfer progress and completion events during streaming',
        () async {
      await service.startServer(port: 0, overrideIp: '127.0.0.1');

      // 128KB payload (spans multiple 256KB chunks, but only one here)
      final payload = Uint8List.fromList(List.generate(131072, (i) => i % 256));
      const filename = 'ProgressTest.nsp';
      service.registerNsp(filename, payload);

      final eventsList = <NetworkInstallEvent>[];
      final sub = service.events.listen(eventsList.add);

      final directUrl = service.getDirectInstallUrl(filename)!;
      final res = await http.get(Uri.parse(directUrl));
      expect(res.statusCode, equals(200));

      await Future<void>.delayed(const Duration(milliseconds: 30));

      final progressEvents =
          eventsList.whereType<TransferProgressEvent>().toList();
      expect(progressEvents, isNotEmpty);
      expect(progressEvents.last.bytesSent, equals(131072));
      expect(progressEvents.last.totalBytes, equals(131072));
      expect(progressEvents.last.progressFraction, equals(1.0));

      final completedEvents =
          eventsList.whereType<TransferCompletedEvent>().toList();
      expect(completedEvents.length, equals(1));
      expect(completedEvents.first.filename, equals(filename));
      expect(completedEvents.first.totalBytes, equals(131072));

      await sub.cancel();
    });

    test('Enforces maximum range size and content length caps', () async {
      await service.startServer(port: 0, overrideIp: '127.0.0.1');

      // Create a 4KB in-memory NSP and lower the caps for this test.
      final payload = Uint8List.fromList(List.generate(4096, (i) => i % 256));
      const filename = 'Capped.nsp';
      service.registerNsp(filename, payload);

      final directUrl = service.getDirectInstallUrl(filename)!;

      service.maxRangeSize = 1024;
      addTearDown(() => service.maxRangeSize = 1024 * 1024 * 1024);

      // Range request larger than maxRangeSize -> 416
      final bigRangeRes = await http.get(
        Uri.parse(directUrl),
        headers: {'Range': 'bytes=0-2047'},
      );
      expect(bigRangeRes.statusCode, equals(416));

      service.maxContentLength = 1024;
      addTearDown(() => service.maxContentLength = 16 * 1024 * 1024 * 1024);

      // Full file download would exceed maxContentLength -> 413
      final tooLargeRes = await http.get(Uri.parse(directUrl));
      expect(tooLargeRes.statusCode, equals(413));
    });

    test('Unregister and clear removes NSPs from serving map', () {
      final sample = Uint8List.fromList([1, 2, 3]);
      service.registerNsp('game1.nsp', sample);
      service.registerNsp('game2.nsp', sample);
      expect(service.registeredNsps.length, equals(2));

      service.unregisterNsp('game1.nsp');
      expect(service.registeredNsps.containsKey('game1.nsp'), isFalse);
      expect(service.registeredNsps.containsKey('game2.nsp'), isTrue);

      service.clearNsps();
      expect(service.registeredNsps, isEmpty);
    });
  });
}
