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
}
