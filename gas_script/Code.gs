/**
 * ============================================
 * APLIKASI PINDAH STOK - BACKEND (Code.gs)
 * ============================================
 *
 * SETUP SPREADSHEET (buat sheet dengan nama persis ini):
 *
 * 1. Sheet "Lokasi"
 *    Kolom A: Nama Lokasi (Contoh: Gudang A, Gudang B, B 1234 XY, dsb.)
 *
 * 2. Sheet "Stok"
 *    Header (baris 1): Lokasi | DRB KUNING | DRB ORANGE | MSU | GAS | SCI
 *
 * 3. Sheet "Transaksi" -> kosongkan saja, header dibuat otomatis oleh script.
 *    (Header baru: Timestamp | Dari | Ke | DRB KUNING | DRB ORANGE | MSU | GAS | SCI | Oleh | FotoURL)
 */

// --- KEAMANAN ---
const API_KEY = 'RAHASIA123'; // Pastikan sama dengan di Flutter

const SHEET_LOKASI    = 'Lokasi';
const SHEET_STOK      = 'Stok';
const SHEET_TRANSAKSI = 'Transaksi';

// Folder tujuan foto surat jalan
const FOLDER_FOTO_ID  = '1PwYsdZOpSb_0lOldRvLp-i-no16KVIhB';

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
      const limit = Number(e.parameter.limit) || 50;
      return jsonResponse({ success: true, data: getRiwayat(limit) });
    }
    return jsonResponse({ success: false, message: 'Action tidak dikenal' });
  } catch (err) {
    return jsonResponse({ success: false, message: err.toString() });
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
    if (body.action === 'pindahStok') {
      return jsonResponse(prosesPindahStok(body));
    }
    return jsonResponse({ success: false, message: 'Action tidak dikenal' });
  } catch (err) {
    return jsonResponse({ success: false, message: err.toString() });
  }
}

// ─────────────────────────────────────────────
// AMBIL DAFTAR LOKASI (Dari Sheet "Lokasi")
// ─────────────────────────────────────────────
function getLokasi() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_LOKASI);
  if (!sheet) return [];
  const data = sheet.getDataRange().getValues();
  // Asumsi baris 1 adalah header "Nama Lokasi"
  const lokasi = [];
  for (let i = 1; i < data.length; i++) {
    if (data[i][0]) lokasi.push(data[i][0].toString());
  }
  return lokasi;
}

// ─────────────────────────────────────────────
// AMBIL DATA STOK TERKINI
// ─────────────────────────────────────────────
function getStok() {
  const sheet = getOrCreateStokSheet();
  const data = sheet.getDataRange().getValues();
  if (data.length <= 1) return [];

  // Lewati baris 1 (Header), ambil baris 2 dst
  return data.slice(1)
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
  // Header Baru: Timestamp | Dari | Ke | DRB KUNING | DRB ORANGE | MSU | GAS | SCI | Oleh | FotoURL
  const values = sheet.getRange(startRow, 1, numRows, 10).getValues();
  return values.reverse().map(r => ({
    timestamp: r[0],
    dari:      r[1],
    ke:        r[2],
    drbKuning: Number(r[3]) || 0,
    drbOrange: Number(r[4]) || 0,
    msu:       Number(r[5]) || 0,
    gas:       Number(r[6]) || 0,
    sci:       Number(r[7]) || 0,
    oleh:      r[8],
    fotoUrl:   r[9],
  }));
}

