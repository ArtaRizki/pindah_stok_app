import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  // Ganti dengan URL /exec hasil deploy Web App Google Apps Script (Code.gs)
  static const String baseUrl =
      'https://script.google.com/macros/s/AKfycbzhRNywLVVvm_mYIgTYWexnFz4i2FHSK__fHjdbFYVqILggRGPDXV3j-5btKUF9P7q0/exec';

  // API Key yang sama dengan di Code.gs
  static const String apiKey = 'RAHASIA123';

  // ─────────────────────────────────────────────
  // GET: Daftar nama lokasi
  // ─────────────────────────────────────────────
  static Future<List<String>> getLokasi() async {
    final res = await _request('GET', '$baseUrl?action=getLokasi&apiKey=$apiKey');
    final body = jsonDecode(res.body);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal mengambil daftar lokasi');
    }
    final List data = body['data'];
    return data.map((e) => e.toString()).toList();
  }

  // ─────────────────────────────────────────────
  // GET: Daftar admin
  // ─────────────────────────────────────────────
  static Future<List<String>> getAdmin() async {
    final res = await _request('GET', '$baseUrl?action=getAdmin&apiKey=$apiKey');
    final body = jsonDecode(res.body);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal mengambil daftar admin');
    }
    final List data = body['data'];
    return data.map((e) => e.toString()).toList();
  }

  // ─────────────────────────────────────────────
  // GET: Stok per lokasi per jenis
  // ─────────────────────────────────────────────
  static Future<List<LokasiStok>> getStok() async {
    final res = await _request('GET', '$baseUrl?action=getStok&apiKey=$apiKey');
    final body = jsonDecode(res.body);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal mengambil data stok');
    }
    final List data = body['data'];
    return data.map((e) => LokasiStok.fromJson(e)).toList();
  }

  // ─────────────────────────────────────────────
  // GET: Riwayat transaksi
  // ─────────────────────────────────────────────
  static Future<List<RiwayatTransaksi>> getRiwayat({
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    String url = '$baseUrl?action=getRiwayat&limit=$limit&apiKey=$apiKey';
    if (startDate != null) {
      url += '&startDate=${startDate.toIso8601String()}';
    }
    if (endDate != null) {
      url += '&endDate=${endDate.toIso8601String()}';
    }
    final res = await _request('GET', url);
    final body = jsonDecode(res.body);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal mengambil riwayat');
    }
    final List data = body['data'];
    return data.map((e) => RiwayatTransaksi.fromJson(e)).toList();
  }

  // ─────────────────────────────────────────────
  // POST: Pindah stok (multi-jenis)
  // quantities: Map<String, int> — key = nama jenis (DRB KUNING, MSU, dst)
  // ─────────────────────────────────────────────
  static Future<Map<String, dynamic>> pindahStok({
    required String dari,
    required String ke,
    required Map<String, int> quantities,
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
        'dari':   dari,
        'ke':     ke,
        'qty':    quantities,
        'oleh':   oleh,
        'fotoBase64':   fotoBase64,
        'fotoMimeType': fotoMimeType,
      }),
    );

    try {
      return jsonDecode(res.body);
    } catch (e) {
      final snippet = res.body.length > 200 ? res.body.substring(0, 200) : res.body;
      throw Exception('Format response tidak valid (bukan JSON). Response: $snippet');
    }
  }

  // ─────────────────────────────────────────────
  // API LOGGER WRAPPER
  // ─────────────────────────────────────────────
  static Future<http.Response> _request(
    String method,
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    debugPrint('\n┌────────────────────────────────────────────────────────');
    debugPrint('│ 🌐 API REQUEST : $method');
    debugPrint('│ 🔗 URL         : $url');
    if (headers != null) debugPrint('│ 📋 HEADERS     : $headers');
    if (body != null) {
      final bodyStr = body.toString();
      if (bodyStr.length > 500) {
        debugPrint('│ 📦 BODY        : ${bodyStr.substring(0, 500)}... (truncated)');
      } else {
        debugPrint('│ 📦 BODY        : $bodyStr');
      }
    }
    debugPrint('└────────────────────────────────────────────────────────');

    final uri = Uri.parse(url);
    http.Response response;
    final startTime = DateTime.now();

    try {
      if (method == 'POST') {
        response = await http.post(uri, headers: headers, body: body);
        // Tangani redirect 302 dari Google Apps Script untuk request POST
        if (response.statusCode == 302 || response.statusCode == 303) {
          final location = response.headers['location'];
          if (location != null) {
            debugPrint('│ ↪️ REDIRECT    : Mengikuti redirect dari Google Apps Script...');
            response = await http.get(Uri.parse(location));
          }
        }
      } else if (method == 'PUT') {
        response = await http.put(uri, headers: headers, body: body);
      } else if (method == 'PATCH') {
        response = await http.patch(uri, headers: headers, body: body);
      } else if (method == 'DELETE') {
        response = await http.delete(uri, headers: headers, body: body);
      } else {
        response = await http.get(uri, headers: headers);
      }
    } catch (e) {
      debugPrint('\n┌────────────────────────────────────────────────────────');
      debugPrint('│ ❌ API ERROR   : $method $url');
      debugPrint('│ 💥 EXCEPTION   : $e');
      debugPrint('└────────────────────────────────────────────────────────');
      rethrow;
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;

    debugPrint('\n┌────────────────────────────────────────────────────────');
    debugPrint('│ 📥 API RESPONSE: $method (Status: ${response.statusCode}) - ${duration}ms');
    debugPrint('│ 🔗 URL         : $url');
    final respStr = response.body;
    if (respStr.length > 1000) {
      debugPrint('│ 📄 BODY        : ${respStr.substring(0, 1000)}... (truncated)');
    } else {
      debugPrint('│ 📄 BODY        : $respStr');
    }
    debugPrint('└────────────────────────────────────────────────────────\n');

    return response;
  }
}