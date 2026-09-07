import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'app_theme.dart';
import 'models.dart';
import 'security.dart';

class SettingsPage extends StatefulWidget {
  final Api api;
  final AppUser user;
  final List<PartyList> lists;
  final PartyList selectedList;
  final List<Participant> participants;
  final Future<void> Function(String) selectList;
  final Future<void> Function() refreshLists;
  final Future<void> Function() reloadSelected;
  final VoidCallback onLogout;

  const SettingsPage({
    super.key,
    required this.api,
    required this.user,
    required this.lists,
    required this.selectedList,
    required this.participants,
    required this.selectList,
    required this.refreshLists,
    required this.reloadSelected,
    required this.onLogout,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool busy = false;
  List<Participant>? invitables;
  List<AdminUser>? adminUsers;

  @override
  void initState() {
    super.initState();
    loadRestricted();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedList.id != widget.selectedList.id) {
      invitables = null;
      loadRestricted();
    }
  }

  Future<void> loadRestricted() async {
    try {
      final invited = widget.user.canManageLists
          ? await widget.api.invitables(widget.selectedList.id)
          : <Participant>[];
      final users = widget.user.isAmosAdmin
          ? await widget.api.adminUsers()
          : <AdminUser>[];
      if (mounted) {
        setState(() {
          invitables = invited;
          adminUsers = users;
        });
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> mutate(Future<void> Function() action, {String? success}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      if (success != null && mounted) showSuccess(context, success);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool get canDeleteList =>
      widget.user.ruolo == 'superadmin' ||
      widget.selectedList.creatorId == widget.user.id;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 30),
        children: [
          _title('Lista attiva'),
          SurfaceCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(widget.selectedList.id),
                    value: widget.selectedList.id,
                    decoration: const InputDecoration(labelText: 'Lista'),
                    items: widget.lists
                        .map(
                          (list) => DropdownMenuItem(
                            value: list.id,
                            child: Text(
                              '${list.nome} · ${list.participantCount} partecipanti',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (value) {
                            if (value != null) widget.selectList(value);
                          },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Creata da ${widget.selectedList.creatorUsername}',
                      style: const TextStyle(color: muted),
                    ),
                  ),
                  if (widget.user.canManageLists || canDeleteList) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (widget.user.canManageLists)
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('create-list'),
                              onPressed: busy ? null : createList,
                              icon: const Icon(Icons.add),
                              label: const Text('Crea lista'),
                            ),
                          ),
                        if (widget.user.canManageLists && canDeleteList)
                          const SizedBox(width: 8),
                        if (canDeleteList)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: busy ? null : deleteList,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Elimina'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          _title('Partecipanti'),
          ...widget.participants.map(
            (person) => SurfaceCard(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: sageSoft,
                  foregroundColor: sage,
                  child: Icon(Icons.person),
                ),
                title: Text(person.username),
                subtitle: Text(person.ruolo),
              ),
            ),
          ),
          if (widget.user.canManageLists)
            InviteTile(
              availableCount: invitables?.length,
              busy: busy,
              onInvite: invite,
            ),
          if (widget.user.canInviteNewUsers)
            SurfaceCard(
              child: ListTile(
                key: const Key('registration-invite-tile'),
                leading: const Icon(Icons.person_add, color: lagoon),
                title: const Text('Invita nuovo utente'),
                subtitle:
                    const Text('Genera codice o link per la registrazione'),
                trailing: const Icon(Icons.chevron_right),
                enabled: !busy,
                onTap: generateRegistrationInvite,
              ),
            ),
          _title('Profilo e sicurezza'),
          SurfaceCard(
            child: ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(
                widget.user.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${widget.user.ruolo}${widget.user.canInviteUsers ? ' · Può invitare utenti' : ''}',
              ),
            ),
          ),
          SurfaceCard(
            child: SwitchListTile(
              title: const Text('Autenticazione a due fattori'),
              subtitle: Text(widget.user.totpEnabled ? 'Attiva' : 'Non attiva'),
              value: widget.user.totpEnabled,
              onChanged: busy
                  ? null
                  : (enabled) => enabled ? enable2fa() : disable2fa(),
            ),
          ),
          if (widget.user.isAmosAdmin) ...[
            _title('Gestione utenti'),
            AdminSection(
              users: adminUsers,
              busy: busy,
              onCreate: createUser,
              onEdit: editUser,
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      await widget.api.logout();
                      widget.onLogout();
                    },
              icon: const Icon(Icons.logout),
              label: const Text('Esci'),
            ),
          ),
        ],
      );

  Widget _title(String value) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );

  Future<void> createList() async {
    final name = await textDialog(context, 'Crea lista', 'Nome');
    if (name == null) return;
    await mutate(() async {
      await widget.api.createList(name);
      await widget.refreshLists();
    }, success: 'Lista creata');
  }

  Future<void> deleteList() async {
    if (!await confirmDialog(
      context,
      'Eliminare definitivamente la lista?',
      'Saranno eliminati tutti i contenuti di “${widget.selectedList.nome}”.',
    )) {
      return;
    }
    await mutate(() async {
      await widget.api.deleteList(widget.selectedList.id);
      await widget.refreshLists();
    }, success: 'Lista eliminata');
  }

  Future<void> invite() async {
    final selected = await showDialog<Participant>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Invita partecipante'),
        children: invitables!
            .map(
              (person) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, person),
                child: ListTile(
                  title: Text(person.username),
                  subtitle: Text(person.ruolo),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (selected == null) return;
    await mutate(() async {
      await widget.api.invite(widget.selectedList.id, selected.id);
      await widget.reloadSelected();
      await widget.refreshLists();
      await loadRestricted();
    }, success: '${selected.username} aggiunto alla lista');
  }

  Future<void> enable2fa() async {
    await mutate(() async {
      final setup = await widget.api.setup2fa();
      if (!mounted) return;
      final controller = TextEditingController();
      final bytes = base64Decode(
        (setup['qr_data_url'] as String).split(',').last,
      );
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Configura 2FA'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.memory(bytes, width: 210, height: 210),
                const SizedBox(height: 8),
                SelectableText('Secret: ${setup['secret']}'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'Codice OTP'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.api.enable2fa(controller.text.trim());
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (e) {
                  if (dialogContext.mounted) showError(dialogContext, e);
                }
              },
              child: const Text('Attiva'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (confirmed == true) await widget.refreshLists();
    });
  }

  Future<void> disable2fa() async {
    final password = await _passwordDialog('Disattiva 2FA');
    if (password != null) {
      await mutate(() async {
        await widget.api.disable2fa(password);
        await widget.refreshLists();
      });
    }
  }

  Future<String?> _passwordDialog(String title) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    controller.clear();
    controller.dispose();
    return value;
  }

  Future<void> generateRegistrationInvite() async {
    await mutate(() async {
      final res = await widget.api.createRegistrationInvite();
      if (!mounted) return;
      final code =
          (res['code'] ?? res['invite_code'] ?? res['token'] ?? '') as String;
      final link = (res['link'] ??
          (code.isNotEmpty
              ? 'https://partysync.amosgranata.it/join?code=$code'
              : '')) as String;

      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: lagoon),
              SizedBox(width: 8),
              Text('Invito Registrazione'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Condividi questo codice con l’utente da invitare. L’utente potrà registrarsi ma non potrà invitare altri finché non lo approvi.',
                style: TextStyle(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sand2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        code.isNotEmpty ? code : link,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copia',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: code.isNotEmpty ? code : link),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Codice copiato negli appunti'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      );
    }, success: 'Invito generato');
  }

  Future<void> createUser() async {
    final data = await userDialog(context);
    if (data == null) return;
    await mutate(() async {
      await widget.api.createUser(
        data.$1,
        data.$2!,
        data.$3,
        canInviteUsers: data.$4,
      );
      await loadRestricted();
    }, success: 'Utente creato');
  }

  Future<void> editUser(AdminUser user) async {
    final data = await userDialog(context, user: user);
    if (data == null) return;
    await mutate(() async {
      await widget.api.updateUser(
        user.id,
        role: user.username == 'amos' ? null : data.$3,
        password: data.$2,
        canInviteUsers: data.$4,
      );
      await loadRestricted();
    }, success: 'Utente aggiornato');
  }
}

