import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:catatan_keuangan/data.dart';
import 'package:catatan_keuangan/import_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Reads binary XLS disguised as CSV, ignores summary and footer', () {
    final entries = parseReport(
        File('test/fixtures/report_disguised.csv').readAsBytesSync());
    expect(entries.length, 2);
    expect(total(entries, true), 61000);
    expect(total(entries, false), 8500);
    expect(entries.first.category, 'Pendidikan');
    expect(entries.first.date, DateTime(2026, 10, 16));
  });

  test('Reads UTF-8 CSV, quoted fields and Indonesian currency', () {
    final bytes = Uint8List.fromList(utf8.encode(
        'Tanggal;Keterangan;Pengeluaran;Pemasukan;Kategori\r\n'
        '16/10/2026;"Buku; pensil";Rp8.500;;Pendidikan\r\n'));
    final entry = parseReport(bytes).single;
    expect(entry.note, 'Buku; pensil');
    expect(entry.amount, 8500);
  });

  test('Rejects invalid dates and ambiguous amounts rather than skipping them', () {
    for (final row in [
      ['31/02/2026', 'Buku', 'Rp1.000', '', 'Pendidikan'],
      ['01/02/2026', 'Buku', 'Rp1.000', 'Rp2.000', 'Pendidikan'],
      ['01/02/2026', 'Buku', 'Rp1,50', '', 'Pendidikan'],
    ]) {
      expect(() => parseReportRows([
        ['Tanggal', 'Keterangan', 'Pengeluaran', 'Pemasukan', 'Kategori'],
        row,
      ]), throwsFormatException);
    }
  });
}
