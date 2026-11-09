# TASKS.md — Plano incremental de desenvolvimento

**Versão:** 0.3 — Fase 0 e F1-01 feitas; demais tarefas pendentes  
**Data:** 09/11/2026 (plano original: 07/11/2026)  
**Fontes de verdade:** `SPEC.md` (regras), `DESIGN.md` (interação), `ARCHITECTURE.md` (estrutura), `TESTING.md` (casos), `DECISIONS.md` (decisões).

> **Modo de trabalho:** tarefas pequenas, testáveis e com explicação didática. Implementar apenas uma tarefa ou pequena fatia vertical por vez no Codex. Não marcar como concluída sem testes reais e sem explicar o que foi feito.

## 0. Portões de qualidade aplicáveis a todas as tarefas

- [ ] Confirmar requisitos e casos de teste da tarefa.
- [ ] Escrever teste primeiro nas regras de domínio, quando couber (RED → GREEN → REFACTOR).
- [ ] Manter widget, ViewModel, domínio e persistência com responsabilidades claras.
- [ ] Salvar em SQLite cada ação confirmada; não atualizar o total oficial antes da gravação.
- [ ] Executar análise/formatação, testes novos e regressão aplicável.
- [ ] Conferir o fluxo manualmente no Android se houver alterações visuais e ambiente disponível.
- [ ] Atualizar documentação e registrar decisões novas.
- [ ] Entregar explicação: problema, arquivos, fluxo, conceito Flutter/Dart, testes e limitações.

**Critério de parada:** falha de teste P0/P1 ou risco de perda de dados → corrigir antes de avançar. A ausência de SDK/dispositivo não autoriza declarar build/testes realizados.

## Fase 0 — Scaffold Flutter e fundação de qualidade

**Objetivo:** projeto criado, executável no Android e preparado para crescer sem excesso de pastas vazias.

| Tarefa | Entrega | Critério de conclusão | Status real — 09/11/2026 |
| --- | --- | --- | --- |
| F0-01 | Verificar ambiente `flutter doctor`, Dart, Android SDK, emulador/dispositivo | Relatório de ambiente com limitações; não instalar coisas silenciosamente | **Feito.** Flutter 3.47.9/Dart 3.13.7 instalado após permissão; diagnóstico e limites registrados. Doctor ainda alerta sobre cmdline-tools/licenças; isso não impediu o build. |
| F0-02 | Criar projeto Flutter organizado no padrão do `ARCHITECTURE.md` | App compila/abre em Android, nome e package definidos explicitamente | **Feito.** MarketList / `market_list` / `br.com.rodolpho.marketlist`; compilou e abriu no Samsung SM-S936B (Android 17). Usuário confirmou tela normal visível. Base iOS gerada, sem build iOS. |
| F0-03 | Configurar `app/`, `core/`, feature inicial e `Provider`/`ChangeNotifier` | Dependências mínimas, sem arquitetura fictícia | **Feito.** Estado de tema em memória, feature somente de demonstração; sem banco, modelos ou pastas futuras vazias. |
| F0-04 | Criar tema claro e tema AMOLED com tokens centralizados | Dark com fundo principal `#000000`; tela de demonstração legível | **Feito.** Temas, alternância e fonte ampliada testados; tela normal inspecionada por captura no Android. Auditoria física completa de contraste/leitor de tela segue para F4/F7. |
| F0-05 | Criar primeiro teste unitário, widget smoke test e verificação estática | Testes reais aprovados e comandos registrados | **Feito.** Formatado, analyze sem problemas; 3 testes unitários de ViewModel + 4 de widget aprovados. |
| F0-06 | Entregar primeira compilação de desenvolvimento, se ambiente permitir | APK de teste/execução; registrar como build de desenvolvimento, não release | **Feito.** `flutter build apk --debug` aprovado; 1 teste de integração no Android aprovado. APK normal restaurado, instalado e aberto após a integração. |

**Explicações didáticas:** `main.dart`, `MaterialApp`, `Scaffold`, `Widget`, `StatelessWidget`, `StatefulWidget`, `pubspec.yaml` e como o Flutter organiza o repositório.

**Evidência da Fase 0:** `PHASE_0_REPORT.md`, incluindo arquivos, comandos, falhas corrigidas, APK, fluxo do estado e exercício opcional. Nenhuma regra de negócio foi alterada; Q-006 continua aberta. Os portões gerais acima são um checklist reutilizável, não uma alegação de SQLite ou funcionalidades futuras prontas.

## Fase 1 — Listas persistentes

**Objetivo:** criar, listar e remover listas ativas mesmo sem conexão.

