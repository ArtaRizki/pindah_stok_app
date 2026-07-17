import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Exception khusus untuk error yang berasal dari API,
/// supaya UI bisa membedakan pesan yang aman ditampilkan ke user.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  // TODO(keamanan): baseUrl & apiKey sebaiknya tidak di-hardcode di source code
  // (apalagi kalau repo ini pernah/akan jadi public atau di-share).
  // Pindahkan ke --dart-define saat build, contoh:
  //   flutter build apk --dart-define=API_BASE_URL=... --dart-define=API_KEY=...
  // lalu baca dengan String.fromEnvironment('API_BASE_URL').
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://script.google.com/macros/s/AKfycbzhRNywLVVvm_mYIgTYWexnFz4i2FHSK__fHjdbFYVqILggRGPDXV3j-5btKUF9P7q0/exec',
  );

  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: 'RAHASIA123',
  );

  static const Duration _timeout = Duration(seconds: 15);

  static Future<List<LokasiStok>> getStok() async {
    final res = await _request('GET', '$baseUrl?action=getStok&apiKey=$apiKey');
    final body = _decodeJson(res.body);
    if (body['success'] != true) {
      throw ApiException(body['message'] ?? 'Gagal mengambil data stok');
    }
    final List data = body['data'] ?? [];
    return data.map((e) => LokasiStok.fromJson(e)).toList();
  }

  static Future<List<RiwayatTransaksi>> getRiwayat({int limit = 50}) async {
    final res = await _request('GET', '$baseUrl?action=getRiwayat&limit=$limit&apiKey=$apiKey');
    final body = _decodeJson(res.body);
    if (body['success'] != true) {
      throw ApiException(body['message'] ?? 'Gagal mengambil riwayat');
    }
    final List data = body['data'] ?? [];
    return data.map((e) => RiwayatTransaksi.fromJson(e)).toList();
  }

  static Future<Map<String, dynamic>> pindahStok({
    required String dari,
    required String ke,
    required int qty,
    required String oleh,
    String? fotoBase64,
    String? fotoMimeType,
  }) async {
    final res = await _request(
      'POST',
      baseUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'apiKey': apiKey,
        'action': 'pindahStok',
        'dari': dari,
        'ke': ke,
        'qty': qty,
        'oleh': oleh,
        'fotoBase64': fotoBase64,
        'fotoMimeType': fotoMimeType,
      }),
    );
    return _decodeJson(res.body);
  }

  /// Decode JSON dengan pesan error yang informatif kalau response
  /// ternyata bukan JSON (misal halaman login Google / error HTML).
  static Map<String, dynamic> _decodeJson(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      final snippet = raw.length > 150 ? raw.substring(0, 150) : raw;
      throw ApiException('Format response tidak valid (bukan JSON): $snippet');
    }
  }

  // --- API LOGGER WRAPPER ---
  static Future<http.Response> _request(
    String method,
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    _log('REQUEST', method: method, url: url, headers: headers, body: body);

    final uri = Uri.parse(url);
    http.Response response;
    final startTime = DateTime.now();

    try {
      response = await _send(method, uri, headers: headers, body: body).timeout(_timeout);

      // Tangani redirect 302/303 dari Google Apps Script untuk request POST.
      if (response.statusCode == 302 || response.statusCode == 303) {
        final location = response.headers['location'];
        if (location != null) {
          if (kDebugMode) debugPrint('↪️ Mengikuti redirect dari Google Apps Script...');
          response = await http.get(Uri.parse(location)).timeout(_timeout);
        }
      }
    } on TimeoutException {
      throw ApiException('Koneksi timeout, periksa jaringan internet Anda');
    } on SocketException {
      throw ApiException('Tidak ada koneksi internet');
    } on ApiException {
      rethrow;
    } catch (e) {
      _log('ERROR', method: method, url: url, error: e);
      throw ApiException('Gagal menghubungi server: $e');
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    _log('RESPONSE', method: method, url: url, statusCode: response.statusCode, body: response.body, durationMs: duration);

    if (response.statusCode >= 400) {
      throw ApiException('Server merespons dengan error (${response.statusCode})');
    }

    return response;
  }

  static Future<http.Response> _send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    switch (method) {
      case 'POST':
        return http.post(uri, headers: headers, body: body);
      case 'PUT':
        return http.put(uri, headers: headers, body: body);
      case 'PATCH':
        return http.patch(uri, headers: headers, body: body);
      case 'DELETE':
        return http.delete(uri, headers: headers, body: body);
      default:
        return http.get(uri, headers: headers);
    }
  }

  static void _log(
    String tag, {
    String? method,
    String? url,
    Map<String, String>? headers,
    Object? body,
    int? statusCode,
    Object? error,
    int? durationMs,
  }) {
    if (!kDebugMode) return; // Jangan buang waktu build string log di release.

    final buffer = StringBuffer('\n┌─── API $tag ');
    if (method != null) buffer.write('$method ');
    if (statusCode != null) buffer.write('($statusCode, ${durationMs}ms) ');
    buffer.writeln();
    if (url != null) buffer.writeln('│ URL   : $url');
    if (headers != null) buffer.writeln('│ HDR   : $headers');
    if (body != null) buffer.writeln('│ BODY  : ${_truncate(body.toString(), 500)}');
    if (error != null) buffer.writeln('│ ERROR : $error');
    buffer.write('└───────────────────────────────────────');
    debugPrint(buffer.toString());
  }

  static String _truncate(String s, int max) => s.length > max ? '${s.substring(0, max)}... (truncated)' : s;
}