/// Jenis-jenis fiber box default (Bawaan).
const List<String> jenisFiberBox = [
  'DRB KUNING',
  'DRB ORANGE',
  'MSU',
  'GAS',
  'GLOBAL',
  'SCI',
];

// ─────────────────────────────────────────────
// STOK PER LOKASI
// ─────────────────────────────────────────────
class LokasiStok {
  final String lokasi;
  final Map<String, int> items;

  LokasiStok({
    required this.lokasi,
    required this.items,
  });

  /// Total semua jenis barang di lokasi ini.
  int get totalQty => items.values.fold(0, (sum, val) => sum + val);

  /// Helper getter (opsional, karena `items` sudah berupa Map)
  Map<String, int> get perJenis => items;

  factory LokasiStok.fromJson(Map<String, dynamic> json) {
    final Map<String, int> parsedItems = {};
    final rawItems = json['items'] as Map<String, dynamic>? ?? {};
    
    rawItems.forEach((key, value) {
      parsedItems[key] = (value as num?)?.toInt() ?? 0;
    });

    return LokasiStok(
      lokasi: json['lokasi']?.toString() ?? '',
      items: parsedItems,
    );
  }
}

// ─────────────────────────────────────────────
// RIWAYAT TRANSAKSI (MULTI-JENIS & DINAMIS)
// ─────────────────────────────────────────────
class RiwayatTransaksi {
  final DateTime timestamp;
  final String dari;
  final String ke;
  final String oleh;
  final String fotoUrl;
  final Map<String, int> items;

  RiwayatTransaksi({
    required this.timestamp,
    required this.dari,
    required this.ke,
    required this.oleh,
    required this.fotoUrl,
    required this.items,
  });

  /// Total qty yang dipindah dalam transaksi ini.
  int get totalQty => items.values.fold(0, (sum, val) => sum + val);

  /// Map jenis -> qty hanya untuk jenis yang > 0 (dipakai di tampilan riwayat).
  Map<String, int> get perJenisAktif {
    final map = <String, int>{};
    items.forEach((key, value) {
      if (value > 0) map[key] = value;
    });
    return map;
  }

  factory RiwayatTransaksi.fromJson(Map<String, dynamic> json) {
    DateTime ts = DateTime.now();
    final rawTs = json['timestamp'];
    if (rawTs is String) {
      ts = DateTime.tryParse(rawTs) ?? DateTime.now();
    }

    final Map<String, int> parsedItems = {};
    final rawItems = json['items'] as Map<String, dynamic>? ?? {};
    rawItems.forEach((key, value) {
      parsedItems[key] = (value as num?)?.toInt() ?? 0;
    });

    return RiwayatTransaksi(
      timestamp: ts,
      dari:      json['dari']?.toString() ?? '',
      ke:        json['ke']?.toString() ?? '',
      oleh:      json['oleh']?.toString() ?? 'Tidak diketahui',
      fotoUrl:   json['fotoUrl']?.toString() ?? '',
      items:     parsedItems,
    );
  }
}
