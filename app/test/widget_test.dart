import 'package:flutter_test/flutter_test.dart';
import 'package:partysync/models.dart';

void main() {
  test('deserializza gli ID PostgreSQL BIGINT', () {
    final item = Elemento.fromJson({
      'id': '42',
      'nome': 'Ghiaccio',
      'chi_porta': 'Anna',
      'completato': false,
    });
    expect(item.id, 42);
    expect(item.nome, 'Ghiaccio');
  });
}
