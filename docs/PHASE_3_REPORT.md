# Fase 3 — Relatório incremental

Usuário autorizou prosseguir da F3 em diante fase por fase, com uma tarefa pequena e commit/envio individual por vez. Decisões aprovadas em 10/11/2026: preço zero gratuito, limite técnico int64 e quantidade não confirmada em item planejado com valor direto, inclusive misto. Detalhes em DECISIONS D-028/029/030.

## F3-01 — Moeda e overflow

**Concluída em 10/11/2026.** Benefício: converter preços de forma exata e recusar estouro numérico, sem transformar zero em ausência. Ainda não existe UI de preço nesta tarefa.

Arquivos: core/money/money.dart (funções puras), list_budget_input.dart (delegação do orçamento), test/unit/money_test.dart (17 casos), README e docs SPEC/DESIGN/DECISIONS/ARCHITECTURE/TESTING/TASKS/este relatório (decisões, progresso e evidências). Sem alteração de esquema/dependência.

Fluxo: texto `4,22` → separação decimal → int 422 → validação/operação verificada → formatação `R$ 4,22`. Vazio permanece null; `0,00` vira 0. Sem milhar, prefixo R$ ou sinais na entrada. Formatação aceita negativos para diferenças futuras, sem permitir preço negativo. Soma/produto usam BigInt no intermediário e só retornam int quando couber em int64. Não mudam banco nem total oficial.

Conceitos: int? é anulável como em C#; BigInt representa intermediários sem wrap de 64 bits, cumprindo papel semelhante a BigInteger. int nativo Dart tem overflow circular (documentação do SDK em lib/core/int.dart), logo conferir resultado depois de uma multiplicação em int seria tarde. Funções puras são determinísticas e testáveis sem widgets. Orçamento reutiliza as funções, evitando dois conversores que poderiam divergir.

TDD: RED saiu 1 por implementação inexistente. Análise passou. Primeira regressão teve 205 aprovados/1 falha por texto de erro do orçamento alterado ao compartilhar o parser; restaurado o texto original, sem mudar expectativa. Regressão seguinte: **206 aprovados**, saída 0. Os 17 novos incluem extremos, roundtrip e rejeição de overflow. Formatados 3 arquivos, 2 ajustados. Comandos completos e logs em TESTING seção 23.

Android/limites: nenhuma tela nova para testar manualmente; APK F2 continua sendo a versão normal instalada. Não foram repetidos build/integracão Android/iOS/release nesta tarefa pura. Para verificar: `flutter test test/unit/money_test.dart`. Exercício opcional numa branch de treino: acrescentar roundtrip de 1.234 centavos, esperando 12,34 e o mesmo inteiro. Próxima tarefa: F3-02, já autorizada.
