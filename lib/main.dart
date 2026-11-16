import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'data.dart';

const green = Color(0xFF0F6B4F);
const background = Color(0xFFF6F7F4);
const ink = Color(0xFF14201A);
const muted = Color(0xFF5B665F);
const border = Color(0xFFE3E7E1);
const pale = Color(0xFFE4F2EB);
const amber = Color(0xFFC77700);

String rupiah(int amount) =>
    'Rp ${NumberFormat.decimalPattern('id_ID').format(amount)}';
String dateLabel(DateTime date, String pattern) =>
    DateFormat(pattern, 'id_ID').format(date);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Catatan Keuangan',
    debugShowCheckedModeBanner: false,
    locale: const Locale('id', 'ID'),
    supportedLocales: const [Locale('id', 'ID')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(seedColor: green,
          primary: green, surface: background),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink, fontSize: 14),
        titleLarge: TextStyle(color: ink, fontSize: 24, fontWeight: FontWeight.w700),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: border)),
        contentPadding: const EdgeInsets.all(16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    ),
    home: const Home(),
  );
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  final ledger = Ledger();
  List<Entry> entries = [];
  bool loading = true;
  bool failed = false;
  int tab = 0;
  int filter = 0;
  DateTime day = DateUtils.dateOnly(DateTime.now());
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ledger.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    try {
      final result = await ledger.read();
      if (!mounted) return;
      setState(() {
        entries = result;
        loading = false;
        failed = false;
      });
    } catch (_) {
      if (mounted) setState(() { loading = false; failed = true; });
    }
  }

  Future<void> edit([Entry? entry]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EntryForm(ledger: ledger, entry: entry)),
    );
    if (changed == true) await load();
  }

  Widget heading(String subtitle, String title) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(subtitle, style: const TextStyle(color: muted, fontSize: 13)),
      const SizedBox(height: 4),
      Text(title, style: Theme.of(context).textTheme.titleLarge),
    ]),
  );

  Widget monthPicker() => Row(children: [
    IconButton(
      tooltip: 'Bulan sebelumnya',
      onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)),
      icon: const Icon(Icons.chevron_left),
    ),
    Expanded(child: Text(dateLabel(month, 'MMMM yyyy'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600))),
    IconButton(
      tooltip: 'Bulan berikutnya',
      onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)),
      icon: const Icon(Icons.chevron_right),
    ),
  ]);

  Widget transactions(List<Entry> items) {
    if (items.isEmpty) {
      return panel(child: Column(children: [
        const SizedBox(height: 16),
        const Icon(Icons.receipt_long_outlined, size: 40, color: green),
        const SizedBox(height: 12),
        const Text('Belum ada catatan', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('Catat pemasukan atau pengeluaran Anda.',
            textAlign: TextAlign.center, style: TextStyle(color: muted)),
        TextButton(onPressed: () => edit(), child: const Text('Tambah catatan')),
      ]));
    }
    return panel(padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => edit(items[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 2),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: pale,
                      borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: Text(items[i].title.substring(
                      0, math.min(2, items[i].title.length)),
                      style: const TextStyle(color: green, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(items[i].title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${items[i].category} · ${dateLabel(items[i].date, 'HH.mm')}',
                        style: const TextStyle(color: muted, fontSize: 11)),
                  ],
                )),
                const SizedBox(width: 8),
                Flexible(child: Text(
                  '${items[i].income ? '+' : '−'}${rupiah(items[i].amount)}',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: items[i].income ? green : ink,
                      fontWeight: FontWeight.w600, fontSize: 13),
                )),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget overview() {
    final now = DateTime.now();
    final current = inMonth(entries, now);
    final income = total(current, true);
    final expense = total(current, false);
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day - 6 + i));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      heading(dateLabel(now, 'EEEE, d MMMM yyyy'), 'Catatan hari ini'),
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Selisih bulan ini', style: TextStyle(color: Color(0xFFD3EBDF))),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(rupiah(income - expense),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700,
                  color: Colors.white))),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: summaryCell('Pemasukan', income, dark: true)),
            const SizedBox(width: 12),
            Expanded(child: summaryCell('Pengeluaran', expense, dark: true)),
          ]),
        ]),
      ),
      const SizedBox(height: 18),
      Row(children: [
        for (final d in days)
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Semantics(
              selected: sameDay(d, day),
              button: true,
              label: dateLabel(d, 'EEEE d MMMM'),
              child: InkWell(
                onTap: () => setState(() => day = d),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 64),
                  decoration: BoxDecoration(
                    color: sameDay(d, day) ? green : Colors.white,
                    border: Border.all(color: sameDay(d, day) ? green : border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(dateLabel(d, 'EEE'), style: TextStyle(fontSize: 10,
                        color: sameDay(d, day) ? Colors.white : ink)),
                    Text('${d.day}', style: TextStyle(fontWeight: FontWeight.w700,
                        color: sameDay(d, day) ? Colors.white : ink, fontSize: 16)),
                  ]),
                ),
              ),
            ),
          )),
      ]),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(sameDay(day, now) ? 'Hari ini' : dateLabel(day, 'd MMMM'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        TextButton(onPressed: () => setState(() {
          month = DateTime(day.year, day.month); tab = 1;
        }), child: const Text('Lihat semua')),
      ]),
      transactions(entries.where((e) => sameDay(e.date, day)).toList()),
    ]);
  }

  Widget history() {
    final current = inMonth(entries, month);
    final filtered = current.where((e) =>
        filter == 0 || (filter == 1 ? e.income : !e.income)).toList();
    final groups = <DateTime, List<Entry>>{};
    for (final entry in filtered) {
      groups.putIfAbsent(DateUtils.dateOnly(entry.date), () => []).add(entry);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      heading('Riwayat', 'Catatan'),
      monthPicker(),
      const SizedBox(height: 12),
      panel(child: Column(children: [
        Row(children: [
          Expanded(child: summaryCell('Masuk', total(current, true))),
          Expanded(child: summaryCell('Keluar', total(current, false))),
        ]),
        const Divider(),
        summaryCell('Selisih', total(current, true) - total(current, false)),
      ])),
      const SizedBox(height: 16),
      Wrap(spacing: 8, children: [
        for (var i = 0; i < 3; i++)
          ChoiceChip(
            label: Text(['Semua', 'Pemasukan', 'Pengeluaran'][i]),
            selected: filter == i,
            showCheckmark: false,
            onSelected: (_) => setState(() => filter = i),
          ),
      ]),
      const SizedBox(height: 16),
      if (groups.isEmpty) transactions([]),
      for (final group in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 8),
          child: Row(children: [
            Expanded(child: Text(dateLabel(group.key, 'EEEE, d MMM'),
                style: const TextStyle(color: muted, fontSize: 12))),
            Text(rupiah(total(group.value, true) - total(group.value, false)),
                style: const TextStyle(color: green, fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        transactions(group.value),
        const SizedBox(height: 12),
      ],
    ]);
  }

  Widget report() {
    final current = inMonth(entries, month);
    final now = DateTime.now();
    final end = month.year == now.year && month.month == now.month
        ? DateUtils.dateOnly(now) : DateTime(month.year, month.month + 1, 0);
    final days = List.generate(7, (i) => DateTime(end.year, end.month, end.day - 6 + i));
    final values = [
      for (final d in days)
        [total(entries.where((e) => sameDay(e.date, d)), true),
         total(entries.where((e) => sameDay(e.date, d)), false)],
    ];
    final maxValue = values.expand((v) => v).fold<int>(1, math.max);
    final expense = total(current, false);
    final categories = {
      for (final c in current.where((e) => !e.income).map((e) => e.category).toSet())
        c: total(current.where((e) => e.category == c), false),
    }.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      heading(dateLabel(month, 'MMMM yyyy'), 'Rekap bulanan'),
      monthPicker(),
      const SizedBox(height: 16),
      panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('7 hari terakhir', style: TextStyle(fontWeight: FontWeight.w700)),
        Text('${dateLabel(days.first, 'd MMM')} – ${dateLabel(end, 'd MMM yyyy')}',
            style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 14),
        const Row(children: [
          Icon(Icons.circle, size: 9, color: green), Text(' Masuk    '),
          Icon(Icons.circle, size: 9, color: amber), Text(' Keluar'),
        ]),
        const SizedBox(height: 24),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < days.length; i++)
            Expanded(child: Semantics(
              label: '${dateLabel(days[i], 'd MMM')}, masuk ${rupiah(values[i][0])}, '
                  'keluar ${rupiah(values[i][1])}',
              child: Column(children: [
                SizedBox(height: 136, child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var j = 0; j < 2; j++)
                      Tooltip(
                        message: rupiah(values[i][j]),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 10,
                          height: math.max(2.0, values[i][j] / maxValue * 136),
                          decoration: BoxDecoration(
                            color: values[i][j] == 0 ? border : (j == 0 ? green : amber),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                )),
                const SizedBox(height: 10),
                Text(dateLabel(days[i], 'EEE'), style: const TextStyle(fontSize: 10, color: muted)),
                Text('${days[i].day}', style: const TextStyle(fontSize: 11)),
              ]),
            )),
        ]),
      ])),
      const SizedBox(height: 24),
      const Text('Pengeluaran per kategori',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      const SizedBox(height: 14),
      if (categories.isEmpty)
        panel(child: const Text('Belum ada pengeluaran pada bulan ini.',
            style: TextStyle(color: muted))),
      for (final c in categories) ...[
        panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(c.key, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(rupiah(c.value), style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: c.value / expense,
                minHeight: 6, color: green, backgroundColor: pale)),
          const SizedBox(height: 8),
          Text('${(c.value / expense * 100).round()}% dari total pengeluaran',
              style: const TextStyle(fontSize: 12, color: muted)),
        ])),
        const SizedBox(height: 10),
      ],
    ]);
  }

  Widget profile() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    heading('Ruang pribadi', 'Profil'),
    panel(child: const Column(children: [
      CircleAvatar(radius: 34, backgroundColor: pale,
          child: Icon(Icons.person_outline, color: green, size: 36)),
      SizedBox(height: 16),
      Text('Keuangan pribadi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      SizedBox(height: 6),
      Text('Offline · Tanpa akun', style: TextStyle(color: muted)),
    ])),
    const SizedBox(height: 16),
    panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Penyimpanan di perangkat', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('${entries.length} catatan tersimpan'),
      const SizedBox(height: 8),
      const Text('Data tersimpan lokal di HP ini. Menghapus data aplikasi atau '
          'menghapus instalasi dapat menghilangkan catatan.',
          style: TextStyle(color: muted, height: 1.5)),
    ])),
    const SizedBox(height: 24),
    const Text('Catatan Keuangan · 1.0.0', textAlign: TextAlign.center,
        style: TextStyle(color: muted, fontSize: 12)),
  ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: loading
        ? const Center(child: CircularProgressIndicator())
        : failed
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Catatan belum dapat dimuat.'),
              TextButton(onPressed: load, child: const Text('Coba lagi')),
            ]))
          : RefreshIndicator(
              onRefresh: load,
              child: SingleChildScrollView(
                key: ValueKey(tab),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: [overview, history, report, profile][tab](),
              ),
            )),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(color: Colors.white,
            border: Border(top: BorderSide(color: border))),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          nav(0, Icons.home_outlined, 'Beranda'),
          nav(1, Icons.receipt_long_outlined, 'Catatan'),
          IconButton.filled(
            onPressed: loading || failed ? null : () => edit(),
            tooltip: 'Tambah catatan',
            style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
            icon: const Icon(Icons.add, size: 28),
          ),
          nav(2, Icons.bar_chart_outlined, 'Rekap'),
          nav(3, Icons.person_outline, 'Profil'),
        ]),
      ),
    ),
  );

  Widget nav(int index, IconData icon, String label) => Expanded(
    child: Semantics(selected: tab == index, child: InkWell(
      onTap: () => setState(() => tab = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: tab == index ? green : muted),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: tab == index ? green : muted,
              fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ),
    )),
  );
}

