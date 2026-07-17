import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<LokasiStok> _stok = [];
  bool _loading = true;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _timer;

  final _qtyFormat = NumberFormat.decimalPattern('id_ID');

  @override
  void initState() {
    super.initState();
    _muatStok();
    // Polling tiap 15 detik supaya tampilan stok mendekati realtime.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _muatStok(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _muatStok({bool silent = false}) async {
    // Hanya tampilkan spinner penuh saat pertama kali load / pull-to-refresh manual.
    // Saat polling silent, jangan timpa data lama dengan layar error kalau cuma gangguan jaringan sesaat.
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await ApiService.getStok();
      if (!mounted) return;
      setState(() {
        _stok = data;
        _error = null;
        _loading = false;
        _lastUpdated = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Saat polling silent dan sudah ada data sebelumnya, biarkan data lama tetap tampil.
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

  @override
  Widget build(BuildContext context) {
    final total = _stok.fold<int>(0, (sum, s) => sum + s.qty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Fiber Box', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : () => _muatStok(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _muatStok(),
          child: _buildBody(total),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text('Pindah Stok', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 2,
        onPressed: _stok.isEmpty
            ? null
            : () async {
                final daftarLokasi = _stok.map((s) => s.lokasi).toList();
                final berhasil = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => TransferScreen(daftarLokasi: daftarLokasi)),
                );
                if (berhasil == true) _muatStok();
              },
      ),
    );
  }

  Widget _buildBody(int total) {
    // Body selalu dibungkus list yang bisa di-scroll, supaya RefreshIndicator
    // tetap berfungsi walaupun sedang menampilkan state loading/error/kosong.
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
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: () => _muatStok(),
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
          Center(
            child: Text('Belum ada data lokasi stok', style: TextStyle(color: Colors.black54)),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        if (_error != null) _buildBannerPeringatan(),
        _buildSummaryCard(total),
        if (_lastUpdated != null) _buildLastUpdatedLabel(),
        const SizedBox(height: 28),
        Text(
          'Rincian Lokasi',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
        ),
        const SizedBox(height: 16),
        ..._stok.map((s) => _buildStockCard(s)),
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
              'Gagal memuat data terbaru, menampilkan data terakhir yang tersimpan.',
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

  Widget _buildSummaryCard(int total) {
    final primary = Theme.of(context).colorScheme.primary;
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
            'Total Keseluruhan',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            _qtyFormat.format(total),
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Text(
            'pcs',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard(LokasiStok s) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.warehouse_rounded, color: primary),
        ),
        title: Text(
          s.lokasi,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${_qtyFormat.format(s.qty)} pcs',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
    );
  }
}