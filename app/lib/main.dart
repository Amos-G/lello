import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';

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
    secondary: lagoon,
    onSecondary: Colors.white,
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
          borderRadius: BorderRadius.all(Radius.circular(20))),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: sand0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: lagoon),
  );
}

void main() => runApp(const PartySyncApp());

class PartySyncApp extends StatefulWidget {
  const PartySyncApp({super.key});
  @override
  State<PartySyncApp> createState() => _PartySyncAppState();
}

class _PartySyncAppState extends State<PartySyncApp> {
  final api = Api();
  bool loading = true;
  bool authenticated = false;

  @override
  void initState() {
    super.initState();
    api.restoreSession().then((ok) {
      if (mounted) {
        setState(() {
          authenticated = ok;
          loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Lello',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        builder: (context, child) => ColoredBox(
          color: const Color(0xFFD8D4CC),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 430),
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Color(0x2916231F),
                    blurRadius: 60,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
        home: loading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : authenticated
                ? HomePage(
                    api: api,
                    onLogout: () => setState(() => authenticated = false),
                  )
                : LoginPage(
                    api: api,
                    onLogin: () => setState(() => authenticated = true),
                  ),
      );
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.toString())));
}

BoxDecoration surfaceDecoration({double radius = 20}) => BoxDecoration(
      color: Colors.white.withValues(alpha: 0.88),
      border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1460401F),
          blurRadius: 28,
          offset: Offset(0, 10),
        ),
      ],
    );

ButtonStyle addIconButtonStyle() => IconButton.styleFrom(
      backgroundColor: sunset,
      foregroundColor: Colors.white,
      disabledBackgroundColor: sunset.withValues(alpha: 0.55),
      disabledForegroundColor: Colors.white70,
      fixedSize: const Size.square(54),
    );

class AppListCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;

  const AppListCard({
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
        child: child,
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

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.beach_access_rounded,
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted),
                ),
              ],
            ],
          ),
        ),
      );
}

class LoginPage extends StatefulWidget {
  final Api api;
  final VoidCallback onLogin;
  const LoginPage({super.key, required this.api, required this.onLogin});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final user = TextEditingController();
  final pass = TextEditingController();
  final otp = TextEditingController();
  String? ticket;
  bool busy = false;