Widget panel({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) =>
    Container(
      padding: padding,
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
      child: child,
    );

Widget summaryCell(String title, int value, {bool dark = false}) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: dark ? const Color(0xFF0A5A41) : Colors.transparent,
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: TextStyle(fontSize: 12,
        color: dark ? const Color(0xFFD3EBDF) : muted)),
    const SizedBox(height: 4),
    FittedBox(fit: BoxFit.scaleDown, child: Text(rupiah(value),
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
            color: dark ? Colors.white : green))),
  ]),
);

class EntryForm extends StatefulWidget {
  const EntryForm({super.key, required this.ledger, this.entry});
  final Ledger ledger;
  final Entry? entry;
  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController amount;
  late final TextEditingController note;
  late bool income;
  late DateTime date;
  late String category;
  bool busy = false;
  bool categoriesReady = false;
  List<String> incomes = List.of(incomeCategories);
  List<String> expenses = List.of(expenseCategories);

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    amount = TextEditingController(text: e?.amount.toString() ?? '');
    note = TextEditingController(text: e?.note ?? '');
    income = e?.income ?? true;
    date = e?.date ?? DateTime.now();
    category = e?.category ?? incomeCategories.first;
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      final incoming = await widget.ledger.categories(true);
      final outgoing = await widget.ledger.categories(false);
      if (!mounted) return;
      setState(() {
        incomes = incoming;
        expenses = outgoing;
        categoriesReady = true;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kategori belum dapat dimuat. Coba lagi.')));
      }
    }
  }

  Future<void> addCategory() async {
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CategoryDialog(ledger: widget.ledger, income: income),
    );
    if (name == null || !mounted) return;
    setState(() {
      (income ? incomes : expenses).add(name);
      category = name;
    });
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  void setDate(DateTime value) => setState(() {
    date = DateTime(value.year, value.month, value.day, date.hour, date.minute);
  });

  Future<void> pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (value != null && mounted) setDate(value);
  }

  Future<void> save() async {
    if (busy || !categoriesReady || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.ledger.save(Entry(
        id: widget.entry?.id,
        amount: int.parse(amount.text),
        income: income,
        date: date,
        category: category,
        note: note.text.trim(),
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan. Silakan coba lagi.')),
        );
      }
    }
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) =>
      AlertDialog(
        title: const Text('Hapus catatan?'),
        content: const Text('Catatan ini akan dihapus dari perangkat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.ledger.delete(widget.entry!.id!);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus. Silakan coba lagi.')));
      }
    }
  }

  Widget label(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.entry == null ? 'Catatan baru' : 'Edit catatan',
              style: const TextStyle(fontSize: 14, color: muted)),
          actions: [
            if (widget.entry != null)
              IconButton(onPressed: busy ? null : remove,
                  tooltip: 'Hapus catatan', icon: const Icon(Icons.delete_outline)),
          ],
        ),
        body: SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Form(key: form, child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.entry == null ? 'Tambah catatan' : 'Edit catatan',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Pemasukan')),
                  ButtonSegment(value: false, label: Text('Pengeluaran')),
                ],
                selected: {income},
                showSelectedIcon: false,
                onSelectionChanged: busy ? null : (selection) => setState(() {
                  income = selection.first;
                  category = (income ? incomes : expenses).first;
                }),
              ),
              label('Jumlah'),
              TextFormField(
                controller: amount,
                enabled: !busy,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(prefixText: 'Rp ', hintText: '0'),
                validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                    ? 'Masukkan jumlah lebih dari nol.' : null,
              ),
              label('Tanggal'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(label: const Text('Hari ini'),
                    selected: sameDay(date, now), showCheckmark: false,
                    onSelected: busy ? null : (_) => setDate(now)),
                ChoiceChip(label: const Text('Kemarin'),
                    selected: sameDay(date, yesterday), showCheckmark: false,
                    onSelected: busy ? null : (_) => setDate(yesterday)),
                ActionChip(label: const Text('Pilih tanggal'),
                    avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                    onPressed: busy ? null : pickDate),
              ]),
              const SizedBox(height: 8),
              Text(dateLabel(date, 'EEEE, d MMMM yyyy'),
                  style: const TextStyle(color: muted, fontSize: 12)),
              label('Kategori'),
              if (!categoriesReady)
                TextButton(onPressed: loadCategories,
                    child: const Text('Muat kategori')),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in income ? incomes : expenses)
                  ChoiceChip(label: Text(c), selected: category == c,
                      showCheckmark: false,
                      onSelected: busy ? null : (_) => setState(() => category = c)),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Kategori baru'),
                  onPressed: busy || !categoriesReady ? null : addCategory,
                ),
              ]),
              label('Catatan'),
              TextFormField(
                controller: note, enabled: !busy,
                maxLength: 120, minLines: 2, maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    hintText: 'Contoh: Jasa desain (opsional)'),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: busy || !categoriesReady ? null : save,
                  child: Text(busy ? 'Memproses…' : 'Simpan catatan')),
            ],
          )),
        )),
      ),
    );
  }
}

class CategoryDialog extends StatefulWidget {
  const CategoryDialog({super.key, required this.ledger, required this.income});
  final Ledger ledger;
  final bool income;

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  final controller = TextEditingController();
  bool saving = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() { saving = true; error = null; });
    try {
      final name = await widget.ledger.addCategory(controller.text, widget.income);
      if (mounted) Navigator.pop(context, name);
    } catch (exception) {
      if (mounted) {
        setState(() {
          saving = false;
          error = exception is ArgumentError
              ? exception.message.toString() : 'Gagal menyimpan kategori. Coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: const Text('Kategori baru'),
      content: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.income ? 'Untuk pemasukan' : 'Untuk pengeluaran',
              style: const TextStyle(color: muted)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            enabled: !saving,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
                labelText: 'Nama kategori', hintText: 'Contoh: Pendidikan',
                errorText: error, errorMaxLines: 3),
            onSubmitted: (_) => save(),
          ),
        ]),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Batal')),
        FilledButton(onPressed: saving ? null : save,
            child: Text(saving ? 'Menyimpan…' : 'Tambah')),
      ],
    ),
  );
}
