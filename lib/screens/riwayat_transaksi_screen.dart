import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class RiwayatTransaksiScreen extends StatefulWidget {
  const RiwayatTransaksiScreen({super.key});

  @override
  State<RiwayatTransaksiScreen> createState() => _RiwayatTransaksiScreenState();
}

class _RiwayatTransaksiScreenState extends State<RiwayatTransaksiScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  List<RiwayatTransaksi> _transaksi = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default to last 7 days
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 7));
    _fetchRiwayat();
  }

  Future<void> _fetchRiwayat() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getRiwayat(
        limit: 100,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      setState(() {
        _transaksi = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchRiwayat();
    }
  }

  Future<void> _bukaFoto(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka foto')),
        );
      }
    }
  }

  Widget _buildItemText(MapEntry<String, int> item) {
    if (item.value <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(item.key, style: const TextStyle(color: Colors.black87)),
          Text(
            '${item.value}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Filter Tanggal',
            onPressed: _pilihTanggal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _fetchRiwayat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Info rentang tanggal
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            width: double.infinity,
            child: Row(
              children: [
                const Icon(Icons.filter_alt_outlined, color: Colors.black54, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _startDate != null && _endDate != null
                        ? '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}'
                        : 'Semua Tanggal',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ),
                if (_startDate != null)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                      _fetchRiwayat();
                    },
                    child: const Text(
                      'Hapus Filter',
                      style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  )
              ],
            ),
          ),
          const Divider(height: 1),
          
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                'Gagal memuat: $_error',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchRiwayat,
                                child: const Text('Coba Lagi'),
                              )
                            ],
                          ),
                        ),
                      )
                    : _transaksi.isEmpty
                        ? const Center(
                            child: Text(
                              'Tidak ada riwayat transaksi pada rentang tanggal ini.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _transaksi.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final t = _transaksi[index];
                              
                              // Filter barang yang lebih dari 0
                              final activeItems = t.items.entries
                                  .where((e) => e.value > 0)
                                  .toList();

                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header: Waktu & PIC
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            DateFormat('dd MMM yyyy, HH:mm').format(t.timestamp),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.person_outline, size: 14, color: Color(0xFF2563EB)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  t.oleh.isEmpty ? 'Tidak diketahui' : t.oleh,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF2563EB),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Rute: Dari -> Ke
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Dari', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                                Text(
                                                  t.dari,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 16),
                                            child: Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                const Text('Ke', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                                Text(
                                                  t.ke,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  textAlign: TextAlign.right,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(height: 1),
                                      ),
                                      
                                      // Item list
                                      const Text(
                                        'Barang yang dipindah:',
                                        style: TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                      const SizedBox(height: 8),
                                      if (activeItems.isEmpty)
                                        const Text('-', style: TextStyle(color: Colors.black54))
                                      else
                                        ...activeItems.map(_buildItemText),
                                      
                                      // Foto button
                                      if (t.fotoUrl.isNotEmpty && t.fotoUrl != 'N/A') ...[
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 40,
                                          child: OutlinedButton.icon(
                                            onPressed: () => _bukaFoto(t.fotoUrl),
                                            icon: const Icon(Icons.image_outlined, size: 18),
                                            label: const Text('Lihat Surat Jalan'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF2563EB),
                                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
