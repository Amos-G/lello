class Elemento {
  final int id;
  final String nome;
  final String chiPorta;
  final bool completato;

  const Elemento({
    required this.id,
    required this.nome,
    required this.chiPorta,
    required this.completato,
  });

  factory Elemento.fromJson(Map<String, dynamic> json) => Elemento(
        id: int.parse(json['id'].toString()),
        nome: json['nome'] as String,
        chiPorta: json['chi_porta'] as String,
        completato: json['completato'] as bool,
      );
}

class EtichetteReport {
  final String defaultLabel;
  final List<String> labels;

  const EtichetteReport({
    required this.defaultLabel,
    required this.labels,
  });

  factory EtichetteReport.fromJson(Map<String, dynamic> json) {
    final defaultLabel = json['default_label'] as String;
    final labels = ((json['labels'] as List?) ?? const [])
        .map((label) => label.toString())
        .toSet()
        .toList();
    if (!labels.contains(defaultLabel)) labels.insert(0, defaultLabel);
    return EtichetteReport(defaultLabel: defaultLabel, labels: labels);
  }
}

class Scenario {
  final int id;
  final String titolo;
  final List<Elemento> elementi;

  const Scenario({
    required this.id,
    required this.titolo,
    required this.elementi,
  });

  factory Scenario.fromJson(Map<String, dynamic> json) => Scenario(
        id: int.parse(json['id'].toString()),
        titolo: json['titolo'] as String,
        elementi: ((json['elementi'] as List?) ?? [])
            .map((e) => Elemento.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Spesa {
  final int id;
  final int utenteId;
  final String username;
  final String descrizione;
  final int importoCents;
  final DateTime createdAt;

  const Spesa({
    required this.id,
    required this.utenteId,
    required this.username,
    required this.descrizione,
    required this.importoCents,
    required this.createdAt,
  });

  factory Spesa.fromJson(Map<String, dynamic> json) => Spesa(
        id: int.parse(json['id'].toString()),
        utenteId: int.parse(json['utente_id'].toString()),
        username: json['username'] as String,
        descrizione: json['descrizione'] as String,
        importoCents: int.parse(json['importo_cents'].toString()),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class PartecipanteSpese {
  final int userId;
  final String username;
  final int paidCents;
  final int shareCents;
  final int balanceCents;

  const PartecipanteSpese({
    required this.userId,
    required this.username,
    required this.paidCents,
    required this.shareCents,
    required this.balanceCents,
  });

  factory PartecipanteSpese.fromJson(Map<String, dynamic> json) =>
      PartecipanteSpese(
        userId: int.parse(json['user_id'].toString()),
        username: json['username'] as String,
        paidCents: int.parse(json['paid_cents'].toString()),
        shareCents: int.parse(json['share_cents'].toString()),
        balanceCents: int.parse(json['balance_cents'].toString()),
      );
}

class PagamentoSpese {
  final int fromUserId;
  final String fromUsername;
  final int toUserId;
  final String toUsername;
  final int amountCents;

  const PagamentoSpese({
    required this.fromUserId,
    required this.fromUsername,
    required this.toUserId,
    required this.toUsername,
    required this.amountCents,
  });

  factory PagamentoSpese.fromJson(Map<String, dynamic> json) => PagamentoSpese(
        fromUserId: int.parse(json['from_user_id'].toString()),
        fromUsername: json['from_username'] as String,
        toUserId: int.parse(json['to_user_id'].toString()),
        toUsername: json['to_username'] as String,
        amountCents: int.parse(json['amount_cents'].toString()),
      );
}

class SpeseReport {
  final List<Spesa> spese;
  final List<PartecipanteSpese> participants;
  final List<PagamentoSpese> settlements;
  final int totalCents;

  const SpeseReport({
    required this.spese,
    required this.participants,
    required this.settlements,
    required this.totalCents,
  });

  factory SpeseReport.fromJson(Map<String, dynamic> json) => SpeseReport(
        spese: ((json['spese'] as List?) ?? [])
            .map((e) => Spesa.fromJson(e as Map<String, dynamic>))
            .toList(),
        participants: ((json['participants'] as List?) ?? [])
            .map(
              (e) => PartecipanteSpese.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        settlements: ((json['settlements'] as List?) ?? [])
            .map((e) => PagamentoSpese.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalCents: int.parse(json['total_cents'].toString()),
      );
}