| Tarefa | Entrega | Critério de conclusão |
| --- | --- | --- |
| F1-01 | Modelos de `ShoppingList`, ID e datas em UTC | Testes de domínio de validação/estado aprovados |
| F1-02 | `AppDatabase` e migração SQLite inicial | Integridade referencial e abertura/versão testadas |
| F1-03 | Repositório para criar/listar/remover lista ativa | CT-001, CT-002, CT-003 aprovados |
| F1-04 | Tela `Minhas listas` e formulário de criação | Fluxo de criação e retorno claros; widget test |
| F1-05 | Abrir lista após fechar/reiniciar em modo avião | Teste de integração com banco real, quando disponível |

**Status real — 09/11/2026:** **F1-01 feita** após autorização para prosseguir. Modelo `ShoppingList` imutável, ID externo não vazio, nome validado, datas normalizadas em UTC e estados coerentes; 21 testes novos aprovados. `flutter analyze` sem problemas; `flutter test` com **28 aprovados** incluindo a regressão da Fase 0; formatação de 13 arquivos verificada. F1-02 a F1-05 continuam **pendentes e não iniciadas**. Não há persistência nem mudança de interface nesta tarefa. Evidência e aprendizado: `PHASE_1_REPORT.md`.

**Critérios:** persistência após reiniciar; erro de gravação não exibe falso sucesso; lista ativa identificada claramente.

**Explicações didáticas:** `class`, `final`, construtores, `Future`, `async/await`, SQLite, repositório e tratamento de erros.

## Fase 2 — Produtos e quantidade planejada

**Objetivo:** montar a lista em casa com mínimo de fricção.

| Tarefa | Entrega | Critério de conclusão |
| --- | --- | --- |
| F2-01 | Modelo de item e campo `plannedQuantity?` | Testar que `null` ≠ 1 |
| F2-02 | Adicionar/editar/remover item com persistência | CT-004 a CT-006, CT-021 conforme aplicável |
| F2-03 | Formulário compacto com nome e quantidade opcionais | UX-001/UX-002; sem exigir marca, foto nem categoria |
| F2-04 | Ordenação estável por `sortOrder` | Item não muda de posição após edição |
| F2-05 | Remoção lógica com redução do conjunto visível | CT-005, CT-050; política de `Desfazer` só depois de decisão |

**Explicações didáticas:** valor opcional (`int?`), formulário, validação, diferença entre estado visual e domínio.

## Fase 3 — Registros de compra e matemática financeira

**Objetivo:** permitir registrar, corrigir e remover preços com exatidão.

| Tarefa | Entrega | Critério de conclusão |
| --- | --- | --- |
| F3-01 | Conversor de moeda `pt-BR` ↔ centavos e validações | Testes para `4,22`, centavos e formatos inválidos |
| F3-02 | Modelo `PurchaseEntry` com quantidade × unidade OU valor direto | Testar exclusividade dos modos e subtotais |
| F3-03 | Calculadora pura de item/lista e compra parcial | CT-008 a CT-010, CT-013 a CT-017, CT-020, CT-026 |
| F3-04 | SQLite para inserir/atualizar/excluir entradas | CT-022 a CT-027; transações e integridade |
| F3-05 | ViewModel atualiza total após sucesso de persistência | CT-033 a CT-035 e UX-008 |
| F3-06 | Painel de item existente e `Adicionar outro preço` | UX-020; 3 × 3,50 + 2 × 4,20 = R$ 18,90 |
| F3-07 | Produto espontâneo com quantidade/preço no mesmo formulário | CT-018/CT-019, UX-003/UX-004 |

**Decisão a resolver antes de F3-01:** política de preço zero e limites de entrada. Antes de F3-06: comportamento de valor direto com quantidade planejada.

**Explicações didáticas:** encapsulamento, imutabilidade, `List`, `fold`, testes unitários, por que centavos inteiros evitam erros financeiros.

## Fase 4 — Experiência principal, filtros e orçamento

**Objetivo:** ter a primeira tela de compra realmente prática.

| Tarefa | Entrega | Critério de conclusão |
| --- | --- | --- |
| F4-01 | Lista de itens compacta com estados visuais | Pendente, parcial, concluído compreensíveis sem depender só de cor |
| F4-02 | Filtros `Todos` / `A comprar` | UX-011 a UX-016; total preservado |
| F4-03 | Barra inferior fixa com total e `+ Adicionar` | UX-005, UX-017 e validação com teclado |
| F4-04 | Orçamento opcional, saldo/excedente | CT-028 a CT-031, sem bloquear ações |
| F4-05 | Temas claro/AMOLED e ajustes de acessibilidade | UX-009, UX-018, UX-019; inspeção em celular real |
| F4-06 | Ajustes de feedback e velocidade de cadastro | Confirmar salva, erro não apaga campos; evitar toque duplo |

