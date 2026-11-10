# Fase 3 — Relatório incremental

Usuário autorizou prosseguir da F3 em diante fase por fase, com uma tarefa pequena e commit/envio individual por vez. Decisões aprovadas em 10/11/2026: preço zero gratuito, limite técnico int64 e quantidade não confirmada em item planejado com valor direto, inclusive misto. Detalhes em DECISIONS D-028/029/030.

## F3-01 — Moeda e overflow

**Concluída em 10/11/2026.** Benefício: converter preços de forma exata e recusar estouro numérico, sem transformar zero em ausência. Ainda não existe UI de preço nesta tarefa.

Arquivos: core/money/money.dart (funções puras), list_budget_input.dart (delegação do orçamento), test/unit/money_test.dart (17 casos), README e docs SPEC/DESIGN/DECISIONS/ARCHITECTURE/TESTING/TASKS/este relatório (decisões, progresso e evidências). Sem alteração de esquema/dependência.

Fluxo: texto `4,22` → separação decimal → int 422 → validação/operação verificada → formatação `R$ 4,22`. Vazio permanece null; `0,00` vira 0. Sem milhar, prefixo R$ ou sinais na entrada. Formatação aceita negativos para diferenças futuras, sem permitir preço negativo. Soma/produto usam BigInt no intermediário e só retornam int quando couber em int64. Não mudam banco nem total oficial.

Conceitos: int? é anulável como em C#; BigInt representa intermediários sem wrap de 64 bits, cumprindo papel semelhante a BigInteger. int nativo Dart tem overflow circular (documentação do SDK em lib/core/int.dart), logo conferir resultado depois de uma multiplicação em int seria tarde. Funções puras são determinísticas e testáveis sem widgets. Orçamento reutiliza as funções, evitando dois conversores que poderiam divergir.

TDD: RED saiu 1 por implementação inexistente. Análise passou. Primeira regressão teve 205 aprovados/1 falha por texto de erro do orçamento alterado ao compartilhar o parser; restaurado o texto original, sem mudar expectativa. Regressão seguinte: **206 aprovados**, saída 0. Os 17 novos incluem extremos, roundtrip e rejeição de overflow. Formatados 3 arquivos, 2 ajustados. Comandos completos e logs em TESTING seção 23.

Android/limites: nenhuma tela nova para testar manualmente; APK F2 continua sendo a versão normal instalada. Não foram repetidos build/integracão Android/iOS/release nesta tarefa pura. Para verificar: `flutter test test/unit/money_test.dart`. Exercício opcional numa branch de treino: acrescentar roundtrip de 1.234 centavos, esperando 12,34 e o mesmo inteiro. Próxima tarefa: F3-02, já autorizada.

## F3-02 — Modelo de entrada

**Concluída em 10/11/2026.** PurchaseEntry representa exatamente uma compra por quantidade × preço unitário ou valor total sem quantidade. Preserva zero gratuito e não inventa unidades. Subtotal é derivado/verificado na construção, não um valor arbitrário recebido do chamador.

Arquivos novos: domain/models/purchase_entry.dart e test/unit/purchase_entry_test.dart; README/TASKS/TESTING/ARCHITECTURE/DECISIONS/relatório atualizados. Campos final e tipos imutáveis preservam identidade/vínculo/dados; construtor verifica exclusividade em execução, sem assert. Sem métodos de banco ou widget. Fluxo: dados em centavos → construtor valida modo → cálculo puro verificado → instância ou erro.

Conceitos: parâmetros nomeados opcionais representam os campos, mas não dispensam invariantes. Getter isDirect é derivado, sem flag redundante; subtotalCents é calculado uma vez antes de permitir usar o objeto. RangeError para overflow também é ArgumentError, útil para distinguir dado inválido. Não se armazena subtotal duplicado no banco futuro: a instância calcula a partir dos campos.

RED saiu 1 por arquivo/tipo inexistente. GREEN/regressão: **224 aprovados**, incluindo **18 novos**; análise sem problemas. Formatados 2 arquivos. Sem migração/UI/build/integracão Android nesta tarefa. Para validar: `flutter test test/unit/purchase_entry_test.dart`. Exercício opcional numa branch de treino: conferir 2 unidades a 350 centavos com subtotal 700. Próxima tarefa: calculadora F3-03, autorizada. Nenhuma regra aprovada foi alterada.

## F3-03 — Calculadora e estados

**Concluída em 10/11/2026.** shopping_calculator.dart calcula uma fotografia imutável da lista e de cada produto: entradas, subtotal, quantidade conhecida, quantidade total opcional, faltante opcional e estado derivado. Não há flags persistidas redundantes nem dependência Flutter. Item removido conserva dados/subtotal e é excluído do total oficial calculado.

Arquivos: novo domain/shopping_calculator.dart e teste unitário com 22 casos; README/TASKS/TESTING/ARCHITECTURE/DECISIONS/relatório atualizados. IDs duplicados, entradas órfãs/fora da lista e somas não representáveis são recusados; dados não são corrigidos silenciosamente. Ordem é a posição persistida, sem mutar inputs. Fotografia guarda cópias imutáveis de coleções.

Fluxo: itens/entradas válidos → agrupar por identidade → subtotal/quantidade verificados → estado por regras aprovadas → somar somente não removidos. Pendente significa nenhuma entrada, não subtotal zero. Produto gratuito pode estar comprado. Planejado com direto (inclusive misto suficiente) fica Quantidade não confirmada por D-030; quantidade total/faltante ficam null, enquanto unidades conhecidas permanecem preservadas. Sem direto, 3/5 é parcial/faltam 2 e 6/5 é comprado/faltam 0, sem bloqueio.

Conceitos: Map agrupa como Dictionary em C#; Set detecta identidade duplicada; enum explicita estados; List.unmodifiable protege a fotografia; funções puras recebem dados e devolvem resultado determinístico. BigInt protege também soma de unidades gratuitas contra overflow, sem converter unidade desconhecida em uma unidade.

TDD RED: calculadora inexistente. Um aviso de estilo foi corrigido antes da análise final, que passou. Regressão: **246 aprovados**, incluindo **22 novos**, sem alterar expectativas. Dois arquivos formatados. Sem migração/UI/Android/build nesta tarefa. Para verificar: `flutter test test/unit/shopping_calculator_test.dart`. Exercício opcional em branch de treino: conferir parcial 2/5 e faltante 3. Próxima F3-04: persistir entradas e aplicar essas invariantes transacionalmente.
