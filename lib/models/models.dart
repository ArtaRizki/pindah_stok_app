/// Jenis-jenis fiber box yang tersedia.
const List<String> jenisFiberBox = [
  'DRB KUNING',
  'DRB ORANGE',
  'MSU',
  'GAS',
  'SCI',
];

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

class RiwayatTransaksi {
  final DateTime timestamp;
  final String dari;
  final String ke;
  final String jenis;
  final int qty;
  final String oleh;
  final String fotoUrl;

  RiwayatTransaksi({
    required this.timestamp,
    required this.dari,
    required this.ke,
    required this.jenis,
    required this.qty,
    required this.oleh,
    required this.fotoUrl,
  });

  factory RiwayatTransaksi.fromJson(Map<String, dynamic> json) {
    return RiwayatTransaksi(
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      dari:      json['dari']?.toString() ?? '',
      ke:        json['ke']?.toString() ?? '',
      jenis:     json['jenis']?.toString() ?? '-',
      qty:       (json['qty'] as num?)?.toInt() ?? 0,
      oleh:      json['oleh']?.toString() ?? '',
      fotoUrl:   json['fotoUrl']?.toString() ?? '',
    );
  }
}
