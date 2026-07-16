import 'dart:async';
import 'package:flutter/material.dart';
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
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
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
      appBar: AppBar(title: const Text('Stok Fiber Box')),
      body: RefreshIndicator(
        onRefresh: _muatStok,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Total Stok: $total pcs',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ..._stok.map((s) => ListTile(
                            leading: const Icon(Icons.warehouse),
                            title: Text(s.lokasi),
                            trailing: Text(
                              '${s.qty} pcs',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          )),
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Pindah Stok'),
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
}
