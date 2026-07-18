/**
 * ============================================
 * APLIKASI PINDAH STOK - BACKEND (Code.gs)
 * ============================================
 */

// --- KEAMANAN ---
const API_KEY = 'RAHASIA123';

const SHEET_LOKASI    = 'Lokasi';
const SHEET_STOK      = 'Stok';
const SHEET_TRANSAKSI = 'Transaksi';

const FOLDER_FOTO_ID  = '1PwYsdZOpSb_0lOldRvLp-i-no16KVIhB';

const INITIAL_JENIS_FIBER = ['DRB KUNING', 'DRB ORANGE', 'MSU', 'GAS', 'GLOBAL', 'SCI'];
const FIXED_TRX_COLS = ['Timestamp', 'Dari', 'Ke', 'PIC', 'FotoURL'];

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
      const startDate = e.parameter.startDate;
      const endDate = e.parameter.endDate;
      return jsonResponse({ success: true, data: getRiwayat(limit, startDate, endDate) });
    }
    return jsonResponse({ success: false, message: 'Action tidak dikenal' });
  } catch (err) {
    return jsonResponse({ success: false, message: err.toString() });
  }
}

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

function getLokasi() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_LOKASI);
  if (!sheet) return [];
  const data = sheet.getDataRange().getValues();
  const lokasi = [];
  for (let i = 1; i < data.length; i++) {
    if (data[i][0]) lokasi.push(data[i][0].toString());
  }
  return lokasi;
}

function getStok() {
  const sheet = getOrCreateStokSheet();
  const data = sheet.getDataRange().getValues();
  if (data.length <= 1) return [];

  const headers = data[0];
  
  return data.slice(1)
    .filter(r => r[0])
    .map(r => {
      const items = {};
      for (let j = 1; j < headers.length; j++) {
        const key = headers[j].toString().trim();
        if (key) items[key] = Number(r[j]) || 0;
      }
      return {
        lokasi: r[0]?.toString() ?? '',
        items: items
      };
    });
}

function getRiwayat(limit, startDateStr, endDateStr) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_TRANSAKSI);
  if (!sheet) return [];
  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return [];

  const data = sheet.getDataRange().getValues();
  const headers = data[0];
  
  const tsIdx = headers.indexOf('Timestamp');
  const dariIdx = headers.indexOf('Dari');
  const keIdx = headers.indexOf('Ke');
  const olehIdx = headers.indexOf('PIC');
  const fotoIdx = headers.indexOf('FotoURL');
  
  const startDate = startDateStr ? new Date(startDateStr) : null;
  const endDate = endDateStr ? new Date(endDateStr) : null;
  if (endDate) endDate.setHours(23, 59, 59, 999);

  const filteredData = [];
  for (let i = 1; i < data.length; i++) {
    const r = data[i];
    const ts = new Date(r[tsIdx]);
    if (startDate && ts < startDate) continue;
    if (endDate && ts > endDate) continue;
    filteredData.push(r);
  }
  
  const numRows = Math.min(limit, filteredData.length);
  const startRow = filteredData.length - numRows; 
  
  const result = [];
  for (let i = filteredData.length - 1; i >= startRow; i--) {
    const r = filteredData[i];
    const items = {};
    for (let j = 0; j < headers.length; j++) {
      const colName = headers[j];
      if (!FIXED_TRX_COLS.includes(colName) && colName) {
         items[colName] = Number(r[j]) || 0;
      }
    }
    result.push({
      timestamp: r[tsIdx],
      dari:      r[dariIdx],
      ke:        r[keIdx],
      oleh:      r[olehIdx],
      fotoUrl:   r[fotoIdx],
      items:     items
    });
  }
  return result;
}

