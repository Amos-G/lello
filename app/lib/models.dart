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
