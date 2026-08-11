/**
 * ============================================
 * APLIKASI PINDAH STOK - BACKEND (Code.gs)
 * ============================================
 */

// --- KEAMANAN ---
const API_KEY = "RAHASIA123";

const SHEET_LOKASI = "Lokasi";
const SHEET_STOK = "Stok";
const SHEET_TRANSAKSI = "Transaksi";
const SHEET_ADMIN = "Admin";

const FOLDER_FOTO_ID = "1PwYsdZOpSb_0lOldRvLp-i-no16KVIhB";

const INITIAL_JENIS_FIBER = [
  "DRB KUNING",
  "DRB ORANGE",
  "MSU",
  "GAS",
  "GLOBAL",
  "SCI",
];
const FIXED_TRX_COLS = ["Timestamp", "Dari", "Ke", "PIC", "Keterangan", "FotoURL"];
const FIXED_STOK_COLS = ["Lokasi", "Keterangan"];

function doGet(e) {
  try {
    // 1. CEK AKSES WEB BROWSER
    // Jika tidak ada apiKey dan tidak ada action, asumsikan ini akses dari browser biasa
    if (!e.parameter || (!e.parameter.apiKey && !e.parameter.action)) {
      return HtmlService.createTemplateFromFile("Index")
        .evaluate()
        .setTitle("Pindah Stok Apps")
        .addMetaTag("viewport", "width=device-width, initial-scale=1")
        .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
    }

    // 2. CEK AKSES API MOBILE
    if (e.parameter.apiKey !== API_KEY) {
      return jsonResponse({ success: false, message: "Unauthorized access" });
    }
    const action = e.parameter.action || "getStok";

    if (action === "getLokasi") {
      return jsonResponse({ success: true, data: getLokasi() });
    }
    if (action === "getAdmin") {
      return jsonResponse({ success: true, data: getAdmin() });
    }
    if (action === "getStok") {
      return jsonResponse({ success: true, data: getStok() });
    }
    if (action === "getRiwayat") {
      const limit = Number(e.parameter.limit) || 50;
      const startDate = e.parameter.startDate;
      const endDate = e.parameter.endDate;
      const pic = e.parameter.pic;
      return jsonResponse({
        success: true,
        data: getRiwayat(limit, startDate, endDate, pic),
      });
    }
    return jsonResponse({ success: false, message: "Action tidak dikenal" });
  } catch (err) {
    return jsonResponse({ success: false, message: err.toString() });
  }
}

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents);
    if (body.apiKey !== API_KEY) {
      return jsonResponse({ success: false, message: "Unauthorized access" });
    }
    if (body.action === "pindahStok") {
      return jsonResponse(prosesPindahStok(body));
    }
    return jsonResponse({ success: false, message: "Action tidak dikenal" });
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

function getAdmin() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(SHEET_ADMIN);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_ADMIN);
    sheet.appendRow(["Username", "Password", "Role"]);
    sheet.getRange("A1:C1").setFontWeight("bold");
    return [];
  }
  const data = sheet.getDataRange().getValues();
  const admins = [];
  for (let i = 1; i < data.length; i++) {
    const username = data[i][0];
    const password = data[i][1];
    const role = data[i][2];
    if (username) {
      admins.push({
        username: username.toString().trim(),
        password: password ? password.toString().trim() : "",
        role: role ? role.toString().trim().toLowerCase() : "admin",
      });
    }
  }
  return admins;
}

function getStok() {
  const sheet = getOrCreateStokSheet();
  const data = sheet.getDataRange().getValues();
  if (data.length <= 1) return [];

  const headers = data[0];
  const lokasiIdx = headers.indexOf("Lokasi");
  const ketIdx = headers.indexOf("Keterangan");

  return data
    .slice(1)
    .filter((r) => r[0])
    .map((r) => {
      const items = {};
      for (let j = 0; j < headers.length; j++) {
        const key = headers[j].toString().trim();
        if (key && !FIXED_STOK_COLS.includes(key)) {
          items[key] = Number(r[j]) || 0;
        }
      }
      return {
        lokasi: r[lokasiIdx]?.toString() ?? "",
        status: ketIdx !== -1 ? r[ketIdx]?.toString() : "",
        items: items,
      };
    });
}

