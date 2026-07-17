import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class TransferScreen extends StatefulWidget {
  final List<String> daftarLokasi;
  const TransferScreen({super.key, required this.daftarLokasi});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _olehController = TextEditingController();

  String? _dari;
  String? _ke;
  File? _fotoSuratJalan;
  bool _loading = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _olehController.dispose();
    super.dispose();
  }

  Future<void> _ambilFoto() async {
    final picker = ImagePicker();
    // imageQuality dikompres & di-resize supaya base64 yang dikirim ke GAS
    // tidak terlalu besar (maksimal ~200-300KB).
    final foto = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (foto != null) setState(() => _fotoSuratJalan = File(foto.path));
  }

  void _hapusFoto() => setState(() => _fotoSuratJalan = null);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_dari == _ke) {
      _tampilkanPesan('Lokasi asal dan tujuan tidak boleh sama');
      return;
    }

    final konfirmasi = await _tampilkanKonfirmasi();
    if (konfirmasi != true) return;

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
        oleh: _olehController.text.trim().isEmpty ? 'Tidak diketahui' : _olehController.text.trim(),
        fotoBase64: fotoBase64,
        fotoMimeType: 'image/jpeg',
      );

      if (result['success'] == true) {
        if (!mounted) return;
        _tampilkanPesan('Stok berhasil dipindah', sukses: true);
        Navigator.pop(context, true);
      } else {
        throw Exception(result['message'] ?? 'Gagal memindahkan stok');
      }
    } catch (e) {
      if (mounted) _tampilkanPesan('Gagal: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _tampilkanPesan(String pesan, {bool sukses = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        backgroundColor: sukses ? Colors.green.shade600 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool?> _tampilkanKonfirmasi() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Transfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _baris('Dari', _dari ?? '-'),
            _baris('Ke', _ke ?? '-'),
            _baris('Qty', '${_qtyController.text} pcs'),
            _baris('Petugas', _olehController.text.trim().isEmpty ? 'Tidak diketahui' : _olehController.text.trim()),
            _baris('Foto', _fotoSuratJalan == null ? 'Tidak ada' : 'Terlampir'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kirim')),
        ],
      ),
    );
  }

  Widget _baris(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Colors.black54))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Lokasi tujuan tidak boleh sama dengan lokasi asal.
    final opsiTujuan = widget.daftarLokasi.where((l) => l != _dari).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pindah Stok', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCard(
                judul: 'Detail Lokasi & Petugas',
                icon: Icons.location_on_outlined,
                children: [
                  DropdownButtonFormField<String>(
                    value: _dari,
                    decoration: _inputDecoration('Dari Lokasi'),
                    items: widget.daftarLokasi.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setState(() {
                      _dari = v;
                      if (_ke == v) _ke = null;
                    }),
                    validator: (v) => v == null ? 'Pilih lokasi asal' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _ke,
                    decoration: _inputDecoration('Ke Lokasi'),
                    items: opsiTujuan.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setState(() => _ke = v),
                    validator: (v) => v == null ? 'Pilih lokasi tujuan' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDecoration('Qty (Jumlah)'),
                    validator: (v) {
                      final qty = int.tryParse(v ?? '');
                      if (qty == null || qty <= 0) return 'Masukkan jumlah yang valid';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _olehController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration('Nama Petugas'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildCard(
                judul: 'Bukti Surat Jalan',
                icon: Icons.receipt_long_outlined,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                    onPressed: _ambilFoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(_fotoSuratJalan == null ? 'Ambil Foto Surat Jalan' : 'Ganti Foto'),
                  ),
                  if (_fotoSuratJalan != null) ...[
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_fotoSuratJalan!, height: 180, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _tombolHapusFoto(),
                        ),
                      ],
                    ),
                  ],
                ],
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
      ),
    );
  }

  Widget _tombolHapusFoto() {
    return InkWell(
      onTap: _hapusFoto,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  Widget _buildCard({required String judul, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(judul, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}