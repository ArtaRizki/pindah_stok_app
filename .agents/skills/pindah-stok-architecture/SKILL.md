---
name: pindah-stok-architecture
description: >-
  Provides architectural knowledge of the Pindah Stok application, explaining how the 
  Google Apps Script backend and Flutter UI handle dynamic locations and items automatically.
---

# Arsitektur Pindah Stok (Dinamis)

## Overview
Aplikasi Pindah Stok memiliki desain arsitektur dinamis untuk memfasilitasi kebutuhan di lapangan (seperti lokasi transit yang berubah-ubah dan jenis barang fiber box yang terus bertambah).

**Jangan pernah men-*hardcode* daftar lokasi atau daftar barang jika Anda diminta untuk mengubah alur sistem di proyek ini.** Semua hal harus bergantung pada pembacaan respons Google Apps Script yang bersifat *Map* atau struktur data dinamis.

## 1. Lokasi Dinamis (Tambak / Transit Sementara)
- Di Flutter UI (`transfer_screen.dart`), pengguna dapat mengetikkan nama lokasi tujuan (misal "TAMBAK A") melalui opsi "+ Tambah Lokasi Baru".
- Backend (`Code.gs` fungsi `prosesPindahStok`) akan memvalidasi *array* `data` di Sheet `Stok`.
- Jika lokasi tidak ditemukan (baris = -1), backend akan:
  1. Menambahkan nama lokasi ke baris baru di Sheet `Lokasi`.
  2. Menambahkan nama lokasi ke baris baru di Sheet `Stok` (dengan nilai 0 pada semua kolom barang).
- Saat `getStok` dipanggil oleh aplikasi, lokasi-lokasi yang total stoknya `0` difilter agar tidak muncul (disembunyikan) pada halaman Dashboard.

## 2. Jenis Barang Dinamis
- Secara default, aplikasi memiliki 6 jenis barang bawaan: `DRB KUNING, DRB ORANGE, MSU, GAS, GLOBAL, SCI`.
- Pengguna bisa menambahkan barang manual lewat "+ Tambah Barang Lainnya" di form `transfer_screen.dart`.
- `Code.gs` membandingkan JSON `qty` yang dikirim dengan header Sheet `Stok` dan Sheet `Transaksi`.
- Jika ada *key* (jenis barang) yang belum pernah ada, `Code.gs` akan *menambahkan kolom baru* di sisi paling kanan dari Sheet `Stok` dan Sheet `Transaksi`, lalu mengisi nilai barang barunya, serta mengatur nilai untuk baris yang ada (yang lama) dengan default `0`.
- Di model Flutter (`models.dart`), `LokasiStok` dan `RiwayatTransaksi` membaca semua JSON object ke dalam `Map<String, int> items` dan `UI` melakukan *looping* pada `.entries`, bukan lagi ke *field* spesifik (`drbKuning`, dll).

## Aturan Utama (Common Mistakes)
- **Hardcoding Data:** Jangan menambahkan variabel `int jenisBaru` ke dalam file `models.dart`. Selalu andalkan map dinamis (`items`).
- **Google Apps Script:** Jangan mengubah fungsi indeks (seperti `headerStok.indexOf(jenis)`) yang sudah berfungsi dinamis. Ketika merefaktor, ingat bahwa penambahan baris atau kolom harus diselaraskan antara logika *array memori* dan API eksekusi (*SpreadsheetApp*).
- **Format UI:** Tampilan `ListView` atau `Wrap` selalu menggunakan method bawaan `.map((e) => ...)` dari *Map entries*, sehingga tidak perlu di-set kaku (harus bisa menampung `N` jenis item).
