import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () async {
                    final shareText = 'Ti invito su Lello! 🎉\n\n'
                        '1. Installa l’app dall’APK allegato.\n'
                        '2. Apri Lello e tocca "Registrati".\n'
                        '3. Inserisci il codice di invito:\n'
                        '$code\n\n'
                        '(Codice monouso valido per una registrazione)';
                    
                    // Copia automaticamente negli appunti per sicurezza
                    await Clipboard.setData(ClipboardData(text: shareText));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '📋 Testo e codice copiati! Se la chat invia solo il file APK, incolla il messaggio subito sotto.',
                          ),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    }

                    try {
                      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
                        const channel =
                            MethodChannel('it.partysync.partysync/apk_share');
                        final String? apkPath =
                            await channel.invokeMethod<String>('getApkPath');
                        if (apkPath != null && File(apkPath).existsSync()) {
                          await Share.shareXFiles(
                            [
                              XFile(
                                apkPath,
                                mimeType:
                                    'application/vnd.android.package-archive',
                                name: 'Lello.apk',
                              ),
                            ],
                            text: shareText,
                            subject: 'Invito a Lello',
                          );
                          return;
                        }
                      }
                    } catch (e) {
                      debugPrint('Errore condivisione APK: $e');
                    }
                    await Share.share(shareText, subject: 'Invito a Lello');
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Invia file APK + Istruzioni'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final shareText = 'Ti invito su Lello! 🎉\n\n'
                        '1. Installa l’app Lello.\n'
                        '2. Apri l’app e tocca "Registrati".\n'
                        '3. Inserisci il codice di invito:\n'
                        '$code\n\n'
                        '(Codice monouso valido per una registrazione)';
                    await Clipboard.setData(ClipboardData(text: shareText));
                    await Share.share(shareText, subject: 'Invito a Lello');
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Invia solo Messaggio con Codice'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
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

enum AdminFilter { all, guide, follower, canInvite, totp }

class AdminSection extends StatefulWidget {
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
  State<AdminSection> createState() => _AdminSectionState();
}

class _AdminSectionState extends State<AdminSection> {
  final searchController = TextEditingController();
  AdminFilter filter = AdminFilter.all;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Widget _statBadge(String label, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      );

  Widget _filterChip(String label, AdminFilter target) {
    final active = filter == target;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: lagoon,
      backgroundColor: sand0,
      labelStyle: TextStyle(
        color: active ? Colors.white : ink,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(color: active ? lagoon : line),
      onSelected: (_) => setState(() => filter = target),
    );
  }

  Widget _userCard(AdminUser user) {
    final isSuper = user.ruolo == 'superadmin';
    final isGuida = user.ruolo == 'guida';
    final avatarColor = isSuper
        ? sunset
        : isGuida
            ? lagoon
            : sage;
    final avatarBg = isSuper
        ? sunsetSoft
        : isGuida
            ? lagoonSoft
            : sageSoft;
    final avatarIcon = isSuper
        ? Icons.shield
        : isGuida
            ? Icons.explore
            : Icons.person;

    return SurfaceCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: avatarBg,
          foregroundColor: avatarColor,
          child: Icon(avatarIcon, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.totpEnabled)
              const Tooltip(
                message: '2FA Attivo',
                child: Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.verified_user, size: 16, color: gold),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSuper
                      ? sunsetSoft
                      : isGuida
                          ? lagoonSoft
                          : sageSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  user.ruolo.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSuper
                        ? sunset
                        : isGuida
                            ? lagoon
                            : ink,
                  ),
                ),
              ),
              if (isGuida)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: user.canInviteUsers ? sageSoft : sand2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user.canInviteUsers ? Icons.check : Icons.lock_outline,
                        size: 11,
                        color: user.canInviteUsers ? sage : muted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        user.canInviteUsers ? 'Può invitare' : 'No inviti',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: user.canInviteUsers ? ink : muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        trailing: IconButton(
          onPressed: widget.busy ? null : () => widget.onEdit(user),
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Modifica utente',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.users == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final query = searchController.text.trim().toLowerCase();
    final users = widget.users!;

    final guideCount = users.where((u) => u.ruolo == 'guida').length;
    final guideCanInviteCount =
        users.where((u) => u.ruolo == 'guida' && u.canInviteUsers).length;
    final followerCount = users.where((u) => u.ruolo == 'follower').length;
    final totpCount = users.where((u) => u.totpEnabled).length;

    final filtered = users.where((u) {
      if (query.isNotEmpty && !u.username.toLowerCase().contains(query)) {
        return false;
      }
      switch (filter) {
        case AdminFilter.all:
          return true;
        case AdminFilter.guide:
          return u.ruolo == 'guida';
        case AdminFilter.follower:
          return u.ruolo == 'follower';
        case AdminFilter.canInvite:
          return u.canInviteUsers || u.username == 'amos';
        case AdminFilter.totp:
          return u.totpEnabled;
      }
    }).toList();

    return Column(
      key: const Key('admin-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pannello Utenti (${users.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: ink,
                      ),
                    ),
                    FilledButton.icon(
                      key: const Key('create-user'),
                      onPressed: widget.busy ? null : widget.onCreate,
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Nuovo'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _statBadge(
                      'Guide: $guideCount ($guideCanInviteCount attive)',
                      lagoon,
                      lagoonSoft,
                    ),
                    _statBadge('Follower: $followerCount', sage, sageSoft),
                    _statBadge('2FA: $totpCount', gold, sand2),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Cerca per username…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => searchController.clear()),
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: sand0,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _filterChip('Tutti (${users.length})', AdminFilter.all),
              const SizedBox(width: 6),
              _filterChip('Guide ($guideCount)', AdminFilter.guide),
              const SizedBox(width: 6),
              _filterChip('Follower ($followerCount)', AdminFilter.follower),
              const SizedBox(width: 6),
              _filterChip('Può invitare', AdminFilter.canInvite),
              const SizedBox(width: 6),
              _filterChip('2FA ($totpCount)', AdminFilter.totp),
            ],
          ),
        ),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Nessun utente corrisponde ai filtri impostati',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            ),
          )
        else
          ...filtered.map((user) => _userCard(user)),
      ],
    );
  }
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
