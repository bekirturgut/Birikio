import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersion extends StatelessWidget {
  final bool badge;
  const AppVersion({super.key, this.badge = false});

  static final Future<String?> _version = _readVersion();

  static Future<String?> _readVersion() async {
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _version,
    builder: (context, snapshot) {
      final version = snapshot.data;
      if (version == null || version.isEmpty) return const SizedBox.shrink();
      final color = Theme.of(context).colorScheme.onSurfaceVariant;
      final label = Text(
        'v$version',
        style: TextStyle(
          color: color,
          fontSize: badge ? 10 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: badge ? .2 : 1.3,
        ),
      );
      if (!badge) return label;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: label,
      );
    },
  );
}
