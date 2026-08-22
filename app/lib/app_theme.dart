import 'package:flutter/material.dart';

const sand0 = Color(0xFFFFFDF8);
const sand1 = Color(0xFFFBF8F1);
const ink = Color(0xFF173F3C);
const muted = Color(0xFF71807D);
const lagoon = Color(0xFF0E8D8B);
const lagoonSoft = Color(0xFFDEF3F2);
const sunset = Color(0xFFD95F2F);
const sunsetSoft = Color(0xFFFFE3D6);
const danger = Color(0xFFB14B31);
const line = Color(0x1F143F3A);

ThemeData buildAppTheme() {
  final colors = ColorScheme.fromSeed(seedColor: lagoon).copyWith(
    primary: sunset,
    secondary: lagoon,
    surface: sand1,
    onSurface: ink,
    error: danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: sand1,
    fontFamily: 'Manrope',
    appBarTheme: const AppBarTheme(
      backgroundColor: sand0,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: sunset,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: sunsetSoft,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
  );
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class SurfaceCard extends StatelessWidget {
  final Widget child;
  const SurfaceCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: line),
        ),
        child: child,
      );
}

class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;
  const EmptyState(
      {super.key,
      required this.title,
      this.subtitle,
      required this.icon,
      this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: muted),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted)),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ]),
        ),
      );
}

String euro(int cents) {
  final sign = cents < 0 ? '-' : '';
  final value = cents.abs();
  return '$sign${value ~/ 100},${(value % 100).toString().padLeft(2, '0')} €';
}

int? parseEuroCents(String value) {
  final match = RegExp(r'^(\d+)(?:[,.](\d{1,2}))?$').firstMatch(value.trim());
  if (match == null) return null;
  final decimals = (match.group(2) ?? '').padRight(2, '0');
  return int.parse(match.group(1)!) * 100 +
      int.parse(decimals.isEmpty ? '0' : decimals);
}

Future<String?> textDialog(BuildContext context, String title, String label,
    {String initial = ''}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla')),
        FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Salva')),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<bool> confirmDialog(
        BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Conferma')),
        ],
      ),
    ) ??
    false;
