import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Free questions per subject. The rest need Premium.
const freePerSubject = 5;

/// Create these two subscription IDs in Google Play Console.
const productIds = {'premium_monthly', 'premium_yearly'};

class Question {
  final String subject, text, explanation, topic;
  final List<String> options;
  final int answer, index;
  Question(this.subject, this.index, Map<String, dynamic> m)
      : text = m['q'],
        options = List<String>.from(m['o']),
        answer = m['a'],
        explanation = m['e'],
        topic = m['t'];
}

class AppState extends ChangeNotifier {
  late SharedPreferences prefs;
  final Map<String, List<Question>> bank = {};
  bool pro = false;
  int streak = 0, best = 0, tests = 0;
  String last = '';
  Map<String, int> weak = {};

  Future<void> load() async {
    prefs = await SharedPreferences.getInstance();
    final raw = json.decode(await rootBundle.loadString('assets/questions.json'))
        as Map<String, dynamic>;
    raw.forEach((subject, list) {
      final l = list as List;
      bank[subject] = [for (var i = 0; i < l.length; i++) Question(subject, i, l[i])];
    });
    pro = prefs.getBool('pro') ?? false;
    streak = prefs.getInt('streak') ?? 0;
    best = prefs.getInt('best') ?? 0;
    tests = prefs.getInt('tests') ?? 0;
    last = prefs.getString('last') ?? '';
    weak = Map<String, int>.from(json.decode(prefs.getString('weak') ?? '{}'));
  }

  bool isFree(Question q) => pro || q.index < freePerSubject;

  Future<void> setPro(bool v) async {
    pro = v;
    await prefs.setBool('pro', v);
    notifyListeners();
  }

  Future<void> recordResult(int score, int total, List<String> wrong) async {
    final now = DateTime.now();
    String day(DateTime d) => d.toIso8601String().substring(0, 10);
    if (last != day(now)) {
      streak = last == day(now.subtract(const Duration(days: 1))) ? streak + 1 : 1;
      last = day(now);
    }
    final pct = (score * 100 / total).round();
    if (pct > best) best = pct;
    tests++;
    for (final t in wrong) {
      weak[t] = (weak[t] ?? 0) + 1;
    }
    await prefs.setInt('streak', streak);
    await prefs.setString('last', last);
    await prefs.setInt('best', best);
    await prefs.setInt('tests', tests);
    await prefs.setString('weak', json.encode(weak));
    notifyListeners();
  }
}

void startQuiz(BuildContext context, AppState app, List<Question> pool) {
  final free = pool.where(app.isFree).toList()..shuffle();
  if (free.isEmpty) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumScreen(app: app)));
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => QuizScreen(app: app, qs: free, locked: pool.length - free.length),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppState();
  await app.load();
  runApp(MdcatApp(app: app));
}

class MdcatApp extends StatelessWidget {
  final AppState app;
  const MdcatApp({super.key, required this.app});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MDCAT Prep',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF14213D),
            secondary: const Color(0xFFF2A900),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF14213D),
            brightness: Brightness.dark,
          ),
        ),
        home: HomeScreen(app: app),
      );
}

class HomeScreen extends StatelessWidget {
  final AppState app;
  const HomeScreen({super.key, required this.app});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('MDCAT Prep')),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              _stat('${app.streak}', 'Day streak'),
              _stat('${app.best}%', 'Best score'),
              _stat('${app.tests}', 'Tests'),
            ]),
            const SizedBox(height: 16),
            Text('Choose a subject', style: Theme.of(context).textTheme.titleLarge),
            for (final s in app.bank.keys)
              Card(
                child: ListTile(
                  title: Text(s),
                  subtitle: Text('${app.bank[s]!.length} questions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ChapterScreen(app: app, subject: s)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => startQuiz(
                context,
                app,
                (app.bank.values.expand((l) => l).toList()..shuffle()).take(20).toList(),
              ),
              child: const Text('Full mock test (20 questions)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PremiumScreen(app: app)),
              ),
              child: Text(app.pro ? 'Premium active' : 'Go Premium'),
            ),
          ]),
        ),
      );

  Widget _stat(String value, String label) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ),
      );
}

class ChapterScreen extends StatelessWidget {
  final AppState app;
  final String subject;
  const ChapterScreen({super.key, required this.app, required this.subject});

