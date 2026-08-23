import 'package:flutter/material.dart';

import 'api.dart';
import 'app_theme.dart';
import 'models.dart';

class ParticipantSelector extends StatelessWidget {
  final List<ExpenseParticipant> participants;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  const ParticipantSelector(
      {super.key,
      required this.participants,
      required this.selected,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
        key: const Key('participant-selector'),
        children: participants
            .map((person) => CheckboxListTile(
                  dense: true,
                  value: selected.contains(person.userId),
                  title: Text(person.username),
                  onChanged: (enabled) => onChanged(toggleParticipantSelection(
                      selected, person.userId, enabled == true)),
                ))
            .toList(),
      );
}

class ObligationCard extends StatelessWidget {
  final Obligation obligation;
  final String currentUserId;
  final VoidCallback onPay;
  const ObligationCard(
      {super.key,
      required this.obligation,
      required this.currentUserId,
      required this.onPay});

  @override
  Widget build(BuildContext context) => SurfaceCard(
        child: ListTile(
          leading: const Icon(Icons.swap_horiz, color: lagoon),
          title: Text(
              '${obligation.fromUsername} deve ${euro(obligation.amountCents)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('a ${obligation.toUsername}'),
          trailing: obligation.fromUserId == currentUserId
              ? FilledButton(
                  key: const Key('pay-obligation'),
                  onPressed: onPay,
                  child: const Text('Paga'))
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
  const ExpensesPage(
      {super.key,
      required this.api,
      required this.listId,
      required this.currentUserId,
      required this.report,
      required this.reload});

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
    final names = widget.report.participants
        .where((person) => expense.participantIds.contains(person.userId))
        .map((person) => person.username)
        .toList();
    return names.isEmpty ? 'Nessun partecipante' : names.join(', ');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.reload,
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Totale: ${euro(widget.report.totalCents)}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                    height: 105,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      children: widget.report.participants
                          .map((person) => Container(
                                width: 145,
                                margin: const EdgeInsets.all(4),
                                padding: const EdgeInsets.all(12),
                                decoration: surfaceDecoration(radius: 18),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(person.username,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const Spacer(),
                                      Text(
                                          person.balanceCents < 0
                                              ? 'deve dare'
                                              : person.balanceCents > 0
                                                  ? 'deve ricevere'
                                                  : 'in pari',
                                          style: const TextStyle(color: muted)),
                                      Text(euro(person.balanceCents.abs()),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ]),
                              ))
                          .toList(),
                    )),
                if (widget.report.obligations.isNotEmpty) ...[
                  const Padding(
                      padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
                      child: Text('Obblighi di pagamento',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  ...widget.report.obligations
                      .map((obligation) => ObligationCard(
                            obligation: obligation,
                            currentUserId: widget.currentUserId,
                            onPay: () => paymentDialog(obligation),
                          )),
                ],
                if (widget.report.payments.isNotEmpty) ...[
                  const Padding(
                      padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
                      child: Text('Pagamenti registrati',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  ...widget.report.payments.map((payment) => SurfaceCard(
                          child: ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(
                            '${payment.fromUsername} → ${payment.toUsername}'),
                        subtitle:
                            payment.note == null ? null : Text(payment.note!),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(euro(payment.amountCents),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          if (payment.fromUserId == widget.currentUserId)
                            IconButton(
                              tooltip: 'Elimina pagamento',
                              color: danger,
                              onPressed: busy
                                  ? null
                                  : () => mutate(widget.api.deletePayment(
                                      widget.listId, payment.id)),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ]),
                      ))),
                ],
                const Padding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 4),
                    child: Text('Spese',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                if (widget.report.spese.isEmpty)
                  const SizedBox(
                      height: 230,
                      child: EmptyState(
                          title: 'Nessuna spesa',
                          icon: Icons.account_balance_wallet_outlined))
                else
                  ...widget.report.spese.map((expense) => SurfaceCard(
                          child: ListTile(
                        leading:
                            const Icon(Icons.payments_outlined, color: lagoon),
                        title: Text(expense.descrizione,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '${expense.username} · inclusi: ${participantNames(expense)}'),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(euro(expense.importoCents),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
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
                                          expense.descrizione)) {
                                        await mutate(widget.api.deleteSpesa(
                                            widget.listId, expense.id));
                                      }
                                    },
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ]),
                      ))),
              ],
            ),
          ),
        ),
        ComposerSurface(
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('add-expense'),
              onPressed: busy ? null : expenseDialog,
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi spesa'),
            ),
          ),
        ),
      ]);

  Future<void> expenseDialog() async {
    final description = TextEditingController();
    final amount = TextEditingController();
    var selected =
        widget.report.participants.map((person) => person.userId).toSet();
    final data = await showDialog<(String, int, List<String>)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                title: const Text('Nuova spesa'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: description,
                      decoration:
                          const InputDecoration(labelText: 'Descrizione')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Importo', suffixText: '€')),
                  const SizedBox(height: 12),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Dividi tra',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  ParticipantSelector(
                      participants: widget.report.participants,
                      selected: selected,
                      onChanged: (value) =>
                          setDialogState(() => selected = value)),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Annulla')),
                  FilledButton(
                      key: const Key('submit-expense'),
                      onPressed: () {
                        final cents = parseEuroCents(amount.text);
                        if (description.text.trim().isEmpty ||
                            cents == null ||
                            cents <= 0) {
                          showError(context,
                              'Inserisci descrizione e importo validi');
                          return;
                        }
                        if (selected.isEmpty) {
                          showError(
                              context, 'Seleziona almeno un partecipante');
                          return;
                        }
                        Navigator.pop(dialogContext, (
                          description.text.trim(),
                          cents,
                          selected.toList()
                        ));
                      },
                      child: const Text('Aggiungi')),
                ],
              )),
    );
    description.dispose();
    amount.dispose();
    if (data != null) {
      await mutate(
          widget.api.addSpesa(widget.listId, data.$1, data.$2, data.$3));
    }
  }

  Future<void> paymentDialog(Obligation obligation) async {
    final amount = TextEditingController(
        text: euro(obligation.amountCents).replaceAll(' €', ''));
    final note = TextEditingController();
    final result = await showDialog<(int, String?)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registra pagamento'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
              initialValue: obligation.toUsername,
              enabled: false,
              decoration: const InputDecoration(labelText: 'Destinatario')),
          const SizedBox(height: 12),
          TextField(
              key: const Key('payment-amount'),
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'Importo (max ${euro(obligation.amountCents)})',
                  suffixText: '€')),
          const SizedBox(height: 12),
          TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Nota (opzionale)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla')),
          FilledButton(
              key: const Key('submit-payment'),
              onPressed: () {
                final cents = parseEuroCents(amount.text);
                if (cents == null ||
                    cents <= 0 ||
                    cents > obligation.amountCents) {
                  showError(dialogContext,
                      'Importo non valido o superiore al debito residuo');
                  return;
                }
                Navigator.pop(dialogContext, (
                  cents,
                  note.text.trim().isEmpty ? null : note.text.trim()
                ));
              },
              child: const Text('Registra')),
        ],
      ),
    );
    amount.dispose();
    note.dispose();
    if (result != null) {
      await mutate(widget.api.addPayment(
          widget.listId, obligation.toUserId, result.$1, result.$2));
    }
  }
}
