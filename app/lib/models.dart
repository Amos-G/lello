String idString(Object? value) => value?.toString() ?? '';

int intValue(Object? value) => int.parse(value.toString());

class AppUser {
  final String id;
  final String username;
  final String ruolo;
  final bool totpEnabled;
  final bool canInviteUsers;

  const AppUser({
    required this.id,
    required this.username,
    required this.ruolo,
    required this.totpEnabled,
    this.canInviteUsers = false,
  });

  bool get canManageLists => ruolo == 'guida' || ruolo == 'superadmin';
  bool get isAmosAdmin => username == 'amos' && ruolo == 'superadmin';
  bool get canInviteNewUsers =>
      isAmosAdmin || (ruolo == 'guida' && canInviteUsers);

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: idString(json['id']),
        username: json['username'] as String,
        ruolo: json['ruolo'] as String,
        totpEnabled: json['totp_enabled'] == true,
        canInviteUsers:
            json['can_invite_users'] == true || json['puo_invitare'] == true,
      );
}

class PartyList {
  final String id;
  final String nome;
  final String creatorId;
  final String creatorUsername;
  final int participantCount;

  const PartyList({
    required this.id,
    required this.nome,
    required this.creatorId,
    required this.creatorUsername,
    required this.participantCount,
  });

  factory PartyList.fromJson(Map<String, dynamic> json) => PartyList(
        id: idString(json['id']),
        nome: json['nome'] as String,
        creatorId: idString(json['creatore_id']),
        creatorUsername: (json['creatore_username'] ?? '') as String,
        participantCount: intValue(json['partecipanti_count'] ?? 0),
      );
}

String? resolveSelectedListId(List<PartyList> lists, String? storedId) {
  if (lists.isEmpty) return null;
  if (storedId != null && lists.any((list) => list.id == storedId)) {
    return storedId;
  }
  return lists.first.id;
}

class Participant {
  final String id;
  final String username;
  final String ruolo;

  const Participant({
    required this.id,
    required this.username,
    required this.ruolo,
  });

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        id: idString(json['id'] ?? json['user_id']),
        username: json['username'] as String,
        ruolo: (json['ruolo'] ?? '') as String,
      );
}

class AssigneeOption {
  final String? userId;
  final String label;
  const AssigneeOption({required this.userId, required this.label});
}

class EtichetteReport {
  final String defaultLabel;
  final List<AssigneeOption> labels;

  const EtichetteReport({required this.defaultLabel, required this.labels});

  factory EtichetteReport.fromJson(Map<String, dynamic> json) =>
      EtichetteReport(
        defaultLabel: json['default_label'] as String? ?? 'Da Assegnare',
        labels: ((json['labels'] as List?) ?? const []).map((raw) {
          final label = Map<String, dynamic>.from(raw as Map);
          return AssigneeOption(
            userId: idString(label['user_id']),
            label: label['label'] as String,
          );
        }).toList(),
      );

  List<AssigneeOption> get options => [
        AssigneeOption(userId: null, label: defaultLabel),
        ...labels,
      ];
}

class Elemento {
  final String id;
  final String nome;
  final String? assigneeUserId;
  final String chiPorta;
  final bool completato;

  const Elemento({
    required this.id,
    required this.nome,
    required this.assigneeUserId,
    required this.chiPorta,
    required this.completato,
  });

  factory Elemento.fromJson(Map<String, dynamic> json) => Elemento(
        id: idString(json['id']),
        nome: json['nome'] as String,
        assigneeUserId: json['chi_porta_utente_id'] == null
            ? null
            : idString(json['chi_porta_utente_id']),
        chiPorta: (json['chi_porta_username'] ??
            json['chi_porta'] ??
            'Da Assegnare') as String,
        completato: json['completato'] == true,
      );
}

class Scenario {
  final String id;
  final String titolo;
  final List<Elemento> elementi;

  const Scenario({
    required this.id,
    required this.titolo,
    required this.elementi,
  });

