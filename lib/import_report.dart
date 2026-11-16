import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel2003/excel2003.dart';

import 'data.dart';

/// Detects the actual content, including XLS files incorrectly named CSV.
List<Entry> parseReport(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
    throw const FormatException('File kosong atau melebihi 10 MB.');
  }
  List<List<dynamic>> rows;
  if (bytes.length >= 8 &&
      bytes.take(8).join(',') == '208,207,17,224,161,177,26,225') {
    final book = XlsReader.fromBytes(bytes);
    if (book.sheetCount != 1) {
      throw const FormatException('Gunakan laporan dengan satu lembar kerja.');
    }
    rows = book.sheet(0).rows;
  } else {
    final text = utf8.decode(bytes).replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final header = text.split('\n').firstWhere(
        (line) => line.contains('Tanggal') && line.contains('Kategori'),
        orElse: () => '');
    final separator = header.contains('\t') ? '\t' : header.contains(';') ? ';' : ',';
    rows = CsvToListConverter(fieldDelimiter: separator, eol: '\n',
        shouldParseNumbers: false, allowInvalid: false).convert(text);
  }
  return parseReportRows(rows);
}

List<Entry> parseReportRows(List<List<dynamic>> rows) {
  const required = ['Tanggal', 'Keterangan', 'Pengeluaran', 'Pemasukan', 'Kategori'];
  final headerIndex = rows.indexWhere((row) =>
      required.every((name) => row.any((cell) => cell?.toString().trim() == name)));
  if (headerIndex < 0) {
    throw const FormatException(
        'Kolom wajib: Tanggal, Keterangan, Pengeluaran, Pemasukan, Kategori.');
  }
  final header = rows[headerIndex].map((v) => v?.toString().trim() ?? '').toList();
  final result = <Entry>[];
  for (var i = headerIndex + 1; i < rows.length; i++) {
    final row = rows[i];
    String value(String name) {
      final index = header.indexOf(name);
      return index < row.length ? row[index]?.toString().trim() ?? '' : '';
    }
    final rawDate = value('Tanggal');
    final outgoing = value('Pengeluaran');
    final incoming = value('Pemasukan');
    if (rawDate.isEmpty && outgoing.isEmpty && incoming.isEmpty) continue;
    try {
      final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(rawDate);
      if (match == null) throw const FormatException('Tanggal harus DD/MM/YYYY.');
      final day = int.parse(match[1]!);
      final month = int.parse(match[2]!);
      final year = int.parse(match[3]!);
      final date = DateTime(year, month, day);
      if (date.day != day || date.month != month || year < 2000 || year > 2100) {
        throw const FormatException('Tanggal tidak valid.');
      }
      final expense = _money(outgoing);
      final income = _money(incoming);
      if ((expense > 0) == (income > 0)) {
        throw const FormatException('Isi tepat satu nominal pemasukan atau pengeluaran.');
      }
      final category = value('Kategori').replaceAll(RegExp(r'\s+'), ' ');
      if (category.isEmpty || category.length > 40) {
        throw const FormatException('Nama kategori harus 1–40 karakter.');
      }
      final note = value('Keterangan');
      if (note.length > 120) {
        throw const FormatException('Keterangan melebihi 120 karakter.');
      }
      result.add(Entry(amount: income > 0 ? income : expense, income: income > 0,
          date: date, category: category, note: note));
    } on FormatException catch (error) {
      throw FormatException('Baris ${i + 1}: ${error.message}');
    }
  }
  if (result.isEmpty) throw const FormatException('Tidak ada transaksi dalam laporan.');
  return result;
}

int _money(String input) {
  final value = input.replaceAll(RegExp(r'rp', caseSensitive: false), '').replaceAll(' ', '');
  if (value.isEmpty || value == '-') return 0;
  if (!RegExp(r'^(?:\d+|\d{1,3}(?:\.\d{3})+)(?:,00)?$').hasMatch(value)) {
    throw const FormatException('Nominal Rupiah tidak valid.');
  }
  final amount = int.parse(value.replaceAll('.', '').replaceAll(',00', ''));
  if (amount > 999999999999) throw const FormatException('Nominal terlalu besar.');
  return amount;
}
