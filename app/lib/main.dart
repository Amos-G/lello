import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api.dart';
import 'app_theme.dart';
import 'content_pages.dart';
import 'expenses_page.dart';
import 'models.dart';
import 'settings_page.dart';

void main() => runApp(const PartySyncApp());

class PartySyncApp extends StatefulWidget {
  const PartySyncApp({super.key});
  @override
  State<PartySyncApp> createState() => _PartySyncAppState();
}

class _PartySyncAppState extends State<PartySyncApp> {
  late final Api api;
  bool loading = true;
  bool authenticated = false;

  @override
  void initState() {
    super.initState();
    api = Api(onUnauthorized: () {
      if (mounted) setState(() => authenticated = false);
    });
    api.restoreToken().then((hasToken) {
      if (mounted) {
        setState(() {
          authenticated = hasToken;
          loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Lello',
        theme: buildAppTheme(),
        builder: (context, child) => ColoredBox(
          color: const Color(0xFFD8D4CC),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 430),
              decoration: const BoxDecoration(
                boxShadow: [
                  BoxShadow(color: Color(0x2916231F), blurRadius: 60),
                ],
              ),
              child: child,
            ),
          ),
        ),
        home: loading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : authenticated
                ? HomeShell(
                    api: api,
                    onLogout: () => setState(() => authenticated = false))
                : LoginPage(
                    api: api,
                    onLogin: () => setState(() => authenticated = true)),
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
  final username = TextEditingController();
  final password = TextEditingController();
  final otp = TextEditingController();
  String? ticket;
  bool busy = false;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    otp.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (ticket == null) {
        final result =
            await widget.api.login(username.text.trim(), password.text);
        if (result['requires_2fa'] == true) {
          if (mounted) {
            setState(() => ticket = result['login_ticket'] as String);
          }
        } else {
          await widget.api.acceptToken(result['token'] as String);
          widget.onLogin();
        }
      } else {
        await widget.api.verify2fa(ticket!, otp.text.trim());
        widget.onLogin();
      }
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
                        controller: username,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration:
                            const InputDecoration(labelText: 'Username'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: password,
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

class HomeShell extends StatefulWidget {
  final Api api;
  final VoidCallback onLogout;
  const HomeShell({super.key, required this.api, required this.onLogout});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppUser? user;
  List<PartyList> lists = [];
  String? selectedListId;
  List<Elemento> items = [];
  List<Scenario> scenarios = [];
  List<Participant> participants = [];
  EtichetteReport labels =
      const EtichetteReport(defaultLabel: 'Da Assegnare', labels: []);
  SpeseReport expenses = const SpeseReport(
      spese: [],
      payments: [],
      participants: [],
      obligations: [],
      totalCents: 0);
  int tab = 0;
  bool loading = true;
  bool contentLoading = false;
  Object? fatalError;
  StreamSubscription? socketSubscription;
  WebSocketChannel? socketChannel;
  Timer? reconnectTimer;
  Timer? eventDebounce;
  int reconnectAttempt = 0;

  PartyList? get selectedList {
    final id = selectedListId;
    if (id != null) {
      for (final list in lists) {
        if (list.id == id) return list;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    bootstrap();
  }

  Future<void> bootstrap() async {
    try {
      final current = await widget.api.me();
      final available = await widget.api.lists();
      final stored = await Api.storage.read(key: 'selected_list_id');
      final resolved = resolveSelectedListId(available, stored);
      if (!mounted) return;
      setState(() {
        user = current;
        lists = available;
        selectedListId = resolved;
        loading = false;
      });
      if (resolved != null) await reloadSelected();
      unawaited(connectSocket());
    } catch (e) {
      if (mounted) {
        setState(() {
          fatalError = e;
          loading = false;
        });
      }
    }
  }

  Future<void> refreshLists() async {
    final current = await widget.api.me();
    final available = await widget.api.lists();
    final old = selectedListId;
    final resolved = resolveSelectedListId(available, old);
    if (!mounted) return;
    setState(() {
      user = current;
      lists = available;
      selectedListId = resolved;
    });
    if (resolved == null) {
      clearContent();
      await Api.storage.delete(key: 'selected_list_id');
    } else {
      await Api.storage.write(key: 'selected_list_id', value: resolved);
      if (resolved != old) clearContent();
      await reloadSelected();
    }
  }

  Future<void> selectList(String id) async {
    if (id == selectedListId) return;
    setState(() {
      selectedListId = id;
      clearContent(notify: false);
      contentLoading = true;
    });
    await Api.storage.write(key: 'selected_list_id', value: id);
    await reloadSelected();
  }

  void clearContent({bool notify = true}) {
    void clear() {
      items = [];
      scenarios = [];
      participants = [];
      labels = const EtichetteReport(defaultLabel: 'Da Assegnare', labels: []);
      expenses = const SpeseReport(
          spese: [],
          payments: [],
          participants: [],
          obligations: [],
          totalCents: 0);
    }

    if (notify && mounted) {
      setState(clear);
    } else {
      clear();
    }
  }

  Future<void> reloadSelected() async {
    final listId = selectedListId;
    if (listId == null) return;
    if (mounted) setState(() => contentLoading = true);
    try {
      final data = await Future.wait([
        widget.api.elementi(listId),
        widget.api.scenari(listId),
        widget.api.etichette(listId),
        widget.api.participants(listId),
        widget.api.spese(listId),
      ]);
      if (!mounted || selectedListId != listId) return;
      setState(() {
        items = data[0] as List<Elemento>;
        scenarios = data[1] as List<Scenario>;
        labels = data[2] as EtichetteReport;
        participants = data[3] as List<Participant>;
        expenses = data[4] as SpeseReport;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted && selectedListId == listId) {
        setState(() => contentLoading = false);
      }
    }
  }

  Future<void> reloadExpenses() async {
    final listId = selectedListId;
    if (listId == null) return;
    try {
      final value = await widget.api.spese(listId);
      if (mounted && selectedListId == listId) setState(() => expenses = value);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> connectSocket() async {
    reconnectTimer?.cancel();
    try {
      final channel = await widget.api.socket();
      if (!mounted) {
        await channel.sink.close();
        return;
      }
      reconnectAttempt = 0;
      await socketSubscription?.cancel();
      await socketChannel?.sink.close();
      socketChannel = channel;
      socketSubscription = channel.stream.listen(handleSocketEvent,
          onDone: scheduleReconnect, onError: (_) => scheduleReconnect());
    } catch (_) {
      scheduleReconnect();
    }
  }

  void scheduleReconnect() {
    if (!mounted) return;
    socketSubscription?.cancel();
    socketChannel?.sink.close();
    reconnectTimer?.cancel();
    reconnectAttempt++;
    final seconds = reconnectAttempt > 5 ? 30 : 1 << (reconnectAttempt - 1);
    reconnectTimer = Timer(Duration(seconds: seconds), connectSocket);
  }

  void handleSocketEvent(dynamic raw) {
    try {
      final message = jsonDecode(raw as String) as Map<String, dynamic>;
      final event = message['event'] as String?;
      if (event == null || event == 'connected') return;
      final payload =
          Map<String, dynamic>.from((message['payload'] as Map?) ?? const {});
      final listId = payload['lista_id']?.toString();
      if (event == 'lista.invited' || event == 'lista.deleted') {
        eventDebounce?.cancel();
        eventDebounce = Timer(const Duration(milliseconds: 180), refreshLists);
        return;
      }
      if (listId != selectedListId) return;
      eventDebounce?.cancel();
      eventDebounce = Timer(const Duration(milliseconds: 180), () {
        if (event.startsWith('spesa.') || event.startsWith('pagamento.')) {
          reloadExpenses();
        } else {
          reloadSelected();
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    socketSubscription?.cancel();
    socketChannel?.sink.close();
    reconnectTimer?.cancel();
    eventDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (fatalError != null || user == null) {
      return Scaffold(
          body: EmptyState(
        title: 'Impossibile caricare PartySync',
        subtitle: fatalError.toString(),
        icon: Icons.cloud_off,
        action: FilledButton(
            onPressed: () {
              setState(() {
                loading = true;
                fatalError = null;
              });
              bootstrap();
            },
            child: const Text('Riprova')),
      ));
    }
    if (lists.isEmpty) {
      return Scaffold(
        appBar: appBar(),
        body: EmptyState(
          title: 'Nessuna lista disponibile',
          subtitle: user!.canManageLists
              ? 'Crea la prima lista per iniziare.'
              : 'Una guida deve invitarti a una lista.',
          icon: Icons.playlist_remove,
          action: user!.canManageLists
              ? FilledButton.icon(
                  onPressed: createFirstList,
                  icon: const Icon(Icons.add),
                  label: const Text('Crea lista'))
              : null,
        ),
      );
    }
    final currentList = selectedList!;
    final pages = [
      ItemsPage(
          api: widget.api,
          listId: currentList.id,
          items: items,
          labels: labels,
          reload: reloadSelected),
      ScenariosPage(
          api: widget.api,
          listId: currentList.id,
          items: items,
          scenarios: scenarios,
          labels: labels,
          reload: reloadSelected),
      ExpensesPage(
          api: widget.api,
          listId: currentList.id,
          currentUserId: user!.id,
          report: expenses,
          reload: reloadExpenses),
      PrivateListPage(account: user!.username, items: items, labels: labels),
      SettingsPage(
          api: widget.api,
          user: user!,
          lists: lists,
          selectedList: currentList,
          participants: participants,
          selectList: selectList,
          refreshLists: refreshLists,
          reloadSelected: reloadSelected,
          onLogout: widget.onLogout),
    ];
    return Scaffold(
      appBar: appBar(),
      body: contentLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: tab, children: pages),
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
                icon: Icon(Icons.checklist_rounded), label: 'Lista'),
            NavigationDestination(
                icon: Icon(Icons.landscape_rounded), label: 'Scenari'),
            NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Spese'),
            NavigationDestination(
                icon: Icon(Icons.lock_rounded), label: 'Privata'),
            NavigationDestination(
                icon: Icon(Icons.settings_rounded), label: 'Impostazioni'),
          ],
        ),
      ),
    );
  }

  AppBar appBar() => AppBar(
        title: Row(children: [
          SizedBox(
            width: 150,
            height: 70,
            child: Image.asset(
              'assets/brand/logo_lello.png',
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              semanticLabel: 'Lello',
            ),
          ),
          if (selectedList != null)
            Expanded(
                child: Text(selectedList!.nome,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold))),
        ]),
      );

  Future<void> createFirstList() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Crea lista'),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nome')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Annulla')),
                FilledButton(
                    onPressed: () {
                      final value = controller.text.trim();
                      if (value.isNotEmpty) Navigator.pop(dialogContext, value);
                    },
                    child: const Text('Crea')),
              ],
            ));
    controller.dispose();
    if (name == null) return;
    try {
      await widget.api.createList(name);
      await refreshLists();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }
}