  factory Scenario.fromJson(Map<String, dynamic> json) => Scenario(
        id: idString(json['id']),
        titolo: json['titolo'] as String,
        elementi: ((json['elementi'] as List?) ?? const [])
            .map((e) => Elemento.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class Spesa {
  final String id;
  final String userId;
  final String username;
  final String descrizione;
  final int importoCents;
  final List<String> participantIds;
  final DateTime createdAt;

  const Spesa({
    required this.id,
    required this.userId,
    required this.username,
    required this.descrizione,
    required this.importoCents,
    required this.participantIds,
    required this.createdAt,
  });

  factory Spesa.fromJson(Map<String, dynamic> json) => Spesa(
        id: idString(json['id']),
        userId: idString(json['utente_id']),
        username: json['username'] as String,
        descrizione: json['descrizione'] as String,
        importoCents: intValue(json['importo_cents']),
        participantIds: ((json['participant_ids'] as List?) ?? const [])
            .map(idString)
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class ExpenseParticipant {
  final String userId;
  final String username;
  final int paidCents;
  final int shareCents;
  final int balanceCents;

  const ExpenseParticipant({
    required this.userId,
    required this.username,
    required this.paidCents,
    required this.shareCents,
    required this.balanceCents,
  });

  factory ExpenseParticipant.fromJson(Map<String, dynamic> json) =>
      ExpenseParticipant(
        userId: idString(json['user_id']),
        username: json['username'] as String,
        paidCents: intValue(json['paid_cents']),
        shareCents: intValue(json['share_cents']),
        balanceCents: intValue(json['balance_cents']),
      );
}

class Obligation {
  final String fromUserId;
  final String fromUsername;
  final String toUserId;
  final String toUsername;
  final int amountCents;

  const Obligation({
    required this.fromUserId,
    required this.fromUsername,
    required this.toUserId,
    required this.toUsername,
    required this.amountCents,
  });

  factory Obligation.fromJson(Map<String, dynamic> json) => Obligation(
        fromUserId: idString(json['from_user_id']),
        fromUsername: json['from_username'] as String,
        toUserId: idString(json['to_user_id']),
        toUsername: json['to_username'] as String,
        amountCents: intValue(json['amount_cents']),
      );
}

class Payment {
  final String id;
  final String fromUserId;
  final String fromUsername;
  final String toUserId;
  final String toUsername;
  final int amountCents;
  final String? note;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.fromUserId,
    required this.fromUsername,
    required this.toUserId,
    required this.toUsername,
    required this.amountCents,
    required this.note,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: idString(json['id']),
        fromUserId: idString(json['da_utente_id']),
        fromUsername: (json['da_username'] ?? '') as String,
        toUserId: idString(json['a_utente_id']),
        toUsername: (json['a_username'] ?? '') as String,
        amountCents: intValue(json['importo_cents']),
        note: json['nota'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class SpeseReport {
  final List<Spesa> spese;
  final List<Payment> payments;
  final List<ExpenseParticipant> participants;
  final List<Obligation> obligations;
  final int totalCents;

  const SpeseReport({
    required this.spese,
    required this.payments,
    required this.participants,
    required this.obligations,
    required this.totalCents,
  });

  factory SpeseReport.fromJson(Map<String, dynamic> json) => SpeseReport(
        spese: ((json['spese'] as List?) ?? const [])
            .map((e) => Spesa.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        payments: ((json['pagamenti'] as List?) ?? const [])
            .map((e) => Payment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        participants: ((json['participants'] as List?) ?? const [])
            .map(
              (e) => ExpenseParticipant.fromJson(
                  Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        obligations: ((json['obligations'] as List?) ??
                (json['settlements'] as List?) ??
                const [])
            .map(
              (e) => Obligation.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        totalCents: intValue(json['total_cents'] ?? 0),
      );
}

class AdminUser {
  final String id;
  final String username;
  final String ruolo;
  final bool totpEnabled;
  final bool canInviteUsers;

  const AdminUser({
    required this.id,
    required this.username,
    required this.ruolo,
    required this.totpEnabled,
    this.canInviteUsers = false,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: idString(json['id']),
        username: json['username'] as String,
        ruolo: json['ruolo'] as String,
        totpEnabled: json['totp_enabled'] == true,
        canInviteUsers:
            json['can_invite_users'] == true || json['puo_invitare'] == true,
      );
}

Set<String> toggleParticipantSelection(
  Set<String> selected,
  String participantId,
  bool enabled,
) {
  final next = {...selected};
  enabled ? next.add(participantId) : next.remove(participantId);
  return next;
}
