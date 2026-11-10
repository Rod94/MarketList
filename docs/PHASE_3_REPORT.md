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

## F3-04 — Entradas persistidas e v3

**Data:** 10/11/2026. Entradas agora podem ser criadas/corrigidas/excluídas pelo repositório, com fotografia de itens/entradas/estados/total confirmada. A UI ainda é de planejamento; ligação de preço vem a seguir.

Arquivos: migrations/v3.dart (tabela/índice/restrições), AppDatabase (upgrade sequencial), ShoppingRepository (contrato/fotografia/erros), SqliteShoppingRepository (transações/mapeamento/guardas), testes novos purchase_repository_test.dart (18) e entries_migration_test.dart (5), regressões app_database/items_migration/database_smoke e fake com operações explicitamente não usadas até F3-05. README/TASKS/DECISIONS/ARCHITECTURE/TESTING/relatório atualizados. V1/v2 e dependências não mudaram.

Fluxo: **dados validados → transação verifica lista ativa/item não removido → inserir/substituir/excluir → calcular fotografia/limites → commit → Future devolve resultado**. Overflow ou falha SQL reverte tudo. Retry de criação compara ID/dados; não duplica nem sobrescreve. Correção mantém ID/vínculo; exclusão só afeta sua entrada. Remoção de item mantém entradas mas retira subtotal do total. Cascade de lista ativa apaga dependências atomicamente; finalizadas permanecem protegidas.

Migração v2→v3 apenas acrescenta tabela/índice; testes comparam todos os dados e provocam falha após CREATE TABLE para provar rollback/versão e retry. Instalação nova tem esquema igual ao upgrade. CHECK protege modos/tipos/produto int64 e FK impede órfãos. Soma entre linhas é protegida pela calculadora na transação, porque CHECK não valida agregados de outras linhas. Após abrir v3, APK v1/v2 não serve como rollback; downgrade é recusado sem apagar dados.

Conceitos: transação junta validação e escrita; fotografia de retorno evita mostrar um total de outra leitura parcialmente atualizada. JOIN liga entrada→item→lista; parâmetros protegem valores. FK/cascade fazem a exclusão física acompanhar a árvore de dependências; soft delete não dispara cascade. UPDATE troca todas as colunas do modo, preenchendo null para as incompatíveis. Erro propaga, sem retorno de sucesso fictício.

Testes: RED por APIs inexistentes; primeiros 16 de repositório passaram; 5 de migração somaram regressão 267. Dois cenários adicionais (concorrência no limite e cascade abortado) levaram a **269 aprovados/0 falhas**, análise sem problemas. Nenhuma expectativa financeira foi relaxada. Para verificar: `flutter test test/database/purchase_repository_test.dart test/database/entries_migration_test.dart`. Exercício opcional em branch de treino: conferir que uma correção para zero conserva o ID e vira compra gratuita. Execução Android/APK registrada abaixo após resultado efetivo.

Android F3-04: `flutter test integration_test/database_smoke_test.dart --no-uninstall -d RXCY300NZZH --verbose` → **13 aprovados**, saída 0; `flutter test integration_test/app_smoke_test.dart --no-uninstall -d RXCY300NZZH --verbose` → **7 aprovados**, saída 0. Total **20 nativos**, todos em bancos próprios. `flutter build apk --debug` passou em **12,5 s**; cópia marketlist-f3-04-debug.apk instalada com install -r (**Success**) e aberta (**Status: ok**). Sem uninstall, reset, modo avião ou iOS/release nesta tarefa. Nova UI financeira ainda não ligada.
