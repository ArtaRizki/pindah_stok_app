import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  // Ganti dengan URL /exec hasil deploy Web App Google Apps Script (Code.gs)
  static const String baseUrl =
      'https://script.google.com/macros/s/GANTI_DENGAN_DEPLOYMENT_ID/exec';

  static Future<List<LokasiStok>> getStok() async {
    final res = await http.get(Uri.parse('$baseUrl?action=getStok'));
    final body = jsonDecode(res.body);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal mengambil data stok');
    }
    final List data = body['data'];
    return data.map((e) => LokasiStok.fromJson(e)).toList();
  }

  static Future<List<RiwayatTransaksi>> getRiwayat({int limit = 50}) async {
    final res = await http.get(Uri.parse('$baseUrl?action=getRiwayat&limit=$limit'));
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
    final res = await http.post(
      Uri.parse(baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'pindahStok',
        'dari': dari,
        'ke': ke,
        'qty': qty,
        'oleh': oleh,
        'fotoBase64': fotoBase64,
        'fotoMimeType': fotoMimeType,
      }),
    );
    return jsonDecode(res.body);
  }
}