  @override
  void dispose() {
    user.dispose();
    pass.dispose();
    otp.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => busy = true);
    try {
      if (ticket != null) {
        await widget.api.verify2fa(ticket!, otp.text.trim());
      } else {
        final result = await widget.api.login(user.text.trim(), pass.text);
        if (result['requires_2fa'] == true) {
          pass.clear();
          setState(() => ticket = result['login_ticket']);
          return;
        }
        await widget.api.acceptToken(result['token']);
      }
      widget.onLogin();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: surfaceDecoration(radius: 24),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/launcher/app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Lello',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 34,
                              ),
                    ),
                    const SizedBox(height: 32),
                    if (ticket == null) ...[
                      TextField(
                        controller: user,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration:
                            const InputDecoration(labelText: 'Username'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: pass,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration:
                            const InputDecoration(labelText: 'Password'),
                        onSubmitted: (_) => submit(),
                      ),
                    ] else ...[
                      const Text(
                        'Inserisci il codice a 6 cifre dell’app Authenticator.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: otp,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofocus: true,
                        decoration:
                            const InputDecoration(labelText: 'Codice OTP'),
                        onSubmitted: (_) => submit(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: busy ? null : submit,
                      icon: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(ticket == null ? 'Accedi' : 'Verifica'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class HomePage extends StatefulWidget {
  final Api api;
  final VoidCallback onLogout;
  const HomePage({super.key, required this.api, required this.onLogout});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  List<Elemento> items = [];
  List<Scenario> scenarios = [];
  String defaultLabel = 'Da Assegnare';
  List<String> labels = const ['Da Assegnare'];
  SpeseReport? expenses;
  String? expensesError;
  int? scenarioId;
  String? username;
  bool loading = true;
  StreamSubscription? socketSub;
  Timer? reloadDebounce;
  Timer? reconnectTimer;
  bool connecting = false;

  @override
  void initState() {
    super.initState();
    loadUser();
    reload();
    if (!kIsWeb) connect();
  }

  Future<void> loadUser() async {
    try {
      final user = await widget.api.me();
      if (mounted) setState(() => username = user['username'] as String?);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> connect() async {
    if (connecting || !mounted) return;
    connecting = true;
    try {
      final channel = await widget.api.socket();
      if (!mounted) {
        await channel.sink.close();
        return;
      }
      await socketSub?.cancel();
      socketSub = channel.stream.listen(
        (_) {
          reloadDebounce?.cancel();
          reloadDebounce = Timer(const Duration(milliseconds: 150), reload);
        },
        onDone: () {
          scheduleReconnect();
        },
        onError: (_) {
          scheduleReconnect();
        },
      );
    } catch (_) {
      scheduleReconnect();
    } finally {
      connecting = false;
    }
  }

  void scheduleReconnect() {
    if (!mounted) return;
    reconnectTimer?.cancel();
    reconnectTimer = Timer(const Duration(seconds: 10), connect);
  }

  Future<void> reload() async {
    try {
      final result = await Future.wait([
        widget.api.elementi(),
        widget.api.scenari(),
        widget.api.etichette(),
      ]);
      SpeseReport? loadedExpenses;
      String? loadedExpensesError;
      try {
        loadedExpenses = await widget.api.spese();
      } catch (error) {
        loadedExpensesError = error.toString();
      }
      if (!mounted) return;
      setState(() {
        items = result[0] as List<Elemento>;
        scenarios = result[1] as List<Scenario>;
        final labelReport = result[2] as EtichetteReport;
        defaultLabel = labelReport.defaultLabel;
        labels = labelReport.labels;
        expenses = loadedExpenses;
        expensesError = loadedExpensesError;
        if (!scenarios.any((s) => s.id == scenarioId)) {
          scenarioId = scenarios.isEmpty ? null : scenarios.first.id;
        }
        loading = false;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  void dispose() {
    socketSub?.cancel();
    reloadDebounce?.cancel();
    reconnectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: SizedBox(
            width: 150,
            height: 70,
            child: Image.asset(
              'assets/brand/logo_lello.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              semanticLabel: 'Lello',
            ),
          ),
          actions: [
            IconButton.filledTonal(
              tooltip: 'Profilo e 2FA',
              icon: const Icon(Icons.account_circle_rounded),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfilePage(
                      api: widget.api,
                      onLogout: widget.onLogout,
                    ),
                  ),
                );
                if (mounted) await reload();
              },
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(
                index: tab,
                children: [
                  GlobalList(
                    api: widget.api,
                    items: items,
                    defaultLabel: defaultLabel,
                    labels: labels,
                    reload: reload,
                  ),
                  Scenarios(
                    api: widget.api,
                    items: items,
                    scenarios: scenarios,
                    scenarioId: scenarioId,
                    defaultLabel: defaultLabel,
                    labels: labels,
                    onScenario: (value) => setState(() => scenarioId = value),
                    reload: reload,
                  ),
                  SpesePage(
                    api: widget.api,
                    report: expenses,
                    error: expensesError,
                    reload: reload,
                  ),
                  PrivateList(
                    account: username,
                    items: items,
                    defaultLabel: defaultLabel,
                    labels: labels,
                  ),
                ],
              ),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2930281E),
                blurRadius: 40,
                offset: Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (value) => setState(() => tab = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.checklist_rounded),
                label: 'Lista',
              ),
              NavigationDestination(
                icon: Icon(Icons.landscape_rounded),
                label: 'Scenari',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Spese',
              ),
              NavigationDestination(
                icon: Icon(Icons.lock_rounded),
                label: 'Privata',
              ),
            ],
          ),
        ),
      );
}

String euro(int cents) {
  final sign = cents < 0 ? '-' : '';
  final value = cents.abs();
  final whole = value ~/ 100;
  final decimal = (value % 100).toString().padLeft(2, '0');
  return '$sign$whole,$decimal €';
}

int? parseEuroCents(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(normalized);
  if (match == null) return null;
  final euro = int.parse(match.group(1)!);
  final cents = (match.group(2) ?? '').padRight(2, '0');
  return euro * 100 + int.parse(cents.isEmpty ? '0' : cents);
}

String shortDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

class SpesePage extends StatefulWidget {
  final Api api;
  final SpeseReport? report;
  final String? error;
  final Future<void> Function() reload;

  const SpesePage({
    super.key,
    required this.api,
    required this.report,
    required this.error,
    required this.reload,
  });

  @override
  State<SpesePage> createState() => _SpesePageState();
}

class _SpesePageState extends State<SpesePage> {
  final descrizione = TextEditingController();
  final importo = TextEditingController();
  String filter = 'Tutti';
  bool busy = false;

  List<String> get filters => [
        'Tutti',
        ...((widget.report?.participants ?? [])
            .map((user) => user.username)
            .toSet()
            .toList()
          ..sort()),
      ];

  List<Spesa> get visibleExpenses {
    final spese = widget.report?.spese ?? const <Spesa>[];
    return filter == 'Tutti'
        ? spese
        : spese.where((spesa) => spesa.username == filter).toList();
  }

  @override
  void dispose() {
    descrizione.dispose();
    importo.dispose();
    super.dispose();
  }

  Future<void> mutate(Future<void> action) async {
    setState(() => busy = true);
    try {
      await action;
      await widget.reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addExpense() async {
    final text = descrizione.text.trim();
    if (text.isEmpty) {
      showError(context, 'Inserisci una descrizione');
      return;
    }
    importo.clear();
    final cents = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        void submitAmount() {
          final value = parseEuroCents(importo.text);
          if (value == null || value <= 0) {
            showError(dialogContext, 'Inserisci un importo valido');
            return;
          }
          Navigator.pop(dialogContext, value);
        }

        return AlertDialog(
          title: const Text('Importo della spesa'),
          content: TextField(
            controller: importo,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Importo',
              suffixText: '€',
            ),
            onSubmitted: (_) => submitAmount(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: submitAmount,
              child: const Text('Aggiungi'),
            ),
          ],
        );
      },
    );
    if (cents == null) return;
    await mutate(widget.api.addSpesa(text, cents));
    descrizione.clear();
    importo.clear();
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    if (report == null) {
      final error = widget.error;
      if (error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Spese non disponibili',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                  onPressed: widget.reload,
                ),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final availableFilters = filters;
    if (!availableFilters.contains(filter)) filter = 'Tutti';
    final visible = visibleExpenses;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.reload,
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: Text.rich(
                    TextSpan(
                      text: 'Totale spese:  ',
                      style: const TextStyle(color: muted, fontSize: 15),
                      children: [
                        TextSpan(
                          text: euro(report.totalCents),
                          style: const TextStyle(
                            color: ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 112,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 8, 12),
                    scrollDirection: Axis.horizontal,
                    children: report.participants
                        .map((user) => _BalanceCard(user: user))
                        .toList(),
                  ),
                ),
                if (report.settlements.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'Pagamenti suggeriti',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...report.settlements.map(
                    (payment) => AppListCard(
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.swap_horiz_rounded),
                        title: Text(
                          '${payment.fromUsername} deve ${euro(payment.amountCents)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('a ${payment.toUsername}'),
                      ),
                    ),
                  ),
                ],
                SizedBox(
                  height: 58,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    scrollDirection: Axis.horizontal,
                    children: availableFilters
                        .map(
                          (value) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: filter == value,
                              label: Text(value),
                              onSelected: (_) => setState(() => filter = value),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                if (visible.isEmpty)
                  const SizedBox(
                    height: 290,
                    child: EmptyState(
                      title: 'Nessuna spesa',
                      subtitle: 'Aggiungi la prima spesa per iniziare.',
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  )
                else
                  ...visible.map(
                    (spesa) => AppListCard(
                      child: Dismissible(
                        key: ValueKey(spesa.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: danger,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.all(20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async =>
                            await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Eliminare la spesa?'),
                                content: Text(spesa.descrizione),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Annulla'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Elimina'),
                                  ),
                                ],
                              ),
                            ) ??
                            false,
                        onDismissed: (_) =>
                            mutate(widget.api.deleteSpesa(spesa.id)),
                        child: ListTile(
                          leading: const Icon(
                            Icons.payments_outlined,
                            color: lagoon,
                          ),
                          title: Text(
                            spesa.descrizione,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${spesa.username} · ${shortDate(spesa.createdAt)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                euro(spesa.importoCents),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Elimina spesa',
                                color: danger,
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () =>
                                    mutate(widget.api.deleteSpesa(spesa.id)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ComposerSurface(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: descrizione,
                  decoration: const InputDecoration(
                    labelText: 'Nuova spesa',
                    isDense: true,
                  ),
                  onSubmitted: (_) => addExpense(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Aggiungi spesa',
                style: addIconButtonStyle(),
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add),
                onPressed: busy ? null : addExpense,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final PartecipanteSpese user;

  const _BalanceCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final balance = user.balanceCents;
    final color = balance > 0
        ? Colors.green
        : balance < 0
            ? Colors.red
            : Theme.of(context).colorScheme.outline;
    final label = balance > 0
        ? 'deve ricevere'
        : balance < 0
            ? 'deve dare'
            : 'in pari';
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: surfaceDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            user.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color)),
          Text(
            euro(balance.abs()),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class PrivateLocalItem {
  final String id;
  final String nome;
  final bool completato;

  const PrivateLocalItem({
    required this.id,
    required this.nome,
    required this.completato,
  });

  factory PrivateLocalItem.fromJson(Map<String, dynamic> json) =>
      PrivateLocalItem(
        id: json['id'] as String,
        nome: json['nome'] as String,
        completato: json['completato'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'completato': completato,
      };

  PrivateLocalItem copyWith({String? nome, bool? completato}) =>
      PrivateLocalItem(
        id: id,
        nome: nome ?? this.nome,
        completato: completato ?? this.completato,
      );
}

class PrivateList extends StatefulWidget {
  final String? account;
  final List<Elemento> items;
  final String defaultLabel;
  final List<String> labels;

  const PrivateList({
    super.key,
    required this.account,
    required this.items,
    required this.defaultLabel,
    required this.labels,
  });

  @override
  State<PrivateList> createState() => _PrivateListState();
}

class _PrivateListState extends State<PrivateList> {
  final controller = TextEditingController();
  String selectedAssignee = 'Da Assegnare';
  List<PrivateLocalItem> localItems = [];
  Map<String, bool> completed = {};
  String? loadedAccount;
  bool loading = true;

  String get _prefix => 'private:${widget.account}';
  String get _assigneeKey => '$_prefix:assignee';
  String get _itemsKey => '$_prefix:items';
  String get _completedKey => '$_prefix:completed';

  List<String> get people => {
        widget.defaultLabel,
        ...widget.labels,
        ...widget.items.map((item) => item.chiPorta),
      }.toList()
        ..sort();

  List<Elemento> get importedItems => widget.items
      .where((item) => item.chiPorta == selectedAssignee)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant PrivateList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account) load();
    if (!people.contains(selectedAssignee)) {
      setState(() => selectedAssignee = widget.defaultLabel);
      unawaited(saveAssignee(widget.defaultLabel));
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final account = widget.account;
    if (account == null) {
      setState(() => loading = true);
      return;
    }
    try {
      final values = await Future.wait([
        Api.storage.read(key: _assigneeKey),
        Api.storage.read(key: _itemsKey),
        Api.storage.read(key: _completedKey),
      ]);
      final decodedItems = values[1] == null
          ? <PrivateLocalItem>[]
          : (jsonDecode(values[1]!) as List)
              .map(
                (item) =>
                    PrivateLocalItem.fromJson(item as Map<String, dynamic>),
              )
              .toList();
      final decodedCompleted = values[2] == null
          ? <String, bool>{}
          : (jsonDecode(values[2]!) as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, value == true),
            );
      if (!mounted || widget.account != account) return;
      setState(() {
        selectedAssignee = values[0] ?? widget.defaultLabel;
        if (!people.contains(selectedAssignee)) {
          selectedAssignee = widget.defaultLabel;
        }
        localItems = decodedItems;
        completed = decodedCompleted;
        loadedAccount = account;
        loading = false;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> saveAssignee(String value) async {
    if (widget.account == null) return;
    await Api.storage.write(key: _assigneeKey, value: value);
  }

  Future<void> saveLocalItems() async {
    if (widget.account == null) return;
    await Api.storage.write(
      key: _itemsKey,
      value: jsonEncode(localItems.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> saveCompleted() async {
    if (widget.account == null) return;
    await Api.storage.write(key: _completedKey, value: jsonEncode(completed));
  }

  Future<void> chooseAssignee(String value) async {
    setState(() => selectedAssignee = value);
    try {
      await saveAssignee(value);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> addLocalItem() async {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    setState(() {
      localItems = [
        ...localItems,
        PrivateLocalItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          nome: name,
          completato: false,
        ),
      ];
    });
    controller.clear();
    try {
      await saveLocalItems();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> toggleCompleted(String key, bool value) async {
    setState(() => completed = {...completed, key: value});
    try {
      await saveCompleted();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> toggleLocalItem(PrivateLocalItem item, bool value) async {
    setState(() {
      localItems = localItems
          .map(
            (current) => current.id == item.id
                ? current.copyWith(completato: value)
                : current,
          )
          .toList();
    });
    try {
      await saveLocalItems();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> deleteLocalItem(PrivateLocalItem item) async {
    setState(() {
      localItems =
          localItems.where((current) => current.id != item.id).toList();
    });
    try {
      await saveLocalItems();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading || widget.account == null || loadedAccount != widget.account) {
      return const Center(child: CircularProgressIndicator());
    }
    final assignees = people;
    if (!assignees.contains(selectedAssignee)) {
      selectedAssignee = widget.defaultLabel;
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: surfaceDecoration(),
            child: DropdownButtonFormField<String>(
              key: ValueKey(selectedAssignee),
              initialValue: selectedAssignee,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Chi lo porta'),
              items: assignees
                  .map(
                    (name) => DropdownMenuItem(
                      value: name,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) chooseAssignee(value);
              },
            ),
          ),
        ),
        Expanded(
          child: importedItems.isEmpty && localItems.isEmpty
              ? const EmptyState(
                  title: 'Nessun elemento privato',
                  icon: Icons.lock_outline_rounded,
                )
              : ListView(
                  padding: const EdgeInsets.only(top: 2, bottom: 8),
                  children: [
                    ...importedItems.map((item) {
                      final key = 'global:${item.id}';
                      final done = completed[key] ?? false;
                      return AppListCard(
                        child: ListTile(
                          leading: Checkbox(
                            value: done,
                            onChanged: (value) =>
                                toggleCompleted(key, value ?? false),
                          ),
                          title: Text(
                            item.nome,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              decoration:
                                  done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text('Da lista globale: ${item.chiPorta}'),
                        ),
                      );
                    }),
                    ...localItems.map(
                      (item) => AppListCard(
                        child: ListTile(
                          leading: Checkbox(
                            value: item.completato,
                            onChanged: (value) =>
                                toggleLocalItem(item, value ?? false),
                          ),
                          title: Text(
                            item.nome,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              decoration: item.completato
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: const Text('Solo su questo dispositivo'),
                          trailing: IconButton(
                            tooltip: 'Elimina item privato',
                            color: danger,
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => deleteLocalItem(item),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        ComposerSurface(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Nuovo item privato',
                    isDense: true,
                  ),
                  onSubmitted: (_) => addLocalItem(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Aggiungi item privato',
                style: addIconButtonStyle(),
                icon: const Icon(Icons.add),
                onPressed: addLocalItem,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class GlobalList extends StatefulWidget {
  final Api api;
  final List<Elemento> items;
  final String defaultLabel;
  final List<String> labels;
  final Future<void> Function() reload;
  const GlobalList({
    super.key,
    required this.api,
    required this.items,
    required this.defaultLabel,
    required this.labels,
    required this.reload,
  });
  @override
  State<GlobalList> createState() => _GlobalListState();
}

class _GlobalListState extends State<GlobalList> {
  final name = TextEditingController();
  String filter = 'Tutti';
  String assignee = 'Da Assegnare';
  final Map<int, bool> completionOverrides = {};
  final Set<int> completionBusy = {};
  final Set<int> completionHiding = {};
  final Set<int> completionReorderReady = {};
  final Set<int> completionArriving = {};

  List<String> get people => {
        widget.defaultLabel,
        ...widget.labels,
        ...widget.items.map((item) => item.chiPorta),
      }.toList()
        ..sort();

  Future<void> mutate(Future<void> action) async {
    try {
      await action;
      await widget.reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  bool displayedCompletion(Elemento item) =>
      completionOverrides[item.id] ?? item.completato;

  bool sortedCompletion(Elemento item) =>
      completionReorderReady.contains(item.id)
          ? displayedCompletion(item)
          : item.completato;

  Future<void> toggleCompletion(Elemento item, bool value) async {
    if (completionBusy.contains(item.id)) return;
    setState(() {
      completionBusy.add(item.id);
      completionOverrides[item.id] = value;
    });
    try {
      await widget.api.patchElemento(item.id, {'completato': value});
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() => completionHiding.add(item.id));
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      setState(() {
        completionHiding.remove(item.id);
        completionReorderReady.add(item.id);
        completionArriving.add(item.id);
      });
      await Future.wait([
        widget.reload(),
        Future<void>.delayed(const Duration(milliseconds: 220)),
      ]);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) {
        setState(() {
          completionOverrides.remove(item.id);
          completionBusy.remove(item.id);
          completionHiding.remove(item.id);
          completionReorderReady.remove(item.id);
          completionArriving.remove(item.id);
        });
      }
    }
  }

  Future<void> addItem() async {
    final itemName = name.text.trim();
    if (itemName.isEmpty) return;
    var selectedAssignee = assignee;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Chi lo porta?'),
          content: DropdownButtonFormField<String>(
            initialValue: selectedAssignee,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Chi porta'),
            items: people
                .map(
                  (person) => DropdownMenuItem(
                    value: person,
                    child: Text(person, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setDialogState(() => selectedAssignee = value);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selectedAssignee),
              child: const Text('Aggiungi'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    assignee = selected;
    await mutate(widget.api.addElemento(itemName, selected));
    name.clear();
  }

  Future<void> chooseAssignee(Elemento item) async {
    final controller = TextEditingController(
      text: item.chiPorta == widget.defaultLabel ? '' : item.chiPorta,
    );
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chi lo porta?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nome o ${widget.defaultLabel}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              controller.text.trim().isEmpty
                  ? widget.defaultLabel
                  : controller.text.trim(),
            ),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    if (selected != null) {
      mutate(widget.api.patchElemento(item.id, {'chi_porta': selected}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['Tutti', ...people];
    if (!filters.contains(filter)) filter = 'Tutti';
    if (!people.contains(assignee)) assignee = widget.defaultLabel;
    final filtered = filter == 'Tutti'
        ? widget.items
        : widget.items.where((e) => e.chiPorta == filter).toList();
    final originalOrder = {
      for (var index = 0; index < filtered.length; index++)
        filtered[index].id: index,
    };
    final visible = List<Elemento>.from(filtered)
      ..sort((a, b) {
        final completionOrder = (sortedCompletion(a) ? 1 : 0)
            .compareTo(sortedCompletion(b) ? 1 : 0);
        if (completionOrder != 0) return completionOrder;
        return originalOrder[a.id]!.compareTo(originalOrder[b.id]!);
      });
    return Column(
      children: [
        SizedBox(
          height: 58,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            scrollDirection: Axis.horizontal,
            children: filters
                .map(
                  (value) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: filter == value,
                      label: Text(value),
                      onSelected: (_) => setState(() => filter = value),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const EmptyState(title: 'Nessun elemento')
              : RefreshIndicator(
                  onRefresh: widget.reload,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 2, bottom: 8),
                    itemCount: visible.length,
                    findChildIndexCallback: (key) {
                      if (key is! ValueKey<int>) return null;
                      final index =
                          visible.indexWhere((item) => item.id == key.value);
                      return index < 0 ? null : index;
                    },
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      final hidden = completionHiding.contains(item.id);
                      final arriving = completionArriving.contains(item.id);
                      return KeyedSubtree(
                        key: ValueKey(item.id),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOut,
                          alignment: Alignment.topCenter,
                          child: hidden
                              ? const SizedBox(width: double.infinity)
                              : TweenAnimationBuilder<double>(
                                  key: ValueKey('${item.id}:$arriving'),
                                  tween: Tween(
                                    begin: arriving ? 0 : 1,
                                    end: 1,
                                  ),
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                  builder: (context, progress, child) =>
                                      Opacity(
                                    opacity: progress,
                                    child: Transform.translate(
                                      offset: Offset(0, 8 * (1 - progress)),
                                      child: child,
                                    ),
                                  ),
                                  child: AppListCard(
                                    child: Dismissible(
                                      key: ValueKey(item.id),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        color: danger,
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.all(20),
                                        child: const Icon(Icons.delete,
                                            color: Colors.white),
                                      ),
                                      confirmDismiss: (_) async =>
                                          await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text(
                                                  'Eliminare dal DB globale?'),
                                              content: Text(item.nome),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text('Annulla'),
                                                ),
                                                FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: const Text('Elimina'),
                                                ),
                                              ],
                                            ),
                                          ) ??
                                          false,
                                      onDismissed: (_) => mutate(
                                          widget.api.deleteElemento(item.id)),
                                      child: ListTile(
                                        leading: Checkbox(
                                          value: displayedCompletion(item),
                                          onChanged:
                                              completionBusy.contains(item.id)
                                                  ? null
                                                  : (value) => toggleCompletion(
                                                        item,
                                                        value ?? false,
                                                      ),
                                        ),
                                        title: Text(
                                          item.nome,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            decoration:
                                                displayedCompletion(item)
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                          ),
                                        ),
                                        subtitle: GestureDetector(
                                          onTap: () => chooseAssignee(item),
                                          child: Text(
                                            item.chiPorta,
                                            style:
                                                const TextStyle(color: muted),
                                          ),
                                        ),
                                        trailing: IconButton(
                                          tooltip: 'Elimina',
                                          color: danger,
                                          icon: const Icon(
                                              Icons.delete_outline_rounded),
                                          onPressed: () => mutate(widget.api
                                              .deleteElemento(item.id)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        ComposerSurface(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Nuovo oggetto',
                    isDense: true,
                  ),
                  onSubmitted: (_) => addItem(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Aggiungi',
                style: addIconButtonStyle(),
                icon: const Icon(Icons.add),
                onPressed: addItem,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class Scenarios extends StatelessWidget {
  final Api api;
  final List<Elemento> items;
  final List<Scenario> scenarios;
  final int? scenarioId;
  final String defaultLabel;
  final List<String> labels;
  final ValueChanged<int?> onScenario;
  final Future<void> Function() reload;
  const Scenarios({
    super.key,
    required this.api,
    required this.items,
    required this.scenarios,
    required this.scenarioId,
    required this.defaultLabel,
    required this.labels,
    required this.onScenario,
    required this.reload,
  });

  Future<void> run(BuildContext context, Future<void> action) async {
    try {
      await action;
      await reload();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = scenarios.where((s) => s.id == scenarioId).firstOrNull;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: surfaceDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(scenarioId),
                    initialValue: scenarioId,
                    decoration: const InputDecoration(labelText: 'Scenario'),
                    hint: const Text('Nessuno scenario'),
                    items: scenarios
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.titolo),
                          ),
                        )
                        .toList(),
                    onChanged: onScenario,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final value = await textDialog(
                      context,
                      'Nuovo scenario',
                      'Titolo',
                    );
                    if (!context.mounted) return;
                    if (value != null) run(context, api.addScenario(value));
                  },
                  child: const Text('Nuovo'),
                ),
                if (current != null)
                  PopupMenuButton<String>(
                    tooltip: 'Azioni scenario',
                    onSelected: (value) async {
                      if (value != 'delete') return;
                      final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Elimina scenario?'),
                              content: Text(current.titolo),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Annulla'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Elimina'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (confirmed && context.mounted) {
                        run(context, api.deleteScenario(current.id));
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Elimina scenario'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (current == null)
          const Expanded(
            child: EmptyState(
              title: 'Crea uno scenario per iniziare',
              icon: Icons.landscape_outlined,
            ),
          )
        else ...[
          Expanded(
            child: current.elementi.isEmpty
                ? const EmptyState(
                    title: 'Nessun elemento associato',
                    icon: Icons.link_off_rounded,
                  )
                : ListView(
                    padding: const EdgeInsets.only(top: 2, bottom: 8),
                    children: current.elementi
                        .map(
                          (item) => AppListCard(
                            child: ListTile(
                              leading: Checkbox(
                                value: item.completato,
                                onChanged: (value) => run(
                                  context,
                                  api.patchElemento(item.id, {
                                    'completato': value,
                                  }),
                                ),
                              ),
                              title: Text(
                                item.nome,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  decoration: item.completato
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Text(item.chiPorta),
                              trailing: IconButton(
                                tooltip: 'Rimuovi dallo scenario',
                                icon: const Icon(Icons.link_off_rounded),
                                onPressed: () => run(
                                  context,
                                  api.detach(current.id, item.id),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          ComposerSurface(
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: lagoonSoft,
                        foregroundColor: lagoon,
                      ),
                      icon: const Icon(Icons.link),
                      label: const Text(
                        'Associa item',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                      onPressed: () => showAttach(context, current),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Crea nuovo item',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                      onPressed: () => showCreateItem(context, current),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> showAttach(BuildContext context, Scenario scenario) async {
    final existing = scenario.elementi.map((e) => e.id).toSet();
    final available = items.where((e) => !existing.contains(e.id)).toList();
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: available.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('Tutti gli elementi sono già presenti'),
                ),
              )
            : ListView(
                children: [
                  const ListTile(
                    title: Text(
                      'Elementi disponibili',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...available.map(
                    (item) => ListTile(
                      title: Text(item.nome),
                      subtitle: Text(item.chiPorta),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await run(context, api.attach(scenario.id, item.id));
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> showCreateItem(BuildContext context, Scenario scenario) async {
    final names = {
      ...labels,
      ...items.map((item) => item.chiPorta),
    }.where((name) => name != defaultLabel).toList()
      ..sort();
    final input = await _newItemDialog(context, [defaultLabel, ...names]);
    if (input == null || !context.mounted) return;
    await run(
      context,
      api.createAndAttach(scenario.id, input.nome, input.chiPorta),
    );
  }
}

class _NewItemInput {
  final String nome;
  final String chiPorta;

  const _NewItemInput(this.nome, this.chiPorta);
}

Future<_NewItemInput?> _newItemDialog(
  BuildContext context,
  List<String> assignees,
) async {
  final controller = TextEditingController();
  var assignee = assignees.first;
  final result = await showDialog<_NewItemInput>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Crea nuovo item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nome item'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: assignee,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Chi porta'),
              items: assignees
                  .map(
                    (name) => DropdownMenuItem(
                      value: name,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setDialogState(() => assignee = value);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(dialogContext, _NewItemInput(name, assignee));
              }
            },
            child: const Text('Crea e associa'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

Future<String?> textDialog(
  BuildContext context,
  String title,
  String label,
) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isNotEmpty) Navigator.pop(context, value);
          },
          child: const Text('Salva'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

Future<String?> passwordDialog(BuildContext context, String title) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(labelText: 'Conferma la password'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              Navigator.pop(context, controller.text);
            }
          },
          child: const Text('Conferma'),
        ),
      ],
    ),
  );
  controller.clear();
  controller.dispose();
  return result;
}

class ProfilePage extends StatefulWidget {
  final Api api;
  final VoidCallback onLogout;
  const ProfilePage({super.key, required this.api, required this.onLogout});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? user;
  EtichetteReport? labelsReport;
  bool labelsBusy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await Future.wait([
        widget.api.me(),
        widget.api.etichette(),
      ]);
      if (mounted) {
        setState(() {
          user = values[0] as Map<String, dynamic>;
          labelsReport = values[1] as EtichetteReport;
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profilo e sicurezza')),
        body: user == null || labelsReport == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppListCard(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(
                        user!['username'],
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('Account Lello'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sicurezza',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  AppListCard(
                    margin: EdgeInsets.zero,
                    child: SwitchListTile(
                      title: const Text('Autenticazione a due fattori'),
                      subtitle:
                          Text(user!['totp_enabled'] ? 'Attiva' : 'Non attiva'),
                      value: user!['totp_enabled'],
                      onChanged: (enabled) =>
                          enabled ? enable2fa() : disable2fa(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Etichette "Chi lo porta"',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  AppListCard(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.label_rounded, color: lagoon),
                      title: Text(
                        labelsReport!.defaultLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('Etichetta predefinita'),
                      trailing: IconButton(
                        tooltip: 'Rinomina etichetta predefinita',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: labelsBusy ? null : renameDefaultLabel,
                      ),
                    ),
                  ),
                  ...labelsReport!.labels
                      .where((label) => label != labelsReport!.defaultLabel)
                      .map(
                        (label) => AppListCard(
                          margin: const EdgeInsets.only(top: 10),
                          child: ListTile(
                            leading: const Icon(
                              Icons.label_outline_rounded,
                              color: muted,
                            ),
                            title: Text(
                              label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            trailing: IconButton(
                              tooltip: 'Rimuovi etichetta',
                              color: danger,
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed:
                                  labelsBusy ? null : () => removeLabel(label),
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Esci'),
                    onPressed: () async {
                      await widget.api.logout();
                      if (!context.mounted) return;
                      widget.onLogout();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
      );

  Future<void> renameDefaultLabel() async {
    final controller = TextEditingController(text: labelsReport!.defaultLabel);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rinomina etichetta predefinita'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Nuovo nome'),
          onSubmitted: (value) {
            final label = value.trim();
            if (label.isNotEmpty) Navigator.pop(dialogContext, label);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final label = controller.text.trim();
              if (label.isNotEmpty) Navigator.pop(dialogContext, label);
            },
            child: const Text('Rinomina'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value == labelsReport!.defaultLabel) return;
    await updateLabels(widget.api.renameDefaultLabel(value));
  }

  Future<void> removeLabel(String label) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Rimuovere l’etichetta?'),
            content: Text(
              'Gli item associati a "$label" passeranno a '
              '"${labelsReport!.defaultLabel}".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Rimuovi'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await updateLabels(widget.api.deleteLabel(label));
  }

  Future<void> updateLabels(Future<EtichetteReport> action) async {
    setState(() => labelsBusy = true);
    try {
      final report = await action;
      if (mounted) setState(() => labelsReport = report);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => labelsBusy = false);
    }
  }

  Future<void> enable2fa() async {
    try {
      final setup = await widget.api.setup2fa();
      if (!mounted) return;
      final code = TextEditingController();
      final png = base64Decode(
        (setup['qr_data_url'] as String).split(',').last,
      );
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Configura 2FA'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.memory(png, width: 220, height: 220),
                const Text(
                  'Scansiona il QR, poi inserisci il codice generato.',
                ),
                const SizedBox(height: 12),
                SelectableText('Secret: ${setup['secret']}'),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'Codice OTP'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.api.enable2fa(code.text.trim());
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
              child: const Text('Attiva'),
            ),
          ],
        ),
      );
      if (confirmed == true) await load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> disable2fa() async {
    final password = await passwordDialog(context, 'Disattiva 2FA');
    if (password == null) return;
    try {
      await widget.api.disable2fa(password);
      await load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }
}
