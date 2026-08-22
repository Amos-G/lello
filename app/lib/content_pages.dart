import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'api.dart';
import 'app_theme.dart';
import 'models.dart';

class ItemsPage extends StatefulWidget {
  final Api api;
  final String listId;
  final List<Elemento> items;
  final EtichetteReport labels;
  final Future<void> Function() reload;
  const ItemsPage(
      {super.key,
      required this.api,
      required this.listId,
      required this.items,
      required this.labels,
      required this.reload});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  bool busy = false;

  Future<void> mutate(Future<void> action) async {
    if (busy) return;
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

  Future<void> addItem() async {
    final result = await itemDialog(context, widget.labels.options);
    if (result != null) {
      await mutate(
          widget.api.createElemento(widget.listId, result.$1, result.$2));
    }
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        RefreshIndicator(
          onRefresh: widget.reload,
          child: widget.items.isEmpty
              ? ListView(children: const [
                  SizedBox(
                      height: 500,
                      child: EmptyState(
                          title: 'Nessun elemento',
                          subtitle: 'Aggiungi ciò che serve alla festa.',
                          icon: Icons.checklist_rounded))
                ])
              : ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 90),
                  children: widget.items
                      .map((item) => SurfaceCard(
                            child: ListTile(
                              leading: Checkbox(
                                value: item.completato,
                                onChanged: busy
                                    ? null
                                    : (value) => mutate(widget.api
                                        .patchElemento(widget.listId, item.id,
                                            {'completato': value == true})),
                              ),
                              title: Text(item.nome,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      decoration: item.completato
                                          ? TextDecoration.lineThrough
                                          : null)),
                              subtitle: Text(item.chiPorta),
                              onTap: busy
                                  ? null
                                  : () async {
                                      final result = await itemDialog(
                                          context, widget.labels.options,
                                          item: item);
                                      if (result != null) {
                                        await mutate(widget.api.patchElemento(
                                            widget.listId, item.id, {
                                          'nome': result.$1,
                                          'chi_porta_utente_id': result.$2
                                        }));
                                      }
                                    },
                              trailing: IconButton(
                                tooltip: 'Elimina',
                                color: danger,
                                onPressed: busy
                                    ? null
                                    : () async {
                                        if (await confirmDialog(
                                            context,
                                            'Eliminare l’elemento?',
                                            'Sarà rimosso anche dai tuoi scenari privati.')) {
                                          await mutate(widget.api
                                              .deleteElemento(
                                                  widget.listId, item.id));
                                        }
                                      },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ),
                          ))
                      .toList(),
                ),
        ),
        Positioned(
            right: 18,
            bottom: 18,
            child: FloatingActionButton.extended(
              onPressed: busy ? null : addItem,
              icon: const Icon(Icons.add),
              label: const Text('Elemento'),
            )),
      ]);
}

Future<(String, String?)?> itemDialog(
    BuildContext context, List<AssigneeOption> options,
    {Elemento? item}) async {
  final controller = TextEditingController(text: item?.nome ?? '');
  String? assignee = item?.assigneeUserId;
  final result = await showDialog<(String, String?)>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
              title:
                  Text(item == null ? 'Nuovo elemento' : 'Modifica elemento'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Nome')),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: assignee ?? '',
                  decoration: const InputDecoration(labelText: 'Chi lo porta'),
                  items: options
                      .map((option) => DropdownMenuItem(
                          value: option.userId ?? '',
                          child: Text(option.label)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => assignee = value == '' ? null : value),
                ),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Annulla')),
                FilledButton(
                    onPressed: () {
                      final name = controller.text.trim();
                      if (name.isNotEmpty) {
                        Navigator.pop(dialogContext, (name, assignee));
                      }
                    },
                    child: const Text('Salva')),
              ],
            )),
  );
  controller.dispose();
  return result;
}

class ScenariosPage extends StatefulWidget {
  final Api api;
  final String listId;
  final List<Elemento> items;
  final List<Scenario> scenarios;
  final EtichetteReport labels;
  final Future<void> Function() reload;
  const ScenariosPage(
      {super.key,
      required this.api,
      required this.listId,
      required this.items,
      required this.scenarios,
      required this.labels,
      required this.reload});

  @override
  State<ScenariosPage> createState() => _ScenariosPageState();
}

class _ScenariosPageState extends State<ScenariosPage> {
  String? selectedId;
  bool busy = false;