function getRiwayat(limit, startDateStr, endDateStr, picStr) {
  const sheet =
    SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_TRANSAKSI);
  if (!sheet) return [];
  const lastRow = sheet.getLastRow();
  if (lastRow <= 1) return [];

  const data = sheet.getDataRange().getValues();
  const headers = data[0];

  const tsIdx = headers.indexOf("Timestamp");
  const dariIdx = headers.indexOf("Dari");
  const keIdx = headers.indexOf("Ke");
  
  // Tangani perubahan nama kolom dari "Oleh" menjadi "PIC"
  let olehIdx = headers.indexOf("PIC");
  if (olehIdx === -1) olehIdx = headers.indexOf("Oleh");
  
  const ketIdx = headers.indexOf("Keterangan");
  const fotoIdx = headers.indexOf("FotoURL");

  const startDate = startDateStr ? new Date(startDateStr) : null;
  const endDate = endDateStr ? new Date(endDateStr) : null;
  if (endDate) endDate.setHours(23, 59, 59, 999);

  const filteredData = [];
  for (let i = 1; i < data.length; i++) {
    const r = data[i];
    const ts = new Date(r[tsIdx]);
    if (startDate && ts < startDate) continue;
    if (endDate && ts > endDate) continue;
    if (picStr && r[olehIdx] !== picStr) continue;
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
      dari: r[dariIdx],
      ke: r[keIdx],
      oleh: r[olehIdx],
      keterangan: ketIdx !== -1 ? r[ketIdx] : "",
      fotoUrl: r[fotoIdx],
      items: items,
    });
  }
  return result;
}

function prosesPindahStok(body) {
  const dari = body.dari;
  const ke = body.ke;
  const qtyMap = body.qty;
  const oleh = body.oleh || "Tidak diketahui";
  const keterangan = body.keterangan || "";

  if (!dari || !ke || !qtyMap) {
    return {
      success: false,
      message: "Data tidak lengkap: dari, ke, dan qty wajib diisi",
    };
  }
  if (dari === ke) {
    return {
      success: false,
      message: "Lokasi asal dan tujuan tidak boleh sama",
    };
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
      return {
        success: false,
        message: "Semua jumlah jenis barang 0, tidak ada yang dipindahkan",
      };
    }

    let fotoUrl = "";
    if (body.fotoBase64) {
      try {
        fotoUrl = simpanFotoSuratJalan(
          body.fotoBase64,
          body.fotoMimeType || "image/jpeg",
          dari,
          ke,
        );
      } catch (e) {
        return {
          success: false,
          message:
            "Gagal upload foto surat jalan. Transaksi dibatalkan. (" +
            e.message +
            ")",
        };
      }
    }

    let barisDari = -1,
      barisKe = -1;
    for (let i = 1; i < data.length; i++) {
      if (data[i][0] === dari) barisDari = i;
      if (data[i][0] === ke) barisKe = i;
    }

    if (barisDari === -1)
      return {
        success: false,
        message: 'Lokasi asal "' + dari + '" tidak ditemukan',
      };

    if (barisKe === -1) {
      const lokasiSheet =
        SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_LOKASI);
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
        return {
          success: false,
          message:
            "Stok " +
            item.jenis +
            " di " +
            dari +
            " tidak cukup (butuh " +
            item.qty +
            ", sisa " +
            stokDari +
            ")",
        };
      }
    }

    for (const item of itemsDipindah) {
      const stokDariLama = Number(data[barisDari][item.kolomIdx]) || 0;
      stokSheet
        .getRange(barisDari + 1, item.kolomIdx + 1)
        .setValue(stokDariLama - item.qty);

      const stokKeLama = Number(data[barisKe][item.kolomIdx]) || 0;
      stokSheet
        .getRange(barisKe + 1, item.kolomIdx + 1)
        .setValue(stokKeLama + item.qty);
    }
    
    // Update keterangan di Stok
    if (keterangan && barisKe !== -1) {
      const ketIdx = headerStok.indexOf("Keterangan");
      if (ketIdx !== -1) {
        stokSheet.getRange(barisKe + 1, ketIdx + 1).setValue(keterangan);
      }
    }

    const trxSheet = getOrCreateTransaksiSheet();
    const trxData = trxSheet.getDataRange().getValues();
    const trxHeader = trxData[0];

    for (const item of itemsDipindah) {
      if (trxHeader.indexOf(item.jenis) === -1) {
        const picIndex = trxHeader.indexOf("PIC");
        if (picIndex !== -1) {
          trxSheet.insertColumnBefore(picIndex + 1);
          trxSheet.getRange(1, picIndex + 1).setValue(item.jenis);
          trxHeader.splice(picIndex, 0, item.jenis);
        } else {
          trxHeader.push(item.jenis);
          trxSheet.getRange(1, trxHeader.length).setValue(item.jenis);
        }
      }
    }

    const newRowTrx = new Array(trxHeader.length).fill("");
    newRowTrx[trxHeader.indexOf("Timestamp")] = new Date();
    newRowTrx[trxHeader.indexOf("Dari")] = dari;
    newRowTrx[trxHeader.indexOf("Ke")] = ke;
    newRowTrx[trxHeader.indexOf("PIC")] = oleh;
    
    const trxKetIdx = trxHeader.indexOf("Keterangan");
    if (trxKetIdx !== -1) newRowTrx[trxKetIdx] = keterangan;
    
    newRowTrx[trxHeader.indexOf("FotoURL")] = fotoUrl;

    for (const item of itemsDipindah) {
      newRowTrx[trxHeader.indexOf(item.jenis)] = item.qty;
    }

    trxSheet.appendRow(newRowTrx);

    return {
      success: true,
      message: "Stok berhasil dipindah",
      data: { dari, ke, qtyMap, fotoUrl },
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
    sheet.appendRow(["Lokasi", "Keterangan", ...INITIAL_JENIS_FIBER]);
  } else {
    // Migrasi: tambahkan kolom Keterangan jika belum ada
    const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn() || 1).getValues()[0];
    if (!headers.includes("Keterangan")) {
      sheet.insertColumnAfter(1);
      sheet.getRange(1, 2).setValue("Keterangan");
    }
  }
  return sheet;
}

function getOrCreateTransaksiSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(SHEET_TRANSAKSI);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_TRANSAKSI);
    sheet.appendRow([
      "Timestamp",
      "Dari",
      "Ke",
      "PIC",
      "Keterangan",
      "FotoURL",
      ...INITIAL_JENIS_FIBER,
    ]);
  } else {
    // Migrasi: Tambahkan kolom Keterangan di sebelah kanan PIC
    const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn() || 1).getValues()[0];
    if (!headers.includes("Keterangan")) {
      let picIdx = headers.indexOf("PIC");
      if (picIdx === -1) picIdx = headers.indexOf("Oleh");
      if (picIdx !== -1) {
        sheet.insertColumnAfter(picIdx + 1);
        sheet.getRange(1, picIdx + 2).setValue("Keterangan");
      }
    }
  }
  return sheet;
}

function simpanFotoSuratJalan(base64Data, mimeType, dari, ke) {
  const folder = DriveApp.getFolderById(FOLDER_FOTO_ID);
  const bytes = Utilities.base64Decode(base64Data);
  const ext = mimeType.split("/")[1] || "jpg";
  const fileName =
    "SJ_" + dari + "_ke_" + ke + "_" + new Date().getTime() + "." + ext;
  const blob = Utilities.newBlob(bytes, mimeType, fileName);
  const file = folder.createFile(blob);
  try {
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
  } catch (e) {
    // Abaikan error jika aturan Workspace (kantor) melarang akses publik
  }
  return "https://drive.google.com/uc?id=" + file.getId();
}

function jsonResponse(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(
    ContentService.MimeType.JSON,
  );
}

// ============================================
// FUNGSI WRAPPER UNTUK WEB (google.script.run)
// ============================================

// Fungsi ini dipanggil dari Index.html tanpa perlu API_KEY (karena dijalankan dalam sesi user)
function webGetStok() {
  return getStok();
}

