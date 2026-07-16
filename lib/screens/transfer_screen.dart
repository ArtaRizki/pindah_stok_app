import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class TransferScreen extends StatefulWidget {
  final List<String> daftarLokasi;
  const TransferScreen({super.key, required this.daftarLokasi});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  String? _dari;
  String? _ke;
  final _qtyController = TextEditingController();
  final _olehController = TextEditingController();
  File? _fotoSuratJalan;
  bool _loading = false;

  Future<void> _ambilFoto() async {
    final picker = ImagePicker();
    // imageQuality dikompres dan di-resize supaya base64 yang dikirim ke GAS tidak terlalu besar (maksimal ~200-300KB)
    final foto = await picker.pickImage(
      source: ImageSource.camera, 
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (foto != null) {
      setState(() => _fotoSuratJalan = File(foto.path));
    }
  }

  Future<void> _submit() async {
    if (_dari == null || _ke == null || _qtyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lengkapi lokasi asal, tujuan, dan qty')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      String? fotoBase64;
      if (_fotoSuratJalan != null) {
        final bytes = await _fotoSuratJalan!.readAsBytes();
        fotoBase64 = base64Encode(bytes);
      }

      final result = await ApiService.pindahStok(
        dari: _dari!,
        ke: _ke!,
        qty: int.parse(_qtyController.text),
        oleh: _olehController.text.isEmpty ? 'Tidak diketahui' : _olehController.text,
        fotoBase64: fotoBase64,
        fotoMimeType: 'image/jpeg',
      );

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stok berhasil dipindah')),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pindah Stok', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Detail Lokasi & Petugas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: _dari,
                    decoration: InputDecoration(
                      labelText: 'Dari Lokasi',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    items: widget.daftarLokasi
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) => setState(() => _dari = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _ke,
                    decoration: InputDecoration(
                      labelText: 'Ke Lokasi',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    items: widget.daftarLokasi
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) => setState(() => _ke = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Qty (Jumlah)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _olehController,
                    decoration: InputDecoration(
                      labelText: 'Nama Petugas',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Bukti Surat Jalan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                    onPressed: _ambilFoto,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_fotoSuratJalan == null ? 'Ambil Foto Surat Jalan' : 'Ganti Foto'),
                  ),
            if (_fotoSuratJalan != null) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_fotoSuratJalan!, height: 180, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 2,
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Simpan Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
