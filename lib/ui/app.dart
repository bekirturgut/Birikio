import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import '../data/store.dart';
import 'widgets.dart';
import 'palette.dart';
import 'forms.dart';
import 'reports.dart';
import 'brand.dart';
import 'launch.dart';

class BirikioApp extends StatelessWidget {
  final FinanceStore store;
  final bool initialize;
  const BirikioApp({super.key, required this.store, this.initialize = false});
  ThemeData theme(bool dark) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: mint,
          brightness: dark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: dark ? mint : const Color(0xFF087A59),
          surface: dark ? ink : const Color(0xFFF5F6FA),
          surfaceContainer: dark ? const Color(0xFF171D2B) : Colors.white,
          onSurfaceVariant: dark
              ? const Color(0xFF99A3B9)
              : const Color(0xFF626C80),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'Roboto',
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(backgroundColor: scheme.surface, elevation: 0),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? ink : const Color(0xFFF2F4F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(18),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      dividerColor: dark ? Colors.white : Colors.black,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (_, _) => MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      title: 'Birikio • Hayaline ulaş',
      theme: theme(false),
      darkTheme: theme(true),
      themeMode: store.followSystem
          ? ThemeMode.system
          : (store.dark ? ThemeMode.dark : ThemeMode.light),
      themeAnimationDuration: const Duration(milliseconds: 450),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              !store.motion || MediaQuery.disableAnimationsOf(context),
        ),
        child: child!,
      ),
      home: PopScope(
        canPop: false,
        child: initialize
            ? BirikioLaunch(
                store: store,
                home: HomeShell(store: store),
              )
            : HomeShell(store: store),
      ),
    ),
  );
}

class HomeShell extends StatefulWidget {
  final FinanceStore store;
  const HomeShell({super.key, required this.store});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  FinanceStore get s => widget.store;
  int page = 0;
  String query = '';
  bool? burst;
  int burstKey = 0;
  Timer? timer;
  final titles = [
    'Genel bakış',
    'Gelirler',
    'Giderler',
    'Birikimler',
    'Bütçem',
    'Analiz',
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(Duration(minutes: 1), (_) => refresh());
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    try {
      await s.catchUp();
      if (mounted) setState(() {});
    } catch (_) {
      toast('Tekrarlayan kayıtlar kaydedilemedi. Tekrar denenecek.');
    }
  }

