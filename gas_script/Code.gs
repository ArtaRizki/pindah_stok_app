/**
 * ============================================
 * APLIKASI PINDAH STOK - BACKEND (Code.gs)
 * ============================================
 *
 * SETUP SPREADSHEET (buat sheet dengan nama persis ini):
 *
 * 1. Sheet "Lokasi"
 *    Kolom A: Nama Lokasi (Contoh: Gudang A, Gudang B, B 1234 XY, dsb.)
 *    Isi sesuai lokasi nyata. Admin bisa tambah/hapus kapan saja tanpa update APK.
 *
 * 2. Sheet "Stok"
 *    Header (baris 1): Lokasi | DRB KUNING | DRB ORANGE | MSU | GAS | SCI
 *    Baris 2 dst: nama lokasi harus sama persis dengan Sheet "Lokasi"
 *    Script akan otomatis sinkronisasi jika ada lokasi baru di Sheet Lokasi.
 *
 * 3. Sheet "Transaksi" -> kosongkan saja, header dibuat otomatis oleh script.
 *
 * DEPLOY SEBAGAI WEB APP:
 *   Deploy > New deployment > Web app
 *   Execute as: Me
 *   Who has access: Anyone with the link
 *   Copy URL yang berakhiran /exec, tempel ke `baseUrl` di api_service.dart
 */

// --- KEAMANAN ---
const API_KEY = 'RAHASIA123'; // Pastikan sama dengan di Flutter

const SHEET_LOKASI     = 'Lokasi';
const SHEET_STOK       = 'Stok';
const SHEET_TRANSAKSI  = 'Transaksi';
const FOLDER_FOTO_NAME = 'Foto Surat Jalan - Pindah Stok';

// Daftar jenis fiber box yang dikelola (urutan = urutan kolom di Sheet Stok)
const JENIS_FIBER = ['DRB KUNING', 'DRB ORANGE', 'MSU', 'GAS', 'SCI'];

// ─────────────────────────────────────────────
// HANDLER GET
// ─────────────────────────────────────────────
function doGet(e) {
  try {
    if (e.parameter.apiKey !== API_KEY) {
      return jsonResponse({ success: false, message: 'Unauthorized access' });
    }
    const action = e.parameter.action || 'getStok';

    if (action === 'getLokasi') {
      return jsonResponse({ success: true, data: getLokasi() });
    }
    if (action === 'getStok') {
      return jsonResponse({ success: true, data: getStok() });
    }
    if (action === 'getRiwayat') {
      const limit = parseInt(e.parameter.limit || '50', 10);
      return jsonResponse({ success: true, data: getRiwayat(limit) });
    }
    return jsonResponse({ success: false, message: 'Action tidak dikenal: ' + action });
  } catch (err) {
    return jsonResponse({ success: false, message: err.message });
  }
}

// ─────────────────────────────────────────────
// HANDLER POST
// ─────────────────────────────────────────────
function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents);
    if (body.apiKey !== API_KEY) {
      return jsonResponse({ success: false, message: 'Unauthorized access' });
    }
    const action = body.action || 'pindahStok';

    if (action === 'pindahStok') {
      return jsonResponse(prosesPindahStok(body));
    }
    if (action === 'tambahLokasi') {
      return jsonResponse(tambahLokasi(body.namaLokasi));
    }
    return jsonResponse({ success: false, message: 'Action tidak dikenal: ' + action });
  } catch (err) {
    return jsonResponse({ success: false, message: err.message });
  }
}

// ─────────────────────────────────────────────
// AMBIL SEMUA NAMA LOKASI
// ─────────────────────────────────────────────
function getLokasi() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(SHEET_LOKASI);
  if (!sheet) {
    // Buat sheet Lokasi otomatis jika belum ada
    sheet = ss.insertSheet(SHEET_LOKASI);
    sheet.appendRow(['Nama Lokasi']);
    return [];
  }
  const values = sheet.getDataRange().getValues();
  return values
    .slice(1)               // skip header
    .map(r => r[0]?.toString().trim())
    .filter(v => v);       // buang baris kosong
}