class InviteTile extends StatelessWidget {
  final int? availableCount;
  final bool busy;
  final VoidCallback onInvite;

  const InviteTile({
    super.key,
    required this.availableCount,
    required this.busy,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) => SurfaceCard(
        child: ListTile(
          key: const Key('invite-section'),
          leading: const Icon(Icons.person_add_alt_1, color: lagoon),
          title: const Text('Invita partecipante'),
          subtitle: Text(
            availableCount == null
                ? 'Caricamento…'
                : availableCount == 0
                    ? 'Nessun utente invitabile'
                    : '$availableCount disponibili',
          ),
          trailing: const Icon(Icons.chevron_right),
          enabled: !busy && (availableCount ?? 0) > 0,
          onTap: onInvite,
        ),
      );
}

class AdminSection extends StatelessWidget {
  final List<AdminUser>? users;
  final bool busy;
  final VoidCallback onCreate;
  final ValueChanged<AdminUser> onEdit;
  const AdminSection({
    super.key,
    required this.users,
    required this.busy,
    required this.onCreate,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) => Column(
        key: const Key('admin-section'),
        children: [
          if (users == null) const CircularProgressIndicator(),
          ...?users?.map(
            (user) => SurfaceCard(
              child: ListTile(
                title: Text(user.username),
                subtitle: Text(
                  '${user.ruolo}${user.canInviteUsers ? ' · Può invitare' : ''}${user.totpEnabled ? ' · 2FA' : ''}',
                ),
                trailing: IconButton(
                  onPressed: busy ? null : () => onEdit(user),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              key: const Key('create-user'),
              onPressed: busy ? null : onCreate,
              icon: const Icon(Icons.person_add),
              label: const Text('Crea utente'),
            ),
          ),
        ],
      );
}

Future<(String, String?, String, bool)?> userDialog(
  BuildContext context, {
  AdminUser? user,
}) async {
  final username = TextEditingController(text: user?.username ?? '');
  final password = TextEditingController();
  final confirm = TextEditingController();
  var role = user?.ruolo == 'follower' ? 'follower' : 'guida';
  var canInvite = user?.canInviteUsers ?? false;
  String? error;
  final result = await showDialog<(String, String?, String, bool)>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(user == null ? 'Crea utente' : 'Modifica ${user.username}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: username,
                enabled: user == null,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              if (user?.username != 'amos') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Ruolo'),
                  items: const [
                    DropdownMenuItem(value: 'guida', child: Text('Guida')),
                    DropdownMenuItem(
                      value: 'follower',
                      child: Text('Follower'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    role = value!;
                    if (role != 'guida') canInvite = false;
                  }),
                ),
                if (role == 'guida') ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Può invitare utenti',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Permette di generare inviti alla registrazione',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: canInvite,
                    onChanged: (val) => setState(() => canInvite = val),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText:
                      user == null ? 'Password' : 'Nuova password (opzionale)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Conferma password',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(error!, style: const TextStyle(color: danger)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final uValidation = UsernameValidationResult.validate(
                username.text,
              );
              if (!uValidation.isValid) {
                setState(() => error = uValidation.errorMessage);
                return;
              }

              final pass = password.text;
              if (user == null || pass.isNotEmpty) {
                final pValidation = PasswordValidationResult.validate(
                  pass,
                  username: username.text,
                );
                if (!pValidation.isValid) {
                  setState(() => error = pValidation.errorMessage);
                  return;
                }
              }

              if (pass != confirm.text) {
                setState(() => error = 'Le password non coincidono');
                return;
              }

              Navigator.pop(dialogContext, (
                username.text.trim(),
                pass.isEmpty ? null : pass,
                role,
                role == 'guida' ? canInvite : false,
              ));
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    ),
  );
  password.clear();
  confirm.clear();
  username.dispose();
  password.dispose();
  confirm.dispose();
  return result;
}
