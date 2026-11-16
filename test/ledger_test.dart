import 'dart:io';

import 'package:catatan_keuangan/data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late Ledger ledger;

  setUp(() => ledger = Ledger(databasePath: inMemoryDatabasePath));
  tearDown(() => ledger.close());

  test('SQLite persists, updates, and deletes transactions without duplication', () async {
    await ledger.save(Entry(amount: 350000, income: true,
        date: DateTime(2026, 11, 16), category: 'Freelance', note: 'Jasa desain'));
    final first = (await ledger.read()).single;
    expect(first.id, isNotNull);
    expect(first.amount, 350000);
    await ledger.save(Entry(id: first.id, amount: 25000, income: false,
        date: first.date, category: 'Makanan', note: 'Makan siang'));
    final updated = (await ledger.read()).single;
    expect(updated.income, false);
    expect(updated.amount, 25000);
    await ledger.delete(updated.id!);
    expect(await ledger.read(), isEmpty);
  });

  test('Monthly totals isolate year boundaries and transaction types', () {
    final entries = [
      Entry(amount: 100000, income: true, date: DateTime(2026, 12, 31),
          category: 'Jualan', note: ''),
      Entry(amount: 30000, income: false, date: DateTime(2026, 12, 31),
          category: 'Makanan', note: ''),
      Entry(amount: 50000, income: true, date: DateTime(2027, 1, 1),
          category: 'Jualan', note: ''),
    ];
    final december = inMonth(entries, DateTime(2026, 12));
    expect(total(december, true) - total(december, false), 70000);
    expect(total(inMonth(entries, DateTime(2027, 1)), true), 50000);
  });

  test('Rejects invalid amounts before writing', () async {
    await expectLater(ledger.save(Entry(amount: 0, income: true,
        date: DateTime.now(), category: 'Jualan', note: '')),
        throwsArgumentError);
    expect(await ledger.read(), isEmpty);
  });

  test('Creates custom categories and prevents duplicates', () async {
    expect(await ledger.addCategory('Pendidikan', false), 'Pendidikan');
    expect(await ledger.categories(false), contains('Pendidikan'));
    await expectLater(ledger.addCategory(' pendidikan ', false),
        throwsArgumentError);
    await ledger.save(Entry(amount: 100000, income: false,
        date: DateTime.now(), category: 'Pendidikan', note: 'Buku'));
    expect((await ledger.read()).single.category, 'Pendidikan');
  });

  test('Import is atomic, creates categories, and rejects repeated files', () async {
    final entry = Entry(amount: 8500, income: false,
        date: DateTime(2026, 10, 16), category: 'Pendidikan', note: 'Buku');
    await ledger.importEntries([entry, entry], 'first-file');
    expect((await ledger.read()).length, 2);
    expect(await ledger.categories(false), contains('Pendidikan'));
    await expectLater(ledger.importEntries([entry], 'first-file'),
        throwsFormatException);
    expect((await ledger.read()).length, 2);
    final invalid = Entry(amount: 0, income: false, date: entry.date,
        category: 'Invalid', note: '');
    await expectLater(ledger.importEntries([entry, invalid], 'second-file'),
        throwsFormatException);
    expect((await ledger.read()).length, 2);
    await ledger.importEntries([entry], 'second-file');
    expect((await ledger.read()).length, 3);
  });

  test('Version 2 upgrade preserves existing transactions and categories', () async {
    final folder = await Directory.systemTemp.createTemp('ledger_migration_');
    final path = '${folder.path}/ledger.db';
    final old = await openDatabase(path, version: 2, onCreate: (db, _) async {
      await db.execute('CREATE TABLE entries (id INTEGER PRIMARY KEY, amount INTEGER, '
          'income INTEGER, date TEXT, category TEXT, note TEXT)');
      await db.execute('CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT, '
          'name_key TEXT, income INTEGER, UNIQUE(name_key, income))');
      await db.insert('categories', {
        'name': 'Gaji', 'name_key': 'gaji', 'income': 1,
      });
      await db.insert('entries', Entry(amount: 10000, income: true,
          date: DateTime(2026, 10, 1), category: 'Gaji', note: 'Lama').toMap());
    });
    await old.close();
    final upgraded = Ledger(databasePath: path);
    try {
      expect((await upgraded.read()).single.note, 'Lama');
      expect(await upgraded.categories(true), ['Gaji']);
      await upgraded.importEntries([
        Entry(amount: 20000, income: true, date: DateTime(2026, 11, 1),
            category: 'Gaji', note: 'Impor'),
      ], 'new-file');
      expect((await upgraded.read()).length, 2);
    } finally {
      await upgraded.close();
      await folder.delete(recursive: true);
    }
  });
}