  Scenario? get selected {
    final id = selectedId;
    if (id != null) {
      for (final scenario in widget.scenarios) {
        if (scenario.id == id) return scenario;
      }
    }
    return widget.scenarios.isEmpty ? null : widget.scenarios.first;
  }

  Future<void> mutate(Future<void> action) async {
    if (busy) return;
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

  @override
  Widget build(BuildContext context) {
    final current = selected;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
              child: DropdownButtonFormField<String>(
            key: ValueKey(current?.id),
            value: current?.id,
            hint: const Text('Nessuno scenario'),
            items: widget.scenarios
                .map(
                    (s) => DropdownMenuItem(value: s.id, child: Text(s.titolo)))
                .toList(),
            onChanged: (value) => setState(() => selectedId = value),
          )),
          IconButton(
              tooltip: 'Nuovo scenario',
              onPressed: busy
                  ? null
                  : () async {
                      final title =
                          await textDialog(context, 'Nuovo scenario', 'Titolo');
                      if (title != null) {
                        await mutate(
                            widget.api.addScenario(widget.listId, title));
                      }
                    },
              icon: const Icon(Icons.add_circle_outline)),
          if (current != null)
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'rename') {
                  final title = await textDialog(
                      context, 'Rinomina scenario', 'Titolo',
                      initial: current.titolo);
                  if (title != null) {
                    await mutate(widget.api
                        .renameScenario(widget.listId, current.id, title));
                  }
                } else if (await confirmDialog(
                    context, 'Eliminare lo scenario?', current.titolo)) {
                  selectedId = null;
                  await mutate(
                      widget.api.deleteScenario(widget.listId, current.id));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rinomina')),
                PopupMenuItem(value: 'delete', child: Text('Elimina'))
              ],
            ),
        ]),
      ),
      Expanded(
          child: current == null
              ? const EmptyState(
                  title: 'Crea uno scenario per iniziare',
                  icon: Icons.landscape_outlined)
              : RefreshIndicator(
                  onRefresh: widget.reload,
                  child: current.elementi.isEmpty
                      ? ListView(children: const [
                          SizedBox(
                              height: 420,
                              child: EmptyState(
                                  title: 'Nessun elemento associato',
                                  icon: Icons.link_off))
                        ])
                      : ListView(
                          children: current.elementi
                              .map((item) => SurfaceCard(
                                      child: ListTile(
                                    leading: Checkbox(
                                        value: item.completato,
                                        onChanged: busy
                                            ? null
                                            : (value) => mutate(widget.api
                                                    .patchElemento(
                                                        widget.listId,
                                                        item.id, {
                                                  'completato': value == true
                                                }))),
                                    title: Text(item.nome,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text(item.chiPorta),
                                    trailing: IconButton(
                                        onPressed: busy
                                            ? null
                                            : () => mutate(widget.api.detach(
                                                widget.listId,
                                                current.id,
                                                item.id)),
                                        icon: const Icon(Icons.link_off)),
                                  )))
                              .toList()),
                )),
      if (current != null)
        SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        onPressed: busy ? null : () => _attach(current),
                        icon: const Icon(Icons.link),
                        label: const Text('Associa'))),
                const SizedBox(width: 8),
                Expanded(
                    child: FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () async {
                                final item = await itemDialog(
                                    context, widget.labels.options);
                                if (item != null) {
                                  await mutate(widget.api.createAndAttach(
                                      widget.listId,
                                      current.id,
                                      item.$1,
                                      item.$2));
                                }
                              },
                        icon: const Icon(Icons.add),
                        label: const Text('Crea e associa'))),
              ]),
            )),
    ]);
  }

  Future<void> _attach(Scenario scenario) async {
    final existing = scenario.elementi.map((e) => e.id).toSet();
    final available =
        widget.items.where((e) => !existing.contains(e.id)).toList();
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
          child: available.isEmpty
              ? const EmptyState(
                  title: 'Tutti gli elementi sono già associati',
                  icon: Icons.done_all)
              : ListView(
                  children: available
                      .map((item) => ListTile(
                          title: Text(item.nome),
                          subtitle: Text(item.chiPorta),
                          onTap: () => Navigator.pop(context, item.id)))
                      .toList())),
    );
    if (id != null) {
      await mutate(widget.api.attach(widget.listId, scenario.id, id));
    }
  }
}

