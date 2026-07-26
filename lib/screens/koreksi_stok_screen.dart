import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class KoreksiStokScreen extends StatefulWidget {
  final List<String> daftarLokasi;
  const KoreksiStokScreen({super.key, required this.daftarLokasi});

  @override
  State<KoreksiStokScreen> createState() => _KoreksiStokScreenState();
}

class _KoreksiStokScreenState extends State<KoreksiStokScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();

  final List<String> _jenisList = jenisFiberBox.toList();

  String? _selectedLokasi;
  String? _selectedJenis;
  bool _loading = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Koreksi Stok'),
        content: Text(
          'Stok "${_selectedJenis}" di lokasi "${_selectedLokasi}" '
          'akan diubah menjadi ${_qtyCtrl.text}.\n\n'
          'Tindakan ini langsung mengubah data di spreadsheet.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (konfirmasi != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final result = await ApiService.koreksiStok(
        lokasi: _selectedLokasi!,
        jenis: _selectedJenis!,
        jumlahBaru: int.parse(_qtyCtrl.text),
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Stok berhasil dikoreksi'),
            backgroundColor: Colors.green,
          ),
        );
        // Reset form
        setState(() {
          _selectedLokasi = null;
          _selectedJenis = null;
          _qtyCtrl.clear();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal melakukan koreksi stok'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Koreksi Stok'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner peringatan
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCC02)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Koreksi stok langsung mengubah angka di spreadsheet tanpa mencatat transaksi.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF78350F)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Dropdown Lokasi
              const Text('Lokasi', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedLokasi,
                hint: const Text('Pilih Lokasi'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: widget.daftarLokasi.map((l) {
                  return DropdownMenuItem(value: l, child: Text(l));
                }).toList(),
                validator: (v) => v == null ? 'Pilih lokasi terlebih dahulu' : null,
                onChanged: (v) => setState(() => _selectedLokasi = v),
              ),
              const SizedBox(height: 20),

              // Dropdown Jenis
              const Text('Jenis Barang', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedJenis,
                hint: const Text('Pilih Jenis Barang'),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: _jenisList.map((j) {
                  return DropdownMenuItem(value: j, child: Text(j));
                }).toList(),
                validator: (v) => v == null ? 'Pilih jenis barang' : null,
                onChanged: (v) => setState(() => _selectedJenis = v),
              ),
              const SizedBox(height: 20),

              // Input Jumlah
              const Text('Jumlah Baru', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Masukkan jumlah yang benar',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Jumlah wajib diisi';
                  final n = int.tryParse(v);
                  if (n == null || n < 0) return 'Masukkan angka positif';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _simpan,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_loading ? 'Menyimpan...' : 'Simpan Koreksi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
