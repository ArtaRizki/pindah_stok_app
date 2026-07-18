import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class TransferScreen extends StatefulWidget {
  final List<String> daftarLokasi;
  const TransferScreen({super.key, required this.daftarLokasi});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _olehController = TextEditingController();

  // Controller untuk setiap jenis fiber box
  final Map<String, TextEditingController> _qtyControllers = {
    for (final j in jenisFiberBox) j: TextEditingController(text: '0'),
  };

  String? _dari;
  String? _ke;
  File?   _fotoSuratJalan;
  bool    _loading = false;

  @override
  void dispose() {
    _olehController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Buat map jenis → qty dari controllers
  // ─────────────────────────────────────────────
  Map<String, int> get _quantities => {
        for (final entry in _qtyControllers.entries)
          entry.key: int.tryParse(entry.value.text) ?? 0,
      };

  bool get _adaQtyYangDiisi => _quantities.values.any((q) => q > 0);

  // ─────────────────────────────────────────────
  // AMBIL FOTO
  // ─────────────────────────────────────────────
  Future<void> _ambilFoto() async {
    final picker = ImagePicker();
    final foto = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (foto != null) setState(() => _fotoSuratJalan = File(foto.path));
  }

  void _hapusFoto() => setState(() => _fotoSuratJalan = null);

  // ─────────────────────────────────────────────
  // SUBMIT
  // ─────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_adaQtyYangDiisi) {
      _tampilkanPesan('Minimal 1 jenis fiber box harus diisi lebih dari 0');
      return;
    }
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
        dari:        _dari!,
        ke:          _ke!,
        quantities:  _quantities,
        oleh:        _olehController.text.trim().isEmpty
            ? 'Tidak diketahui'
            : _olehController.text.trim(),
        fotoBase64:  fotoBase64,
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
    final qtys = _quantities.entries.where((e) => e.value > 0).toList();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Transfer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _baris('Dari',     _dari ?? '-'),
            _baris('Ke',       _ke ?? '-'),
            _baris('Petugas',  _olehController.text.trim().isEmpty
                ? 'Tidak diketahui'
                : _olehController.text.trim()),
            const Divider(height: 20),
            const Text('Barang dipindahkan:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...qtys.map((e) => _baris(e.key, '${e.value} pcs')),
            _baris('Foto', _fotoSuratJalan == null ? 'Tidak ada' : 'Terlampir'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),  child: const Text('Kirim')),
        ],
      ),
    );
  }

  Widget _baris(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.black54))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final opsiTujuan = widget.daftarLokasi.where((l) => l != _dari).toList();
    final primary    = Theme.of(context).colorScheme.primary;

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
              // ── SECTION: Lokasi & Petugas ──
              _buildCard(
                judul: 'Lokasi & Petugas',
                icon: Icons.location_on_outlined,
                children: [
                  DropdownButtonFormField<String>(
                    value: _dari,
                    decoration: _inputDecoration('Dari Lokasi'),
                    items: widget.daftarLokasi
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
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
                    items: opsiTujuan
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) => setState(() => _ke = v),
                    validator: (v) => v == null ? 'Pilih lokasi tujuan' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _olehController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration('Nama Petugas (opsional)'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── SECTION: Jumlah per Jenis ──
              _buildCard(
                judul: 'Jumlah per Jenis Fiber Box',
                icon: Icons.inventory_2_outlined,
                children: [
                  const Text(
                    'Isi jumlah yang dipindahkan (kosongkan atau isi 0 jika tidak ada)',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  ...jenisFiberBox.map((jenis) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            // Label badge warna
                            Container(
                              width: 110,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: _badgeBg(jenis),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                jenis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _badgeFg(jenis),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Input qty
                            Expanded(
                              child: TextFormField(
                                controller: _qtyControllers[jenis],
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  suffixText: 'pcs',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                onTap: () {
                                  // Hapus "0" otomatis saat diklik
                                  final c = _qtyControllers[jenis]!;
                                  if (c.text == '0') c.clear();
                                },
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
              const SizedBox(height: 16),

              // ── SECTION: Bukti Surat Jalan ──
              _buildCard(
                judul: 'Bukti Surat Jalan',
                icon: Icons.receipt_long_outlined,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: primary),
                    ),
                    onPressed: _ambilFoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(
                      _fotoSuratJalan == null ? 'Ambil Foto Surat Jalan' : 'Ganti Foto',
                    ),
                  ),
                  if (_fotoSuratJalan != null) ...[
                    const SizedBox(height: 16),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _fotoSuratJalan!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
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

              // ── TOMBOL SIMPAN ──
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: primary,
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
                    : const Text(
                        'Simpan Transaksi',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS UI
  // ─────────────────────────────────────────────

  static const _badgeColors = {
    'DRB KUNING': Color(0xFFFFF3CD),
    'DRB ORANGE': Color(0xFFFFE0CC),
    'MSU':        Color(0xFFDCF5E3),
    'GAS':        Color(0xFFD6EAF8),
    'SCI':        Color(0xFFEDE7F6),
  };
  static const _badgeTextColors = {
    'DRB KUNING': Color(0xFF7D5A00),
    'DRB ORANGE': Color(0xFF8B3500),
    'MSU':        Color(0xFF1A6B35),
    'GAS':        Color(0xFF1A4E78),
    'SCI':        Color(0xFF4A2080),
  };

  Color _badgeBg(String jenis) => _badgeColors[jenis] ?? const Color(0xFFF5F5F5);
  Color _badgeFg(String jenis) => _badgeTextColors[jenis] ?? Colors.black87;

  Widget _tombolHapusFoto() => InkWell(
        onTap: _hapusFoto,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
        ),
      );

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      );

  Widget _buildCard({
    required String judul,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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