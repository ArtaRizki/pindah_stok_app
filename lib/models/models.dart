/// Jenis-jenis fiber box yang tersedia (urutan harus sama dengan kolom di Sheet Stok).
const List<String> jenisFiberBox = [
  'DRB KUNING',
  'DRB ORANGE',
  'MSU',
  'GAS',
  'SCI',
];

// ─────────────────────────────────────────────
// STOK PER LOKASI
// ─────────────────────────────────────────────
class LokasiStok {
  final String lokasi;
  final int drbKuning;
  final int drbOrange;
  final int msu;
  final int gas;
  final int sci;

  LokasiStok({
    required this.lokasi,
    this.drbKuning = 0,
    this.drbOrange = 0,
    this.msu = 0,
    this.gas = 0,
    this.sci = 0,
  });

  /// Total semua jenis di lokasi ini.
  int get totalQty => drbKuning + drbOrange + msu + gas + sci;

  /// Map jenis -> qty, berguna untuk tampilan iteratif.
  Map<String, int> get perJenis => {
        'DRB KUNING': drbKuning,
        'DRB ORANGE': drbOrange,
        'MSU':        msu,
        'GAS':        gas,
        'SCI':        sci,
      };

  factory LokasiStok.fromJson(Map<String, dynamic> json) {
    return LokasiStok(
      lokasi:    json['lokasi']?.toString() ?? '',
      drbKuning: (json['drbKuning'] as num?)?.toInt() ?? 0,
      drbOrange: (json['drbOrange'] as num?)?.toInt() ?? 0,
      msu:       (json['msu']       as num?)?.toInt() ?? 0,
      gas:       (json['gas']       as num?)?.toInt() ?? 0,
      sci:       (json['sci']       as num?)?.toInt() ?? 0,
    );
  }
}

// ─────────────────────────────────────────────
// RIWAYAT TRANSAKSI (MULTI-JENIS)
// ─────────────────────────────────────────────
class RiwayatTransaksi {
  final DateTime timestamp;
  final String dari;
  final String ke;
  final int drbKuning;
  final int drbOrange;
  final int msu;
  final int gas;
  final int sci;
  final String oleh;
  final String fotoUrl;

  RiwayatTransaksi({
    required this.timestamp,
    required this.dari,
    required this.ke,
    this.drbKuning = 0,
    this.drbOrange = 0,
    this.msu = 0,
    this.gas = 0,
    this.sci = 0,
    required this.oleh,
    required this.fotoUrl,
  });

  /// Total qty yang dipindah dalam transaksi ini.
  int get totalQty => drbKuning + drbOrange + msu + gas + sci;

  /// Map jenis -> qty hanya untuk jenis yang > 0 (dipakai di tampilan riwayat).
  Map<String, int> get perJenisAktif {
    final map = <String, int>{};
    if (drbKuning > 0) map['DRB KUNING'] = drbKuning;
    if (drbOrange > 0) map['DRB ORANGE'] = drbOrange;
    if (msu > 0)       map['MSU']        = msu;
    if (gas > 0)       map['GAS']        = gas;
    if (sci > 0)       map['SCI']        = sci;
    return map;
  }

  factory RiwayatTransaksi.fromJson(Map<String, dynamic> json) {
    DateTime ts = DateTime.now();
    final raw = json['timestamp'];
    if (raw is String) {
      ts = DateTime.tryParse(raw) ?? DateTime.now();
    } else if (raw is num) {
      // GAS mengirim timestamp sebagai Unix ms
      ts = DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }

    return RiwayatTransaksi(
      timestamp: ts,
      dari:      json['dari']?.toString() ?? '',
      ke:        json['ke']?.toString() ?? '',
      drbKuning: (json['drbKuning'] as num?)?.toInt() ?? 0,
      drbOrange: (json['drbOrange'] as num?)?.toInt() ?? 0,
      msu:       (json['msu']       as num?)?.toInt() ?? 0,
      gas:       (json['gas']       as num?)?.toInt() ?? 0,
      sci:       (json['sci']       as num?)?.toInt() ?? 0,
      oleh:      json['oleh']?.toString() ?? '',
      fotoUrl:   json['fotoUrl']?.toString() ?? '',
    );
  }
}
