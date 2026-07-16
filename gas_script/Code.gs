/**
 * ============================================
 * APLIKASI PINDAH STOK - BACKEND (Code.gs)
 * ============================================
 *
 * SETUP SPREADSHEET (buat sheet dengan nama persis ini):
 *
 * 1. Sheet "Stok"
 *    Kolom A: Lokasi | Kolom B: Qty
 *    Isi baris awal sesuai stok fisik saat ini, total harus 1000, contoh:
 *      Gudang A     | 300
 *      Gudang B     | 300
 *      Gudang C     | 200
 *      Mobil 1      | 100
 *      Lokasi Lain  | 100
 *    (Ganti nama & jumlah lokasi sesuai kondisi asli di lapangan)
 *
 * 2. Sheet "Transaksi" -> kosongkan saja, header dibuat otomatis oleh script
 *
 * DEPLOY SEBAGAI WEB APP:
 *   Deploy > New deployment > Web app
 *   Execute as: Me
 *   Who has access: Anyone with the link
 *   Copy URL yang berakhiran /exec, tempel ke `baseUrl` di api_service.dart
 */

// --- TAMBAHAN KEAMANAN ---
// Gunakan API_KEY ini untuk mencegah akses manipulasi stok secara publik
const API_KEY = 'RAHASIA123'; // Pastikan sama dengan di Flutter

const SHEET_STOK = 'Stok';
const SHEET_TRANSAKSI = 'Transaksi';
const FOLDER_SURAT_JALAN_NAME = 'Foto Surat Jalan - Pindah Stok';

function doGet(e) {
  try {
    if (e.parameter.apiKey !== API_KEY) {
      return jsonResponse({ success: false, message: 'Unauthorized access' });
    }
    const action = e.parameter.action || 'getStok';

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
    return jsonResponse({ success: false, message: 'Action tidak dikenal: ' + action });
  } catch (err) {
    return jsonResponse({ success: false, message: err.message });
  }
}

/** Ambil semua stok per lokasi */
function getStok() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_STOK);
  const values = sheet.getDataRange().getValues();
  return values
    .slice(1) // skip header
    .filter(r => r[0])
    .map(r => ({ lokasi: r[0], qty: Number(r[1]) || 0 }));
}

/** Ambil riwayat transaksi terbaru (paling baru duluan) */
function getRiwayat(limit) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_TRANSAKSI);
  if (!sheet) return [];
  
  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return []; // Kosong (hanya header)

  // Optimasi Performa: Hanya tarik jumlah baris sesuai limit dari bawah
  const numRows = Math.min(limit, lastRow - 1);
  const startRow = lastRow - numRows + 1;
  
  const values = sheet.getRange(startRow, 1, numRows, 6).getValues();
  const rows = values.reverse(); // Balik supaya terbaru muncul duluan
  
  return rows.map(r => ({
    timestamp: r[0],
    dari: r[1],
    ke: r[2],
    qty: Number(r[3]) || 0,
    oleh: r[4],
    fotoUrl: r[5]
  }));
}

/**
 * Proses satu transaksi pindah stok antar lokasi.
 * body: { dari, ke, qty, oleh, fotoBase64, fotoMimeType, apiKey }
 */
function prosesPindahStok(body) {
  const dari = body.dari;
  const ke = body.ke;
  const qty = Number(body.qty);
  const oleh = body.oleh || 'Tidak diketahui';

  if (!dari || !ke || !qty || qty <= 0) {
    return { success: false, message: 'Data tidak lengkap: dari, ke, qty wajib diisi' };
  }
  if (dari === ke) {
    return { success: false, message: 'Lokasi asal dan tujuan tidak boleh sama' };
  }

  // --- PERBAIKAN BUG KRITIS ---
  // Upload foto surat jalan TERLEBIH DAHULU sebelum mengubah angka stok
  let fotoUrl = '';
  if (body.fotoBase64) {
    try {
      fotoUrl = simpanFotoSuratJalan(body.fotoBase64, body.fotoMimeType || 'image/jpeg', dari, ke);
    } catch (e) {
      // Jika upload Drive gagal (kuota habis dll), gagalkan proses agar stok tetap utuh
      return { success: false, message: 'Gagal mengupload foto surat jalan. Transaksi dibatalkan. (' + e.message + ')' };
    }
  }

  // Lock supaya aman kalau ada 2 petugas input barengan (cegah race condition di sheet Stok)
  const lock = LockService.getScriptLock();
  lock.waitLock(30000);

  try {
    const stokSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_STOK);
    const data = stokSheet.getDataRange().getValues();

    let baris_dari = -1, baris_ke = -1;
    for (let i = 1; i < data.length; i++) {
      if (data[i][0] === dari) baris_dari = i;
      if (data[i][0] === ke) baris_ke = i;
    }

    if (baris_dari === -1) return { success: false, message: 'Lokasi asal "' + dari + '" tidak ditemukan di sheet Stok' };
    if (baris_ke === -1) return { success: false, message: 'Lokasi tujuan "' + ke + '" tidak ditemukan di sheet Stok' };

    const stokDari = Number(data[baris_dari][1]) || 0;
    if (stokDari < qty) {
      return { success: false, message: 'Stok di ' + dari + ' tidak cukup (sisa ' + stokDari + ')' };
    }

    // Update stok asal & tujuan (total keseluruhan tetap sama, cuma pindah)
    stokSheet.getRange(baris_dari + 1, 2).setValue(stokDari - qty);
    const stokKe = Number(data[baris_ke][1]) || 0;
    stokSheet.getRange(baris_ke + 1, 2).setValue(stokKe + qty);

    // Catat log transaksi
    const transaksiSheet = getOrCreateTransaksiSheet();
    transaksiSheet.appendRow([new Date(), dari, ke, qty, oleh, fotoUrl]);

    return {
      success: true,
      message: 'Stok berhasil dipindah',
      data: { dari, ke, qty, stokDariSisa: stokDari - qty, stokKeSisa: stokKe + qty, fotoUrl }
    };
  } finally {
    lock.releaseLock();
  }
}

function getOrCreateTransaksiSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(SHEET_TRANSAKSI);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_TRANSAKSI);
    sheet.appendRow(['Timestamp', 'Dari', 'Ke', 'Qty', 'Oleh', 'FotoURL']);
  }
  return sheet;
}

/** Simpan foto surat jalan ke Google Drive, kembalikan URL yang bisa diakses */
function simpanFotoSuratJalan(base64Data, mimeType, dari, ke) {
  const folder = getOrCreateFolder(FOLDER_SURAT_JALAN_NAME);
  const bytes = Utilities.base64Decode(base64Data);
  const ext = (mimeType.split('/')[1]) || 'jpg';
  const fileName = 'SJ_' + dari + '_ke_' + ke + '_' + new Date().getTime() + '.' + ext;
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

function jsonResponse(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
