class LokasiStok {
  final String lokasi;
  final int qty;

  LokasiStok({required this.lokasi, required this.qty});

  factory LokasiStok.fromJson(Map<String, dynamic> json) {
    return LokasiStok(
      lokasi: json['lokasi']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 0,
    );
  }
}

class RiwayatTransaksi {
  final DateTime timestamp;
  final String dari;
  final String ke;
  final int qty;
  final String oleh;
  final String fotoUrl;

  RiwayatTransaksi({
    required this.timestamp,
    required this.dari,
    required this.ke,
    required this.qty,
    required this.oleh,
    required this.fotoUrl,
  });

  factory RiwayatTransaksi.fromJson(Map<String, dynamic> json) {
    return RiwayatTransaksi(
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      dari: json['dari']?.toString() ?? '',
      ke: json['ke']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      oleh: json['oleh']?.toString() ?? '',
      fotoUrl: json['fotoUrl']?.toString() ?? '',
    );
  }
}
