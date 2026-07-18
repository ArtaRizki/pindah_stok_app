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
  File? _fotoSuratJalan;
  bool _loading = false;
  
  bool _tambahLokasiBaru = false;
  final _lokasiBaruController = TextEditingController();

  @override
  void dispose() {
    _olehController.dispose();
    _lokasiBaruController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // HELPERS QTY
  // ─────────────────────────────────────────────
  Map<String, int> get _quantities => {
    for (final entry in _qtyControllers.entries)
      entry.key: int.tryParse(entry.value.text) ?? 0,
  };

  bool get _adaQtyYangDiisi => _quantities.values.any((q) => q > 0);

  void _incrementQty(String jenis) {
    final c = _qtyControllers[jenis]!;
    final val = (int.tryParse(c.text) ?? 0) + 1;
    c.text = val.toString();
  }

  void _decrementQty(String jenis) {
    final c = _qtyControllers[jenis]!;
    final val = (int.tryParse(c.text) ?? 0) - 1;
    if (val >= 0) {
      c.text = val.toString();
    }
  }

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

    String tujuanAkhir = _ke!;
    if (_tambahLokasiBaru) {
      tujuanAkhir = _lokasiBaruController.text.trim();
      if (tujuanAkhir.isEmpty) {
        _tampilkanPesan('Nama lokasi baru tidak boleh kosong');
        return;
      }
    }

    setState(() => _loading = true);
    try {
      String? fotoBase64;
      if (_fotoSuratJalan != null) {
        final bytes = await _fotoSuratJalan!.readAsBytes();
        fotoBase64 = base64Encode(bytes);
      }

      final result = await ApiService.pindahStok(
        dari:        _dari!,
        ke:          tujuanAkhir,
        quantities:  _quantities,
        oleh: _olehController.text.trim().isEmpty
            ? 'Tidak diketahui'
            : _olehController.text.trim(),
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
      if (mounted)
        _tampilkanPesan(
          'Gagal: ${e.toString().replaceFirst('Exception: ', '')}',
        );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Konfirmasi Transfer',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _baris('Dari',     _dari ?? '-'),
            _baris('Ke',       _tambahLokasiBaru ? _lokasiBaruController.text.trim() : (_ke ?? '-')),
            _baris('Petugas',  _olehController.text.trim().isEmpty
                  ? 'Tidak diketahui'
                  : _olehController.text.trim(),
            ),
            const Divider(height: 20),
            const Text(
              'Barang dipindahkan:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ...qtys.map((e) => _baris(e.key, '${e.value} pcs')),
            _baris('Foto', _fotoSuratJalan == null ? 'Tidak ada' : 'Terlampir'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }

  Widget _baris(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final opsiTujuan = widget.daftarLokasi.where((l) => l != _dari).toList();
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pindah Stok',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          children: [
            // ── SECTION: Lokasi & Petugas ──
            _buildSectionTitle('LOKASI & PETUGAS'),
            _buildCard(
              children: [
                DropdownButtonFormField<String>(
                  value: _dari,
                  decoration: _inputDecoration(
                    'Dari Lokasi',
                    Icons.upload_outlined,
                  ),
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
                  decoration: _inputDecoration(
                    'Ke Lokasi',
                    Icons.download_outlined,
                  ),
                  items: [
                    ...opsiTujuan.map((l) => DropdownMenuItem(value: l, child: Text(l))),
                    const DropdownMenuItem(
                      value: '+ Tambah Lokasi Baru',
                      child: Text('+ Tambah Lokasi Baru', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _ke = v;
                      _tambahLokasiBaru = (v == '+ Tambah Lokasi Baru');
                    });
                  },
                  validator: (v) => v == null ? 'Pilih lokasi tujuan' : null,
                ),
                if (_tambahLokasiBaru) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _lokasiBaruController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration(
                      'Nama Lokasi Baru',
                      Icons.add_location_alt_outlined,
                    ).copyWith(
                      fillColor: Colors.blue.shade50,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade200),
                      ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _olehController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration(
                    'Nama Petugas (Opsional)',
                    Icons.person_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── SECTION: Jumlah per Jenis ──
            _buildSectionTitle('BARANG YANG DIPINDAH'),
            _buildCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ...jenisFiberBox.map(
                  (jenis) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // Label badge warna
                            Container(
                              width: 100,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _badgeBg(jenis),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                jenis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _badgeFg(jenis),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const Spacer(),
                            // E-commerce style Qty Input
                            Container(
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _qtyButton(
                                    Icons.remove,
                                    () => _decrementQty(jenis),
                                  ),
                                  SizedBox(
                                    width: 48,
                                    child: TextFormField(
                                      controller: _qtyControllers[jenis],
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onTap: () {
                                        final c = _qtyControllers[jenis]!;
                                        if (c.text == '0') c.clear();
                                      },
                                    ),
                                  ),
                                  _qtyButton(
                                    Icons.add,
                                    () => _incrementQty(jenis),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (jenis != jenisFiberBox.last)
                        Divider(
                          height: 1,
                          color: Colors.grey.shade100,
                          indent: 16,
                          endIndent: 16,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── SECTION: Bukti Surat Jalan ──
            _buildSectionTitle('BUKTI SURAT JALAN'),
            if (_fotoSuratJalan == null)
              InkWell(
                onTap: _ambilFoto,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.05),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 36,
                        color: primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ketuk untuk mengambil foto',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        _fotoSuratJalan!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: InkWell(
                        onTap: _hapusFoto,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 0,
            ),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Simpan Transaksi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS UI
  // ─────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: Colors.grey.shade700),
      ),
    );
  }

  static const _badgeColors = {
    'DRB KUNING': Color(0xFFFFF3CD),
    'DRB ORANGE': Color(0xFFFFE0CC),
    'MSU': Color(0xFFDCF5E3),
    'GAS': Color(0xFFD6EAF8),
    'SCI': Color(0xFFEDE7F6),
  };
  static const _badgeTextColors = {
    'DRB KUNING': Color(0xFF7D5A00),
    'DRB ORANGE': Color(0xFF8B3500),
    'MSU': Color(0xFF1A6B35),
    'GAS': Color(0xFF1A4E78),
    'SCI': Color(0xFF4A2080),
  };

  Color _badgeBg(String jenis) =>
      _badgeColors[jenis] ?? const Color(0xFFF5F5F5);
  Color _badgeFg(String jenis) => _badgeTextColors[jenis] ?? Colors.black87;

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 22),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      );

  Widget _buildCard({
    required List<Widget> children,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