function prosesPindahStok(body) {
  const dari  = body.dari;
  const ke    = body.ke;
  const qtyMap = body.qty; 
  const oleh  = body.oleh || 'Tidak diketahui';

  if (!dari || !ke || !qtyMap) {
    return { success: false, message: 'Data tidak lengkap: dari, ke, dan qty wajib diisi' };
  }
  if (dari === ke) {
    return { success: false, message: 'Lokasi asal dan tujuan tidak boleh sama' };
  }

  const lock = LockService.getScriptLock();
  lock.waitLock(30000);

  try {
    const stokSheet = getOrCreateStokSheet();
    const data = stokSheet.getDataRange().getValues();
    const headerStok = data[0];

    const itemsDipindah = [];
    for (const jenis in qtyMap) {
      const q = Number(qtyMap[jenis]) || 0;
      if (q > 0) {
        let kIdx = headerStok.indexOf(jenis);
        if (kIdx === -1) {
           kIdx = headerStok.length;
           headerStok.push(jenis);
           stokSheet.getRange(1, kIdx + 1).setValue(jenis);
           
           for (let r = 1; r < data.length; r++) {
             data[r].push(0);
           }
        }
        itemsDipindah.push({ jenis: jenis, qty: q, kolomIdx: kIdx });
      }
    }

    if (itemsDipindah.length === 0) {
      return { success: false, message: 'Semua jumlah jenis barang 0, tidak ada yang dipindahkan' };
    }

    let fotoUrl = '';
    if (body.fotoBase64) {
      try {
        fotoUrl = simpanFotoSuratJalan(body.fotoBase64, body.fotoMimeType || 'image/jpeg', dari, ke);
      } catch (e) {
        return { success: false, message: 'Gagal upload foto surat jalan. Transaksi dibatalkan. (' + e.message + ')' };
      }
    }

    let barisDari = -1, barisKe = -1;
    for (let i = 1; i < data.length; i++) {
      if (data[i][0] === dari) barisDari = i;
      if (data[i][0] === ke)   barisKe   = i;
    }

    if (barisDari === -1) return { success: false, message: 'Lokasi asal "' + dari + '" tidak ditemukan' };
    
    if (barisKe === -1) {
      const lokasiSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_LOKASI);
      if (lokasiSheet) lokasiSheet.appendRow([ke]);
      
      const newRow = new Array(headerStok.length).fill(0);
      newRow[0] = ke;
      stokSheet.appendRow(newRow);
      data.push(newRow);
      barisKe = data.length - 1;
    }

    for (const item of itemsDipindah) {
      const stokDari = Number(data[barisDari][item.kolomIdx]) || 0;
      if (stokDari < item.qty) {
        return { success: false, message: 'Stok ' + item.jenis + ' di ' + dari + ' tidak cukup (butuh ' + item.qty + ', sisa ' + stokDari + ')' };
      }
    }

    for (const item of itemsDipindah) {
      const stokDariLama = Number(data[barisDari][item.kolomIdx]) || 0;
      stokSheet.getRange(barisDari + 1, item.kolomIdx + 1).setValue(stokDariLama - item.qty);
      
      const stokKeLama = Number(data[barisKe][item.kolomIdx]) || 0;
      stokSheet.getRange(barisKe + 1, item.kolomIdx + 1).setValue(stokKeLama + item.qty);
    }

    const trxSheet = getOrCreateTransaksiSheet();
    const trxData = trxSheet.getDataRange().getValues();
    const trxHeader = trxData[0];
    
    for (const item of itemsDipindah) {
      if (trxHeader.indexOf(item.jenis) === -1) {
         trxHeader.push(item.jenis);
         trxSheet.getRange(1, trxHeader.length).setValue(item.jenis);
      }
    }

    const newRowTrx = new Array(trxHeader.length).fill('');
    newRowTrx[trxHeader.indexOf('Timestamp')] = new Date();
    newRowTrx[trxHeader.indexOf('Dari')] = dari;
    newRowTrx[trxHeader.indexOf('Ke')] = ke;
    newRowTrx[trxHeader.indexOf('PIC')] = oleh;
    newRowTrx[trxHeader.indexOf('FotoURL')] = fotoUrl;
    
    for (const item of itemsDipindah) {
      newRowTrx[trxHeader.indexOf(item.jenis)] = item.qty;
    }

    trxSheet.appendRow(newRowTrx);

    return {
      success: true,
      message: 'Stok berhasil dipindah',
      data: { dari, ke, qtyMap, fotoUrl }
    };
  } finally {
    lock.releaseLock();
  }
}

function getOrCreateStokSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(SHEET_STOK);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_STOK);
    sheet.appendRow(['Lokasi', ...INITIAL_JENIS_FIBER]);
  }
  return sheet;
}

function getOrCreateTransaksiSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(SHEET_TRANSAKSI);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_TRANSAKSI);
    sheet.appendRow(['Timestamp', 'Dari', 'Ke', 'Oleh', 'FotoURL', ...INITIAL_JENIS_FIBER]);
  } else {
    // If sheet exists but FotoURL is at the end, we just dynamically append to the right. It doesn't break logic.
  }
  return sheet;
}

function simpanFotoSuratJalan(base64Data, mimeType, dari, ke) {
  const folder = DriveApp.getFolderById(FOLDER_FOTO_ID);
  const bytes = Utilities.base64Decode(base64Data);
  const ext = (mimeType.split('/')[1]) || 'jpg';
  const fileName = 'SJ_' + dari + '_ke_' + ke + '_' + new Date().getTime() + '.' + ext;
  const blob = Utilities.newBlob(bytes, mimeType, fileName);
  const file = folder.createFile(blob);
  file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
  return 'https://drive.google.com/uc?id=' + file.getId();
}

function jsonResponse(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}
