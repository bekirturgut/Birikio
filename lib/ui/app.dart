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
import '../data/annual_radar.dart';
import '../data/backup.dart';
import '../data/financial_health.dart';
import '../data/goal_plan.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/local_notifications.dart';
import '../services/home_summary_widget.dart';
import '../services/document_export.dart';
import 'widgets.dart';
import 'palette.dart';
import 'forms.dart';
import 'reports.dart';
import 'brand.dart';
import 'launch.dart';
import 'widget_picker.dart';
import 'app_version.dart';
import 'orbit_chart.dart';
import 'annual_radar.dart';
import 'recurring_editor.dart';
import 'money_input.dart';

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
        fillColor: dark ? const Color(0xFF111827) : const Color(0xFFF3F5FA),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 18,
        ),
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
  int pageDirection = 1;
  String query = '';
  final entrySearch = TextEditingController();
  int entryFilter = 0; // 0: all, 1: income, 2: expense
  DateTime entryMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool entryAllMonths = false;
  int entryView = 0;
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
    entrySearch.dispose();
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
    final previousEntries = s.entries.map((e) => e.id).toSet();
    final previousPlans = s.scheduledExpenses.map((e) => e.id).toSet();
    final previousRules = s.rules.map((e) => e.id).toSet();
    final ok = await sheet<bool>(
      context,
      EntryForm(store: s, income: income, entry: entry),
    );
    if (ok == true && mounted) {
      if (entry == null) {
        final addedEntry = s.entries
            .where((e) => !previousEntries.contains(e.id))
            .firstOrNull;
        final addedPlan = s.scheduledExpenses
            .where((e) => !previousPlans.contains(e.id))
            .firstOrNull;
        final addedRule = s.rules
            .where((e) => !previousRules.contains(e.id))
            .firstOrNull;
        final date =
            addedPlan?.due ??
            addedEntry?.date ??
            addedRule?.start ??
            DateTime.now();
        setState(() {
          page = 1;
          entryView = 0;
          entryFilter = income ? 1 : 2;
          entryMonth = DateTime(date.year, date.month);
          entryAllMonths = false;
          entrySort = 0;
          query = '';
          entrySearch.clear();
          categoryFilter = null;
          entryDateRange = null;
          entryMinAmount = null;
          entryMaxAmount = null;
          recurringFilter = null;
        });
      }
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
    if (i == page) return;
    HapticFeedback.selectionClick();
    setState(() {
      pageDirection = i > page ? 1 : -1;
      page = i;
      query = '';
      entrySearch.clear();
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
                      duration: Duration(milliseconds: reduced ? 0 : 220),
                      reverseDuration: Duration(
                        milliseconds: reduced ? 0 : 180,
                      ),
                      transitionBuilder: (child, a) => CinematicPageTransition(
                        animation: a,
                        entering: child.key == ValueKey(page),
                        direction: pageDirection,
                        child: child,
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(page),
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(18, 6, 18, 100),
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                IconBadge(
                                  [
                                    Icons.space_dashboard_rounded,
                                    Icons.swap_vert_rounded,
                                    Icons.account_balance_wallet_outlined,
                                    Icons.insights_rounded,
                                    Icons.person_outline_rounded,
                                  ][page],
                                  size: 46,
                                ),
                                const SizedBox(width: 12),
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
                                            : [
                                                'GENEL BAKIŞ',
                                                'PARA HAREKETLERİ',
                                                'BİRİKİM VE PLAN',
                                                'FİNANSAL GÖRÜNÜM',
                                                'KİŞİSEL ALAN',
                                              ][page],
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        titles[page],
                                        style: TextStyle(
                                          fontSize: 23,
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
                            if (page == 1)
                              _tabbedPage(entryPage(), entryFilter, 'entry'),
                            if (page == 2)
                              _tabbedPage(walletPage(), walletFilter, 'wallet'),
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
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
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

  Widget _tabbedPage(List<Widget> sections, int selected, String scope) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...sections.take(2),
          AnimatedSwitcher(
            duration: Duration(milliseconds: s.motion ? 200 : 0),
            reverseDuration: Duration(milliseconds: s.motion ? 150 : 0),
            transitionBuilder: (child, animation) =>
                BlurTabTransition(animation: animation, child: child),
            child: Column(
              key: ValueKey('$scope-$selected'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: sections.skip(2).toList(),
            ),
          ),
        ],
      );

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
              (r.endDate == null ||
                  !r
                      .occurrence(s.firstUnpaidBillPeriod(r))
                      .isAfter(day(r.endDate!))) &&
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
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: allEntries,
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('Kayıtlar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                navigate(1);
                setState(() => entryView = 1);
              },
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text('Takvim'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

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
        entryView = 0;
        entryMonth = DateTime(DateTime.now().year, DateTime.now().month);
        entryAllMonths = false;
        categoryFilter = null;
        entryDateRange = null;
        entryMinAmount = null;
        entryMaxAmount = null;
        recurringFilter = null;
        entrySort = 0;
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
              health.attention ?? health.observations.first,
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
        const SectionCard(
          title: 'Puan nasıl hesaplanır?',
          icon: Icons.calculate_outlined,
          action: InfoButton(
            title: 'Puan ağırlıkları',
            message:
                'Gelir–gider %25 · Birikim hareketleri %20 · Aylık birikim sözü %15 · Faturalar %15 · Bütçe %15 · Gelir düzeni %10 · Aylık gidişat %7 · Bakiye %5 · Harcama dağılımı %3. Veri olmayan alanlar puana katılmaz; kalan ağırlıklar yeniden dağıtılır.',
          ),
          child: Text(
            'Yalnızca kayıt bulunan alanlar değerlendirilir.',
            style: TextStyle(fontSize: 12),
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
    final monthlyStatus = monthlyGoalStatus(goal, s.transfers, DateTime.now());
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
                  if (monthlyStatus != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      monthlyStatus.duePassed && monthlyStatus.missing > 0
                          ? 'Bu ay ${money(monthlyStatus.missing)} eksik yatırdın.'
                          : monthlyStatus.late
                          ? 'Bu ayki birikim sözünü gecikmeli tamamladın.'
                          : monthlyStatus.missing == 0
                          ? 'Bu ayki birikim sözünü tamamladın ✓'
                          : '${monthlyStatus.dueDate.day} ${months[monthlyStatus.dueDate.month - 1]} gününe kadar ${money(monthlyStatus.missing)} daha yatır.',
                      style: TextStyle(
                        color:
                            monthlyStatus.duePassed &&
                                (monthlyStatus.missing > 0 ||
                                    monthlyStatus.late)
                            ? colors.negative
                            : accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (!completed &&
                      goal.monthlyDueDay != null &&
                      monthlyStatus == null)
                    Text(
                      'Aylık takip sonraki uygun ayda başlayacak.',
                      style: TextStyle(color: muted, fontSize: 11),
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
              final saved = await mutate(() => s.removeEntry(e.id));
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
    var minText = entryMinAmount == null ? '' : moneyInput(entryMinAmount!);
    var maxText = entryMaxAmount == null ? '' : moneyInput(entryMaxAmount!);
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
                  lastDate: DateTime(2100, 12, 31),
                  initialDateRange:
                      range ??
                      DateTimeRange(
                        start: DateTime(
                          entryMonth.year.clamp(2000, 2100),
                          entryMonth.month,
                        ),
                        end: DateTime(
                          entryMonth.year.clamp(2000, 2100),
                          entryMonth.month + 1,
                          0,
                        ),
                      ),
                  fieldStartLabelText: 'Başlangıç',
                  fieldEndLabelText: 'Bitiş',
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
                    inputFormatters: const [MoneyInputFormatter()],
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
                    inputFormatters: const [MoneyInputFormatter()],
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

  Widget sectionTabs(
    List<String> labels,
    int selected,
    ValueChanged<int> onChanged,
  ) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: List.generate(
        labels.length,
        (i) => Expanded(
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: selected == i
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: .15)
                  : Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => onChanged(i),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_tabIcon(labels[i]), size: 16),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected == i
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  IconData _tabIcon(String label) => switch (label) {
    'Kayıtlar' => Icons.receipt_long_rounded,
    'Yıllık radar' => Icons.calendar_month_rounded,
    'Düzenli' => Icons.autorenew_rounded,
    'Gelirler' => Icons.south_west_rounded,
    'Giderler' => Icons.north_east_rounded,
    'Birikim' => Icons.savings_outlined,
    'Bütçe' => Icons.donut_large_rounded,
    _ => Icons.grid_view_rounded,
  };

  void openRecords<T>(
    String title,
    String scope,
    List<T> Function() items,
    Widget Function(T) builder,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordListPage<T>(
          store: s,
          title: title,
          scope: scope,
          items: items,
          itemBuilder: builder,
        ),
      ),
    );
  }

  List<Widget> entryPage() {
    final colors = financeColors(context);
    final start = DateTime(entryMonth.year, entryMonth.month);
    final end = DateTime(entryMonth.year, entryMonth.month + 1);
    bool dateMatches(DateTime d) =>
        entryAllMonths || (!d.isBefore(start) && d.isBefore(end));
    bool typeMatches(bool income) =>
        entryFilter == 0 || income == (entryFilter == 1);
    List<RadarExpense> scopedPlans() {
      final result = annualRadarItems(
        s,
        entryMonth.year,
      ).where((p) => !p.paid).toList();
      if (entryAllMonths) {
        for (final p in s.scheduledExpenses.where(
          (p) => p.paidAt == null && p.due.year != entryMonth.year,
        )) {
          result.add(
            RadarExpense(
              id: p.id,
              title: p.title,
              category: p.category,
              amount: p.amount,
              due: p.due,
              fromRule: false,
              scheduled: true,
              income: p.income,
            ),
          );
        }
      }
      return result.where((p) => dateMatches(p.due)).toList();
    }

    final monthEntries = s.sorted.where((e) => dateMatches(e.date)).toList();
    final categories = <String>{
      ...monthEntries
          .where((e) => typeMatches(e.income))
          .map((e) => e.category),
      ...scopedPlans()
          .where((p) => dateMatches(p.due) && typeMatches(p.income))
          .map((p) => p.category),
    }.toList()..sort();
    if (!categories.contains(categoryFilter)) categoryFilter = null;
    bool matches(
      String title,
      String category,
      String note,
      int amount,
      DateTime date,
      bool recurring,
    ) =>
        (categoryFilter == null || category == categoryFilter) &&
        (entryDateRange == null ||
            (!day(date).isBefore(day(entryDateRange!.start)) &&
                !day(date).isAfter(day(entryDateRange!.end)))) &&
        (entryMinAmount == null || amount >= entryMinAmount!) &&
        (entryMaxAmount == null || amount <= entryMaxAmount!) &&
        (recurringFilter == null || recurring == recurringFilter) &&
        '$title $category $note'.toLowerCase().contains(query.toLowerCase());
    List<Entry> records() {
      final data = s.sorted
          .where((e) => dateMatches(e.date))
          .where(
            (e) =>
                typeMatches(e.income) &&
                matches(
                  e.title,
                  e.category,
                  e.note,
                  e.amount,
                  e.date,
                  e.rule != null,
                ),
          )
          .toList();
      if (entrySort == 1) data.sort((a, b) => a.date.compareTo(b.date));
      if (entrySort == 2) data.sort((a, b) => b.amount.compareTo(a.amount));
      if (entrySort == 3) data.sort((a, b) => a.amount.compareTo(b.amount));
      return data;
    }

    final data = records();
    List<RadarExpense> plans() {
      final result = scopedPlans()
          .where(
            (p) =>
                typeMatches(p.income) &&
                matches(
                  p.title,
                  p.category,
                  pendingNote(p),
                  p.amount,
                  p.due,
                  p.fromRule,
                ),
          )
          .toList();
      result.sort(
        (a, b) => switch (entrySort) {
          1 => a.due.compareTo(b.due),
          2 => b.amount.compareTo(a.amount),
          3 => a.amount.compareTo(b.amount),
          _ => b.due.compareTo(a.due),
        },
      );
      return result;
    }

    final pending = plans();
    final expected = scopedPlans();
    final expectedIncome = expected
        .where((p) => p.income)
        .fold<int>(0, (v, p) => v + p.amount);
    final expectedExpense = expected
        .where((p) => !p.income)
        .fold<int>(0, (v, p) => v + p.amount);

    final filtered =
        query.isNotEmpty ||
        categoryFilter != null ||
        entryDateRange != null ||
        entryMinAmount != null ||
        entryMaxAmount != null ||
        recurringFilter != null;
    final scope = entryAllMonths
        ? 'Tüm geçmiş · düzenli/yıllık vadeler: ${entryMonth.year}'
        : '${dateLabel(start)} · seçili ay';
    final prefix = <Widget>[
      sectionTabs(
        ['Kayıtlar', 'Yıllık radar', 'Düzenli'],
        entryView,
        (v) => setState(() => entryView = v),
      ),
      const SizedBox(height: 16),
    ];
    if (entryView == 1) return [...prefix, AnnualRadar(store: s)];
    if (entryView == 2) {
      return [
        ...prefix,
        FeatureCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconBadge(Icons.autorenew_rounded, size: 40),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Düzenli gelir ve ödemeler',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const InfoButton(
                    title: 'Düzenli kayıtlar',
                    message:
                        'Seriyi durdurabilir, bitiş tarihini değiştirebilir veya geçmiş kayıtlarını koruyarak silebilirsin. Yeni seri için + düğmesindeki gelir veya gider formunda tekrarlama seç.',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _profileMetric(
                      '${s.rules.where((r) => r.active).length}',
                      'Aktif seri',
                      Icons.play_circle_outline,
                    ),
                  ),
                  Expanded(
                    child: _profileMetric(
                      '${s.rules.where((r) => r.income).length}',
                      'Gelir',
                      Icons.south_west_rounded,
                    ),
                  ),
                  Expanded(
                    child: _profileMetric(
                      '${s.rules.where((r) => !r.income).length}',
                      'Ödeme',
                      Icons.north_east_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (s.rules.isEmpty)
          const EmptyState(
            title: 'Henüz düzenli kayıt yok',
            subtitle: '+ menüsünden gelir veya gider ekleyip tekrarlama seç.',
            icon: Icons.autorenew_rounded,
          ),
        ...s.rules
            .take(5)
            .map((r) => r.isBill ? billCard(r) : regularRecordCard(r)),
        if (s.rules.length > 5)
          OutlinedButton.icon(
            onPressed: () => openRecords<RepeatRule>(
              'Düzenli kayıtlar',
              'Tüm seriler',
              () => s.rules.toList(),
              (r) => r.isBill ? billCard(r) : regularRecordCard(r),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text('Tümünü gör (${s.rules.length})'),
          ),
      ];
    }
    final income = monthEntries
        .where((e) => e.income)
        .fold<int>(0, (v, e) => v + e.amount);
    final expense = monthEntries
        .where((e) => !e.income)
        .fold<int>(0, (v, e) => v + e.amount);
    return [
      ...prefix,
      FeatureCard(
        key: const ValueKey('monthly-summary'),
        color: colors.positive,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Önceki ay',
                  onPressed: () => setState(() {
                    entryAllMonths = false;
                    entryMonth = DateTime(
                      entryMonth.year,
                      entryMonth.month - 1,
                    );
                  }),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        entryAllMonths
                            ? 'Tüm kayıtlar'
                            : '${const ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'][entryMonth.month - 1]} ${entryMonth.year}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: const Size(0, 32),
                          ),
                          onPressed: () =>
                              setState(() => entryAllMonths = !entryAllMonths),
                          icon: Icon(
                            entryAllMonths
                                ? Icons.calendar_month_outlined
                                : Icons.history_rounded,
                            size: 14,
                          ),
                          label: Text(
                            entryAllMonths
                                ? 'Ay ay göster'
                                : 'Tüm kayıtları göster',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sonraki ay',
                  onPressed: () => setState(() {
                    entryAllMonths = false;
                    entryMonth = DateTime(
                      entryMonth.year,
                      entryMonth.month + 1,
                    );
                  }),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            if (entryAllMonths)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Tüm geçmiş ve tek seferlik planlar · düzenli/yıllık vadeler: ${entryMonth.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: _entrySummaryMetric(
                    'GELİR',
                    income,
                    colors.positive,
                    Icons.south_west_rounded,
                    expected: expectedIncome,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _entrySummaryMetric(
                    'GİDER',
                    expense,
                    colors.negative,
                    Icons.north_east_rounded,
                    expected: expectedExpense,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      sectionTabs(
        ['Tümü', 'Gelirler', 'Giderler'],
        entryFilter,
        (v) => setState(() {
          entryFilter = v;
          categoryFilter = null;
        }),
      ),
      const SizedBox(height: 16),
      TextField(
        key: ValueKey('search-$entryFilter-$entryMonth-$entryAllMonths'),
        controller: entrySearch,
        onChanged: (v) => setState(() => query = v),
        decoration: InputDecoration(
          hintText: 'Kayıtlarda ara',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            tooltip: 'Filtrele ve sırala',
            onPressed: entryFilters,
            icon: const Icon(Icons.tune_rounded),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey('category-$entryFilter-$categoryFilter'),
              initialValue: categoryFilter,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Tüm kategoriler'),
                ),
                ...categories.map(
                  (c) => DropdownMenuItem(value: c, child: Text(c)),
                ),
              ],
              onChanged: (v) => setState(() => categoryFilter = v),
            ),
          ),
          const SizedBox(width: 8),
          if (filtered)
            IconButton(
              tooltip: 'Filtreleri temizle',
              onPressed: () => setState(() {
                query = '';
                entrySearch.clear();
                categoryFilter = null;
                entryDateRange = null;
                entryMinAmount = null;
                entryMaxAmount = null;
                recurringFilter = null;
                entrySort = 0;
              }),
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
        ],
      ),
      Text(
        '${data.length} gerçekleşmiş · ${pending.length} bekleyen kayıt',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 12),
      if (data.isNotEmpty)
        SectionCard(
          title: 'Gerçekleşen kayıtlar',
          icon: Icons.receipt_long_rounded,
          action: data.length > 5
              ? TextButton(
                  onPressed: () => openRecords<Entry>(
                    'Gerçekleşen kayıtlar',
                    scope,
                    records,
                    entryTile,
                  ),
                  child: Text('Tümünü gör (${data.length})'),
                )
              : null,
          child: Column(children: data.take(5).map(entryTile).toList()),
        ),
      if (pending.isNotEmpty) ...[
        const SizedBox(height: 14),
        SectionCard(
          title: 'Bekleyen kayıtlar',
          icon: Icons.schedule_rounded,
          action: pending.length > 5
              ? TextButton(
                  onPressed: () => openRecords<RadarExpense>(
                    'Bekleyen kayıtlar',
                    scope,
                    plans,
                    projectedRecordCard,
                  ),
                  child: Text('Tümünü gör (${pending.length})'),
                )
              : null,
          child: Column(
            children: pending.take(5).map(projectedRecordCard).toList(),
          ),
        ),
      ],
      if (data.isEmpty && pending.isEmpty)
        EmptyState(
          title: filtered
              ? 'Filtreye uygun kayıt yok'
              : entryAllMonths
              ? 'Henüz kayıt yok'
              : 'Bu ay kayıt yok',
          subtitle: filtered
              ? 'Aramayı veya filtreleri temizleyerek diğer kayıtlarını görebilirsin.'
              : s.entries.isNotEmpty ||
                    s.scheduledExpenses.isNotEmpty ||
                    s.rules.isNotEmpty
              ? 'Diğer aylardaki kayıtların saklanıyor. Tüm kayıtları açabilir veya üstteki oklarla ay değiştirebilirsin.'
              : 'Gelir, gider veya birikim için sağ alttaki + düğmesini kullan.',
          action: filtered ? 'Filtreleri temizle' : null,
          onTap: () => setState(() {
            entryAllMonths = true;
            query = '';
            entrySearch.clear();
            categoryFilter = null;
            entryDateRange = null;
            entryMinAmount = null;
            entryMaxAmount = null;
            recurringFilter = null;
          }),
          icon: Icons.event_note_outlined,
        ),
    ];
  }

  String pendingNote(RadarExpense p) => p.fromRule
      ? s.rules.where((r) => r.id == p.id).firstOrNull?.note ?? ''
      : s.scheduledExpenses.where((r) => r.id == p.id).firstOrNull?.note ?? '';

  String pendingStatus(DateTime due) {
    final today = day(DateTime.now());
    return day(due).isBefore(today)
        ? 'Gecikti'
        : day(due) == today
        ? 'Bugün'
        : 'Yaklaşan';
  }

  Widget projectedRecordCard(RadarExpense p) {
    if (p.scheduled) {
      return pendingRecordCard(
        s.scheduledExpenses.firstWhere((r) => r.id == p.id),
      );
    }
    final rule = s.rules.where((r) => r.id == p.id).firstOrNull;
    final colors = financeColors(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: IconBadge(
        Icons.autorenew_rounded,
        color: p.income ? colors.positive : colors.negative,
        size: 36,
      ),
      title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        '${dateLabel(p.due)} · ${pendingStatus(p.due)}\n${p.fromRule ? 'Düzenli' : 'Yıllık ödeme'} · ${p.category}',
      ),
      isThreeLine: true,
      trailing: SizedBox(
        width: 118,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${p.income ? '+' : '−'}${money(p.amount)}',
                style: TextStyle(
                  color: p.income ? colors.positive : colors.negative,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (rule != null)
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Düzenli kaydı düzenle',
                  onPressed: () => editRepeatRule(rule),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
              ),
          ],
        ),
      ),
      onTap: rule == null
          ? () => setState(() => entryView = 1)
          : () => sheet<void>(
              context,
              ListenableBuilder(
                listenable: s,
                builder: (context, _) {
                  if (!s.rules.any((r) => r.id == rule.id)) {
                    final route = ModalRoute.of(context);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted && route?.isActive == true) {
                        Navigator.of(context).removeRoute(route!);
                      }
                    });
                    return const SizedBox.shrink();
                  }
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      MediaQuery.viewInsetsOf(context).bottom + 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        rule.isBill ? billCard(rule) : regularRecordCard(rule),
                        if (rule.note.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(rule.note),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget pendingRecordCard(ScheduledExpense p) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                p.income ? Icons.south_west_rounded : Icons.north_east_rounded,
                color: p.income
                    ? financeColors(context).positive
                    : financeColors(context).negative,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${p.income ? '+' : '−'}${money(p.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: p.income
                      ? financeColors(context).positive
                      : financeColors(context).negative,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${dateLabel(p.due)} · ${pendingStatus(p.due)} · ${p.income ? 'Beklenen gelir' : 'Ödeme bekliyor'}',
            style: const TextStyle(fontSize: 12),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Bekleyen kaydı düzenle',
                onPressed: () => sheet<bool>(
                  context,
                  EntryForm(store: s, income: p.income, scheduled: p),
                ),
                icon: const Icon(Icons.edit_outlined),
              ),
              if (!p.income)
                TextButton(
                  onPressed: () async {
                    try {
                      await s.markScheduledExpensePaid(p);
                    } catch (_) {
                      toast('Ödeme kaydedilemedi.');
                    }
                  },
                  child: const Text('Ödendi'),
                ),
              IconButton(
                tooltip: 'Bekleyen kaydı sil',
                onPressed: () async {
                  if (await confirm(
                    context,
                    'Bekleyen kayıt silinsin mi?',
                    'Bu plan kaldırılır; geçmiş kayıtlar korunur.',
                  )) {
                    await mutate(
                      () =>
                          s.scheduledExpenses.removeWhere((e) => e.id == p.id),
                    );
                  }
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget regularRecordCard(RepeatRule r) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${r.income ? '+' : '−'}${money(r.amount)}',
                style: TextStyle(
                  color: r.income
                      ? financeColors(context).positive
                      : financeColors(context).negative,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${frequencies[r.frequency]} · ${r.active ? 'Sonraki: ${dateLabel(r.occurrence(r.cursor))}' : 'Durduruldu'}',
            style: const TextStyle(fontSize: 12),
          ),
          if (r.endDate != null)
            Text(
              'Bitiş: ${dateLabel(r.endDate!)}',
              style: const TextStyle(fontSize: 12),
            ),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => editRepeatRule(r),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Düzenle'),
              ),
              TextButton.icon(
                onPressed: () => toggleRecurringRule(context, s, r),
                icon: Icon(
                  r.active
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 18,
                ),
                label: Text(r.active ? 'Durdur' : 'Sürdür'),
              ),
              TextButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: r.endDate ?? r.start,
                    firstDate: r.start,
                    lastDate: DateTime(2100),
                  );
                  if (d != null) await mutate(() => r.endDate = d);
                },
                icon: const Icon(Icons.event_busy_outlined, size: 18),
                label: const Text('Bitiş tarihi'),
              ),
              IconButton(
                tooltip: 'Seriyi sil',
                onPressed: () async {
                  if (await confirm(
                    context,
                    'Seri silinsin mi?',
                    'Geçmiş kayıtlar korunur; gelecek tekrarlar kaldırılır.',
                  )) {
                    await mutate(
                      () => s.rules.removeWhere((e) => e.id == r.id),
                    );
                  }
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget billCard(RepeatRule rule) {
    final paid = s.entries.where((e) => e.rule == rule.id).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final period = rule.automaticPayment
        ? rule.cursor
        : s.firstUnpaidBillPeriod(rule);
    final due = rule.occurrence(period);
    final ended = rule.endDate != null && due.isAfter(day(rule.endDate!));
    final overdue =
        rule.active &&
        !ended &&
        !rule.automaticPayment &&
        due.isBefore(day(DateTime.now()));
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
          mainAxisSize: MainAxisSize.min,
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
              '${!rule.active
                  ? 'Durduruldu'
                  : ended
                  ? 'Tamamlandı'
                  : rule.automaticPayment
                  ? 'Otomatik kayıt'
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
            if (rule.endDate != null)
              Text('Bitiş: ${dateLabel(rule.endDate!)}'),
            const SizedBox(height: 4),
            Text(
              'Aylık yaklaşık ${money((yearly / 12).round())} · Yıllık yaklaşık ${money(yearly)}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (rule.active &&
                !ended &&
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
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => editRepeatRule(rule),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Düzenle'),
                  ),
                  IconButton(
                    tooltip: 'Seriyi sil',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      if (await confirm(
                        context,
                        'Düzenli ödeme silinsin mi?',
                        'Gelecek vadeler kaldırılır. Geçmiş gider kayıtları korunur.',
                      )) {
                        await mutate(
                          () => s.rules.removeWhere((r) => r.id == rule.id),
                        );
                      }
                    },
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await toggleRecurringRule(context, s, rule);
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

  Future<void> editRepeatRule(RepeatRule rule) =>
      editRecurringRule(context, s, rule);

  Widget _entrySummaryMetric(
    String label,
    int value,
    Color color,
    IconData icon, {
    bool large = false,
    int? expected,
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
      const SizedBox(height: 4),
      if (expected != null)
        Text(
          'Gerçekleşen',
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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
      if (expected != null) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bekleyen',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  money(expected),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );

  List<Widget> walletPage() => [
    sectionTabs(
      ['Tümü', 'Birikim', 'Bütçe'],
      walletFilter,
      (v) => setState(() => walletFilter = v),
    ),
    const SizedBox(height: 16),
    if (walletFilter != 2) ...goalPage(),
    if (walletFilter == 0) heading('Bütçen'),
    if (walletFilter != 1) BudgetPage(store: s),
  ];

  List<ChartSlice> goalDistributionSlices() {
    final funded = s.goals.where((goal) => s.saved(goal) > 0).toList()
      ..sort((a, b) => s.saved(b).compareTo(s.saved(a)));
    const colors = [
      Color(0xFFB9A3FF),
      Color(0xFF70E5BC),
      Color(0xFFFFD780),
      Color(0xFF78B9FF),
      Color(0xFFFF7D8C),
      Color(0xFFDA9EFB),
    ];
    return [
      for (var i = 0; i < funded.length && i < 5; i++)
        ChartSlice(funded[i].title, s.saved(funded[i]), colors[i]),
      if (funded.length > 5)
        ChartSlice(
          'Diğer hedefler',
          funded.skip(5).fold(0, (sum, goal) => sum + s.saved(goal)),
          colors[5],
        ),
    ];
  }

  List<Widget> goalPage() => [
    FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(Icons.savings_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('BİRİKİM CÜZDANI'),
                    SizedBox(height: 4),
                    Text(
                      'Hayallerine ayırdığın',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    if (s.goals.where((goal) => s.saved(goal) > 0).length > 1) ...[
      const SizedBox(height: 16),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('BİRİKİM DAĞILIMI'),
            const SizedBox(height: 7),
            const Text(
              'Hayallerine ayırdığın pay',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 13),
            OrbitChart(
              centerLabel: 'Hedef payı',
              slices: goalDistributionSlices(),
            ),
          ],
        ),
      ),
    ],
    heading('Hedeflerin'),
    if (s.goals.isEmpty)
      emptyGoal()
    else
      ...s.goals
          .take(5)
          .map(
            (g) => Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: goalCard(g),
            ),
          ),
    if (s.goals.length > 5)
      OutlinedButton.icon(
        onPressed: () => openRecords<Goal>(
          'Birikim hedefleri',
          'Tüm hedefler',
          () => s.goals.toList(),
          (g) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: goalCard(g),
          ),
        ),
        icon: const Icon(Icons.arrow_forward_rounded),
        label: Text('Tümünü gör (${s.goals.length})'),
      ),
  ];
  void allEntries() => openRecords<Entry>(
    'Tüm kayıtlar',
    'Tüm aylar',
    () => s.sorted,
    entryTile,
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
    final health = financialHealthReport(s, DateTime.now());
    return [
      FeatureCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const IconBadge(Icons.person_rounded, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('KİŞİSEL ALAN'),
                      const SizedBox(height: 6),
                      const Text(
                        'Senin alanın',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconBadge(
                  Icons.verified_user_outlined,
                  color: colors.positive,
                  size: 36,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _profileMetric(
                    '${s.entries.length}',
                    'Kayıt',
                    Icons.receipt_long_rounded,
                  ),
                ),
                Expanded(
                  child: _profileMetric(
                    '${s.goals.length}',
                    'Hedef',
                    Icons.flag_rounded,
                  ),
                ),
                Expanded(
                  child: _profileMetric(
                    'Yerel',
                    'Veri saklama',
                    Icons.lock_outline_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Material(
              color: colors.accent.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                leading: Icon(
                  Icons.tips_and_updates_outlined,
                  color: colors.accent,
                ),
                title: const Text(
                  'Bu ay dikkat et',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  health.attention ?? 'Her şey yolunda',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showHealthDetails(health),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      SectionCard(
        title: 'Uygulama tercihleri',
        icon: Icons.tune_rounded,
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const IconBadge(Icons.settings_outlined, size: 38),
              title: const Text('Ayarlar'),
              subtitle: const Text('Tema, bildirim ve widget'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: settings,
            ),
            const Divider(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: IconBadge(
                Icons.category_outlined,
                color: colors.positive,
                size: 38,
              ),
              title: const Text('Kategoriler'),
              subtitle: const Text('Gelir ve gider grupları'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: manageCategories,
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      SectionCard(
        title: 'Verilerim ve gizlilik',
        icon: Icons.shield_outlined,
        action: const InfoButton(
          title: 'Yerel veriler',
          message:
              'Kayıtların bu cihazda saklanır. Güncellemeden önce JSON yedek al; uygulamayı kaldırmak veya verilerini temizlemek kayıtlarını silebilir.',
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.positive.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    color: colors.positive,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.lastBackupAt == null
                          ? 'Henüz yedek oluşturulmadı.'
                          : 'Son yedek: ${dateLabel(s.lastBackupAt!.toLocal())}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: IconBadge(
                Icons.save_alt_rounded,
                color: colors.positive,
                size: 38,
              ),
              title: const Text('Yedek oluştur'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => exportData(csv: false),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const IconBadge(Icons.restore_rounded, size: 38),
              title: const Text('Geri yükle'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => importData(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const IconBadge(Icons.table_chart_outlined, size: 38),
              title: const Text('İşlemleri CSV dışa aktar'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => exportData(csv: true),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _profileMetric(String value, String label, IconData icon) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      const SizedBox(height: 3),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
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
            SectionCard(
              title: income ? 'Gelir kategorileri' : 'Gider kategorileri',
              icon: income
                  ? Icons.south_west_rounded
                  : Icons.north_east_rounded,
              color: income
                  ? financeColors(context).positive
                  : financeColors(context).negative,
              child: Column(
                children: [
                  for (final name in [...s.categoriesFor(income)])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: IconBadge(
                        Icons.sell_outlined,
                        size: 30,
                        color: income
                            ? financeColors(context).positive
                            : financeColors(context).negative,
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                                await s.change(
                                  () => s.removeCategory(income, name),
                                );
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
                ],
              ),
            ),
            const SizedBox(height: 18),
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
      final backupAt = DateTime.now();
      String? appVersion;
      if (!csv) {
        try {
          appVersion = (await PackageInfo.fromPlatform()).version;
        } catch (_) {
          // Version metadata is optional; the user's backup must still work.
        }
      }
      final content = csv
          ? createCsv(s)
          : createBackup(s, createdAt: backupAt, appVersion: appVersion);
      final saved = await saveDocument(
        name: name,
        mimeType: csv ? 'text/csv' : 'application/json',
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
      if (!saved) return;
      if (!csv) {
        try {
          await s.change(() => s.lastBackupAt = backupAt);
        } catch (_) {
          toast('Yedek kaydedildi; son yedek tarihi güncellenemedi.');
          return;
        }
      }
      toast(csv ? 'CSV dışa aktarıldı.' : 'Yedek kaydedildi.');
    } catch (_) {
      toast('Dosya kaydedilemedi.');
    }
  }

  Future<void> importData(
    BuildContext dialogContext, {
    bool closeSheet = false,
  }) async {
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
      if (closeSheet && dialogContext.mounted) Navigator.pop(dialogContext);
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
          SectionCard(
            title: 'Görünüm',
            icon: Icons.palette_outlined,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: s.followSystem
                      ? 'system'
                      : (s.dark ? 'dark' : 'light'),
                  decoration: InputDecoration(
                    labelText: 'Tema',
                    helperText: 'Sistem seçeneği cihaz temasını izler.',
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Hatırlatmalar ve widget',
            icon: Icons.notifications_none_rounded,
            child: Column(
              children: [
                SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const IconBadge(
                    Icons.notifications_active_outlined,
                    size: 36,
                  ),
                  title: const Text('Bütçe ve fatura bildirimleri'),
                  subtitle: const Text('Bütçe uyarıları ve ödeme vadeleri'),
                  value: s.notificationsEnabled,
                  onChanged: (enabled) async {
                    if (enabled) {
                      try {
                        final granted = await LocalNotifications.instance
                            .requestPermission();
                        if (!granted) {
                          if (!context.mounted) return;
                          final open = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Bildirim izni gerekli'),
                              content: const Text(
                                'Android bildirimleri kapalı görünüyor. Uygulama bildirim ayarlarını açıp izni verebilirsin.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Kapat'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Ayarları aç'),
                                ),
                              ],
                            ),
                          );
                          if (open == true) {
                            await LocalNotifications.instance.openSettings();
                          }
                          return;
                        }
                      } catch (error) {
                        toast('Bildirim kurulamadı: $error');
                        return;
                      }
                    }
                    if (await mutate(() => s.notificationsEnabled = enabled)) {
                      if (!enabled) {
                        await LocalNotifications.instance.cancelAll();
                      }
                      if (context.mounted) update(() {});
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const IconBadge(Icons.widgets_outlined, size: 36),
                  title: const Text('Widget’ta bakiyeyi göster'),
                  subtitle: const Text('Bakiye gizliliği'),
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Hareket',
            icon: Icons.auto_awesome_rounded,
            child: Column(
              children: [
                SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const IconBadge(
                    Icons.auto_awesome_outlined,
                    size: 36,
                  ),
                  title: Text('Görsel animasyonlar'),
                  subtitle: Text('Geçişler ve görsel efektler'),
                  value: s.motion,
                  onChanged: (v) async {
                    await mutate(() => s.motion = v);
                    if (context.mounted) update(() {});
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          SectionCard(
            title: 'Veriler ve gizlilik',
            icon: Icons.shield_outlined,
            action: const InfoButton(
              title: 'Veriler ve gizlilik',
              message:
                  'Veriler bu cihazda saklanır. Uygulamayı kaldırırsan yerel kayıtların silinebilir. Otomatik kayıtlar açılışta, ön plana dönüşte ve arka plan göreviyle tamamlanır. Birikim aktarımları gelir/gider sayılmaz.',
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const IconBadge(Icons.folder_outlined, size: 38),
              title: const Text('Yedek ve dışa aktarma'),
              subtitle: const Text('Profildeki veri yönetimini aç'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                navigate(4);
              },
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
