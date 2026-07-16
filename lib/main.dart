import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    return MaterialApp(
      title: 'Pindah Stok',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          surface: Colors.grey[50],
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          scrolledUnderElevation: 0,
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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _muatStok();
    // Polling tiap 15 detik supaya tampilan stok mendekati realtime
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _muatStok(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _muatStok({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await ApiService.getStok();
      setState(() {
        _stok = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _stok.fold<int>(0, (sum, s) => sum + s.qty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Fiber Box', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _muatStok,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Error: $_error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _muatStok(silent: false),
                          child: const Text('Coba Lagi'),
                        )
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    children: [
                      _buildSummaryCard(total),
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
                      const SizedBox(height: 80), // Padding for FAB
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Pindah Stok', style: TextStyle(fontWeight: FontWeight.w600)),
        elevation: 2,
        onPressed: () async {
          final daftarLokasi = _stok.map((s) => s.lokasi).toList();
          final berhasil = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TransferScreen(daftarLokasi: daftarLokasi)),
          );
          if (berhasil == true) _muatStok();
        },
      ),
    );
  }

  Widget _buildSummaryCard(int total) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Total Keseluruhan',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            '$total',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
          const Text(
            'pcs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard(LokasiStok s) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.warehouse_rounded, color: Theme.of(context).colorScheme.primary),
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
            '${s.qty} pcs',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
