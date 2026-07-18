# Design: Multi-Jenis Transfer (Surat Jalan)

**Tanggal:** 2026-07-18  
**Konteks:** Klien meminta agar 1 transaksi pindah stok bisa memuat beberapa jenis fiber box sekaligus (seperti surat jalan nyata di lapangan).

---

## Keputusan Desain

| # | Topik | Keputusan |
|---|-------|-----------|
| 1 | Form input | Opsi A — semua 5 jenis tampil sekaligus, qty default 0 |
| 2 | Validasi kosong | Tolak jika semua qty = 0; minimal 1 jenis harus > 0 |
| 3 | Riwayat Sheet | 1 baris per transaksi, kolom terpisah per jenis |
| 4 | Stok kurang | Tolak seluruh transaksi jika satu jenis saja tidak cukup stok |

---

## Jenis Fiber Box

`DRB KUNING`, `DRB ORANGE`, `MSU`, `GAS`, `SCI`

---

## Section 1 — Form Transfer (Flutter)

### Sebelum (saat ini)
- Dropdown: pilih 1 jenis
- Input: qty untuk jenis tersebut
- 1 submit = 1 jenis

### Sesudah
- Hapus dropdown jenis
- Tampilkan 5 baris input qty (labeled per jenis), default 0
- Validasi: setidaknya 1 qty > 0 sebelum submit
- 1 submit = semua jenis sekaligus

**Layout:**
```
Dari: [dropdown lokasi]
Ke:   [dropdown lokasi]
Petugas: [text field]

📦 Jumlah per Jenis:
  DRB KUNING   [____] pcs
  DRB ORANGE   [____] pcs
  MSU          [____] pcs
  GAS          [____] pcs
  SCI          [____] pcs

📷 [Ambil Foto Surat Jalan]
[SIMPAN TRANSAKSI]
```

---

## Section 2 — API & Backend

### Payload POST `pindahStok` (baru)
```json
{
  "apiKey": "...",
  "action": "pindahStok",
  "dari": "Gudang Utama",
  "ke": "B 1234 XY",
  "qty": {
    "DRB KUNING": 25,
    "DRB ORANGE": 25,
    "MSU": 50,
    "GAS": 0,
    "SCI": 0
  },
  "oleh": "Budi",
  "fotoBase64": "...",
  "fotoMimeType": "image/jpeg"
}
```

### Logika Backend `Code.gs` — `prosesPindahStok`

1. Parse `qty` map dari body
2. Filter hanya jenis yang qty > 0
3. Jika tidak ada satu pun → tolak
4. Validasi stok cukup untuk SEMUA jenis yang > 0 (pre-check sebelum ubah data)
5. Jika satu saja kurang → tolak seluruhnya, kembalikan pesan error yang spesifik
6. Upload foto (jika ada)
7. Lock spreadsheet
8. Update sheet Stok (semua kolom jenis yang > 0)
9. Catat 1 baris ke sheet Transaksi

### Sheet "Transaksi" — Header baru
```
Timestamp | Dari | Ke | DRB KUNING | DRB ORANGE | MSU | GAS | SCI | Oleh | FotoURL
```

---

## Section 3 — Model Dart

### `RiwayatTransaksi` (diubah)
- Hapus field `jenis` (String tunggal)
- Tambah field per jenis: `drbKuning`, `drbOrange`, `msu`, `gas`, `sci`

### `ApiService.pindahStok` (diubah)
- Hapus param `jenis` & `qty` (int tunggal)
- Tambah param `quantities: Map<String, int>` berisi semua 5 jenis

---

## Section 4 — Tampilan Riwayat di Aplikasi

Card riwayat menampilkan ringkasan per jenis (hanya tampilkan yang > 0):
```
┌─────────────────────────────────────┐
│ ⬆ Gudang Utama → B 1234 XY          │
│ Jum, 18 Jul 2026 • 16:00            │
│ Oleh: Budi                          │
│ MSU: 50  DRB K: 25  DRB O: 25      │  ← GAS & SCI disembunyikan (0)
│ 📷 Lihat Surat Jalan                │
└─────────────────────────────────────┘
```

---

## File yang Berubah

| File | Perubahan |
|------|-----------|
| `gas_script/Code.gs` | Ubah `prosesPindahStok`, `getRiwayat`, `getOrCreateTransaksiSheet` |
| `lib/models/models.dart` | Ubah `RiwayatTransaksi` (hapus `jenis`, tambah per-jenis) |
| `lib/services/api_service.dart` | Ubah `pindahStok` signature |
| `lib/screens/transfer_screen.dart` | Hapus dropdown jenis, tambah 5 qty fields |
| `lib/main.dart` | Sesuaikan tampilan riwayat jika ada di halaman ini |

---

## Verification Plan

- Build debug → jalankan di device
- Coba transfer: isi 2 jenis > 0, pastikan Sheet Stok berkurang di 2 kolom
- Coba submit semua 0 → harus muncul error
- Coba jenis dengan stok kurang → seluruh transaksi harus ditolak
- Cek Sheet Transaksi: 1 baris dengan 5 kolom qty
