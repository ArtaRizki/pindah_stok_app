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
    // imageQuality dikompres supaya base64 yang dikirim ke GAS tidak terlalu besar
    final foto = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
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
      appBar: AppBar(title: const Text('Pindah Stok')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: _dari,
              decoration: const InputDecoration(labelText: 'Dari Lokasi'),
              items: widget.daftarLokasi
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _dari = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _ke,
              decoration: const InputDecoration(labelText: 'Ke Lokasi'),
              items: widget.daftarLokasi
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _ke = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Qty'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _olehController,
              decoration: const InputDecoration(labelText: 'Nama Petugas'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _ambilFoto,
              icon: const Icon(Icons.camera_alt),
              label: Text(_fotoSuratJalan == null ? 'Foto Surat Jalan' : 'Ganti Foto'),
            ),
            if (_fotoSuratJalan != null) ...[
              const SizedBox(height: 12),
              Image.file(_fotoSuratJalan!, height: 180),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