function webGetRiwayat(limit, startDate, endDate, pic) {
  const riwayat = getRiwayat(limit, startDate, endDate, pic);
  // Konversi object Date ke String agar google.script.run tidak gagal serialize (mengembalikan null)
  // rowIndex = nomor baris aktual di sheet Transaksi (untuk keperluan batalkan transaksi)
  const trxSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_TRANSAKSI);
  const lastRow = trxSheet ? trxSheet.getLastRow() : 0;

  return riwayat.map((r, i) => {
    return {
      timestamp: r.timestamp && r.timestamp.toISOString ? r.timestamp.toISOString() : r.timestamp,
      dari: r.dari,
      ke: r.ke,
      oleh: r.oleh || "-",
      keterangan: r.keterangan || "",
      fotoUrl: r.fotoUrl,
      items: r.items,
      // rowIndex untuk batalkan: karena getRiwayat me-reverse urutan, kalkulasi rowIndex dari belakang
      rowIndex: lastRow - i,
    };
  });
}

function webGetAdmin() {
  return getAdmin();
}

function webProsesPindahStok(dari, ke, qty, oleh, keterangan, fotoBase64, fotoMimeType) {
  // Kita bypass pengecekan apiKey di backend karena akses web sudah dilindungi oleh autentikasi Google akun yang mengakses Web App ini.
  return prosesPindahStok({
    dari: dari,
    ke: ke,
    qty: qty,
    oleh: oleh,
    keterangan: keterangan,
    fotoBase64: fotoBase64,
    fotoMimeType: fotoMimeType,
  });
}

function webLogin(username, password) {
  const admins = getAdmin();
  const user = admins.find(
    (a) => a.username === username && a.password === password,
  );
  if (user) {
    return {
      success: true,
      data: { username: user.username, role: user.role },
    };
  } else {
    return { success: false, message: "Username atau password salah" };
  }
}

// ============================================
// FUNGSI SUPERADMIN
// ============================================

function webTambahAdmin(username, password, role) {
  if (!username || !password) {
    return { success: false, message: "Username dan password wajib diisi" };
  }
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(SHEET_ADMIN);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_ADMIN);
    sheet.appendRow(["Username", "Password", "Role"]);
    sheet.getRange("A1:C1").setFontWeight("bold");
  }
  // Cek apakah username sudah ada
  const existing = getAdmin().find((a) => a.username.toLowerCase() === username.toLowerCase());
  if (existing) {
    return { success: false, message: "Username \"" + username + "\" sudah ada" };
  }
  sheet.appendRow([username.trim(), password.trim(), (role || "admin").toLowerCase()]);
  return { success: true, message: "Admin \"" + username + "\" berhasil ditambahkan" };
}

function webEditAdmin(username, newPassword, newRole) {
  if (!username) return { success: false, message: "Username wajib diisi" };
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_ADMIN);
  if (!sheet) return { success: false, message: "Sheet Admin tidak ditemukan" };

  const data = sheet.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (data[i][0].toString().toLowerCase() === username.toLowerCase()) {
      if (newPassword) sheet.getRange(i + 1, 2).setValue(newPassword.trim());
      if (newRole) sheet.getRange(i + 1, 3).setValue(newRole.toLowerCase());
      return { success: true, message: "Admin \"" + username + "\" berhasil diperbarui" };
    }
  }
  return { success: false, message: "Username \"" + username + "\" tidak ditemukan" };
}

function webHapusAdmin(username) {
  if (!username) return { success: false, message: "Username wajib diisi" };
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(SHEET_ADMIN);
  if (!sheet) return { success: false, message: "Sheet Admin tidak ditemukan" };

  const data = sheet.getDataRange().getValues();
  for (let i = 1; i < data.length; i++) {
    if (data[i][0].toString().toLowerCase() === username.toLowerCase()) {
      sheet.deleteRow(i + 1);
      return { success: true, message: "Admin \"" + username + "\" berhasil dihapus" };
    }
  }
  return { success: false, message: "Username \"" + username + "\" tidak ditemukan" };
}