// ─────────────────────────────────────────────
// PROSES PINDAH STOK (MULTI-JENIS)
// body: { dari, ke, qty: { "MSU": 50, "DRB KUNING": 25, ... }, oleh, fotoBase64, fotoMimeType, apiKey }
// ─────────────────────────────────────────────
function prosesPindahStok(body) {
  const dari  = body.dari;
  const ke    = body.ke;
  const qtyMap = body.qty; // Map<String, int>
  const oleh  = body.oleh || 'Tidak diketahui';

  if (!dari || !ke || !qtyMap) {
    return { success: false, message: 'Data tidak lengkap: dari, ke, dan qty wajib diisi' };
  }
  if (dari === ke) {
    return { success: false, message: 'Lokasi asal dan tujuan tidak boleh sama' };
  }

  // Filter jenis yang qty-nya > 0
  const itemsDipindah = [];
  for (const jenis of JENIS_FIBER) {
    const q = Number(qtyMap[jenis]) || 0;
    if (q > 0) {
      itemsDipindah.push({ jenis: jenis, qty: q, kolomIdx: JENIS_FIBER.indexOf(jenis) });
    }
  }

  if (itemsDipindah.length === 0) {
    return { success: false, message: 'Semua jumlah jenis barang 0, tidak ada yang dipindahkan' };
  }

  // Upload foto DULU sebelum ubah stok
  let fotoUrl = '';
  if (body.fotoBase64) {
    try {
      fotoUrl = simpanFotoSuratJalan(body.fotoBase64, body.fotoMimeType || 'image/jpeg', dari, ke);
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
    
    // Auto-create lokasi tujuan jika belum ada (Tambak / Lokasi Sementara)
    if (barisKe === -1) {
      const lokasiSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_LOKASI);
      if (lokasiSheet) lokasiSheet.appendRow([ke]);
      
      const newRow = [ke, 0, 0, 0, 0, 0];
      stokSheet.appendRow(newRow);
      data.push(newRow);
      barisKe = data.length - 1;
    }

    // PRE-CHECK STOK (Validasi kecukupan seluruh item sebelum merubah apapun)
    for (const item of itemsDipindah) {
      const stokDari = Number(data[barisDari][item.kolomIdx + 1]) || 0;
      if (stokDari < item.qty) {
        return { success: false, message: 'Stok ' + item.jenis + ' di ' + dari + ' tidak cukup (butuh ' + item.qty + ', sisa ' + stokDari + ')' };
      }
    }

    // SEMUA STOK CUKUP -> LAKUKAN PEMOTONGAN & PENAMBAHAN
    for (const item of itemsDipindah) {
      const kolomSheet = item.kolomIdx + 2; // +1 untuk kompensasi 0-index array (kolom A), +1 untuk kompensasi 1-index Sheet (Kolom B = 2)
      
      const stokDariLama = Number(data[barisDari][item.kolomIdx + 1]) || 0;
      stokSheet.getRange(barisDari + 1, kolomSheet).setValue(stokDariLama - item.qty);
      
      const stokKeLama = Number(data[barisKe][item.kolomIdx + 1]) || 0;
      stokSheet.getRange(barisKe + 1, kolomSheet).setValue(stokKeLama + item.qty);
    }

    // Catat ke sheet Transaksi
    // Header Baru: Timestamp | Dari | Ke | DRB KUNING | DRB ORANGE | MSU | GAS | SCI | Oleh | FotoURL
    const transaksiSheet = getOrCreateTransaksiSheet();
    const barisTransaksi = [
      new Date(),
      dari,
      ke,
      Number(qtyMap['DRB KUNING']) || 0,
      Number(qtyMap['DRB ORANGE']) || 0,
      Number(qtyMap['MSU']) || 0,
      Number(qtyMap['GAS']) || 0,
      Number(qtyMap['SCI']) || 0,
      oleh,
      fotoUrl
    ];
    transaksiSheet.appendRow(barisTransaksi);

    return {
      success: true,
      message: 'Stok berhasil dipindah',
      data: { dari, ke, qtyMap, fotoUrl }
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
    sheet.appendRow(['Timestamp', 'Dari', 'Ke', 'DRB KUNING', 'DRB ORANGE', 'MSU', 'GAS', 'SCI', 'Oleh', 'FotoURL']);
  }
  return sheet;
}

// ─────────────────────────────────────────────
// SIMPAN FOTO SURAT JALAN KE GOOGLE DRIVE
// ─────────────────────────────────────────────
function simpanFotoSuratJalan(base64Data, mimeType, dari, ke) {
  const folder = DriveApp.getFolderById(FOLDER_FOTO_ID);
  const bytes = Utilities.base64Decode(base64Data);
  const ext = (mimeType.split('/')[1]) || 'jpg';
  const fileName = 'SJ_' + dari + '_ke_' + ke + '_' + new Date().getTime() + '.' + ext;
  
  const blob = Utilities.newBlob(bytes, mimeType, fileName);
  const file = folder.createFile(blob);
  
  // Set agar bisa dilihat siapa saja (dibutuhkan agar image bisa dirender di Flutter)
  file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
  
  return 'https://drive.google.com/uc?id=' + file.getId();
}

// ─────────────────────────────────────────────
// HELPER RESPONSE JSON
// ─────────────────────────────────────────────
function jsonResponse(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
