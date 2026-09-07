import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api.dart';
import 'app_theme.dart';
import 'content_pages.dart';
import 'expenses_page.dart';
import 'models.dart';
import 'security.dart';
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
    api = Api(
      onUnauthorized: () {
        if (mounted) setState(() => authenticated = false);
      },
    );
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
                  BoxShadow(color: Color(0x2916231F), blurRadius: 60)
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
                    onLogout: () => setState(() => authenticated = false),
                  )
                : LoginPage(
                    api: api,
                    onLogin: () => setState(() => authenticated = true),
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
  final username = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final inviteCode = TextEditingController();
  final otp = TextEditingController();
  String? ticket;
  bool isRegistering = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    password.addListener(_onFieldChanged);
    username.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (isRegistering && mounted) setState(() {});
  }

  @override
  void dispose() {
    password.removeListener(_onFieldChanged);
    username.removeListener(_onFieldChanged);
    username.dispose();
    password.dispose();
    confirmPassword.dispose();
    inviteCode.dispose();
    otp.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (isRegistering) {
        if (inviteCode.text.trim().isEmpty) {
          throw ApiException('Inserisci il codice di invito');
        }
        final uValidation = UsernameValidationResult.validate(username.text);
        if (!uValidation.isValid) {
          throw ApiException(uValidation.errorMessage ?? 'Username non valido');
        }
        final pValidation = PasswordValidationResult.validate(
          password.text,
          username: username.text,
        );
        if (!pValidation.isValid) {
          throw ApiException(
            pValidation.errorMessage ?? 'Password non conforme',
          );
        }
        if (password.text != confirmPassword.text) {
          throw ApiException('Le password non coincidono');
        }

        final res = await widget.api.register(
          inviteCode: inviteCode.text.trim(),
          username: username.text.trim(),
          password: password.text,
        );

        if (res['token'] != null && (res['token'] as String).isNotEmpty) {
          await widget.api.acceptToken(res['token'] as String);
          widget.onLogin();
        } else {
          final loginRes = await widget.api.login(
            username.text.trim(),
            password.text,
          );
          if (loginRes['token'] != null) {
            await widget.api.acceptToken(loginRes['token'] as String);
            widget.onLogin();
          } else {
            setState(() {
              isRegistering = false;
              password.clear();
              confirmPassword.clear();
            });
            if (mounted) {
              showSuccess(
                context,
                'Registrazione completata! Effettua il login.',
              );
            }
          }
        }
      } else {
        if (ticket == null) {
          final result = await widget.api.login(
            username.text.trim(),
            password.text,
          );
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
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _buildPasswordRequirements(PasswordValidationResult result) {
    Widget item(String label, bool satisfied) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(
                satisfied ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 15,
                color: satisfied ? sage : muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: satisfied ? ink : muted,
                    fontWeight: satisfied ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sand0,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Requisiti password:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          item('Almeno 8 caratteri', result.hasMinLength),
          item('Almeno una lettera maiuscola', result.hasUppercase),
          item('Almeno una lettera minuscola', result.hasLowercase),
          item('Almeno un numero', result.hasDigit),
          item('Almeno un simbolo speciale (!@#\$%^&*)', result.hasSymbol),
          item('Nessuna password comune nota', result.isNotCommon),
          if (username.text.trim().length >= 3)
            item('Non contiene il tuo username', result.doesNotContainUsername),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passResult = PasswordValidationResult.validate(
      password.text,
      username: username.text,
    );

    return Scaffold(
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
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 34,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isRegistering
                        ? 'Registrazione su invito'
                        : ticket != null
                            ? 'Autenticazione a due fattori'
                            : 'Accedi al tuo gruppo',
                    style: const TextStyle(color: muted, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  if (isRegistering) ...[
                    TextField(
                      controller: inviteCode,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Codice invito',
                        hintText: 'Inserisci il codice ricevuto',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: username,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: password,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildPasswordRequirements(passResult),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmPassword,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Conferma password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                  ] else if (ticket == null) ...[
                    TextField(
                      controller: username,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: password,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(labelText: 'Password'),
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
                      decoration: const InputDecoration(
                        labelText: 'Codice OTP',
                      ),
                      onSubmitted: (_) => submit(),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: busy ? null : submit,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isRegistering
                                ? Icons.person_add
                                : ticket == null
                                    ? Icons.login
                                    : Icons.verified_user,
                          ),
                    label: Text(
                      isRegistering
                          ? 'Completa registrazione'
                          : ticket == null
                              ? 'Accedi'
                              : 'Verifica',
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (ticket == null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              setState(() {
                                isRegistering = !isRegistering;
                                password.clear();
                                confirmPassword.clear();
                              });
                            },
                      child: Text(
                        isRegistering
                            ? 'Hai già un account? Accedi'
                            : 'Hai un codice di invito? Registrati',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
  List<PartyList> pendingInvites = [];
  Set<String> acceptedListIds = {};
  Set<String> rejectedListIds = {};
  String? selectedListId;
  List<Elemento> items = [];
  List<Scenario> scenarios = [];
  List<Participant> participants = [];
  EtichetteReport labels = const EtichetteReport(
    defaultLabel: 'Da Assegnare',
    labels: [],
  );
  SpeseReport expenses = const SpeseReport(
    spese: [],
    payments: [],
    participants: [],
    obligations: [],
    totalCents: 0,
  );
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

  Future<void> loadInvitationsState(String userId) async {
    try {
      final acceptedJson =
          await Api.storage.read(key: 'user_$userId:accepted_lists');
      final rejectedJson =
          await Api.storage.read(key: 'user_$userId:rejected_lists');
      acceptedListIds = acceptedJson != null
          ? Set<String>.from(jsonDecode(acceptedJson) as List)
          : {};
      rejectedListIds = rejectedJson != null
          ? Set<String>.from(jsonDecode(rejectedJson) as List)
          : {};
    } catch (_) {
      acceptedListIds = {};
      rejectedListIds = {};
    }
  }

  Future<void> saveInvitationsState(String userId) async {
    try {
      await Api.storage.write(
        key: 'user_$userId:accepted_lists',
        value: jsonEncode(acceptedListIds.toList()),
      );
      await Api.storage.write(
        key: 'user_$userId:rejected_lists',
        value: jsonEncode(rejectedListIds.toList()),
      );
    } catch (_) {}
  }

  Future<void> bootstrap() async {
    try {
      final current = await widget.api.me();
      await loadInvitationsState(current.id);
      final rawLists = await widget.api.lists();
      final pending = findPendingInvites(
        rawLists,
        current.id,
        acceptedListIds,
        rejectedListIds,
      );
      final visible = filterAcceptedLists(
        rawLists,
        current.id,
        acceptedListIds,
        rejectedListIds,
      );
      final stored = await Api.storage.read(key: 'selected_list_id');
      final resolved = resolveSelectedListId(visible, stored);
      if (!mounted) return;
      setState(() {
        user = current;
        lists = visible;
        pendingInvites = pending;
        selectedListId = resolved;
        loading = false;
      });
      if (resolved != null) await reloadSelected();
      unawaited(connectSocket());

      if (pending.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) promptNextInvite();
        });
      }
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
    await loadInvitationsState(current.id);
    final rawLists = await widget.api.lists();
    final pending = findPendingInvites(
      rawLists,
      current.id,
      acceptedListIds,
      rejectedListIds,
    );
    final visible = filterAcceptedLists(
      rawLists,
      current.id,
      acceptedListIds,
      rejectedListIds,
    );
    final old = selectedListId;
    final resolved = resolveSelectedListId(visible, old);
    if (!mounted) return;
    setState(() {
      user = current;
      lists = visible;
      pendingInvites = pending;
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

  Future<void> acceptInvite(PartyList list) async {
    if (user == null) return;
    acceptedListIds.add(list.id);
    rejectedListIds.remove(list.id);
    await saveInvitationsState(user!.id);
    await refreshLists();
    await selectList(list.id);
    if (mounted) {
      showSuccess(context, 'Hai accettato l’invito a “${list.nome}”!');
    }
  }

  Future<void> declineInvite(PartyList list) async {
    if (user == null) return;
    rejectedListIds.add(list.id);
    acceptedListIds.remove(list.id);
    await saveInvitationsState(user!.id);
    await refreshLists();
    if (mounted) {
      showSuccess(context, 'Hai rifiutato l’invito a “${list.nome}”.');
    }
  }

  Future<void> promptInvite(PartyList list) async {
    final accept = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mail_outline, color: lagoon),
            SizedBox(width: 8),
            Text('Nuovo invito a una lista'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${list.creatorUsername.isNotEmpty ? list.creatorUsername : "Una guida"} ti ha invitato a partecipare alla lista:',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sand0,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.playlist_add_check, color: sunset),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      list.nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Vuoi accettare l’invito per visualizzare e gestire elementi e spese?',
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('decline-invite'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Rifiuta', style: TextStyle(color: danger)),
          ),
          FilledButton(
            key: const Key('accept-invite'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Accetta'),
          ),
        ],
      ),
    );

    if (accept == true) {
      await acceptInvite(list);
    } else if (accept == false) {
      await declineInvite(list);
    }
  }

  void promptNextInvite() {
    if (pendingInvites.isNotEmpty && mounted) {
      promptInvite(pendingInvites.first);
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
        totalCents: 0,
      );
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
      socketSubscription = channel.stream.listen(
        handleSocketEvent,
        onDone: scheduleReconnect,
        onError: (_) => scheduleReconnect(),
      );
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
      final payload = Map<String, dynamic>.from(
        (message['payload'] as Map?) ?? const {},
      );
      final listId = payload['lista_id']?.toString();
      if (event == 'lista.invited') {
        eventDebounce?.cancel();
        eventDebounce = Timer(const Duration(milliseconds: 180), () async {
          await refreshLists();
          if (mounted && pendingInvites.isNotEmpty) {
            promptNextInvite();
          }
        });
        return;
      }
      if (event == 'lista.deleted') {
        eventDebounce?.cancel();
        eventDebounce = Timer(const Duration(milliseconds: 180), () async {
          final wasSelected = listId == selectedListId;
          await refreshLists();
          if (wasSelected && mounted) {
            showError(
              context,
              'La lista attiva è stata eliminata da una guida o amministratore.',
            );
          }
        });
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
            child: const Text('Riprova'),
          ),
        ),
      );
    }
    if (lists.isEmpty && !(user?.isAmosAdmin ?? false)) {
      return Scaffold(
        appBar: appBar(),
        body: Column(
          children: [
            if (pendingInvites.isNotEmpty)
              _buildPendingInvitesBanner(),
            Expanded(
              child: EmptyState(
                title: 'Nessuna lista attiva',
                subtitle: pendingInvites.isNotEmpty
                    ? 'Hai ${pendingInvites.length} invito in attesa di risposta.'
                    : user!.canManageLists
                        ? 'Crea la prima lista per iniziare.'
                        : 'Una guida deve invitarti a una lista.',
                icon: pendingInvites.isNotEmpty
                    ? Icons.mail_outline
                    : Icons.playlist_remove,
                action: pendingInvites.isNotEmpty
                    ? FilledButton.icon(
                        onPressed: promptNextInvite,
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Visualizza inviti'),
                      )
                    : user!.canManageLists
                        ? FilledButton.icon(
                            onPressed: createFirstList,
                            icon: const Icon(Icons.add),
                            label: const Text('Crea lista'),
                          )
                        : null,
              ),
            ),
          ],
        ),
      );
    }
    final currentList = selectedList;
    final pages = [
      currentList != null
          ? ItemsPage(
              api: widget.api,
              listId: currentList.id,
              items: items,
              labels: labels,
              reload: reloadSelected,
            )
          : EmptyState(
              title: 'Nessuna lista attiva',
              subtitle: 'Crea la prima lista per iniziare.',
              icon: Icons.checklist_rounded,
              action: (user?.canManageLists ?? false)
                  ? FilledButton.icon(
                      onPressed: createFirstList,
                      icon: const Icon(Icons.add),
                      label: const Text('Crea lista'),
                    )
                  : null,
            ),
      currentList != null
          ? ScenariosPage(
              api: widget.api,
              listId: currentList.id,
              items: items,
              scenarios: scenarios,
              labels: labels,
              reload: reloadSelected,
            )
          : EmptyState(
              title: 'Nessuna lista attiva',
              subtitle: 'Crea una lista per gestire gli scenari.',
              icon: Icons.landscape_rounded,
              action: (user?.canManageLists ?? false)
                  ? FilledButton.icon(
                      onPressed: createFirstList,
                      icon: const Icon(Icons.add),
                      label: const Text('Crea lista'),
                    )
                  : null,
            ),
      currentList != null
          ? ExpensesPage(
              api: widget.api,
              listId: currentList.id,
              currentUserId: user!.id,
              report: expenses,
              reload: reloadExpenses,
            )
          : EmptyState(
              title: 'Nessuna lista attiva',
              subtitle: 'Crea una lista per gestire le spese.',
              icon: Icons.account_balance_wallet_rounded,
              action: (user?.canManageLists ?? false)
                  ? FilledButton.icon(
                      onPressed: createFirstList,
                      icon: const Icon(Icons.add),
                      label: const Text('Crea lista'),
                    )
                  : null,
            ),
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
        onLogout: widget.onLogout,
      ),
    ];
    return Scaffold(
      appBar: appBar(),
      body: Column(
        children: [
          if (pendingInvites.isNotEmpty)
            _buildPendingInvitesBanner(),
          Expanded(
            child: contentLoading
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(index: tab, children: pages),
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
            NavigationDestination(
              icon: Icon(Icons.settings_rounded),
              label: 'Impostazioni',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingInvitesBanner() => Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sunsetSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sunset.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.mark_email_unread_outlined, color: sunset),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hai ${pendingInvites.length} ${pendingInvites.length == 1 ? "invito in attesa" : "inviti in attesa"}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: ink,
                ),
              ),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: promptNextInvite,
              child: const Text('Rispondi'),
            ),
          ],
        ),
      );

  AppBar appBar() => AppBar(
        title: Row(
          children: [
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
                child: Text(
                  selectedList!.nome,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
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
          decoration: const InputDecoration(labelText: 'Nome'),
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
            child: const Text('Crea'),
          ),
        ],
      ),
    );
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