function webKoreksiStok(lokasi, jenis, jumlahBaru) {
  if (!lokasi || !jenis || jumlahBaru === undefined || jumlahBaru === null) {
    return { success: false, message: "Lokasi, jenis, dan jumlah wajib diisi" };
  }
  const jumlah = Number(jumlahBaru);
  if (isNaN(jumlah) || jumlah < 0) {
    return { success: false, message: "Jumlah harus berupa angka positif" };
  }

  const lock = LockService.getScriptLock();
  lock.waitLock(15000);
  try {
    const stokSheet = getOrCreateStokSheet();
    const data = stokSheet.getDataRange().getValues();
    const headers = data[0];

    let lokasiRow = -1;
    for (let i = 1; i < data.length; i++) {
      if (data[i][0] === lokasi) { lokasiRow = i; break; }
    }
    if (lokasiRow === -1) return { success: false, message: "Lokasi \"" + lokasi + "\" tidak ditemukan" };

    let jenisCol = headers.indexOf(jenis);
    if (jenisCol === -1) {
      jenisCol = headers.length;
      stokSheet.getRange(1, jenisCol + 1).setValue(jenis);
    }

    const jumlahLama = Number(data[lokasiRow][jenisCol]) || 0;
    stokSheet.getRange(lokasiRow + 1, jenisCol + 1).setValue(jumlah);

    return { success: true, message: "Stok " + jenis + " di " + lokasi + " diubah dari " + jumlahLama + " menjadi " + jumlah };
  } finally {
    lock.releaseLock();
  }
}

function webBatalkanTransaksi(rowIndex) {
  // rowIndex = nomor baris di sheet Transaksi (1-based, termasuk header)
  if (!rowIndex || rowIndex < 2) return { success: false, message: "Index baris tidak valid" };

  const lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    const trxSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(SHEET_TRANSAKSI);
    if (!trxSheet) return { success: false, message: "Sheet Transaksi tidak ditemukan" };

    const data = trxSheet.getDataRange().getValues();
    if (rowIndex > data.length) return { success: false, message: "Baris tidak ditemukan" };

    const headers = data[0];
    const row = data[rowIndex - 1]; // Convert 1-based ke 0-based

    const dariIdx = headers.indexOf("Dari");
    const keIdx = headers.indexOf("Ke");

    const dari = row[dariIdx];
    const ke = row[keIdx];

    // Kembalikan stok: dari += qty, ke -= qty
    const stokSheet = getOrCreateStokSheet();
    const stokData = stokSheet.getDataRange().getValues();
    const stokHeaders = stokData[0];

    let barisDari = -1, barisKe = -1;
    for (let i = 1; i < stokData.length; i++) {
      if (stokData[i][0] === dari) barisDari = i;
      if (stokData[i][0] === ke) barisKe = i;
    }

    // Kembalikan setiap item
    for (let c = 0; c < headers.length; c++) {
      const colName = headers[c];
      if (FIXED_TRX_COLS.includes(colName) || !colName) continue;
      const qty = Number(row[c]) || 0;
      if (qty === 0) continue;

      const stokColIdx = stokHeaders.indexOf(colName);
      if (stokColIdx === -1) continue;

      if (barisDari !== -1) {
        const stokDariNow = Number(stokData[barisDari][stokColIdx]) || 0;
        stokSheet.getRange(barisDari + 1, stokColIdx + 1).setValue(stokDariNow + qty);
      }
      if (barisKe !== -1) {
        const stokKeNow = Number(stokData[barisKe][stokColIdx]) || 0;
        stokSheet.getRange(barisKe + 1, stokColIdx + 1).setValue(Math.max(0, stokKeNow - qty));
      }
    }

    // Update keterangan di Stok
    if (keterangan && barisKe !== -1) {
      const ketIdx = stokHeaders.indexOf("Keterangan");
      if (ketIdx !== -1) {
        stokSheet.getRange(barisKe + 1, ketIdx + 1).setValue(keterangan);
      }
    }

    // Hapus baris transaksi
    trxSheet.deleteRow(rowIndex);

    return { success: true, message: "Transaksi berhasil dibatalkan dan stok dikembalikan" };
  } finally {
    lock.releaseLock();
  }
}