class PrivateLocalItem {
  final String id;
  final String name;
  final bool done;
  const PrivateLocalItem(
      {required this.id, required this.name, required this.done});
  factory PrivateLocalItem.fromJson(Map<String, dynamic> json) =>
      PrivateLocalItem(
          id: json['id'] as String,
          name: json['nome'] as String,
          done: json['completato'] == true);
  Map<String, dynamic> toJson() => {'id': id, 'nome': name, 'completato': done};
  PrivateLocalItem copyWith({bool? done}) =>
      PrivateLocalItem(id: id, name: name, done: done ?? this.done);
}

class PrivateListPage extends StatefulWidget {
  final String account;
  final List<Elemento> items;
  final EtichetteReport labels;
  const PrivateListPage(
      {super.key,
      required this.account,
      required this.items,
      required this.labels});

  @override
  State<PrivateListPage> createState() => _PrivateListPageState();
}

class _PrivateListPageState extends State<PrivateListPage> {
  final controller = TextEditingController();
  String? assigneeId;
  List<PrivateLocalItem> local = [];
  Map<String, bool> completed = {};
  bool loading = true;

  String get prefix => 'private:${widget.account}';

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final values = await Future.wait([
        Api.storage.read(key: '$prefix:assignee'),
        Api.storage.read(key: '$prefix:items'),
        Api.storage.read(key: '$prefix:completed'),
      ]);
      if (!mounted) return;
      setState(() {
        assigneeId = values[0];
        local = values[1] == null
            ? []
            : (jsonDecode(values[1]!) as List)
                .map((e) => PrivateLocalItem.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList();
        completed = values[2] == null
            ? {}
            : (jsonDecode(values[2]!) as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, v == true));
        loading = false;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> saveLocal() => Api.storage.write(
      key: '$prefix:items',
      value: jsonEncode(local.map((e) => e.toJson()).toList()));
  Future<void> saveCompleted() =>
      Api.storage.write(key: '$prefix:completed', value: jsonEncode(completed));

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final validIds = widget.labels.labels.map((e) => e.userId).toSet();
    if (assigneeId != null && !validIds.contains(assigneeId)) assigneeId = null;
    final imported = widget.items
        .where((item) => item.assigneeUserId == assigneeId)
        .toList();
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            value: assigneeId ?? '',
            decoration: const InputDecoration(labelText: 'Chi lo porta'),
            items: widget.labels.options
                .map((option) => DropdownMenuItem(
                    value: option.userId ?? '', child: Text(option.label)))
                .toList(),
            onChanged: (value) {
              final normalized = value == '' ? null : value;
              setState(() => assigneeId = normalized);
              Api.storage.write(key: '$prefix:assignee', value: normalized);
            },
          )),
      Expanded(
          child: imported.isEmpty && local.isEmpty
              ? const EmptyState(
                  title: 'Nessun elemento privato', icon: Icons.lock_outline)
              : ListView(children: [
                  ...imported.map((item) {
                    final key = 'global:${item.id}';
                    final done = completed[key] ?? false;
                    return SurfaceCard(
                        child: CheckboxListTile(
                            value: done,
                            title: Text(item.nome),
                            subtitle:
                                Text('Da lista condivisa: ${item.chiPorta}'),
                            onChanged: (value) {
                              setState(() => completed[key] = value == true);
                              saveCompleted();
                            }));
                  }),
                  ...local.map((item) => SurfaceCard(
                          child: CheckboxListTile(
                        value: item.done,
                        title: Text(item.name),
                        subtitle: const Text('Solo su questo dispositivo'),
                        secondary: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              setState(() =>
                                  local.removeWhere((e) => e.id == item.id));
                              saveLocal();
                            }),
                        onChanged: (value) {
                          setState(() => local = local
                              .map((e) => e.id == item.id
                                  ? e.copyWith(done: value == true)
                                  : e)
                              .toList());
                          saveLocal();
                        },
                      ))),
                ])),
      SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                            labelText: 'Nuovo item privato'),
                        onSubmitted: (_) => addLocal())),
                IconButton.filled(
                    onPressed: addLocal, icon: const Icon(Icons.add)),
              ]))),
    ]);
  }

  void addLocal() {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    setState(() => local.add(PrivateLocalItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: value,
        done: false)));
    controller.clear();
    saveLocal();
  }
}
