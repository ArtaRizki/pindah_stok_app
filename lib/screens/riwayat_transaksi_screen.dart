import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class RiwayatTransaksiScreen extends StatefulWidget {
  final String role;
  final String picName;
  const RiwayatTransaksiScreen({
    super.key,
    required this.role,
    required this.picName,
  });

  @override
  State<RiwayatTransaksiScreen> createState() => _RiwayatTransaksiScreenState();
}

class _RiwayatTransaksiScreenState extends State<RiwayatTransaksiScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  List<RiwayatTransaksi> _transaksi = [];
  bool _loading = false;
  String? _error;

  String? _selectedPic;
  List<String> _adminList = [];

  bool get _isSuperadmin => widget.role == 'superadmin';

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = _endDate!.subtract(const Duration(days: 7));
    // Admin biasa: auto-set filter ke username sendiri
    if (!_isSuperadmin) {
      _selectedPic = widget.picName;
    }
    _fetchAdminAndRiwayat();
  }

  Future<void> _fetchAdminAndRiwayat() async {
    if (_isSuperadmin) {
      try {
        final admins = await ApiService.getAdmin();
        if (mounted) {
          setState(() {
            _adminList = admins.map((e) => e['username'] ?? '').where((u) => u.isNotEmpty).toList();
          });
        }
      } catch (e) {
        debugPrint('Gagal fetch admin: $e');
      }
    }
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
        pic: _selectedPic,
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

  Future<void> _batalkanTransaksi(RiwayatTransaksi t) async {
    if (t.rowIndex == null || t.rowIndex! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Index baris tidak valid, coba muat ulang riwayat.')),
      );
      return;
    }

    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Transaksi?'),
        content: Text(
          'Transaksi dari "${t.dari}" ke "${t.ke}" pada '
          '${DateFormat('dd MMM yyyy, HH:mm').format(t.timestamp)} '
          'akan dibatalkan dan stok akan dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (konfirmasi != true || !mounted) return;

    setState(() => _loading = true);

    try {
      final result = await ApiService.batalkanTransaksi(rowIndex: t.rowIndex!);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Transaksi berhasil dibatalkan'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchRiwayat();
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal membatalkan transaksi'),
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
          // Info rentang tanggal & PIC
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              children: [
                Row(
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
                // Filter PIC: Superadmin bisa pilih, Admin biasa hanya lihat miliknya
                if (_isSuperadmin && _adminList.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, color: Colors.black54, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            isDense: true,
                            hint: const Text('Semua Penginput (PIC)'),
                            value: _selectedPic,
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Semua Penginput (PIC)', style: TextStyle(fontWeight: FontWeight.w500)),
                              ),
                              ..._adminList.map((String pic) {
                                return DropdownMenuItem<String>(
                                  value: pic,
                                  child: Text(pic),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedPic = val;
                              });
                              _fetchRiwayat();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (!_isSuperadmin) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_pin, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Menampilkan transaksi milik: ${widget.picName}',
                        style: const TextStyle(color: Color(0xFF2563EB), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ]
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
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
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
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
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
                                                      (t.oleh?.isEmpty ?? true) ? 'Tidak diketahui' : t.oleh!,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF2563EB),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Tombol Batalkan — hanya Superadmin
                                              if (_isSuperadmin) ...[
                                                const SizedBox(width: 8),
                                                InkWell(
                                                  borderRadius: BorderRadius.circular(6),
                                                  onTap: () => _batalkanTransaksi(t),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFFF0F0),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.undo_rounded, size: 14, color: Colors.red),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Batalkan',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
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
                                      if (t.keterangan != null && t.keterangan!.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Keterangan: ${t.keterangan}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.amber.shade900,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
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
                                      if (t.fotoUrl != null && t.fotoUrl!.isNotEmpty && t.fotoUrl != 'N/A') ...[
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 40,
                                          child: OutlinedButton.icon(
                                            onPressed: () => _bukaFoto(t.fotoUrl!),
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