  void toast(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<bool> mutate(VoidCallback action) async {
    try {
      await s.change(action);
      return true;
    } catch (_) {
      toast('İşlem kaydedilemedi. Lütfen tekrar dene.');
      return false;
    }
  }

  void animateMoney(bool adding) {
    if (s.motion && !MediaQuery.disableAnimationsOf(context)) {
      setState(() {
        burst = adding;
        burstKey++;
      });
    }
  }

  Future<void> addEntry(bool income, [Entry? entry]) async {
    final ok = await sheet<bool>(
      context,
      EntryForm(store: s, income: income, entry: entry),
    );
    if (ok == true && mounted) {
      animateMoney(income);
      toast(entry == null ? 'Kayıt eklendi.' : 'Kayıt güncellendi.');
    }
  }

  Future<void> addGoal([Goal? goal]) async {
    final ok = await sheet<bool>(context, GoalForm(store: s, goal: goal));
    if (ok == true && mounted) {
      animateMoney(true);
      toast(
        goal == null
            ? 'Yeni hedefin hazır. İlk adım senden!'
            : 'Hedef güncellendi.',
      );
    }
  }

  Future<void> transfer(Goal goal, bool adding) async {
    final ok = await sheet<bool>(
      context,
      TransferForm(store: s, goal: goal, adding: adding),
    );
    if (ok == true && mounted) {
      animateMoney(adding);
      toast(
        s.saved(goal) >= goal.target
            ? 'Tebrikler! Hedefine ulaştın ✨'
            : adding
            ? 'Hayaline bir adım daha yaklaştın.'
            : 'Tutar kullanılabilir bakiyene aktarıldı.',
      );
    }
  }

  void navigate(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      page = i;
      query = '';
    });
  }

  void addMenu() => sheet(
    context,
    FormShell(
      title: 'Bugün ne ekleyelim?',
      subtitle: 'Paranın yönünü sen belirle.',
      children: [
        menuTile(
          Icons.south_west_rounded,
          financeColors(context).positive,
          'Gelir ekle',
          'Maaş, serbest iş veya diğer gelirlerin',
          () {
            Navigator.pop(context);
            addEntry(true);
          },
        ),
        menuTile(
          Icons.north_east_rounded,
          financeColors(context).negative,
          'Gider ekle',
          'Harcamalarını takip altında tut',
          () {
            Navigator.pop(context);
            addEntry(false);
          },
        ),
        menuTile(
          Icons.auto_awesome_rounded,
          financeColors(context).accent,
          'Birikim hedefi ekle',
          'Bir sonraki hayalin için yer aç',
          () {
            Navigator.pop(context);
            addGoal();
          },
        ),
      ],
    ),
  );
  Widget menuTile(
    IconData icon,
    Color color,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: EdgeInsets.symmetric(vertical: 8),
    leading: Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color),
    ),
    title: Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle, style: TextStyle(fontSize: 12)),
    trailing: Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
  Widget heading(String title, {String? action, VoidCallback? onTap}) =>
      Padding(
        padding: EdgeInsets.only(top: 26, bottom: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.5,
                ),
              ),
            ),
            if (action != null)
              TextButton(
                onPressed: onTap,
                child: Text(action, style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && page != 0) navigate(0);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 18, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: financeColors(
                              context,
                            ).positive.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const BirikioMark(size: 40),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Birikio',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: financeColors(
                              context,
                            ).positive.withValues(alpha: .08),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.offline_bolt_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'YEREL',
                                style: TextStyle(
                                  fontSize: 8,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Ayarlar',
                          onPressed: settings,
                          icon: Icon(Icons.tune_rounded, size: 22),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: reduced ? 0 : 720),
                      reverseDuration: Duration(
                        milliseconds: reduced ? 0 : 380,
                      ),
                      transitionBuilder: (child, a) =>
                          CinematicPageTransition(animation: a, child: child),
                      child: KeyedSubtree(
                        key: ValueKey(page),
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(24, 6, 24, 100),
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Eyebrow(
                                        page == 0
                                            ? dateLabel(
                                                DateTime.now(),
                                              ).toUpperCase()
                                            : 'PARANIN KONTROLÜ SENDE',
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        titles[page],
                                        style: TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (page == 0)
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 6),
                                    child: Icon(
                                      Icons.wb_twilight_rounded,
                                      color: financeColors(context).accent,
                                      size: 30,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 22),
                            if (page == 0) ...dashboard(),
                            if (page == 1 || page == 2) ...entryPage(page == 1),
                            if (page == 3) ...goalPage(),
                            if (page == 4) BudgetPage(store: s),
                            if (page == 5) AnalysisPage(store: s),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (burst != null)
                Positioned.fill(
                  child: MoneyBurst(
                    key: ValueKey(burstKey),
                    adding: burst!,
                    onEnd: () {
                      if (mounted) setState(() => burst = null);
                    },
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Yeni kayıt ekle',
          onPressed: addMenu,
          backgroundColor: mint,
          foregroundColor: ink,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.add_rounded, size: 32),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: .06),
                ),
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              children: List.generate(6, (i) {
                final icons = [
                  Icons.space_dashboard_rounded,
                  Icons.south_west_rounded,
                  Icons.north_east_rounded,
                  Icons.savings_outlined,
                  Icons.account_balance_wallet_outlined,
                  Icons.bar_chart_rounded,
                ];
                final labels = [
                  'Anasayfa',
                  'Gelir',
                  'Gider',
                  'Birikim',
                  'Bütçe',
                  'Analiz',
                ];
                final active = page == i;
                return Expanded(
                  child: Semantics(
                    selected: active,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => navigate(i),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: reduced ? 0 : 280),
                        padding: EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: active
                              ? mint.withValues(alpha: .12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icons[i],
                              size: 22,
                              color: active
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(height: 5),
                            Text(
                              labels[i],
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: active
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: active
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> dashboard() {
    final now = DateTime.now();
    final entries = s.entries.where(
      (e) => e.date.year == now.year && e.date.month == now.month,
    );
    final incoming = entries
        .where((e) => e.income)
        .fold(0, (v, e) => v + e.amount);
    final outgoing = entries
        .where((e) => !e.income)
        .fold(0, (v, e) => v + e.amount);
    return [
      if (s.featured != null)
        goalCard(s.featured!, featured: true)
      else
        emptyGoal(),
      SizedBox(height: 16),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Eyebrow('KULLANILABİLİR BAKİYE'),
                Spacer(),
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 19,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            SizedBox(height: 12),
            Amount(s.balance, size: 36),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: financeColors(context).accent,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${money(s.savings)} birikimlerinde ayrıldı',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: statCard(true, incoming)),
          SizedBox(width: 12),
          Expanded(child: statCard(false, outgoing)),
        ],
      ),
      heading('Son hareketler', action: 'Tümünü gör →', onTap: allEntries),
      if (s.entries.isEmpty)
        EmptyState(
          title: 'İlk adım, ilk kayıt.',
          subtitle:
              'Gelirini ve giderini ekle.\nFinansal hikâyen burada şekillensin.',
          action: 'İlk kaydımı ekle',
          onTap: addMenu,
          icon: Icons.receipt_long_rounded,
        )
      else
        Panel(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: s.sorted.take(5).map(entryTile).toList()),
        ),
      SizedBox(height: 22),
      Center(
        child: Text(
          'Küçük adımlar. Büyük hayaller.',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: .5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ];
  }

  Widget statCard(bool income, int amount) => InkWell(
    borderRadius: BorderRadius.circular(26),
    onTap: () => navigate(income ? 1 : 2),
    child: Panel(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                income ? Icons.south_west_rounded : Icons.north_east_rounded,
                color: income
                    ? financeColors(context).positive
                    : financeColors(context).negative,
                size: 18,
              ),
              SizedBox(width: 6),
              Text(income ? 'Gelir' : 'Gider', style: TextStyle(fontSize: 13)),
              Spacer(),
              Icon(
                Icons.arrow_outward_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          SizedBox(height: 14),
          Amount(
            amount,
            size: 21,
            color: income
                ? financeColors(context).positive
                : financeColors(context).negative,
          ),
          SizedBox(height: 6),
          Text(
            '${months[DateTime.now().month - 1]} · bu ay',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
  Widget emptyGoal() {
    final colors = financeColors(context);
    return AnimatedContainer(
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 420,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: colors.goalBackground),
      ),
      padding: EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('SIRADAKİ BÜYÜK HAYALİN', color: colors.accent),
          GoalScene(
            icon: 'Motor',
            motion: s.motion && !MediaQuery.disableAnimationsOf(context),
            height: 100,
          ),
          Text(
            'Hayaline yön ver.',
            style: TextStyle(
              color: colors.goalText,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'O motor, o yolculuk, o ilk ev…\nBir hedef koy, birlikte adım adım ilerleyelim.',
            style: TextStyle(
              color: colors.goalMuted,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
            ),
            onPressed: () => addGoal(),
            icon: Icon(Icons.add_rounded, size: 18),
            label: Text('İlk hedefimi oluştur'),
          ),
        ],
      ),
    );
  }

  Widget goalCard(Goal goal, {bool featured = false}) {
    final saved = s.saved(goal),
        ratio = (s.saved(goal) / goal.target).clamp(0.0, 1.0);
    final colors = financeColors(context);
    final completed = saved >= goal.target;
    final accent = completed ? colors.positive : colors.accent;
    final text = completed ? colors.completedText : colors.goalText;
    final muted = completed ? colors.completedMuted : colors.goalMuted;
    return AnimatedContainer(
      key: ValueKey('goal-card-${goal.id}'),
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 500,
      ),
      margin: EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: completed
              ? colors.completedBackground
              : colors.goalBackground,
        ),
        border: Border.all(color: accent.withValues(alpha: .16)),
      ),
      padding: EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Eyebrow(
                  saved >= goal.target
                      ? 'HEDEF TAMAMLANDI ✦'
                      : featured
                      ? 'ODAK NOKTAN'
                      : 'BİRİKİM HEDEFİN',
                  color: completed ? colors.gold : accent,
                ),
              ),
              if (s.featured?.id == goal.id)
                Icon(Icons.push_pin_rounded, color: accent, size: 14),
              PopupMenuButton<String>(
                tooltip: 'Hedef seçenekleri',
                icon: Icon(Icons.more_horiz, color: text),
                onSelected: (v) async {
                  if (v == 'edit') addGoal(goal);
                  if (v == 'pin') await mutate(() => s.pinned = goal.id);
                  if (v == 'history') goalHistory(goal);
                  if (v == 'delete' && mounted) {
                    final ok = await confirm(
                      context,
                      'Hedef silinsin mi?',
                      'Bu hedefin birikimi kullanılabilir bakiyene geri aktarılacak.',
                    );
                    if (ok) {
                      await mutate(() {
                        s.goals.removeWhere((g) => g.id == goal.id);
                        s.transfers.removeWhere((t) => t.goal == goal.id);
                        if (s.pinned == goal.id) s.pinned = null;
                      });
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                  PopupMenuItem(
                    value: 'pin',
                    child: Text('Ana ekranda göster'),
                  ),
                  PopupMenuItem(
                    value: 'history',
                    child: Text('Birikim hareketleri'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Hedefi sil')),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: TextStyle(
                        color: text,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.6,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      saved >= goal.target
                          ? 'Başardın! Bu hayal artık gerçek.'
                          : 'Her adım seni yaklaştırır.',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 110,
                child: AnimatedSwitcher(
                  duration: Duration(
                    milliseconds: MediaQuery.disableAnimationsOf(context)
                        ? 0
                        : 500,
                  ),
                  child: completed
                      ? AchievementScene(
                          key: ValueKey('achieved'),
                          motion:
                              s.motion &&
                              !MediaQuery.disableAnimationsOf(context),
                        )
                      : GoalScene(
                          key: ValueKey('in-progress'),
                          icon: goal.icon,
                          motion:
                              s.motion &&
                              !MediaQuery.disableAnimationsOf(context),
                          height: 96,
                        ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Amount(saved, size: 24, color: text)),
              Text(
                '%${(ratio * 100).floor()}',
                style: TextStyle(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (completed)
            Container(
              key: ValueKey('goal-completed-banner'),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, color: accent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hedefe ulaştın',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: colors.gold,
                    size: 18,
                  ),
                ],
              ),
            )
          else
            TweenAnimationBuilder<double>(
              tween: Tween(end: ratio),
              duration: Duration(
                milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 800,
              ),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  color: accent,
                  backgroundColor: accent.withValues(alpha: .12),
                ),
              ),
            ),
          SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                'Hedef ${money(goal.target)}',
                style: TextStyle(color: muted, fontSize: 10),
              ),
              Text(
                completed
                    ? 'Tamamlandı ✓'
                    : '${money(math.max(0, goal.target - saved))} kaldı',
                style: TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
          if (completed)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => transfer(goal, true),
                icon: Icon(Icons.add_rounded, size: 16),
                label: Text('Birikime eklemeye devam et'),
                style: TextButton.styleFrom(foregroundColor: accent),
              ),
            ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: colors.onAccent,
                    minimumSize: Size(0, 44),
                  ),
                  onPressed: completed
                      ? () => addGoal()
                      : () => transfer(goal, true),
                  icon: Icon(
                    completed ? Icons.auto_awesome_rounded : Icons.add_rounded,
                    size: 18,
                  ),
                  label: Text(completed ? 'Yeni hedef oluştur' : 'Para ekle'),
                ),
              ),
              SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Birikimden para çek',
                style: IconButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: .1),
                  foregroundColor: accent,
                ),
                onPressed: saved > 0 ? () => transfer(goal, false) : null,
                icon: Icon(Icons.remove_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget entryTile(Entry e) => ListTile(
    contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 0),
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: (e.income ? mint : coral).withValues(alpha: .1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        e.income ? Icons.south_west_rounded : Icons.north_east_rounded,
        color: e.income
            ? financeColors(context).positive
            : financeColors(context).negative,
        size: 19,
      ),
    ),
    title: Text(
      e.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      '${e.category} · ${e.date.day} ${months[e.date.month - 1]}${e.rule != null ? ' ↻' : ''}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 10),
    ),
    trailing: Text(
      '${e.income ? '+' : '−'}${money(e.amount)}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: e.income
            ? financeColors(context).positive
            : financeColors(context).negative,
      ),
    ),
    onTap: () => entryDetails(e),
  );
  void entryDetails(Entry e) => sheet(
    context,
    FormShell(
      title: e.title,
      subtitle: '${e.category} · ${dateLabel(e.date)}',
      children: [
        Amount(
          e.amount,
          color: e.income
              ? financeColors(context).positive
              : financeColors(context).negative,
          size: 36,
        ),
        if (e.note.isNotEmpty)
          Padding(padding: EdgeInsets.only(top: 20), child: Text(e.note)),
        if (e.rule != null)
          Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Tekrarlayan işlemden oluşturuldu. Bu kaydı silmek veya düzenlemek gelecek tekrarları değiştirmez.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            addEntry(e.income, e);
          },
          icon: Icon(Icons.edit_outlined, size: 18),
          label: Text('Kaydı düzenle'),
        ),
        SizedBox(height: 8),
        TextButton(
          onPressed: () async {
            final ok = await confirm(
              context,
              'Kayıt silinsin mi?',
              '${e.title} kaydı kalıcı olarak silinecek ve bakiyen yeniden hesaplanacak.',
            );
            if (ok) {
              final saved = await mutate(
                () => s.entries.removeWhere((x) => x.id == e.id),
              );
              if (saved && mounted) {
                Navigator.pop(context);
                animateMoney(false);
              }
            }
          },
          child: Text(
            'Kaydı sil',
            style: TextStyle(color: financeColors(context).negative),
          ),
        ),
      ],
    ),
  );
  List<Widget> entryPage(bool income) {
    final data = s.sorted
        .where(
          (e) =>
              e.income == income &&
              '${e.title} ${e.category} ${e.note}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    final rules = s.rules.where((r) => r.income == income && r.active).toList();
    return [
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(
              income
                  ? 'TOPLAM GELİR · TÜM ZAMANLAR'
                  : 'TOPLAM GİDER · TÜM ZAMANLAR',
            ),
            SizedBox(height: 12),
            Amount(
              income ? s.income : s.expense,
              size: 34,
              color: income
                  ? Theme.of(context).colorScheme.primary
                  : financeColors(context).negative,
            ),
            SizedBox(height: 8),
            Text(
              '${s.entries.where((e) => e.income == income).length} kayıt · ${rules.length} aktif tekrar',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      if (rules.isNotEmpty) ...[
        heading('Otomatik kayıtlar'),
        ...rules.map(
          (r) => Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Panel(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.autorenew_rounded,
                    color: financeColors(context).accent,
                    size: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title,
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${frequencies[r.frequency]} · ${money(r.amount)}',
                          style: TextStyle(fontSize: 11),
                        ),
                        Text(
                          'Sonraki: ${dateLabel(r.occurrence(r.cursor))}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final stop = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text('Tekrarlama durdurulsun mu?'),
                          content: Text(
                            'Geçmiş kayıtlar korunur. Yeni otomatik kayıt oluşturulmaz. Yeni tutar veya sıklık için yeni bir tekrar ekleyebilirsin.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: Text('Vazgeç'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: Text('Durdur'),
                            ),
                          ],
                        ),
                      );
                      if (stop == true) await mutate(() => r.active = false);
                    },
                    child: Text('Durdur', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
      heading('Kayıtların', action: '+ Ekle', onTap: () => addEntry(income)),
      TextField(
        onChanged: (v) => setState(() => query = v),
        decoration: InputDecoration(
          hintText: 'Ad, kategori veya not ara',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
      SizedBox(height: 16),
      if (data.isEmpty)
        EmptyState(
          title: query.isEmpty ? 'Henüz kayıt yok' : 'Sonuç bulunamadı',
          subtitle: query.isEmpty
              ? 'İlk kaydını ekleyerek başlayabilirsin.'
              : 'Farklı bir kelimeyle aramayı dene.',
          action: 'Kayıt ekle',
          onTap: () => addEntry(income),
          icon: Icons.receipt_long_outlined,
        )
      else
        Panel(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Column(children: data.map(entryTile).toList()),
        ),
    ];
  }

  List<Widget> goalPage() => [
    Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('HAYALLERİNE AYIRDIĞIN'),
          SizedBox(height: 12),
          Amount(s.savings, color: financeColors(context).accent, size: 34),
          SizedBox(height: 8),
          Text(
            '${s.goals.length} hedef · ${s.goals.where((g) => s.saved(g) >= g.target).length} tamamlandı',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
    heading('Hedeflerin', action: '+ Yeni hedef', onTap: () => addGoal()),
    if (s.goals.isEmpty)
      emptyGoal()
    else
      ...s.goals.map(
        (g) =>
            Padding(padding: EdgeInsets.only(bottom: 16), child: goalCard(g)),
      ),
  ];
  void allEntries() => sheet(
    context,
    ListenableBuilder(
      listenable: s,
      builder: (_, _) => FormShell(
        title: 'Tüm hareketler',
        subtitle:
            '${s.entries.length} gelir ve gider kaydı · en yeniden eskiye',
        children: s.sorted.isEmpty
            ? [Text('Henüz kayıt yok.')]
            : s.sorted.map(entryTile).toList(),
      ),
    ),
  );
  void goalHistory(Goal goal) {
    final list = s.transfers.where((t) => t.goal == goal.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    sheet(
      context,
      FormShell(
        title: goal.title,
        subtitle: 'Birikim hareketlerin',
        children: [
          if (list.isEmpty) Text('Henüz aktarım yapılmadı.'),
          ...list.map(
            (t) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                t.amount > 0
                    ? Icons.add_circle_outline
                    : Icons.remove_circle_outline,
                color: t.amount > 0
                    ? financeColors(context).positive
                    : financeColors(context).negative,
              ),
              title: Text(
                t.amount > 0 ? 'Birikime eklendi' : 'Bakiyeye geri alındı',
              ),
              subtitle: Text(dateLabel(t.date)),
              trailing: Text(
                money(t.amount),
                style: TextStyle(
                  color: t.amount > 0
                      ? financeColors(context).positive
                      : financeColors(context).negative,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void settings() => sheet(
    context,
    StatefulBuilder(
      builder: (context, update) => FormShell(
        title: 'Ayarlar',
        subtitle: 'Senin paran. Senin alanın.',
        children: [
          DropdownButtonFormField<String>(
            initialValue: s.followSystem
                ? 'system'
                : (s.dark ? 'dark' : 'light'),
            decoration: InputDecoration(
              labelText: 'Tema',
              helperText:
                  'Sistem seçiliyken telefonun teması otomatik takip edilir.',
              helperMaxLines: 2,
              prefixIcon: Icon(Icons.brightness_auto_rounded),
            ),
            items: [
              DropdownMenuItem(
                value: 'system',
                child: Text('Sistem (otomatik)'),
              ),
              DropdownMenuItem(value: 'dark', child: Text('Koyu')),
              DropdownMenuItem(value: 'light', child: Text('Açık')),
            ],
            onChanged: (value) async {
              if (value == null) return;
              await mutate(() {
                s.followSystem = value == 'system';
                if (!s.followSystem) s.dark = value == 'dark';
              });
              if (context.mounted) update(() {});
            },
          ),
          SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.auto_awesome_outlined),
            title: Text('Görsel animasyonlar'),
            subtitle: Text('Hareketli hedefler ve banknot efektleri'),
            value: s.motion,
            onChanged: (v) async {
              await mutate(() => s.motion = v);
              if (context.mounted) update(() {});
            },
          ),
          SizedBox(height: 16),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('YALNIZCA SENİN CİHAZINDA'),
                SizedBox(height: 12),
                Text(
                  'Hesap açman veya internete bağlanman gerekmez. Veriler bu cihazda tutulur. Uygulamayı kaldırırsan yerel kayıtların silinebilir.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
                SizedBox(height: 12),
                Text(
                  'Otomatik kayıtlar açılışta, ön plana dönüşte ve uygulama açıkken tamamlanır. Birikim aktarımları gelir / gider analizine dahil edilmez.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: financeColors(context).negative,
              minimumSize: Size(0, 52),
            ),
            onPressed: () async {
              final ok = await confirm(
                context,
                'Tüm veriler silinsin mi?',
                'Gelirler, giderler, otomatik kayıtlar, hedefler ve bütçeler kalıcı olarak silinecek. Bu işlem geri alınamaz.',
              );
              if (ok) {
                try {
                  await s.clear();
                  if (context.mounted) Navigator.pop(context);
                  toast('Tüm finansal veriler silindi.');
                } catch (_) {
                  toast('Veriler silinemedi. Tekrar dene.');
                }
              }
            },
            icon: Icon(Icons.delete_outline_rounded),
            label: Text('Tüm verileri sil'),
          ),
          SizedBox(height: 20),
          Center(
            child: Text(
              'Birikio  /  1.0.0',
              style: TextStyle(fontSize: 11, letterSpacing: 2),
            ),
          ),
        ],
      ),
    ),
  );
}
