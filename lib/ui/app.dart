import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_selector/file_selector.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import '../data/store.dart';
import '../data/backup.dart';
import '../data/financial_health.dart';
import '../services/local_notifications.dart';
import '../services/home_summary_widget.dart';
import 'widgets.dart';
import 'palette.dart';
import 'forms.dart';
import 'reports.dart';
import 'brand.dart';
import 'launch.dart';
import 'widget_picker.dart';
import 'app_version.dart';

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
  int entryFilter = 0; // 0: all, 1: income, 2: expense
  int walletFilter = 0; // 0: all, 1: savings, 2: budget
  String? categoryFilter;
  DateTimeRange? entryDateRange;
  int? entryMinAmount;
  int? entryMaxAmount;
  bool? recurringFilter;
  int entrySort = 0; // newest, oldest, highest, lowest
  bool? burst;
  int burstKey = 0;
  Timer? timer;
  final titles = ['Genel bakış', 'Gelir & Gider', 'Cüzdan', 'Analiz', 'Profil'];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    s.addListener(onStoreChanged);
    timer = Timer.periodic(Duration(minutes: 1), (_) => refresh());
    Future<void>.delayed(Duration.zero, () => onStoreChanged());
  }

  void onStoreChanged() {
    if (!mounted) return;
    Future<void>.delayed(Duration.zero, () async {
      if (!mounted || s.busy) return;
      try {
        await HomeSummaryWidget.sync(s);
      } catch (_) {
        // The app stays usable when the launcher has no widget support.
      }
      if (!s.notificationsEnabled) return;
      try {
        await LocalNotifications.instance.sync(s);
      } catch (_) {
        // In-app budget and overdue states still work without OS delivery.
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    s.removeListener(onStoreChanged);
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
      if (entry == null) animateMoney(income);
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
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Birikio',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              const AppVersion(badge: true),
                            ],
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
                                  Row(
                                    children: [
                                      Icon(
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Icons.nightlight_round
                                            : Icons.wb_sunny_rounded,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? financeColors(context).accent
                                            : financeColors(context).gold,
                                        size: 25,
                                      ),
                                      IconButton(
                                        tooltip: 'Ana ekranı düzenle',
                                        onPressed: editDashboard,
                                        icon: const Icon(
                                          Icons.dashboard_customize_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            SizedBox(height: 22),
                            if (page == 0) ...dashboard(),
                            if (page == 1) ...entryPage(),
                            if (page == 2) ...walletPage(),
                            if (page == 3) AnalysisPage(store: s),
                            if (page == 4) ...profilePage(),
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
              children: List.generate(5, (i) {
                final icons = [
                  Icons.space_dashboard_rounded,
                  Icons.swap_vert_rounded,
                  Icons.account_balance_wallet_outlined,
                  Icons.bar_chart_rounded,
                  Icons.person_outline_rounded,
                ];
                final labels = [
                  'Anasayfa',
                  'Gelir & Gider',
                  'Cüzdan',
                  'Analiz',
                  'Profil',
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

  void editDashboard() => sheet(
    context,
    StatefulBuilder(
      builder: (context, update) {
        const labels = <String, (String, IconData)>{
          'goal': ('Birikim hedefi', Icons.savings_rounded),
          'summary': ('Bu ayın özeti', Icons.auto_graph_rounded),
          'balance': (
            'Ayrı bakiye kartı',
            Icons.account_balance_wallet_rounded,
          ),
          'cashflow': ('Ayrı gelir / gider kartları', Icons.swap_vert_rounded),
          'activity': ('Son hareketler', Icons.receipt_long_rounded),
          'overdue': (
            'Gecikmiş ödemeler',
            Icons.notification_important_rounded,
          ),
        };
        final visible = s.dashboardSections;
        final ordered = [
          ...visible,
          ...FinanceStore.availableDashboardSections.where(
            (id) => !visible.contains(id),
          ),
        ];
        return FormShell(
          title: 'Ana ekranı düzenle',
          subtitle:
              'Kartları açıp kapat, oklarla sıralarını değiştir. Seçimlerin otomatik kaydedilir.',
          children: [
            for (final id in ordered)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        labels[id]!.$2,
                        color: financeColors(context).accent,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          labels[id]!.$1,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (visible.contains(id)) ...[
                        IconButton(
                          tooltip: '${labels[id]!.$1} yukarı',
                          visualDensity: VisualDensity.compact,
                          onPressed: visible.indexOf(id) == 0
                              ? null
                              : () async {
                                  if (await mutate(() {
                                        final index = s.dashboardSections
                                            .indexOf(id);
                                        s.dashboardSections.removeAt(index);
                                        s.dashboardSections.insert(
                                          index - 1,
                                          id,
                                        );
                                      }) &&
                                      context.mounted) {
                                    update(() {});
                                  }
                                },
                          icon: const Icon(Icons.keyboard_arrow_up_rounded),
                        ),
                        IconButton(
                          tooltip: '${labels[id]!.$1} aşağı',
                          visualDensity: VisualDensity.compact,
                          onPressed: visible.indexOf(id) == visible.length - 1
                              ? null
                              : () async {
                                  if (await mutate(() {
                                        final index = s.dashboardSections
                                            .indexOf(id);
                                        s.dashboardSections.removeAt(index);
                                        s.dashboardSections.insert(
                                          index + 1,
                                          id,
                                        );
                                      }) &&
                                      context.mounted) {
                                    update(() {});
                                  }
                                },
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                      ],
                      Switch.adaptive(
                        value: visible.contains(id),
                        onChanged: (enabled) async {
                          if (await mutate(() {
                                if (enabled) {
                                  s.dashboardSections.add(id);
                                } else {
                                  s.dashboardSections.remove(id);
                                }
                              }) &&
                              context.mounted) {
                            update(() {});
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  List<Widget> dashboard() {
    final now = DateTime.now();
    final overdueBills = s.rules
        .where(
          (r) =>
              r.isBill &&
              !r.automaticPayment &&
              r.active &&
              r.occurrence(s.firstUnpaidBillPeriod(r)).isBefore(day(now)),
        )
        .toList();
    final entries = s.entries.where(
      (e) => e.date.year == now.year && e.date.month == now.month,
    );
    final incoming = entries
        .where((e) => e.income)
        .fold(0, (v, e) => v + e.amount);
    final outgoing = entries
        .where((e) => !e.income)
        .fold(0, (v, e) => v + e.amount);
    final transferred = s.transfers
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .fold<int>(0, (sum, t) => sum + t.amount);
    final health = financialHealthReport(s, now);
    final sections = <String, Widget>{
      'goal': s.featured != null
          ? goalCard(s.featured!, featured: true)
          : emptyGoal(),
      'balance': Panel(
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
      'cashflow': Row(
        children: [
          Expanded(child: statCard(true, incoming)),
          SizedBox(width: 12),
          Expanded(child: statCard(false, outgoing)),
        ],
      ),
      'summary': financialSummary(incoming, outgoing, transferred, health),
      if (overdueBills.isNotEmpty)
        'overdue': Panel(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.notification_important_rounded,
              color: financeColors(context).negative,
            ),
            title: Text(
              '${overdueBills.length} gecikmiş ödemen var',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('Düzenli ödemelerini kontrol et'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              navigate(1);
              setState(() => entryFilter = 2);
            },
          ),
        ),
      'activity': Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      ),
    };
    return [
      for (final id in s.dashboardSections)
        if (sections[id] case final widget?) ...[
          widget,
          const SizedBox(height: 14),
        ],
      if (s.dashboardSections.isEmpty)
        Panel(
          child: Center(
            child: TextButton.icon(
              onPressed: editDashboard,
              icon: const Icon(Icons.dashboard_customize_rounded),
              label: const Text('Ana ekranına kart ekle'),
            ),
          ),
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
    onTap: () {
      navigate(1);
      setState(() {
        entryFilter = income ? 1 : 2;
        categoryFilter = null;
      });
    },
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
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(colors: colors.goalBackground),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.savings_rounded, color: colors.accent, size: 29),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Eyebrow('BİRİKİM HEDEFİ', color: colors.accent),
                const SizedBox(height: 5),
                Text(
                  'Bir hedefle başla',
                  style: TextStyle(
                    color: colors.goalText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Küçük adımlar birikime dönüşür.',
                  style: TextStyle(color: colors.goalMuted, fontSize: 11),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: addGoal,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      'Hedef oluştur  →',
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget financialSummary(
    int incoming,
    int outgoing,
    int transferred,
    FinancialHealthReport health,
  ) {
    final colors = financeColors(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final savingsRate = incoming > 0
        ? (transferred / incoming * 100).round()
        : null;
    return AnimatedContainer(
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 420,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.dark
              ? [const Color(0xFF1F2C3D), const Color(0xFF1C2035)]
              : [const Color(0xFFEAF8F3), const Color(0xFFF1ECFA)],
        ),
      ),
      padding: const EdgeInsets.all(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Eyebrow('BU AYIN ÖZETİ', color: colors.accent),
              const Spacer(),
              Icon(Icons.auto_graph_rounded, color: colors.accent, size: 22),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: colors.positive.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('KULLANILABİLİR BAKİYE', color: colors.positive),
                const SizedBox(height: 5),
                Amount(s.balance, size: 26),
                const SizedBox(height: 3),
                Text(
                  '${money(s.savings)} birikimlerinde ayrıldı',
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: summaryMetric('GELİR', money(incoming), colors.positive),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: summaryMetric('GİDER', money(outgoing), colors.negative),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.savings_outlined, color: colors.accent, size: 19),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hedeflere net aktarım',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      if (savingsRate != null)
                        Text(
                          'Gelirin %$savingsRate kadarı',
                          style: TextStyle(color: muted, fontSize: 10),
                        ),
                    ],
                  ),
                ),
                Text(
                  money(transferred),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Finans yönetimi puanı',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                health.score == null
                    ? 'Veri bekleniyor'
                    : '${health.score} / 100',
                style: TextStyle(
                  color: health.score == null ? muted : colors.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: LinearProgressIndicator(
              value: (health.score ?? 0) / 100,
              minHeight: 7,
              backgroundColor: colors.accent.withValues(alpha: .13),
              valueColor: AlwaysStoppedAnimation(colors.accent),
            ),
          ),
          const SizedBox(height: 9),
          if (health.score != null) ...[
            Text(
              health.dataQuality,
              style: TextStyle(
                color: colors.accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              health.observations.first,
              style: TextStyle(color: muted, fontSize: 11, height: 1.35),
            ),
          ] else
            Text(
              'Gelir, gider veya birikim kaydı ekledikçe değerlendirme oluşur.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          if (health.score != null) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => showHealthDetails(health),
              icon: const Icon(Icons.insights_rounded, size: 16),
              label: const Text('Puanı ve yorumları incele'),
            ),
          ],
        ],
      ),
    );
  }

  Widget summaryMetric(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  void showHealthDetails(FinancialHealthReport report) => sheet(
    context,
    FormShell(
      title: 'Paranın genel resmi',
      subtitle:
          'Son üç tamamlanmış ay ve bu ayın kayıtlarından hesaplanan ${report.score}/100 puan · ${report.dataQuality.toLowerCase()}. Otomatik fatura kayıtları gerçek banka tahsilatını doğrulamaz.',
      children: [
        Eyebrow('ÖNE ÇIKANLAR', color: financeColors(context).accent),
        const SizedBox(height: 10),
        for (final observation in report.observations)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 17,
                    color: financeColors(context).accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      observation,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Eyebrow(
          'PUANI OLUŞTURAN ALANLAR',
          color: financeColors(context).accent,
        ),
        const SizedBox(height: 10),
        for (final factor in report.factors)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          factor.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${factor.score}/100',
                        style: TextStyle(
                          color: financeColors(context).accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: factor.score / 100,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    factor.explanation,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Gelir–gider %25 · Birikim %20 · Faturalar %15 · Bütçe %15 · Gelir düzeni %10 · Aylık gidişat %7 · Bakiye %5 · Harcama dağılımı %3. Veri olmayan alanlar puana katılmaz; kalan ağırlıklar yeniden dağıtılır.',
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Widget goalCard(Goal goal, {bool featured = false}) {
    final saved = s.saved(goal),
        ratio = (s.saved(goal) / goal.target).clamp(0.0, 1.0);
    final colors = financeColors(context);
    final completed = saved >= goal.target;
    final accent = completed ? colors.positive : colors.accent;
    final text = completed ? colors.completedText : colors.goalText;
    final muted = completed ? colors.completedMuted : colors.goalMuted;
    final monthlyNeeded = requiredMonthlySaving(goal, saved, DateTime.now());
    final projected = projectedGoalDate(goal, saved, DateTime.now());
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
          if (goal.targetDate != null || goal.monthlyContribution != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (goal.targetDate != null)
                    Text(
                      'Hedef tarihi: ${dateLabel(goal.targetDate!)}',
                      style: TextStyle(color: text, fontSize: 11),
                    ),
                  if (!completed && goal.targetDate != null)
                    Text(
                      monthsUntil(DateTime.now(), goal.targetDate!) == 0
                          ? 'Hedef tarihi geçti veya bugün'
                          : '${monthsUntil(DateTime.now(), goal.targetDate!)} ay kaldı',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                  if (goal.monthlyContribution != null)
                    Text(
                      'Aylık plan: ${money(goal.monthlyContribution!)}',
                      style: TextStyle(color: text, fontSize: 11),
                    ),
                  if (!completed && monthlyNeeded != null)
                    Text(
                      'Zamanında ulaşmak için ayda yaklaşık ${money(monthlyNeeded)} gerekli',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (!completed && projected != null)
                    Text(
                      'Planına göre tahmini bitiş: ${dateLabel(projected)}',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
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
  void entryFilters() {
    DateTimeRange? range = entryDateRange;
    var minText = entryMinAmount == null
        ? ''
        : (entryMinAmount! / 100).toStringAsFixed(2).replaceAll('.', ',');
    var maxText = entryMaxAmount == null
        ? ''
        : (entryMaxAmount! / 100).toStringAsFixed(2).replaceAll('.', ',');
    bool? repeat = recurringFilter;
    var order = entrySort;
    String? error;
    sheet(
      context,
      StatefulBuilder(
        builder: (dialogContext, update) => FormShell(
          title: 'Filtrele ve sırala',
          subtitle: 'Aradığın hareketleri kolayca bul.',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.date_range_rounded),
              title: Text(
                range == null
                    ? 'Tüm tarihler'
                    : '${dateLabel(range!.start)} – ${dateLabel(range!.end)}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: dialogContext,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  initialDateRange: range,
                );
                if (picked != null) update(() => range = picked);
              },
            ),
            if (range != null)
              TextButton(
                onPressed: () => update(() => range = null),
                child: const Text('Tarih aralığını temizle'),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: minText,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'En az',
                      suffixText: '₺',
                    ),
                    onChanged: (value) => minText = value,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: maxText,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'En çok',
                      suffixText: '₺',
                    ),
                    onChanged: (value) => maxText = value,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: repeat == null ? 0 : (repeat == true ? 1 : 2),
              decoration: const InputDecoration(labelText: 'Tekrarlama'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Tümü')),
                DropdownMenuItem(value: 1, child: Text('Tekrarlayan')),
                DropdownMenuItem(value: 2, child: Text('Tek seferlik')),
              ],
              onChanged: (value) => repeat = value == 0 ? null : value == 1,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: order,
              decoration: const InputDecoration(labelText: 'Sıralama'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('En yeni')),
                DropdownMenuItem(value: 1, child: Text('En eski')),
                DropdownMenuItem(
                  value: 2,
                  child: Text('Tutar: yüksekten düşüğe'),
                ),
                DropdownMenuItem(
                  value: 3,
                  child: Text('Tutar: düşükten yükseğe'),
                ),
              ],
              onChanged: (value) => order = value ?? 0,
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: financeColors(context).negative),
              ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                final min = minText.trim().isEmpty ? null : parseMoney(minText);
                final max = maxText.trim().isEmpty ? null : parseMoney(maxText);
                if ((minText.trim().isNotEmpty && min == null) ||
                    (maxText.trim().isNotEmpty && max == null) ||
                    (min != null && max != null && min > max)) {
                  update(() => error = 'Tutar aralığını kontrol et.');
                  return;
                }
                setState(() {
                  entryDateRange = range;
                  entryMinAmount = min;
                  entryMaxAmount = max;
                  recurringFilter = repeat;
                  entrySort = order;
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('Uygula'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  entryDateRange = null;
                  entryMinAmount = null;
                  entryMaxAmount = null;
                  recurringFilter = null;
                  entrySort = 0;
                  categoryFilter = null;
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('Tüm filtreleri temizle'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> entryPage() {
    final availableCategories =
        s.sorted
            .where((e) => entryFilter == 0 || e.income == (entryFilter == 1))
            .map((e) => e.category)
            .toSet()
            .toList()
          ..sort();
    if (categoryFilter != null &&
        !availableCategories.contains(categoryFilter)) {
      categoryFilter = null;
    }
    final data = s.sorted
        .where(
          (e) =>
              (entryFilter == 0 || e.income == (entryFilter == 1)) &&
              (categoryFilter == null || e.category == categoryFilter) &&
              (entryDateRange == null ||
                  (!day(e.date).isBefore(day(entryDateRange!.start)) &&
                      !day(e.date).isAfter(day(entryDateRange!.end)))) &&
              (entryMinAmount == null || e.amount >= entryMinAmount!) &&
              (entryMaxAmount == null || e.amount <= entryMaxAmount!) &&
              (recurringFilter == null ||
                  (e.rule != null) == recurringFilter) &&
              '${e.title} ${e.category} ${e.note}'.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    if (entrySort == 1) {
      data.sort((a, b) => a.date.compareTo(b.date));
    } else if (entrySort == 2) {
      data.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (entrySort == 3) {
      data.sort((a, b) => a.amount.compareTo(b.amount));
    }
    final rules = s.rules
        .where(
          (r) =>
              r.active &&
              !r.isBill &&
              (entryFilter == 0 || r.income == (entryFilter == 1)) &&
              (categoryFilter == null || r.category == categoryFilter),
        )
        .toList();
    final bills = s.rules
        .where(
          (r) =>
              r.isBill &&
              entryFilter != 1 &&
              (categoryFilter == null || r.category == categoryFilter),
        )
        .toList();
    final colors = financeColors(context);
    final darkTheme = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = entryFilter == 2 ? colors.negative : colors.positive;
    return [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: List.generate(3, (index) {
            final selected = entryFilter == index;
            final color = index == 2 ? colors.negative : colors.positive;
            final labels = ['Tümü', 'Gelirler', 'Giderler'];
            final icons = [
              Icons.grid_view_rounded,
              Icons.south_west_rounded,
              Icons.north_east_rounded,
            ];
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      entryFilter = index;
                      categoryFilter = null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: s.motion ? 280 : 0),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: darkTheme ? .23 : .13)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? color.withValues(alpha: .35)
                            : Colors.transparent,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: .12),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icons[index],
                          size: 16,
                          color: selected
                              ? color
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              labels[index],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: selected
                                    ? color
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
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
      const SizedBox(height: 16),
      AnimatedContainer(
        duration: Duration(milliseconds: s.motion ? 330 : 0),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              selectedColor.withValues(alpha: darkTheme ? .22 : .13),
              Theme.of(context).colorScheme.surface,
            ],
          ),
          border: Border.all(color: selectedColor.withValues(alpha: .16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_graph_rounded, size: 17, color: selectedColor),
                const SizedBox(width: 8),
                Eyebrow('TÜM ZAMANLAR'),
              ],
            ),
            const SizedBox(height: 18),
            if (entryFilter == 0)
              Row(
                children: [
                  Expanded(
                    child: _entrySummaryMetric(
                      'GELİR',
                      s.income,
                      colors.positive,
                      Icons.south_west_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _entrySummaryMetric(
                      'GİDER',
                      s.expense,
                      colors.negative,
                      Icons.north_east_rounded,
                    ),
                  ),
                ],
              )
            else
              _entrySummaryMetric(
                entryFilter == 1 ? 'TOPLAM GELİR' : 'TOPLAM GİDER',
                entryFilter == 1 ? s.income : s.expense,
                selectedColor,
                entryFilter == 1
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                large: true,
              ),
            const SizedBox(height: 17),
            Divider(color: selectedColor.withValues(alpha: .18), height: 1),
            const SizedBox(height: 12),
            Text(
              '${data.length} kayıt · ${rules.length} aktif tekrar',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      if (bills.isNotEmpty) ...[
        heading('Düzenli ödemeler'),
        ...bills.map(billCard),
      ],
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
      heading('Kayıtların', action: '+ Ekle', onTap: addMenu),
      OutlinedButton.icon(
        onPressed: entryFilters,
        icon: const Icon(Icons.filter_list_rounded),
        label: Text(
          entryDateRange == null &&
                  entryMinAmount == null &&
                  entryMaxAmount == null &&
                  recurringFilter == null &&
                  entrySort == 0
              ? 'Filtrele ve sırala'
              : 'Filtreler etkin · düzenle',
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey('category-$entryFilter-$categoryFilter'),
        initialValue: categoryFilter,
        decoration: const InputDecoration(labelText: 'Kategoriye göre göster'),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('Tüm kategoriler'),
          ),
          ...availableCategories.map(
            (c) => DropdownMenuItem(value: c, child: Text(c)),
          ),
        ],
        onChanged: (value) => setState(() => categoryFilter = value),
      ),
      const SizedBox(height: 12),
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
          onTap: addMenu,
          icon: Icons.receipt_long_outlined,
        )
      else
        Panel(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Column(children: data.map(entryTile).toList()),
        ),
    ];
  }

  Widget billCard(RepeatRule rule) {
    final paid = s.entries.where((e) => e.rule == rule.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final period = rule.automaticPayment
        ? rule.cursor
        : s.firstUnpaidBillPeriod(rule);
    final due = rule.occurrence(period);
    final overdue = !rule.automaticPayment && due.isBefore(day(DateTime.now()));
    final yearly = switch (rule.frequency) {
      1 => rule.amount * 365,
      2 => rule.amount * 52,
      3 => rule.amount * 12,
      _ => rule.amount,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  color: overdue
                      ? financeColors(context).negative
                      : financeColors(context).accent,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    rule.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  money(rule.amount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${rule.automaticPayment
                  ? 'Otomatik kayıt'
                  : !rule.active
                  ? 'Durduruldu'
                  : overdue
                  ? 'Gecikti'
                  : 'Ödeme bekliyor'} · ${dateLabel(due)}',
              style: TextStyle(
                fontSize: 12,
                color: overdue
                    ? financeColors(context).negative
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (paid.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Son ödeme: ${dateLabel(paid.first.date)} · Ödendi',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${rule.category} · ${frequencies[rule.frequency]} · Sonraki vade ${dateLabel(due)}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Aylık yaklaşık ${money((yearly / 12).round())} · Yıllık yaklaşık ${money(yearly)}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (rule.active &&
                !rule.automaticPayment &&
                !due.isAfter(day(DateTime.now()))) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await s.markBillPaid(rule, period);
                    if (mounted) setState(() {});
                    toast('Ödeme kaydedildi.');
                  } catch (_) {
                    toast('Ödeme kaydedilemedi.');
                  }
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Ödendi olarak işaretle'),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => editBill(rule),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Düzenle'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await s.change(() => rule.active = !rule.active);
                      if (mounted) setState(() {});
                    },
                    icon: Icon(
                      rule.active
                          ? Icons.pause_circle_outline_rounded
                          : Icons.play_circle_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      rule.active
                          ? 'Gelecek ödemeleri durdur'
                          : 'Ödemeleri sürdür',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> editBill(RepeatRule rule) async {
    var title = rule.title;
    var amount = (rule.amount / 100).toStringAsFixed(2).replaceAll('.', ',');
    var category = rule.category;
    final firstFuturePeriod = rule.automaticPayment
        ? rule.cursor
        : s.firstUnpaidBillPeriod(rule);
    final applicableDueChanges =
        rule.dueDayChanges.keys
            .where((period) => period <= firstFuturePeriod)
            .toList()
          ..sort();
    var dueDay =
        (applicableDueChanges.isEmpty
                ? rule.start.day
                : rule.dueDayChanges[applicableDueChanges.last]!)
            .toString();
    var error = '';
    await sheet(
      context,
      StatefulBuilder(
        builder: (dialogContext, update) => FormShell(
          title: 'Düzenli ödemeyi düzenle',
          subtitle:
              'Değişiklikler sonraki gider kayıtlarına uygulanır. Önceki ödemeler korunur.',
          children: [
            TextFormField(
              initialValue: title,
              decoration: const InputDecoration(labelText: 'Ad'),
              onChanged: (value) => title = value,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Tutar',
                suffixText: '₺',
              ),
              onChanged: (value) => amount = value,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: {category, ...s.expenseCategories}
                  .map(
                    (name) => DropdownMenuItem(value: name, child: Text(name)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) category = value;
              },
            ),
            if (rule.frequency == 3 || rule.frequency == 4) ...[
              const SizedBox(height: 12),
              TextFormField(
                initialValue: dueDay,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Vade günü (1–31)',
                  helperText: 'Kısa aylarda son güne uyarlanır.',
                ),
                onChanged: (value) => dueDay = value,
              ),
            ],
            if (error.isNotEmpty)
              Text(
                error,
                style: TextStyle(color: financeColors(context).negative),
              ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                final cents = parseMoney(amount);
                final parsedDay = int.tryParse(dueDay);
                if (title.trim().isEmpty ||
                    cents == null ||
                    parsedDay == null ||
                    parsedDay < 1 ||
                    parsedDay > 31) {
                  update(() => error = 'Ad, tutar ve vade gününü kontrol et.');
                  return;
                }
                try {
                  await s.change(() {
                    rule.title = title.trim();
                    rule.amount = cents;
                    rule.category = category;
                    if (rule.frequency == 3 || rule.frequency == 4) {
                      rule.dueDayChanges[firstFuturePeriod] = parsedDay;
                    }
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (_) {
                  update(() => error = 'Kaydedilemedi.');
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entrySummaryMetric(
    String label,
    int value,
    Color color,
    IconData icon, {
    bool large = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            money(value),
            maxLines: 1,
            style: TextStyle(
              fontSize: large ? 31 : 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
        ),
      ),
    ],
  );

  List<Widget> walletPage() {
    final accent = financeColors(context).accent;
    final labels = ['Tümü', 'Birikim', 'Bütçe'];
    final icons = [
      Icons.grid_view_rounded,
      Icons.savings_rounded,
      Icons.donut_large_rounded,
    ];
    return [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: List.generate(3, (index) {
            final selected = walletFilter == index;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => walletFilter = index);
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: s.motion ? 280 : 0),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: selected
                          ? accent.withValues(alpha: .16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? accent.withValues(alpha: .34)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icons[index],
                          size: 16,
                          color: selected
                              ? accent
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              labels[index],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: selected
                                    ? accent
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
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
      const SizedBox(height: 18),
      if (walletFilter != 2) ...goalPage(),
      if (walletFilter == 0) heading('Bütçen'),
      if (walletFilter != 1) BudgetPage(store: s),
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

  List<Widget> profilePage() {
    final colors = financeColors(context);
    final scheme = Theme.of(context).colorScheme;
    return [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.accent.withValues(alpha: .22),
              colors.positive.withValues(alpha: .10),
            ],
          ),
          border: Border.all(color: colors.accent.withValues(alpha: .20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: .20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.person_rounded, size: 34, color: colors.accent),
            ),
            const SizedBox(height: 18),
            const Text(
              'Senin alanın',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -.7,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Finans yolculuğun bu cihazda, senin kontrolünde.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.positive.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.offline_bolt_rounded,
                    size: 15,
                    color: colors.positive,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Yalnızca bu cihazda',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.positive,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      heading('Birikio özetin'),
      Row(
        children: [
          Expanded(
            child: _profileStat(
              'KAYIT',
              '${s.entries.length}',
              Icons.receipt_long_rounded,
              colors.positive,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _profileStat(
              'HEDEF',
              '${s.goals.length}',
              Icons.savings_rounded,
              colors.accent,
            ),
          ),
        ],
      ),
      heading('Tercihlerin'),
      Panel(
        padding: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 8,
          ),
          leading: Icon(Icons.category_outlined, color: colors.positive),
          title: const Text(
            'Kategoriler',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('Gelir ve gider kategorilerini düzenle'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: manageCategories,
        ),
      ),
      const SizedBox(height: 12),
      Panel(
        padding: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 8,
          ),
          leading: Icon(Icons.tune_rounded, color: colors.accent),
          title: const Text(
            'Ayarlar',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('Tema, animasyonlar ve verilerin'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: settings,
        ),
      ),
    ];
  }

  Widget _profileStat(String label, String value, IconData icon, Color color) =>
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );

  void manageCategories() => sheet(
    context,
    StatefulBuilder(
      builder: (dialogContext, update) => FormShell(
        title: 'Kategoriler',
        subtitle:
            'Adı değiştirince ilişkili kayıtlar ve tekrarlar güncellenir. Silinen kategorinin geçmiş kayıtları korunur.',
        children: [
          for (final income in [true, false]) ...[
            Text(
              income ? 'Gelir kategorileri' : 'Gider kategorileri',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final name in [...s.categoriesFor(income)])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(name),
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      tooltip: '$name düzenle',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final next = await categoryNameDialog(name);
                        if (next == null) return;
                        try {
                          await s.change(
                            () => s.renameCategory(income, name, next),
                          );
                          update(() {});
                          if (mounted) setState(() {});
                        } catch (_) {
                          toast(
                            'Kategori adı değiştirilemedi. Adı kontrol et.',
                          );
                        }
                      },
                    ),
                    IconButton(
                      tooltip: '$name sil',
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: financeColors(context).negative,
                      ),
                      onPressed: () async {
                        final ok = await confirm(
                          dialogContext,
                          'Kategori silinsin mi?',
                          '$name yeni kayıtlarda görünmeyecek. Eski işlemler ve tekrarlar kendi kategori adıyla kalacak.',
                        );
                        if (!ok) return;
                        try {
                          await s.change(() => s.removeCategory(income, name));
                          update(() {});
                          if (mounted) setState(() {});
                        } catch (_) {
                          toast('Kategori silinemedi.');
                        }
                      },
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              onPressed: () async {
                final name = await categoryNameDialog();
                if (name == null) return;
                try {
                  await s.change(() => s.addCategory(income, name));
                  update(() {});
                  if (mounted) setState(() {});
                } catch (_) {
                  toast('Kategori eklenemedi. Adı kontrol et.');
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Kategori ekle'),
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    ),
  );

  Future<String?> categoryNameDialog([String initial = '']) async {
    var value = initial;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          initial.isEmpty ? 'Yeni kategori' : 'Kategori adını değiştir',
        ),
        content: TextFormField(
          autofocus: true,
          maxLength: 40,
          initialValue: initial,
          onChanged: (text) => value = text,
          decoration: const InputDecoration(labelText: 'Kategori adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, value),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> exportData({required bool csv}) async {
    try {
      final name = csv ? 'birikio-islemler.csv' : 'birikio-yedek.json';
      final location = await getSaveLocation(suggestedName: name);
      if (location == null) return;
      final content = csv ? createCsv(s) : createBackup(s);
      await XFile.fromData(
        Uint8List.fromList(utf8.encode(content)),
        name: name,
        mimeType: csv ? 'text/csv' : 'application/json',
      ).saveTo(location.path);
      toast(csv ? 'CSV dışa aktarıldı.' : 'Yedek kaydedildi.');
    } catch (_) {
      toast('Dosya kaydedilemedi.');
    }
  }

  Future<void> importData(BuildContext dialogContext) async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Birikio JSON',
            extensions: ['json'],
            mimeTypes: ['application/json'],
          ),
        ],
      );
      if (file == null || !file.name.toLowerCase().endsWith('.json')) return;
      final raw = await file.readAsString();
      final data = parseBackup(raw);
      if (!dialogContext.mounted) return;
      final ok = await confirm(
        dialogContext,
        'Yedek geri yüklensin mi?',
        'Mevcut ${s.entries.length} işlem, ${s.goals.length} hedef ve bütçeler yedekteki ${(data['entries'] as List).length} işlem ve ${(data['goals'] as List).length} hedefle değişecek. Bu işlem mevcut verinin üzerine yazar.',
      );
      if (!ok) return;
      await restoreBackup(s, raw);
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      toast('Yedek geri yüklendi.');
    } catch (_) {
      toast('Yedek açılamadı veya doğrulanamadı. Mevcut veriler korundu.');
    }
  }

  Future<void> chooseWidget() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => const WidgetPickerDialog(),
    );
    if (selected == null) return;
    try {
      await HomeWidget.requestPinWidget(androidName: selected);
    } catch (_) {
      toast(
        'Widget eklenemedi. Ana ekranın widget listesinden deneyebilirsin.',
      );
    }
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
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Bütçe ve fatura bildirimleri'),
            subtitle: const Text('Limit eşikleri ve yaklaşan manuel ödemeler'),
            value: s.notificationsEnabled,
            onChanged: (enabled) async {
              if (enabled) {
                try {
                  final granted = await LocalNotifications.instance
                      .requestPermission();
                  if (!granted) {
                    toast(
                      'Bildirim izni verilmedi. Uygulama içi uyarılar çalışır.',
                    );
                    return;
                  }
                } catch (_) {
                  toast('Bildirim izni alınamadı.');
                  return;
                }
              }
              if (await mutate(() => s.notificationsEnabled = enabled)) {
                if (!enabled) await LocalNotifications.instance.cancelAll();
                if (context.mounted) update(() {});
              }
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.widgets_outlined),
            title: const Text('Widget’ta bakiyeyi göster'),
            subtitle: const Text(
              'Kapalıyken yalnızca hedef ilerlemesi görünür.',
            ),
            value: s.showWidgetBalance,
            onChanged: (value) async {
              await mutate(() => s.showWidgetBalance = value);
              if (context.mounted) update(() {});
            },
          ),
          if (Platform.isAndroid)
            TextButton.icon(
              onPressed: chooseWidget,
              icon: const Icon(Icons.add_to_home_screen_rounded),
              label: const Text('Beş widget boyutundan birini seç'),
            ),
          SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.auto_awesome_outlined),
            title: Text('Görsel animasyonlar'),
            subtitle: Text('Hareketli hedefler ve kayıt anı ışık efektleri'),
            value: s.motion,
            onChanged: (v) async {
              await mutate(() => s.motion = v);
              if (context.mounted) update(() {});
            },
          ),
          SizedBox(height: 16),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Eyebrow('VERİLERİM'),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => exportData(csv: false),
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('JSON yedek oluştur'),
                ),
                TextButton.icon(
                  onPressed: () => importData(context),
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Yedekten geri yükle'),
                ),
                TextButton.icon(
                  onPressed: () => exportData(csv: true),
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('İşlemleri CSV dışa aktar'),
                ),
              ],
            ),
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
          const Center(child: AppVersion()),
        ],
      ),
    ),
  );
}
