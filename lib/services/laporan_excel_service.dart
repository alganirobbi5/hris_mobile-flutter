import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/api_config.dart';

class LaporanExcelException implements Exception {
  const LaporanExcelException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LaporanAbsensiRow {
  const LaporanAbsensiRow({
    required this.id,
    required this.tanggal,
    required this.jamMasuk,
    required this.jamKeluar,
    required this.nama,
    this.fotoUrl = '',
    this.alamat = '',
    this.latitude = '',
    this.longitude = '',
  });

  factory LaporanAbsensiRow.fromJson(Map<String, dynamic> json) {
    final String firstName = (json['first_name'] ?? '').toString().trim();
    final String lastName = (json['last_name'] ?? '').toString().trim();
    final String nama = '$firstName $lastName'.trim();

    return LaporanAbsensiRow(
      id: int.tryParse((json['id'] ?? '').toString()) ?? 0,
      tanggal: (json['date'] ?? '').toString(),
      jamMasuk: (json['clock_in'] ?? '').toString(),
      jamKeluar: (json['clock_out'] ?? '').toString(),
      nama: nama.isEmpty ? 'Tanpa Nama' : nama,
      // Field opsional: otomatis dipakai kalau backend mulai mengirimnya.
      fotoUrl: (json['foto_url'] ?? json['foto'] ?? '').toString(),
      alamat: (json['alamat'] ?? '').toString(),
      latitude: (json['latitude'] ?? '').toString(),
      longitude: (json['longitude'] ?? '').toString(),
    );
  }

  final int id;
  final String tanggal;
  final String jamMasuk;
  final String jamKeluar;
  final String nama;
  final String fotoUrl;
  final String alamat;
  final String latitude;
  final String longitude;

  DateTime? get tanggalDate => DateTime.tryParse(tanggal);

  String get hari {
    final DateTime? date = tanggalDate;
    if (date == null) return '-';
    const List<String> namaHari = <String>[
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return namaHari[date.weekday - 1];
  }

  String get tanggalTampil {
    final DateTime? date = tanggalDate;
    if (date == null) return tanggal.isEmpty ? '-' : tanggal;
    return '${_duaDigit(date.day)}/${_duaDigit(date.month)}/${date.year}';
  }

  String get jamMasukTampil => _jam(jamMasuk);

  String get jamKeluarTampil => _jam(jamKeluar);

  bool get terlambat {
    final String masuk = jamMasuk.trim();
    if (masuk.isEmpty || masuk.startsWith('00:00:00')) return false;
    return masuk.compareTo('08:00:00') > 0;
  }

  String get statusTampil {
    final String masuk = jamMasuk.trim();
    if (masuk.isEmpty || masuk.startsWith('00:00:00')) return '-';
    return terlambat ? 'Terlambat' : 'Tepat Waktu';
  }

  String get koordinatTampil {
    final String lat = latitude.trim();
    final String lng = longitude.trim();
    if (lat.isEmpty || lng.isEmpty) return '-';
    return '$lat, $lng';
  }

  String get alamatTampil {
    final String value = alamat.trim();
    return value.isEmpty ? '-' : value;
  }

  String get fotoTampil => fotoUrl.trim().isEmpty ? '-' : 'Lihat Foto';

  static String _jam(String raw) {
    final String value = raw.trim();
    if (value.isEmpty || value.startsWith('00:00:00')) return '-';
    final List<String> parts = value.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return value;
  }

  static String _duaDigit(int value) => value.toString().padLeft(2, '0');
}

class LaporanExcelService {
  LaporanExcelService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _endpoint = 'laporan_absensi.php';
  static const String _companyName = 'PT Contoh Maju Sejahtera';
  static const String _sheetName = 'Laporan Absensi';
  static const String _excelMime =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  Future<List<LaporanAbsensiRow>> fetchRows() async {
    final http.Response response;
    try {
      response = await _client
          .get(ApiConfig.uri(_endpoint))
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const LaporanExcelException(
        'Gagal terhubung ke server. Periksa koneksi internet.',
      );
    }

    if (response.statusCode != 200) {
      throw LaporanExcelException(
        'Server mengembalikan kode ${response.statusCode}.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const LaporanExcelException('Format data laporan tidak valid.');
    }

    if (decoded is! Map<String, dynamic> || decoded['data'] is! List) {
      throw const LaporanExcelException('Data laporan tidak ditemukan.');
    }

    final List<dynamic> data = decoded['data'] as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map(LaporanAbsensiRow.fromJson)
        .toList();
  }

  /// Membuat file Excel lalu membuka share sheet agar user bisa
  /// menyimpan/mengirim file ke perangkat lain.
  Future<void> exportAndShare() async {
    final List<LaporanAbsensiRow> rows = await fetchRows();
    if (rows.isEmpty) {
      throw const LaporanExcelException('Belum ada data absensi untuk diekspor.');
    }

    final List<int> bytes = buildWorkbookBytes(rows);

    final Directory dir = await getTemporaryDirectory();
    final String tanggalFile = _tanggalFile(DateTime.now());
    final File file = File('${dir.path}/Laporan_Absensi_$tanggalFile.xlsx');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path, mimeType: _excelMime)],
        subject: 'Laporan Absensi',
        text: 'Laporan absensi $tanggalFile',
      ),
    );
  }

  List<int> buildWorkbookBytes(List<LaporanAbsensiRow> rows) {
    final Excel excel = Excel.createExcel();
    final Sheet sheet = excel[_sheetName];
    excel.setDefaultSheet(_sheetName);
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    _setColumnWidths(sheet);

    // Palet warna.
    final ExcelColor headerBg = ExcelColor.fromHexString('FF5B4CFF');
    final ExcelColor titleBg = ExcelColor.fromHexString('FF4436D6');
    final ExcelColor softBg = ExcelColor.fromHexString('FFEEF0FF');
    final ExcelColor zebraBg = ExcelColor.fromHexString('FFF6F7FB');
    final ExcelColor borderColor = ExcelColor.fromHexString('FFD1D5DB');
    final ExcelColor textDark = ExcelColor.fromHexString('FF1B1B2F');
    final ExcelColor textMuted = ExcelColor.fromHexString('FF7A7A9D');
    final ExcelColor greenText = ExcelColor.fromHexString('FF1BA97F');
    final ExcelColor greenBg = ExcelColor.fromHexString('FFE6F7F1');
    final ExcelColor redText = ExcelColor.fromHexString('FFE5484D');
    final ExcelColor redBg = ExcelColor.fromHexString('FFFDECEC');
    final ExcelColor linkColor = ExcelColor.fromHexString('FF2563EB');

    final Border border = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: borderColor,
    );

    // Layout baris.
    const int titleRow = 0;
    const int companyRow = 1;
    const int periodRow = 2;
    const int printedRow = 3;
    const int spacerRow = 4;
    const int headerRow = 5;
    final int dataStartRow = headerRow + 1;
    final int dataEndRow = dataStartRow + rows.length - 1;

    final DateTime now = DateTime.now();
    final String period = _periode(rows);

    // Judul.
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: titleRow),
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: titleRow),
      customValue: TextCellValue('LAPORAN ABSENSI KARYAWAN'),
    );
    _styleRange(
      sheet,
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: titleRow),
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: titleRow),
      CellStyle(
        bold: true,
        fontSize: 18,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: titleBg,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      ),
    );

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: companyRow),
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: companyRow),
      customValue: TextCellValue(_companyName.toUpperCase()),
    );
    _styleRange(
      sheet,
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: companyRow),
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: companyRow),
      CellStyle(
        bold: true,
        fontSize: 12,
        fontColorHex: textDark,
        backgroundColorHex: softBg,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      ),
    );

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: periodRow),
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: periodRow),
      customValue: TextCellValue('Periode: $period'),
    );
    _styleRange(
      sheet,
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: periodRow),
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: periodRow),
      CellStyle(
        fontSize: 10,
        fontColorHex: textMuted,
        backgroundColorHex: softBg,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      ),
    );

    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: printedRow),
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: printedRow),
      customValue: TextCellValue(
        'Dicetak: ${_duaDigit(now.day)}/${_duaDigit(now.month)}/${now.year} '
        '${_duaDigit(now.hour)}:${_duaDigit(now.minute)} WIB',
      ),
    );
    _styleRange(
      sheet,
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: printedRow),
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: printedRow),
      CellStyle(
        fontSize: 9,
        fontColorHex: textMuted,
        backgroundColorHex: softBg,
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
      ),
    );

    sheet.setRowHeight(titleRow, 36);
    sheet.setRowHeight(companyRow, 24);
    sheet.setRowHeight(periodRow, 20);
    sheet.setRowHeight(printedRow, 20);
    sheet.setRowHeight(spacerRow, 8);
    sheet.setRowHeight(headerRow, 30);

    // Header tabel.
    const List<String> headers = <String>[
      'No',
      'Tanggal',
      'Hari',
      'Nama Karyawan',
      'Jam Masuk',
      'Jam Keluar',
      'Status',
      'Foto',
      'Alamat',
      'Koordinat',
    ];
    final CellStyle headerStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: headerBg,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: border,
      rightBorder: border,
      topBorder: border,
      bottomBorder: border,
    );

    for (int col = 0; col < headers.length; col++) {
      _setCell(
        sheet,
        row: headerRow,
        column: col,
        value: TextCellValue(headers[col]),
        style: headerStyle,
      );
    }

    final CellStyle baseStyle = CellStyle(
      fontSize: 10,
      fontColorHex: textDark,
      verticalAlign: VerticalAlign.Center,
      leftBorder: border,
      rightBorder: border,
      topBorder: border,
      bottomBorder: border,
    );
    final CellStyle centeredStyle = baseStyle.copyWith(
      horizontalAlignVal: HorizontalAlign.Center,
      verticalAlignVal: VerticalAlign.Center,
    );
    final CellStyle leftStyle = baseStyle.copyWith(
      horizontalAlignVal: HorizontalAlign.Left,
      textWrappingVal: TextWrapping.WrapText,
    );

    int tepatWaktu = 0;
    int terlambat = 0;

    for (int i = 0; i < rows.length; i++) {
      final LaporanAbsensiRow row = rows[i];
      final int excelRow = dataStartRow + i;
      final bool zebra = i.isOdd;
      final ExcelColor? rowBg = zebra ? zebraBg : null;

      if (row.statusTampil == 'Terlambat') {
        terlambat++;
      } else if (row.statusTampil == 'Tepat Waktu') {
        tepatWaktu++;
      }

      CellStyle rowStyle(CellStyle style) {
        return rowBg == null
            ? style
            : style.copyWith(backgroundColorHexVal: rowBg);
      }

      sheet.setRowHeight(excelRow, 22);

      _setCell(
        sheet,
        row: excelRow,
        column: 0,
        value: IntCellValue(i + 1),
        style: rowStyle(centeredStyle),
      );
      _setCell(
        sheet,
        row: excelRow,
        column: 1,
        value: TextCellValue(row.tanggalTampil),
        style: rowStyle(centeredStyle),
      );
      _setCell(
        sheet,
        row: excelRow,
        column: 2,
        value: TextCellValue(row.hari),
        style: rowStyle(centeredStyle),
      );
      _setCell(
        sheet,
        row: excelRow,
        column: 3,
        value: TextCellValue(row.nama),
        style: rowStyle(leftStyle),
      );
      _setCell(
        sheet,
        row: excelRow,
        column: 4,
        value: TextCellValue(row.jamMasukTampil),
        style: rowStyle(centeredStyle),
      );
      _setCell(
        sheet,
        row: excelRow,
        column: 5,
        value: TextCellValue(row.jamKeluarTampil),
        style: rowStyle(centeredStyle),
      );

      final String status = row.statusTampil;
      final CellStyle statusStyle = rowStyle(
        centeredStyle.copyWith(
          boldVal: status != '-',
          fontColorHexVal: status == 'Terlambat'
              ? redText
              : status == 'Tepat Waktu'
                  ? greenText
                  : textMuted,
          backgroundColorHexVal: status == 'Terlambat'
              ? redBg
              : status == 'Tepat Waktu'
                  ? greenBg
                  : rowBg,
        ),
      );
      _setCell(
        sheet,
        row: excelRow,
        column: 6,
        value: TextCellValue(status),
        style: statusStyle,
      );

      if (row.fotoUrl.trim().isEmpty) {
        _setCell(
          sheet,
          row: excelRow,
          column: 7,
          value: TextCellValue('-'),
          style: rowStyle(centeredStyle),
        );
      } else {
        _setCell(
          sheet,
          row: excelRow,
          column: 7,
          value: FormulaCellValue(
            'HYPERLINK("${_escapeFormula(row.fotoUrl.trim())}","Lihat Foto")',
          ),
          style: rowStyle(
            centeredStyle.copyWith(
              fontColorHexVal: linkColor,
              underlineVal: Underline.Single,
            ),
          ),
        );
      }

      _setCell(
        sheet,
        row: excelRow,
        column: 8,
        value: TextCellValue(row.alamatTampil),
        style: rowStyle(leftStyle),
      );
      _setCell(
        sheet,
        row: excelRow,
        column: 9,
        value: TextCellValue(row.koordinatTampil),
        style: rowStyle(centeredStyle),
      );
    }

    // Ringkasan.
    final int summaryRow = dataEndRow + 2;
    final CellIndex summaryStart = CellIndex.indexByColumnRow(
      columnIndex: 0,
      rowIndex: summaryRow,
    );
    sheet.merge(
      summaryStart,
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: summaryRow),
      customValue: TextCellValue(
        'Total: ${rows.length} data   |   Tepat Waktu: $tepatWaktu   |   '
        'Terlambat: $terlambat',
      ),
    );
    _styleRange(
      sheet,
      summaryStart,
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: summaryRow),
      CellStyle(
        bold: true,
        fontSize: 10,
        fontColorHex: textDark,
        backgroundColorHex: softBg,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      ),
    );
    sheet.setRowHeight(summaryRow, 24);

    final int noteRow = summaryRow + 1;
    final CellIndex noteStart = CellIndex.indexByColumnRow(
      columnIndex: 0,
      rowIndex: noteRow,
    );
    sheet.merge(
      noteStart,
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: noteRow),
      customValue: TextCellValue(
        'Laporan ini dibuat otomatis oleh HRIS Mobile.',
      ),
    );
    _styleRange(
      sheet,
      noteStart,
      CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: noteRow),
      CellStyle(
        fontSize: 9,
        italic: true,
        fontColorHex: textMuted,
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      ),
    );

    final List<int>? bytes = excel.encode();
    if (bytes == null) {
      throw const LaporanExcelException('Gagal membuat file Excel.');
    }
    return bytes;
  }

  void _setColumnWidths(Sheet sheet) {
    const List<double> widths = <double>[
      6,
      14,
      12,
      26,
      12,
      12,
      16,
      14,
      30,
      22,
    ];
    for (int i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
  }

  // `setMergedCellStyle` hanya menerapkan style saat ada border, sehingga
  // judul/info tanpa border harus diwarnai manual di seluruh rentang merge.
  void _styleRange(
    Sheet sheet,
    CellIndex start,
    CellIndex end,
    CellStyle style,
  ) {
    for (int row = start.rowIndex; row <= end.rowIndex; row++) {
      for (int column = start.columnIndex; column <= end.columnIndex; column++) {
        sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: column,
                rowIndex: row,
              ),
            )
            .cellStyle = style;
      }
    }
  }

  void _setCell(
    Sheet sheet, {
    required int row,
    required int column,
    required CellValue value,
    CellStyle? style,
  }) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row),
      value,
      cellStyle: style,
    );
  }

  String _periode(List<LaporanAbsensiRow> rows) {
    DateTime? min;
    DateTime? max;
    for (final LaporanAbsensiRow row in rows) {
      final DateTime? date = row.tanggalDate;
      if (date == null) continue;
      if (min == null || date.isBefore(min)) min = date;
      if (max == null || date.isAfter(max)) max = date;
    }
    if (min == null || max == null) return '-';
    final String awal = '${_duaDigit(min.day)}/${_duaDigit(min.month)}/${min.year}';
    final String akhir = '${_duaDigit(max.day)}/${_duaDigit(max.month)}/${max.year}';
    return awal == akhir ? awal : '$awal s/d $akhir';
  }

  String _tanggalFile(DateTime date) =>
      '${date.year}${_duaDigit(date.month)}${_duaDigit(date.day)}';

  String _escapeFormula(String value) => value.replaceAll('"', '""');

  String _duaDigit(int value) => value.toString().padLeft(2, '0');
}
