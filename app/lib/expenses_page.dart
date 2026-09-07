import 'package:flutter/material.dart';

import 'api.dart';
import 'app_theme.dart';
import 'models.dart';

class ParticipantSelector extends StatelessWidget {
  final List<ExpenseParticipant> participants;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  const ParticipantSelector({
    super.key,
    required this.participants,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        key: const Key('participant-selector'),
        children: participants
            .map(
              (person) => CheckboxListTile(
                dense: true,
                value: selected.contains(person.userId),
                title: Text(person.username),
                onChanged: (enabled) => onChanged(
                  toggleParticipantSelection(
                    selected,
                    person.userId,
                    enabled == true,
                  ),
                ),
              ),
            )
            .toList(),
      );
}

class ObligationCard extends StatelessWidget {
  final Obligation obligation;
  final String currentUserId;
  final VoidCallback onPay;
  const ObligationCard({
    super.key,
    required this.obligation,
    required this.currentUserId,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) => SurfaceCard(
        child: ListTile(
          leading: const Icon(Icons.swap_horiz, color: lagoon),
          title: Text(
            '${obligation.fromUsername} deve ${euro(obligation.amountCents)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('a ${obligation.toUsername}'),
          trailing: obligation.fromUserId == currentUserId
              ? FilledButton(
                  key: const Key('pay-obligation'),
                  onPressed: onPay,
                  child: const Text('Salda'),
                )
              : null,
        ),
      );
}

class ExpensesPage extends StatefulWidget {
  final Api api;
  final String listId;
  final String currentUserId;
  final SpeseReport report;
  final Future<void> Function() reload;
  const ExpensesPage({
    super.key,
    required this.api,
    required this.listId,
    required this.currentUserId,
    required this.report,
    required this.reload,
  });

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
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

  String participantNames(Spesa expense) {
    if (expense.participantIds.length == widget.report.participants.length &&
        widget.report.participants.isNotEmpty) {
      return 'Tutti (${widget.report.participants.length})';
    }
    final names = widget.report.participants
        .where((person) => expense.participantIds.contains(person.userId))
        .map((person) => person.username)
        .toList();
    return names.isEmpty ? 'Nessun partecipante' : names.join(', ');
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.reload,
              child: ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Totale spese: ${euro(widget.report.totalCents)}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                  SizedBox(
                    height: 120,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      children: widget.report.participants
                          .map(
                            (person) => Container(
                              width: 145,
                              margin: const EdgeInsets.all(4),
                              padding: const EdgeInsets.all(12),
                              decoration: surfaceDecoration(radius: 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    person.userId == widget.currentUserId
                                        ? '${person.username} (Tu)'
                                        : person.username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    person.balanceCents < 0
                                        ? 'deve dare'
                                        : person.balanceCents > 0
                                            ? 'deve ricevere'
                                            : 'in pari',
                                    style: const TextStyle(color: muted),
                                  ),
                                  Text(
                                    euro(person.balanceCents.abs()),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: person.balanceCents < 0
                                          ? danger
                                          : person.balanceCents > 0
                                              ? sage
                                              : ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  if (widget.report.obligations.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
                      child: Text(
                        'Saldi e debiti rimanenti',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...widget.report.obligations.map(
                      (obligation) => ObligationCard(
                        obligation: obligation,
                        currentUserId: widget.currentUserId,
                        onPay: () => paymentDialog(obligation: obligation),
                      ),
                    ),
                  ],
                  if (widget.report.payments.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
                      child: Text(
                        'Saldi e rimborsi registrati',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...widget.report.payments.map(
                      (payment) => SurfaceCard(
                        child: ListTile(
                          leading: const Icon(
                            Icons.check_circle_outline,
                            color: sage,
                          ),
                          title: Text(
                            '${payment.fromUsername} → ${payment.toUsername}',
                          ),
                          subtitle: Text(
                            [
                              if (payment.note != null &&
                                  payment.note!.isNotEmpty)
                                payment.note!,
                              if (payment.fromUserId == widget.currentUserId)
                                'Registrato da te',
                            ].join(' · '),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                euro(payment.amountCents),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: sage,
                                ),
                              ),
                              if (payment.fromUserId == widget.currentUserId)
                                IconButton(
                                  tooltip: 'Elimina saldo',
                                  color: danger,
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          if (await confirmDialog(
                                            context,
                                            'Eliminare questo saldo?',
                                            'Il debito verrà ripristinato nei conteggi.',
                                          )) {
                                            await mutate(
                                              widget.api.deletePayment(
                                                widget.listId,
                                                payment.id,
                                              ),
                                            );
                                          }
                                        },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
                    child: Text(
                      'Spese della lista',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (widget.report.spese.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: EmptyState(
                        title: 'Nessuna spesa',
                        subtitle: 'Inserisci la prima spesa per la lista attiva.',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    )
                  else
                    ...widget.report.spese.map(
                      (expense) => SurfaceCard(
                        child: ListTile(
                          leading: const Icon(
                            Icons.payments_outlined,
                            color: lagoon,
                          ),
                          title: Text(
                            expense.descrizione,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${expense.userId == widget.currentUserId ? "Creata da te" : "Pagata da ${expense.username}"} · ${participantNames(expense)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                euro(expense.importoCents),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (expense.userId == widget.currentUserId)
                                IconButton(
                                  tooltip: 'Elimina spesa',
                                  color: danger,
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          if (await confirmDialog(
                                            context,
                                            'Eliminare la spesa?',
                                            expense.descrizione,
                                          )) {
                                            await mutate(
                                              widget.api.deleteSpesa(
                                                widget.listId,
                                                expense.id,
                                              ),
                                            );
                                          }
                                        },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                            ],
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
                  child: OutlinedButton.icon(
                    key: const Key('add-settlement'),
                    onPressed: busy
                        ? null
                        : () => paymentDialog(),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Registra saldo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('add-expense'),
                    onPressed: busy ? null : expenseDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Aggiungi spesa'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Future<void> expenseDialog() async {
    final description = TextEditingController();
    final amount = TextEditingController();
    bool allParticipants = true;
    var selected =
        widget.report.participants.map((person) => person.userId).toSet();

    final data = await showDialog<(String, int, List<String>)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cents = parseEuroCents(amount.text);
          final quotaPreview = (cents != null && cents > 0 && selected.isNotEmpty)
              ? euro((cents / selected.length).round())
              : null;

          return AlertDialog(
            title: const Text('Nuova spesa'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: description,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Descrizione spesa'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Importo totale',
                      suffixText: '€',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: sand0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SwitchListTile(
                      dense: true,
                      title: const Text(
                        'Riguarda tutti i partecipanti',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        allParticipants
                            ? 'Inclusi tutti i ${widget.report.participants.length} partecipanti'
                            : 'Personalizzato: ${selected.length} di ${widget.report.participants.length} inclusi',
                      ),
                      value: allParticipants,
                      onChanged: (value) {
                        setDialogState(() {
                          allParticipants = value;
                          if (allParticipants) {
                            selected = widget.report.participants
                                .map((person) => person.userId)
                                .toSet();
                          }
                        });
                      },
                    ),
                  ),
                  if (!allParticipants) ...[
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Seleziona i partecipanti inclusi:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ParticipantSelector(
                      participants: widget.report.participants,
                      selected: selected,
                      onChanged: (value) =>
                          setDialogState(() => selected = value),
                    ),
                  ],
                  if (quotaPreview != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: sageSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pie_chart_outline, color: sage, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Quota: $quotaPreview a testa (${selected.length} ${selected.length == 1 ? "persona" : "persone"})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: ink,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annulla'),
              ),
              FilledButton(
                key: const Key('submit-expense'),
                onPressed: () {
                  final cents = parseEuroCents(amount.text);
                  if (description.text.trim().isEmpty ||
                      cents == null ||
                      cents <= 0) {
                    showError(context, 'Inserisci descrizione e importo validi');
                    return;
                  }
                  if (selected.isEmpty) {
                    showError(
                      context,
                      'Seleziona almeno un partecipante da includere',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, (
                    description.text.trim(),
                    cents,
                    selected.toList(),
                  ));
                },
                child: const Text('Aggiungi'),
              ),
            ],
          );
        },
      ),
    );
    description.dispose();
    amount.dispose();
    if (data != null) {
      await mutate(
        widget.api.addSpesa(widget.listId, data.$1, data.$2, data.$3),
      );
    }
  }

  Future<void> paymentDialog({Obligation? obligation}) async {
    final participantMap = <String, String>{
      for (final p in widget.report.participants)
        if (p.userId != widget.currentUserId) p.userId: p.username,
    };
    if (obligation != null) {
      participantMap[obligation.toUserId] = obligation.toUsername;
    }
    for (final obl in widget.report.obligations) {
      if (obl.fromUserId == widget.currentUserId) {
        participantMap[obl.toUserId] = obl.toUsername;
      }
    }

    if (participantMap.isEmpty) {
      showError(
        context,
        'Non ci sono altri partecipanti a cui inviare un saldo',
      );
      return;
    }

    String selectedRecipientId = obligation?.toUserId ??
        (widget.report.obligations
                .where((o) => o.fromUserId == widget.currentUserId)
                .map((o) => o.toUserId)
                .firstOrNull ??
            participantMap.keys.first);

    final initialAmount = obligation != null
        ? euro(obligation.amountCents).replaceAll(' €', '')
        : '';
    final amount = TextEditingController(text: initialAmount);
    final note = TextEditingController();

    final result = await showDialog<(String, int, String?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final matchedObligation = widget.report.obligations
              .where((o) =>
                  o.fromUserId == widget.currentUserId &&
                  o.toUserId == selectedRecipientId)
              .firstOrNull;

          return AlertDialog(
            title: const Text('Registra saldo o rimborso'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedRecipientId,
                    decoration: const InputDecoration(labelText: 'Destinatario'),
                    items: participantMap.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedRecipientId = val;
                          final newMatch = widget.report.obligations
                              .where((o) =>
                                  o.fromUserId == widget.currentUserId &&
                                  o.toUserId == val)
                              .firstOrNull;
                          if (newMatch != null && amount.text.isEmpty) {
                            amount.text = euro(newMatch.amountCents)
                                .replaceAll(' €', '');
                          }
                        });
                      }
                    },
                  ),
                  if (matchedObligation != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Debito attuale: ${euro(matchedObligation.amountCents)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('payment-amount'),
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: matchedObligation != null
                          ? 'Importo (puoi saldare anche in parte)'
                          : 'Importo versato',
                      suffixText: '€',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(
                      labelText: 'Nota o causale (opzionale)',
                      hintText: 'Es: Restituzione spesa, Bonifico, Contanti',
                    ),
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
                key: const Key('submit-payment'),
                onPressed: () {
                  final cents = parseEuroCents(amount.text);
                  if (cents == null || cents <= 0) {
                    showError(dialogContext, 'Inserisci un importo valido');
                    return;
                  }
                  Navigator.pop(dialogContext, (
                    selectedRecipientId,
                    cents,
                    note.text.trim().isEmpty ? null : note.text.trim(),
                  ));
                },
                child: const Text('Registra'),
              ),
            ],
          );
        },
      ),
    );
    amount.dispose();
    note.dispose();
    if (result != null) {
      await mutate(
        widget.api.addPayment(
          widget.listId,
          result.$1,
          result.$2,
          result.$3,
        ),
      );
    }
  }
}