// ─────────────────────────────────────────────
// TAMBAH LOKASI BARU
// ─────────────────────────────────────────────
function tambahLokasi(namaLokasi) {
  if (!namaLokasi || !namaLokasi.trim()) {
    return { success: false, message: 'Nama lokasi tidak boleh kosong' };
  }
  const nama = namaLokasi.trim();
  const lokasi = getLokasi();
  if (lokasi.includes(nama)) {
    return { success: false, message: 'Lokasi sudah ada: ' + nama };
  }
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const lokasiSheet = ss.getSheetByName(SHEET_LOKASI);
  lokasiSheet.appendRow([nama]);
  // Tambahkan baris nol di sheet Stok agar stok lokasi baru bisa langsung dipakai
  const stokSheet = getOrCreateStokSheet();
  stokSheet.appendRow([nama, 0, 0, 0, 0, 0]);
  return { success: true, message: 'Lokasi berhasil ditambahkan: ' + nama };
}

// ─────────────────────────────────────────────
// AMBIL STOK (semua lokasi, semua jenis)
// ─────────────────────────────────────────────
function getStok() {
  const sheet = getOrCreateStokSheet();
  const values = sheet.getDataRange().getValues();
  return values
    .slice(1)  // skip header
    .filter(r => r[0])
    .map(r => ({
      lokasi:    r[0]?.toString() ?? '',
      drbKuning: Number(r[1]) || 0,
      drbOrange: Number(r[2]) || 0,
      msu:       Number(r[3]) || 0,
      gas:       Number(r[4]) || 0,
      sci:       Number(r[5]) || 0,
    }));
}

// ─────────────────────────────────────────────
// AMBIL RIWAYAT TRANSAKSI
// ─────────────────────────────────────────────
function getRiwayat(limit) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_TRANSAKSI);
  if (!sheet) return [];
  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return [];

  const numRows = Math.min(limit, lastRow - 1);
  const startRow = lastRow - numRows + 1;
  // Kolom: Timestamp | Dari | Ke | Jenis | Qty | Oleh | FotoURL
  const values = sheet.getRange(startRow, 1, numRows, 7).getValues();
  return values.reverse().map(r => ({
    timestamp: r[0],
    dari:      r[1],
    ke:        r[2],
    jenis:     r[3],
    qty:       Number(r[4]) || 0,
    oleh:      r[5],
    fotoUrl:   r[6],
  }));
}

