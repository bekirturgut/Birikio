import 'package:flutter/material.dart';
import 'palette.dart';
import 'widgets.dart';

class WidgetPickerDialog extends StatelessWidget {
  const WidgetPickerDialog({super.key});

  static const _choices =
      <
        ({
          String size,
          String title,
          String detail,
          String name,
          IconData icon,
          int columns,
          int rows,
        })
      >[
        (
          size: '1×1',
          title: 'Hedef yüzdesi',
          detail: 'Hedefine ne kadar yaklaştın?',
          name: 'BirikioMiniWidget',
          icon: Icons.flag_rounded,
          columns: 1,
          rows: 1,
        ),
        (
          size: '2×1',
          title: 'Kullanılabilir bakiye',
          detail: 'Harcanabilir tutarın elinin altında.',
          name: 'BirikioBalanceWidget',
          icon: Icons.account_balance_wallet_rounded,
          columns: 2,
          rows: 1,
        ),
        (
          size: '2×2',
          title: 'Birikim hedefi',
          detail: 'Birikimini ve ilerlemeni izle.',
          name: 'BirikioGoalWidget',
          icon: Icons.savings_rounded,
          columns: 2,
          rows: 2,
        ),
        (
          size: '2×3',
          title: 'Aylık bütçe',
          detail: 'Bu ayki limitini takip et.',
          name: 'BirikioBudgetWidget',
          icon: Icons.pie_chart_rounded,
          columns: 2,
          rows: 3,
        ),
        (
          size: '3×3',
          title: 'Finansal özet',
          detail: 'Paranın genel görünümü.',
          name: 'BirikioOverviewWidget',
          icon: Icons.auto_graph_rounded,
          columns: 3,
          rows: 3,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = financeColors(context);
    final accents = [
      colors.accent,
      colors.positive,
      colors.gold,
      colors.negative,
      colors.accent,
    ];
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        child: Material(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(30),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 22, 16, 23),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors.dark
                          ? [const Color(0xFF302747), const Color(0xFF202A3A)]
                          : [const Color(0xFFEFE7FF), const Color(0xFFE7F8F1)],
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Eyebrow(
                              'ANA EKRAN WIDGET’LARI',
                              color: colors.accent,
                            ),
                            const SizedBox(height: 9),
                            Text(
                              'Ana ekranına bir dokunuş',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.12,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'Sana en uygun görünümü seç.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kapat',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 15),
                  child: Column(
                    children: [
                      for (var i = 0; i < _choices.length; i++) ...[
                        _ChoiceTile(choice: _choices[i], accent: accents[i]),
                        if (i < _choices.length - 1) const SizedBox(height: 7),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final ({
    String size,
    String title,
    String detail,
    String name,
    IconData icon,
    int columns,
    int rows,
  })
  choice;
  final Color accent;
  const _ChoiceTile({required this.choice, required this.accent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: accent.withValues(alpha: .065),
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () => Navigator.pop(context, choice.name),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(choice.icon, color: accent, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            choice.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          choice.size,
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      choice.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              _SizePreview(
                columns: choice.columns,
                rows: choice.rows,
                color: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SizePreview extends StatelessWidget {
  final int columns;
  final int rows;
  final Color color;
  const _SizePreview({
    required this.columns,
    required this.rows,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 29,
    height: 29,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var y = 0; y < rows; y++)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var x = 0; x < columns; x++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}
