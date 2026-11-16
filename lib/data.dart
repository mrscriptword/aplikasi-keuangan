import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const incomeCategories = ['Freelance', 'Jualan', 'Uang saku', 'Lainnya'];
const expenseCategories = [
  'Makanan', 'Tagihan', 'Transportasi', 'Hiburan', 'Lainnya',
];

class Entry {
  const Entry({
    this.id,
    required this.amount,
    required this.income,
    required this.date,
    required this.category,
    required this.note,
  });

  final int? id;
  final int amount;
  final bool income;
  final DateTime date;
  final String category;
  final String note;
  String get title => note.isEmpty ? category : note;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'amount': amount,
    'income': income ? 1 : 0,
    'date': date.toIso8601String(),
    'category': category,
    'note': note,
  };

  factory Entry.fromMap(Map<String, Object?> map) => Entry(
    id: map['id'] as int,
    amount: map['amount'] as int,
    income: map['income'] == 1,
    date: DateTime.parse(map['date'] as String),
    category: map['category'] as String,
    note: map['note'] as String,
  );
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<Entry> inMonth(Iterable<Entry> entries, DateTime month) => entries
    .where((e) => e.date.year == month.year && e.date.month == month.month)
    .toList();

int total(Iterable<Entry> entries, bool income) => entries
    .where((e) => e.income == income)
    .fold(0, (sum, e) => sum + e.amount);

class Ledger {
  Ledger({this.databasePath});
  final String? databasePath;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final location = databasePath ??
        p.join(await getDatabasesPath(), 'catatan_keuangan.db');
    _database = await openDatabase(location, version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount INTEGER NOT NULL CHECK(amount > 0),
            income INTEGER NOT NULL CHECK(income IN (0, 1)),
            date TEXT NOT NULL,
            category TEXT NOT NULL,
            note TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX entries_date ON entries(date)');
        await _createCategories(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createCategories(db);
      },
    );
    return _database!;
  }

  Future<void> _createCategories(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        name_key TEXT NOT NULL,
        income INTEGER NOT NULL CHECK(income IN (0, 1)),
        UNIQUE(name_key, income)
      )
    ''');
    for (final income in [true, false]) {
      for (final name in income ? incomeCategories : expenseCategories) {
        await db.insert('categories', {
          'name': name, 'name_key': name.toLowerCase(), 'income': income ? 1 : 0,
        });
      }
    }
  }

  Future<List<String>> categories(bool income) async {
    final rows = await (await database).query('categories',
        where: 'income = ?', whereArgs: [income ? 1 : 0], orderBy: 'id ASC');
    return rows.map((row) => row['name'] as String).toList();
  }

  Future<String> addCategory(String value, bool income) async {
    final name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty || name.length > 40) {
      throw ArgumentError('Nama kategori harus berisi 1–40 karakter.');
    }
    final db = await database;
    try {
      await db.insert('categories', {
        'name': name, 'name_key': name.toLowerCase(), 'income': income ? 1 : 0,
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw ArgumentError('Kategori tersebut sudah ada.');
      }
      rethrow;
    }
    return name;
  }

  Future<List<Entry>> read() async => (await (await database)
      .query('entries', orderBy: 'date DESC, id DESC'))
      .map(Entry.fromMap).toList();

  Future<void> save(Entry entry) async {
    if (entry.amount <= 0 || entry.amount > 999999999999) {
      throw ArgumentError('Jumlah tidak valid.');
    }
    final available = await categories(entry.income);
    if (!available.contains(entry.category)) {
      throw ArgumentError('Kategori tidak valid.');
    }
    final db = await database;
    if (entry.id == null) {
      await db.insert('entries', entry.toMap());
    } else {
      await db.update('entries', entry.toMap(),
          where: 'id = ?', whereArgs: [entry.id]);
    }
  }

  Future<void> delete(int id) async {
    await (await database).delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