**Explicações didáticas:** ciclo de vida do widget, `ChangeNotifier`, `notifyListeners`, reatividade, tema e layout responsivo.

## Fase 5 — Conferência e finalização irreversível

**Objetivo:** encerrar compra sem bloquear pendências, preservando histórico auditável.

| Tarefa | Entrega | Critério de conclusão |
| --- | --- | --- |
| F5-01 | Agregação de itens pendentes/parciais | FIN-002, FIN-003, FIN-013 |
| F5-02 | Tela de revisão sempre exibida com total e orçamento | FIN-001, FIN-009 a FIN-012 |
| F5-03 | Valor cobrado no caixa opcional + diferença | FIN-018 a FIN-024, em centavos |
| F5-04 | Ações `Voltar e revisar` e `Confirmar finalização` | FIN-004, FIN-005, FIN-006, FIN-014 |
| F5-05 | Operação atômica no SQLite; bloqueio de dupla finalização | FIN-008, FIN-015, FIN-017, CT-047/CT-048 |
| F5-06 | Impedir gravações em finalizada no ViewModel/repositório | CT-046, FIN-016 |

**Explicações didáticas:** transação, invariantes, concorrência, por que não basta desabilitar botões na UI.

## Fase 6 — Histórico para consulta

**Objetivo:** consultar compras passadas sem alterar seus valores.

| Tarefa | Entrega | Critério de conclusão |
| --- | --- | --- |
| F6-01 | Listar compras finalizadas por data | Consulta offline e ordenação estável |
| F6-02 | Detalhe histórico somente leitura com itens e entradas | CT-012, CT-017, FIN-007, FIN-016 |
| F6-03 | Preservar total calculado, orçamento e valor pago no caixa | FIN-022/FIN-023 |
| F6-04 | Pesquisa simples por nome de produto no histórico | CT-043 a CT-045; sem análises sofisticadas |
| F6-05 | Validar imutabilidade após nova compra em outro mês | CT-044, CT-046 |

**Explicações didáticas:** consultas SQL, relacionamentos, diferenças entre dado persistido e dado derivado, `FutureBuilder`/estado assíncrono conforme implementação.

## Fase 7 — Robustez, regressão e entrega do MVP

**Objetivo:** estabilizar uma versão útil e confiável em aparelho real.

| Tarefa | Entrega | Critério de conclusão |
| --- | --- | --- |
| F7-01 | Testes offline, perda/reentrada de rede, reinício | CT-036 a CT-041, UX-010 |
| F7-02 | Migrações, restauração de banco e falhas simuladas | CT-048/CT-049; sem perda de dados confirmados |
| F7-03 | Testes de limite, overflow, entradas inválidas e nomes longos | Nenhuma divergência monetária conhecida |
| F7-04 | Testes de usabilidade, contrastes e desempenho em Android | 100 produtos; teclado, scroll, botões, fonte ampliada |
| F7-05 | Regressão completa e correções | Suite automatizada e smoke test aprovados |
| F7-06 | Gerar APK de distribuição de teste/release conforme ambiente e assinatura | Registrar build, variante, assinatura, versão, limites |
| F7-07 | Revisar `docs/` e relatório final de aprendizado | Documentação reflete exatamente a implementação |

**Atenção:** usar armazenamento local sem sincronização tem risco de perda por desinstalação ou perda do aparelho. **Backup/exportação é evolução separada**, não prometer segurança de dados externos inexistente.

## Futuro / fora do MVP

- Duplicar lista anterior (CT-042): requer aprovação posterior.
- Sincronizar aparelhos/contas, backend/login e solução de conflitos offline.
- Publicar versão iOS: novo ciclo de build/teste/distribuição, sem reescrever o domínio.
- Backup/exportação, reconhecimento de código de barras, gráficos e relatórios de preços.

## Próxima tarefa recomendada ao Codex

**F1-01 entregue.** Próxima tarefa pequena de produto: **F1-02 — AppDatabase e migração SQLite inicial**, ainda não iniciada. A autorização para prosseguir foi recebida; manter uma tarefa pequena por entrega. Pendência de ambiente da Fase 0: configurar Android cmdline-tools/revisar licenças para eliminar a advertência do doctor, caso essa instalação seja autorizada.

**Estado atual:** F0-01 a F0-06 e F1-01 **feitas**, com limites documentados; F1-02 em diante **pendentes e não iniciadas**. Em 09/11/2026, o Git local foi inicializado em `main`, com origin `https://github.com/Rod94/MarketList.git`. A base atual fica registrada no primeiro commit; `AGENTS.md` permanece local e ignorado, conforme solicitado. Os relatos anteriores de ausência de `.git` nos relatórios de fases são históricos das execuções originais.
