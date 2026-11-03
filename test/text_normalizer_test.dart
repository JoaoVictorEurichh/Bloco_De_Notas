import 'package:bloco_de_nota_turma_a/utils/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('remove acentos e converte para minúsculas', () {
    expect(normalizeForSearch('Reunião de Ação às 10h'),
        'reuniao de acao as 10h');
    expect(normalizeForSearch('ÇÃO'), 'cao');
  });

  test('mantém o mesmo tamanho para permitir o destaque do termo', () {
    const text = 'Lógica de Programação';
    expect(normalizeForSearch(text).length, text.length);
  });
}
