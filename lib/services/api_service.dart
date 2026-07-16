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

  static Future<List<LokasiStok>> getStok() async {
    final res = await _request('GET', '$baseUrl?action=getStok&apiKey=$apiKey');
    final body = jsonDecode(res.body);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal mengambil data stok');
    }
    final List data = body['data'];
    return data.map((e) => LokasiStok.fromJson(e)).toList();
  }

  static Future<List<RiwayatTransaksi>> getRiwayat({int limit = 50}) async {
    final res = await _request('GET', '$baseUrl?action=getRiwayat&limit=$limit&apiKey=$apiKey');
    final body = jsonDecode(res.body);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal mengambil riwayat');
    }
    final List data = body['data'];
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
    
    try {
      return jsonDecode(res.body);
    } catch (e) {
      // Jika terjadi error <HTML>, tampilkan 100 karakter pertama agar kita tahu apa isi errornya (misal: Google Login, Payload Too Large, dll)
      final errorSnippet = res.body.length > 100 ? res.body.substring(0, 100) : res.body;
      throw Exception('Format response tidak valid (bukan JSON). Response: $errorSnippet');
    }
  }

  // --- API LOGGER WRAPPER ---
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
      // Potong body jika terlalu panjang (seperti base64 image)
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
