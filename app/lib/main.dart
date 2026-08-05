import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';

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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6750a4)),
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
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
                    Icon(
                      Icons.celebration,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Lello',
                      style: Theme.of(context).textTheme.headlineLarge,
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
      ]);
      if (!mounted) return;
      setState(() {
        items = result[0] as List<Elemento>;
        scenarios = result[1] as List<Scenario>;
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
          title: const Text('Lello'),
          actions: [
            IconButton(
              tooltip: 'Profilo e 2FA',
              icon: const Icon(Icons.manage_accounts),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProfilePage(api: widget.api, onLogout: widget.onLogout),
                ),
              ),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(
                index: tab,
                children: [
                  GlobalList(api: widget.api, items: items, reload: reload),
                  Scenarios(
                    api: widget.api,
                    items: items,
                    scenarios: scenarios,
                    scenarioId: scenarioId,
                    onScenario: (value) => setState(() => scenarioId = value),
                    reload: reload,
                  ),
                  PrivateList(
                    account: username,
                    items: items,
                  ),
                ],
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.checklist), label: 'Lista'),
            NavigationDestination(
              icon: Icon(Icons.collections_bookmark),
              label: 'Scenari',
            ),
            NavigationDestination(
              icon: Icon(Icons.lock_outline),
              label: 'Privata',
            ),
          ],
        ),
      );
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

  const PrivateList({
    super.key,
    required this.account,
    required this.items,
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
        'Da Assegnare',
        ...widget.items
            .map((item) => item.chiPorta)
            .where((name) => name != 'Da Assegnare'),
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
      setState(() => selectedAssignee = 'Da Assegnare');
      unawaited(saveAssignee('Da Assegnare'));
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
        selectedAssignee = values[0] ?? 'Da Assegnare';
        if (!people.contains(selectedAssignee)) {
          selectedAssignee = 'Da Assegnare';
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
      selectedAssignee = 'Da Assegnare';
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
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
        Expanded(
          child: importedItems.isEmpty && localItems.isEmpty
              ? const Center(child: Text('Nessun elemento privato'))
              : ListView(
                  children: [
                    ...importedItems.map((item) {
                      final key = 'global:${item.id}';
                      final done = completed[key] ?? false;
                      return ListTile(
                        leading: Checkbox(
                          value: done,
                          onChanged: (value) =>
                              toggleCompleted(key, value ?? false),
                        ),
                        title: Text(
                          item.nome,
                          style: TextStyle(
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text('Da lista globale: ${item.chiPorta}'),
                      );
                    }),
                    ...localItems.map(
                      (item) => ListTile(
                        leading: Checkbox(
                          value: item.completato,
                          onChanged: (value) =>
                              toggleLocalItem(item, value ?? false),
                        ),
                        title: Text(
                          item.nome,
                          style: TextStyle(
                            decoration: item.completato
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: const Text('Solo su questo dispositivo'),
                        trailing: IconButton(
                          tooltip: 'Elimina item privato',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => deleteLocalItem(item),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(10),
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
                  icon: const Icon(Icons.add),
                  onPressed: addLocalItem,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class GlobalList extends StatefulWidget {
  final Api api;
  final List<Elemento> items;
  final Future<void> Function() reload;
  const GlobalList({
    super.key,
    required this.api,
    required this.items,
    required this.reload,
  });
  @override
  State<GlobalList> createState() => _GlobalListState();
}

class _GlobalListState extends State<GlobalList> {
  final name = TextEditingController();
  String filter = 'Tutti';
  String assignee = 'Da Assegnare';

  List<String> get people => {
        'Da Assegnare',
        ...widget.items
            .map((e) => e.chiPorta)
            .where((e) => e != 'Da Assegnare'),
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

  Future<void> chooseAssignee(Elemento item) async {
    final controller = TextEditingController(
      text: item.chiPorta == 'Da Assegnare' ? '' : item.chiPorta,
    );
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chi lo porta?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nome o Da Assegnare'),
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
                  ? 'Da Assegnare'
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
    if (!people.contains(assignee)) assignee = 'Da Assegnare';
    final visible = filter == 'Tutti'
        ? widget.items
        : widget.items.where((e) => e.chiPorta == filter).toList();
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
              ? const Center(child: Text('Nessun elemento'))
              : RefreshIndicator(
                  onRefresh: widget.reload,
                  child: ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.all(20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async =>
                            await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Eliminare dal DB globale?'),
                                content: Text(item.nome),
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
                            mutate(widget.api.deleteElemento(item.id)),
                        child: ListTile(
                          leading: Checkbox(
                            value: item.completato,
                            onChanged: (value) => mutate(
                              widget.api.patchElemento(item.id, {
                                'completato': value,
                              }),
                            ),
                          ),
                          title: Text(
                            item.nome,
                            style: TextStyle(
                              decoration: item.completato
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Align(
                            alignment: Alignment.centerLeft,
                            child: ActionChip(
                              avatar: const Icon(Icons.person, size: 16),
                              label: Text(item.chiPorta),
                              onPressed: () => chooseAssignee(item),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                mutate(widget.api.deleteElemento(item.id)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nuovo oggetto',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(assignee),
                    initialValue: assignee,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Chi porta',
                      isDense: true,
                    ),
                    items: people
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => assignee = value!),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Aggiungi',
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (name.text.trim().isEmpty) return;
                    mutate(widget.api.addElemento(name.text.trim(), assignee));
                    name.clear();
                  },
                ),
              ],
            ),
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
  final ValueChanged<int?> onScenario;
  final Future<void> Function() reload;
  const Scenarios({
    super.key,
    required this.api,
    required this.items,
    required this.scenarios,
    required this.scenarioId,
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
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Nuovo'),
                onPressed: () async {
                  final value = await textDialog(
                    context,
                    'Nuovo scenario',
                    'Titolo',
                  );
                  if (!context.mounted) return;
                  if (value != null) run(context, api.addScenario(value));
                },
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
        if (current == null)
          const Expanded(
            child: Center(child: Text('Crea uno scenario per iniziare')),
          )
        else ...[
          Expanded(
            child: current.elementi.isEmpty
                ? const Center(child: Text('Nessun elemento associato'))
                : ListView(
                    children: current.elementi
                        .map(
                          (item) => ListTile(
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
                                decoration: item.completato
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Text(item.chiPorta),
                            trailing: IconButton(
                              tooltip: 'Rimuovi dallo scenario',
                              icon: const Icon(Icons.link_off),
                              onPressed: () =>
                                  run(context, api.detach(current.id, item.id)),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: FilledButton.tonalIcon(
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
    final names = items
        .map((item) => item.chiPorta)
        .where((name) => name != 'Da Assegnare')
        .toSet()
        .toList()
      ..sort();
    final input = await _newItemDialog(context, ['Da Assegnare', ...names]);
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
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await widget.api.me();
      if (mounted) setState(() => user = value);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profilo e sicurezza')),
        body: user == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(user!['username']),
                    subtitle: const Text('Account Lello'),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Autenticazione a due fattori'),
                    subtitle:
                        Text(user!['totp_enabled'] ? 'Attiva' : 'Non attiva'),
                    value: user!['totp_enabled'],
                    onChanged: (enabled) =>
                        enabled ? enable2fa() : disable2fa(),
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
