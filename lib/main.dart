import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'models/models.dart';
import 'services/api_service.dart';
import 'screens/transfer_screen.dart';

void main() {
  runApp(const PindahStokApp());
}

class PindahStokApp extends StatelessWidget {
  const PindahStokApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF2563EB);
    return MaterialApp(
      title: 'Pindah Stok',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<LokasiStok> _stok = [];
  List<String> _daftarLokasi = [];
  bool _loading = true;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _timer;

  final _numFormat = NumberFormat.decimalPattern('id_ID');

  // Warna badge per jenis
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

  @override
  void initState() {
    super.initState();
    _muatData();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _muatData(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _muatData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      // Muat lokasi & stok paralel
      final results = await Future.wait([
        ApiService.getLokasi(),
        ApiService.getStok(),
      ]);
      if (!mounted) return;
      setState(() {
        _daftarLokasi = results[0] as List<String>;
        _stok         = results[1] as List<LokasiStok>;
        _error        = null;
        _loading      = false;
        _lastUpdated  = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent || _stok.isEmpty) {
          _error = _pesanError(e);
        }
      });
    }
  }

  String _pesanError(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    return msg.isEmpty ? 'Terjadi kesalahan tak terduga' : msg;
  }

  // Hitung total keseluruhan per jenis
  Map<String, int> get _totalPerJenis {
    final map = <String, int>{};
    for (final s in _stok) {
      s.items.forEach((key, val) {
        map[key] = (map[key] ?? 0) + val;
      });
    }
    return map;
  }

  String _convertToCsv(List<List<dynamic>> rows) {
    return rows.map((row) {
      return row.map((cell) {
        final str = cell.toString();
        if (str.contains(',') || str.contains('"') || str.contains('\n')) {
          return '"${str.replaceAll('"', '""')}"';
        }
        return str;
      }).join(',');
    }).join('\n');
  }

  Future<void> _exportCSV() async {
    try {
      DateTime? startDate;
      DateTime? endDate;

      // Ask for date range
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export Laporan'),
          content: const Text('Apakah Anda ingin memfilter Riwayat Transaksi berdasarkan rentang tanggal?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Semua Waktu'),
            ),
            FilledButton(
              onPressed: () async {
                final r = await showDateRangePicker(
                  context: ctx,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: const Color(0xFF2563EB),
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: Colors.black,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (r != null) {
                  startDate = r.start;
                  endDate = r.end;
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Pilih Tanggal'),
            ),
          ],
        ),
      );

      if (proceed != true) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menyiapkan file export...')));

      // 1. Siapkan file Rekap Stok (Snapshot)
      final List<List<dynamic>> rowsStok = [];
      final Set<String> itemTypes = {};
      for (final s in _stok) {
        itemTypes.addAll(s.items.keys);
      }
      final sortedItems = itemTypes.toList()..sort();
      
      rowsStok.add(['Lokasi', ...sortedItems, 'Total']);
      
      for (final s in _stok) {
        final List<dynamic> row = [s.lokasi];
        for (final item in sortedItems) {
          row.add(s.items[item] ?? 0);
        }
        row.add(s.totalQty);
        rowsStok.add(row);
      }
      
      final csvStok = _convertToCsv(rowsStok);
      final dir = await getTemporaryDirectory();
      final fileStok = File('${dir.path}/Rekap_Stok_${DateTime.now().millisecondsSinceEpoch}.csv');
      await fileStok.writeAsString(csvStok);

      // 2. Ambil data Riwayat Transaksi (Limit 1000)
      final riwayatList = await ApiService.getRiwayat(
        limit: 1000, 
        startDate: startDate, 
        endDate: endDate,
      );
      final List<List<dynamic>> rowsRiwayat = [];
      rowsRiwayat.add(['Waktu', 'Dari', 'Ke', ...sortedItems, 'Total', 'Oleh', 'Foto Surat Jalan']);

      for (final r in riwayatList) {
        final List<dynamic> row = [
          DateFormat('yyyy-MM-dd HH:mm:ss').format(r.timestamp),
          r.dari,
          r.ke,
        ];
        for (final item in sortedItems) {
          row.add(r.items[item] ?? 0);
        }
        row.addAll([
          r.totalQty,
          r.oleh,
          r.fotoUrl,
        ]);
        rowsRiwayat.add(row);
      }

      final csvRiwayat = _convertToCsv(rowsRiwayat);
      final fileRiwayat = File('${dir.path}/Rincian_Transaksi_${DateTime.now().millisecondsSinceEpoch}.csv');
      await fileRiwayat.writeAsString(csvRiwayat);

      // 3. Share kedua file
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(fileStok.path), XFile(fileRiwayat.path)], 
          text: 'Laporan Pindah Stok',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Fiber Box', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : () => _muatData(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _muatData(),
          child: _buildBody(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text('Pindah Stok', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 2,
        onPressed: _daftarLokasi.isEmpty
            ? null
            : () async {
                final berhasil = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransferScreen(daftarLokasi: _daftarLokasi),
                  ),
                );
                if (berhasil == true) _muatData();
              },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _stok.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 200),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null && _stok.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: () => _muatData(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ),
        ],
      );
    }

    if (_stok.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.inventory_2_outlined, color: Colors.black38, size: 48),
          SizedBox(height: 16),
          Center(child: Text('Belum ada data stok', style: TextStyle(color: Colors.black54))),
        ],
      );
    }

    final stokAdaIsinya = _stok.where((s) => s.totalQty > 0).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        if (_error != null) _buildBannerPeringatan(),
        _buildSummaryCard(),
        if (_lastUpdated != null) _buildLastUpdatedLabel(),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Rincian per Lokasi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            TextButton.icon(
              onPressed: _exportCSV,
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text('Export CSV'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (stokAdaIsinya.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('Tidak ada lokasi dengan stok > 0', style: TextStyle(color: Colors.black54)),
            ),
          )
        else
          ...stokAdaIsinya.map((s) => _buildStockCard(s)),
      ],
    );
  }

  Widget _buildBannerPeringatan() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Gagal memuat data terbaru, menampilkan data terakhir.',
              style: TextStyle(fontSize: 12.5, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdatedLabel() {
    final jam = DateFormat('HH:mm:ss').format(_lastUpdated!);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Center(
        child: Text(
          'Terakhir diperbarui $jam',
          style: const TextStyle(fontSize: 12, color: Colors.black45),
        ),
      ),
    );
  }

  /// Summary card — total keseluruhan per jenis fiber box
  Widget _buildSummaryCard() {
    final primary = Theme.of(context).colorScheme.primary;
    final totals  = _totalPerJenis;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primary.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Total Keseluruhan Stok',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: totals.entries.where((e) => e.value > 0).map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      _numFormat.format(entry.value),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Card per lokasi — tampilkan qty per jenis fiber box
  Widget _buildStockCard(LokasiStok s) {
    final primary = Theme.of(context).colorScheme.primary;
    final isGudang = !s.lokasi.toUpperCase().contains(RegExp(r'[A-Z]{1}\s*\d{4}'));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isGudang ? Icons.warehouse_rounded : Icons.local_shipping_rounded,
                    color: primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.lokasi,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Total: ${_numFormat.format(s.totalQty)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: s.perJenis.entries.map((entry) {
                final bg   = _badgeColors[entry.key]    ?? Colors.grey.shade100;
                final fg   = _badgeTextColors[entry.key] ?? Colors.black87;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${entry.key}  ',
                          style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
                        ),
                        TextSpan(
                          text: _numFormat.format(entry.value),
                          style: TextStyle(fontSize: 13, color: fg, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}