import 'package:flutter/material.dart';

const sand0 = Color(0xFFFFFDF8);
const sand1 = Color(0xFFFBF8F1);
const sand2 = Color(0xFFF1E7D7);
const ink = Color(0xFF173F3C);
const muted = Color(0xFF71807D);
const sage = Color(0xFF8CAB75);
const sageSoft = Color(0xFFEEF4E3);
const lagoon = Color(0xFF0E8D8B);
const lagoonSoft = Color(0xFFDEF3F2);
const sunset = Color(0xFFD95F2F);
const sunsetSoft = Color(0xFFFFE3D6);
const gold = Color(0xFFF0B44B);
const danger = Color(0xFFB14B31);
const line = Color(0x1F143F3A);

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: lagoon,
    brightness: Brightness.light,
  ).copyWith(
    primary: sunset,
    onPrimary: Colors.white,
    primaryContainer: sunsetSoft,
    onPrimaryContainer: ink,
    secondary: lagoon,
    onSecondary: Colors.white,
    secondaryContainer: sageSoft,
    onSecondaryContainer: ink,
    surface: sand1,
    onSurface: ink,
    error: danger,
    outline: muted,
    outlineVariant: line,
  );
  final textTheme = ThemeData.light().textTheme.apply(
        fontFamily: 'Manrope',
        bodyColor: ink,
        displayColor: ink,
      );
  const fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(15)),
    borderSide: BorderSide(color: line),
  );
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: sand1,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: sand0,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: 80,
      titleTextStyle: textTheme.headlineMedium?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
      ),
      shape: const Border(bottom: BorderSide(color: line)),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(15)),
        borderSide: BorderSide(color: lagoon, width: 1.5),
      ),
      labelStyle: TextStyle(color: muted, fontSize: 12),
      floatingLabelStyle: TextStyle(color: lagoon, fontWeight: FontWeight.w700),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: Color(0xFF64816C), width: 2),
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? lagoon : Colors.white,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.62),
      selectedColor: lagoonSoft,
      disabledColor: sand2,
      side: const BorderSide(color: line),
      shape: const StadiumBorder(),
      labelStyle: textTheme.labelLarge?.copyWith(color: ink),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(
        color: lagoon,
        fontWeight: FontWeight.w800,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: sunset,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: sunset,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: lagoon,
        minimumSize: const Size.square(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 66,
      elevation: 0,
      backgroundColor: Colors.white.withValues(alpha: 0.92),
      surfaceTintColor: Colors.transparent,
      indicatorColor: sunsetSoft,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? sunset : muted,
          size: 28,
        ),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: sand0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: sand0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    cardTheme: const CardThemeData(
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: lagoon),
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

BoxDecoration surfaceDecoration({double radius = 20}) => BoxDecoration(
      color: Colors.white.withValues(alpha: 0.88),
      border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
            color: Color(0x1460401F), blurRadius: 28, offset: Offset(0, 10)),
      ],
    );

ButtonStyle addIconButtonStyle() => IconButton.styleFrom(
      backgroundColor: sunset,
      foregroundColor: Colors.white,
      disabledBackgroundColor: sunset.withValues(alpha: 0.55),
      disabledForegroundColor: Colors.white70,
      fixedSize: const Size.square(54),
    );

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;

  const SurfaceCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 10),
  });

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 72),
        margin: margin,
        decoration: surfaceDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      );
}

class ComposerSurface extends StatelessWidget {
  final Widget child;

  const ComposerSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: sand1.withValues(alpha: 0.94),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1C302C22),
                blurRadius: 30,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: child,
        ),
      );
}

class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(
                  color: Color(0x2EF0B44B),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 38, color: sage),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted),
                ),
              ],
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
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

Future<String?> textDialog(
  BuildContext context,
  String title,
  String label, {
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) Navigator.pop(dialogContext, value);
          },
          child: const Text('Salva'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<bool> confirmDialog(
  BuildContext context,
  String title,
  String body,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    ) ??
    false;