  @override
  Widget build(BuildContext context) {
    final qs = app.bank[subject]!;
    final topics = qs.map((q) => q.topic).toSet().toList();
    return Scaffold(
      appBar: AppBar(title: Text(subject)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final t in topics)
          Card(
            child: ListTile(
              title: Text(t),
              subtitle: Text('${qs.where((q) => q.topic == t).length} questions'),
              onTap: () => startQuiz(context, app, qs.where((q) => q.topic == t).toList()),
            ),
          ),
        FilledButton(
          onPressed: () => startQuiz(context, app, qs),
          child: const Text('All chapters'),
        ),
      ]),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final AppState app;
  final List<Question> qs;
  final int locked;
  const QuizScreen({super.key, required this.app, required this.qs, required this.locked});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int i = 0, score = 0;
  int? picked;
  late int secs = widget.qs.length * 60;
  Timer? timer;
  final wrong = <String>[];

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (--secs <= 0) {
        _finish();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _pick(int j) {
    final q = widget.qs[i];
    setState(() {
      picked = j;
      if (j == q.answer) {
        score++;
      } else {
        wrong.add(q.topic);
      }
    });
  }

  void _next() {
    if (i == widget.qs.length - 1) {
      _finish();
    } else {
      setState(() {
        i++;
        picked = null;
      });
    }
  }

  void _finish() {
    timer?.cancel();
    if (!mounted) return;
    widget.app.recordResult(score, widget.qs.length, wrong);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          app: widget.app,
          score: score,
          total: widget.qs.length,
          locked: widget.locked,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.qs[i];
    final time = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: Text('${i + 1} / ${widget.qs.length}'), actions: [
        Padding(padding: const EdgeInsets.all(16), child: Text(time)),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        LinearProgressIndicator(value: i / widget.qs.length),
        const SizedBox(height: 16),
        Text(q.text, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (var j = 0; j < q.options.length; j++) _option(q, j),
        if (picked != null) ...[
          Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(q.explanation))),
          FilledButton(
            onPressed: _next,
            child: Text(i == widget.qs.length - 1 ? 'Finish' : 'Next'),
          ),
        ],
      ]),
    );
  }

  Widget _option(Question q, int j) {
    Color? color;
    if (picked != null) {
      if (j == q.answer) {
        color = Colors.green.withOpacity(0.25);
      } else if (j == picked) {
        color = Colors.red.withOpacity(0.25);
      }
    }
    return Card(
      color: color,
      child: ListTile(
        leading: CircleAvatar(radius: 14, child: Text('ABCD'[j])),
        title: Text(q.options[j]),
        onTap: picked == null ? () => _pick(j) : null,
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final AppState app;
  final int score, total, locked;
  const ResultScreen({
    super.key,
    required this.app,
    required this.score,
    required this.total,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    final top = (app.weak.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(5);
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('$score / $total', style: Theme.of(context).textTheme.headlineMedium),
        Text('${(score * 100 / total).round()}%',
            style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 16),
        Text('Weak topics', style: Theme.of(context).textTheme.titleLarge),
        if (top.isEmpty) const Text('No weak topics. Great work!'),
        for (final e in top) ListTile(title: Text(e.key), trailing: Text('x${e.value}')),
        if (locked > 0)
          Card(
            child: ListTile(
              title: Text('$locked more questions are locked'),
              trailing: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PremiumScreen(app: app)),
                ),
                child: const Text('Go Premium'),
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          child: const Text('Back to home'),
        ),
      ]),
    );
  }
}

class PremiumScreen extends StatefulWidget {
  final AppState app;
  const PremiumScreen({super.key, required this.app});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? sub;
  List<ProductDetails> products = [];
  String? error;

  @override
  void initState() {
    super.initState();
    sub = iap.purchaseStream.listen(_onPurchases);
    _load();
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!await iap.isAvailable()) {
      setState(() => error = 'Google Play is not available on this device.');
      return;
    }
    final r = await iap.queryProductDetails(productIds);
    setState(() {
      products = r.productDetails;
      if (products.isEmpty) error = 'Plans are not set up in Play Console yet.';
    });
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        // TODO before launch: verify p.verificationData on your server.
        await widget.app.setPro(true);
      }
      if (p.pendingCompletePurchase) await iap.completePurchase(p);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Premium')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
            'Unlock all questions, full mock tests, detailed explanations '
            'and weak-topic history.',
          ),
          const SizedBox(height: 16),
          if (widget.app.pro)
            const Card(child: ListTile(title: Text('Premium active')))
          else ...[
            if (error != null) Text(error!),
            for (final p in products)
              Card(
                child: ListTile(
                  title: Text(p.title),
                  trailing: Text(p.price),
                  onTap: () => iap.buyNonConsumable(
                    purchaseParam: PurchaseParam(productDetails: p),
                  ),
                ),
              ),
            TextButton(onPressed: iap.restorePurchases, child: const Text('Restore purchase')),
          ],
        ]),
      );
}