// ─────────────────────────────────────────────
// PROSES PINDAH STOK
// body: { dari, ke, jenis, qty, oleh, fotoBase64, fotoMimeType, apiKey }
// ─────────────────────────────────────────────
function prosesPindahStok(body) {
  const dari  = body.dari;
  const ke    = body.ke;
  const jenis = body.jenis;   // Contoh: "DRB KUNING"
  const qty   = Number(body.qty);
  const oleh  = body.oleh || 'Tidak diketahui';

  if (!dari || !ke || !jenis || !qty || qty <= 0) {
    return { success: false, message: 'Data tidak lengkap: dari, ke, jenis, qty wajib diisi' };
  }
  if (dari === ke) {
    return { success: false, message: 'Lokasi asal dan tujuan tidak boleh sama' };
  }
  // Validasi jenis
  const kolomIdx = JENIS_FIBER.indexOf(jenis);
  if (kolomIdx === -1) {
    return { success: false, message: 'Jenis fiber box tidak dikenal: ' + jenis };
  }
  const kolomSheet = kolomIdx + 2; // Kolom B = indeks 2 (1-based), C = 3, dst.

  // Upload foto DULU sebelum ubah stok
  let fotoUrl = '';
  if (body.fotoBase64) {
    try {
      fotoUrl = simpanFotoSuratJalan(body.fotoBase64, body.fotoMimeType || 'image/jpeg', dari, ke, jenis);
    } catch (e) {
      return { success: false, message: 'Gagal upload foto surat jalan. Transaksi dibatalkan. (' + e.message + ')' };
    }
  }

  // Lock untuk cegah race condition
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);

  try {
    const stokSheet = getOrCreateStokSheet();
    const data = stokSheet.getDataRange().getValues();

    let barisDari = -1, barisKe = -1;
    for (let i = 1; i < data.length; i++) {
      if (data[i][0] === dari) barisDari = i;
      if (data[i][0] === ke)   barisKe   = i;
    }

    if (barisDari === -1) return { success: false, message: 'Lokasi asal "' + dari + '" tidak ditemukan' };
    if (barisKe   === -1) return { success: false, message: 'Lokasi tujuan "' + ke + '" tidak ditemukan' };

    const stokDari = Number(data[barisDari][kolomIdx + 1]) || 0;
    if (stokDari < qty) {
      return { success: false, message: 'Stok ' + jenis + ' di ' + dari + ' tidak cukup (sisa ' + stokDari + ')' };
    }

    // Update sheet Stok
    stokSheet.getRange(barisDari + 1, kolomSheet).setValue(stokDari - qty);
    const stokKe = Number(data[barisKe][kolomIdx + 1]) || 0;
    stokSheet.getRange(barisKe + 1, kolomSheet).setValue(stokKe + qty);

    // Catat ke sheet Transaksi
    const transaksiSheet = getOrCreateTransaksiSheet();
    transaksiSheet.appendRow([new Date(), dari, ke, jenis, qty, oleh, fotoUrl]);

    return {
      success: true,
      message: 'Stok berhasil dipindah',
      data: { dari, ke, jenis, qty, stokDariSisa: stokDari - qty, stokKeSisa: stokKe + qty, fotoUrl }
    };
  } finally {
    lock.releaseLock();
  }
}

// ─────────────────────────────────────────────
// HELPER: BUAT ATAU AMBIL SHEET STOK
// ─────────────────────────────────────────────
function getOrCreateStokSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(SHEET_STOK);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_STOK);
    sheet.appendRow(['Lokasi', 'DRB KUNING', 'DRB ORANGE', 'MSU', 'GAS', 'SCI']);
  }
  return sheet;
}

// ─────────────────────────────────────────────
// HELPER: BUAT ATAU AMBIL SHEET TRANSAKSI
// ─────────────────────────────────────────────
function getOrCreateTransaksiSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(SHEET_TRANSAKSI);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_TRANSAKSI);
    sheet.appendRow(['Timestamp', 'Dari', 'Ke', 'Jenis', 'Qty', 'Oleh', 'FotoURL']);
  }
  return sheet;
}

// ─────────────────────────────────────────────
// SIMPAN FOTO SURAT JALAN KE GOOGLE DRIVE
// ─────────────────────────────────────────────
function simpanFotoSuratJalan(base64Data, mimeType, dari, ke, jenis) {
  const folder = getOrCreateFolder(FOLDER_FOTO_NAME);
  const bytes = Utilities.base64Decode(base64Data);
  const ext = (mimeType.split('/')[1]) || 'jpg';
  const fileName = 'SJ_' + jenis.replace(/\s+/g, '_') + '_' + dari + '_ke_' + ke + '_' + new Date().getTime() + '.' + ext;
  const blob = Utilities.newBlob(bytes, mimeType, fileName);
  const file = folder.createFile(blob);
  file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
  return 'https://drive.google.com/uc?id=' + file.getId();
}

function getOrCreateFolder(name) {
  const folders = DriveApp.getFoldersByName(name);
  if (folders.hasNext()) return folders.next();
  return DriveApp.createFolder(name);
}

// ─────────────────────────────────────────────
// HELPER RESPONSE JSON
// ─────────────────────────────────────────────
function jsonResponse(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
