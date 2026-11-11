# TASKS.md — Plano incremental de desenvolvimento

**Versão:** 1.6 — Fases 0/1/2 concluídas; F3-01 a F3-06 concluídas

**Data:** 10/11/2026 (plano original: 07/11/2026)
**Fontes de verdade:** `SPEC.md` (regras), `DESIGN.md` (interação), `ARCHITECTURE.md` (estrutura), `TESTING.md` (casos), `DECISIONS.md` (decisões).

> **Modo de trabalho:** tarefas pequenas, testáveis e com explicação didática. Implementar apenas uma tarefa ou pequena fatia vertical por vez no Codex. Não marcar como concluída sem testes reais e sem explicar o que foi feito.

**Versionamento autorizado pelo usuário:** a partir da F2-01, concluir e validar cada tarefa pequena, criar seu commit e enviar ao GitHub. Informar hash e resultados reais; não marcar envio como feito se falhar.

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

| Tarefa | Entrega | Critério de conclusão | Status real |
| --- | --- | --- | --- |
| F1-01 | Modelos de `ShoppingList`, ID e datas em UTC | Testes de domínio de validação/estado aprovados | **Feito:** modelo imutável e 21 testes de domínio |
| F1-02 | `AppDatabase` e migração SQLite inicial | Integridade referencial e abertura/versão testadas | **Feito:** v1, FK e 15 testes SQLite; validação nativa |
| F1-03 | Repositório para criar/listar/remover lista ativa | CT-001, CT-002, CT-003 aprovados | **Feito:** 26 testes do repositório; confirmação de persistência e proteção de finalizadas |
| F1-04 | Tela `Minhas listas` e formulário de criação | Fluxo de criação e retorno claros; widget test | **Feito:** nome/orçamento, estados de erro/carga, ID de retry, exclusão confirmada; 23 testes unitários e 13 novos de widget |
| F1-05 | Abrir lista após fechar/reiniciar em modo avião | Teste de integração com banco real, quando disponível | **Feito:** roteiro ADB no app normal, sem rede padrão, criou lista, force-stop, novo PID, dados recuperados; limpeza restrita e rede/tela restauradas |

**Status real — 09/11/2026:** **Fase 1 concluída.** Testes finais: **105 convencionais aprovados**, **9 de integração Android aprovados** (3 interface + 6 banco/repositório), mais **1 roteiro de reinício offline aprovado** no banco normal do app. Análise sem problemas, 28 arquivos Dart formatados e APK debug instalado. Interrupções do runner e diagnóstico sem DDS incompatível foram registrados; a execução com DDS normal passou sem relaxar expectativas. O teste offline removeu somente a própria lista e restaurou modo avião/Wi-Fi/tela; rede padrão reconectada confirmada. Evidências em `PHASE_1_REPORT.md`.

**Critérios:** persistência após reiniciar; erro de gravação não exibe falso sucesso; lista ativa identificada claramente.

**Explicações didáticas:** `class`, `final`, construtores, `Future`, `async/await`, SQLite, repositório e tratamento de erros.

## Fase 2 — Produtos e quantidade planejada

**Objetivo:** montar a lista em casa com mínimo de fricção.

| Tarefa | Entrega | Critério de conclusão | Status real — 10/11/2026 |
| --- | --- | --- | --- |
| F2-01 | Modelo de item e campo `plannedQuantity?` | Testar que `null` ≠ 1 | **Feito:** modelo Dart puro imutável; 24 testes novos aprovados, regressão com 129 aprovados, analyze sem problemas |
| F2-02 | Adicionar/editar/remover item com persistência | CT-004 a CT-006, CT-021 conforme aplicável | **Feito:** migração v1→v2, CRUD transacional com remoção marcada, retry e bloqueio de finalizadas; 31 testes novos SQLite, regressão com 160 aprovados e 13 nativos aprovados (10 banco + 3 UI após tentativa interrompida do runner) |
| F2-03 | Formulário compacto com nome obrigatório e quantidade opcional | UX-001/UX-002 na fatia de planejamento; sem exigir marca, foto nem categoria | **Feito:** navegação, inclusão/edição persistida, formulário acessível com teclado, erros/retry e proteção de gravação; 16 novos testes, regressão 176 aprovados |
| F2-04 | Ordenação estável por `sortOrder` | Item não muda de posição após edição | **Feito:** comparador puro, carga/cache ordenados e identidade preservada; 5 novos testes, regressão com 181 aprovados |
| F2-05 | Remoção lógica com redução do conjunto visível | CT-005; base de CT-050 (subtotal depende de F3); `Desfazer` só depois de decisão | **Feito:** remoção confirmada/ocultação, campos mantidos na falha e recarga; 8 novos testes, regressão 189 aprovados, 17 nativos e 1 reinício offline com produtos aprovados |

**Escopo F2-01:** representação dos campos documentados, incluindo origem, posição e data de remoção; nenhum fluxo de ordenação/remoção, CRUD, migração ou tela de produto foi antecipado. CT-006/UX-002 têm cobertura apenas da semântica do modelo. Evidências e explicação: `PHASE_2_REPORT.md`.

**Escopo F2-02:** persistência e leitura de registros, incluindo os marcados como removidos. O backend atribui/preserva posição porque ela é campo obrigatório do modelo. Formulário, integração visual de ordenação e ocultação de removidos continuam pendentes em F2-03/04/05. CT-005 está coberto na marcação persistida; CT-021 na identidade preservada, sem entradas de compra ainda. A migração mantém a v1 publicada intacta, sem reset nem reescrever listas. Ver resultados/limitações atualizados em `PHASE_2_REPORT.md` e TESTING.

**Explicações didáticas:** valor opcional (`int?`), formulário, validação, diferença entre estado visual e domínio.

**Saída real da Fase 2 — 10/11/2026:** tarefas F2-01 a F2-05 **feitas**. App normal permite planejar, editar/limpar quantidade e remover mantendo ordem. Verificação final: **189 testes convencionais, 17 nativos (7 UI + 10 banco) e 1 roteiro offline com novo processo aprovados**; analyze sem problemas, 39 arquivos Dart formatados, APK normal instalado/aberto. Roteiro criou só uma lista própria, conferiu produtos/quantidades/ordem/remoção após reiniciar sem rede, excluiu só essa lista e restaurou rede/tela. Nenhum reset/uninstall/migração extra foi realizado em F2-03/04/05.

**Limites de cobertura:** UX-001 completo com preço e CT-050 financeiro requerem F3; estabilidade após compra/filtros/total requer F3/F4. Não se marcou esses fluxos completos como testados. O rótulo CT-050 foi esclarecido para separar a base de remoção desta fase do cálculo futuro, sem alterar regra de negócio. Q-004 continua aberta e Desfazer não foi implementado.

## Fase 3 — Registros de compra e matemática financeira

**Objetivo:** permitir registrar, corrigir e remover preços com exatidão.

| Tarefa | Entrega | Critério de conclusão | Status real |
| --- | --- | --- | --- |
| F3-01 | Conversor de moeda `pt-BR` ↔ centavos e validações | Testes para `4,22`, centavos e formatos inválidos | **Feito:** 17 novos testes; regressão 206 aprovados; analyze sem problemas |
| F3-02 | Modelo `PurchaseEntry` com quantidade × unidade OU valor direto | Testar exclusividade dos modos e subtotais | **Feito:** modelo puro imutável e subtotal verificado; 18 novos testes, regressão 224 aprovados |
| F3-03 | Calculadora pura de item/lista e compra parcial | CT-008 a CT-010, CT-013 a CT-017, CT-020, CT-026 | **Feito no domínio:** 22 novos casos de cálculo/estados/invariantes; regressão 246 aprovados; histórico UI ainda F5/F6 |
| F3-04 | SQLite para inserir/atualizar/excluir entradas | CT-022 a CT-027; transações e integridade | **Feito:** migração v3, fotografia transacional e rollback por overflow/erro; 23 novos testes SQLite, regressão 269 aprovados |
| F3-05 | ViewModel atualiza total após sucesso de persistência | CT-033 a CT-035 e UX-008 | **Feito:** fotografia confirmada separada da prévia; 12 novos testes, regressão 281 aprovados e 8 nativos após desbloqueio |
| F3-06 | Painel de item existente e `Adicionar outro preço` | UX-020; 3 × 3,50 + 2 × 4,20 = R$ 18,90 | **Feito:** painel/formulário, correção/exclusão, prévia e totais confirmados; 8 novos widgets, regressão 289 e 10 nativos aprovados |
| F3-07 | Produto espontâneo com quantidade/preço no mesmo formulário | CT-018/CT-019, UX-003/UX-004 | **Feito:** inclusão atômica, prévia, tratamento de falha e 297 testes Flutter aprovados. Evidências no relatório F3 |

**Decisões resolvidas pelo usuário em 10/11/2026:** zero explícito é gratuito (D-028); limite técnico int64 com overflow recusado (D-029); valor direto em item planejado, inclusive caso misto, mantém Quantidade não confirmada e A comprar (D-030). Autorizado seguir da F3 em diante fase por fase, uma tarefa/commit por vez, parando somente quando decisão necessária ou portão de qualidade impedir.

**Explicações didáticas:** encapsulamento, imutabilidade, `List`, `fold`, testes unitários, por que centavos inteiros evitam erros financeiros.

## Fase 4 — Experiência principal, filtros e orçamento

**Objetivo:** ter a primeira tela de compra realmente prática.

| Tarefa | Entrega | Critério de conclusão |
| --- | --- | --- |
| F4-01 | Lista de itens compacta com estados visuais | **Feito:** quatro estados com texto e ícone, altura de toque verificada; 298 testes aprovados |
| F4-02 | Filtros `Todos` / `A comprar` | **Feito:** UX-011 a UX-016, ordem e total preservados; 299 testes aprovados |
| F4-03 | Barra inferior fixa com total e `+ Adicionar` | **Feito:** total fixo ao rolar 100 itens, inclusão acessível com teclado e fonte 2× em widget; 300 testes aprovados |
| F4-04 | Orçamento opcional, saldo/excedente | **Feito:** CT-028 a CT-031, edição transacional em lista ativa, zero explícito e nenhuma restrição à compra; 303 testes aprovados |
| F4-05 | Temas claro/AMOLED e ajustes de acessibilidade | **Feito:** preferência persistida e fundo AMOLED verificados no Samsung; semântica dos itens e fonte 2× cobertas em widget. Inspeção manual da leitura em voz alta com TalkBack pendente |
| F4-06 | Ajustes de feedback e velocidade de cadastro | **Feito:** Desfazer por cinco segundos na tela da compra, restauração transacional e contagens nos filtros quando há espaço. Regressão com 311 testes Flutter e 26 Android aprovados |

**Explicações didáticas:** ciclo de vida do widget, `ChangeNotifier`, `notifyListeners`, reatividade, tema e layout responsivo.

## Fase 5 — Conferência e finalização irreversível

**Objetivo:** encerrar compra sem bloquear pendências, preservando histórico auditável.

| Tarefa | Entrega | Critério de conclusão |
| --- | --- | --- |
| F5-01 | Agregação de itens pendentes/parciais | **Feito no domínio:** FIN-002, FIN-003, FIN-013 e D-030, com ordem e total preservados. 313 testes aprovados |
| F5-02 | Tela de revisão sempre exibida com total e orçamento | **Feito:** rota de conferência, total fixo, saldo/excedente e aviso consolidado. 316 testes aprovados |
| F5-03 | Valor cobrado no caixa opcional + diferença | **Feito na conferência:** caixa vazio ou zero distintos, diferença em centavos e erro de formato. 317 testes aprovados. Persistência na F5-05 |
| F5-04 | Ações `Voltar e revisar` e `Confirmar finalização` | **Feito:** retorno à edição e confirmação protegida por callback; 320 testes aprovados. Conexão ao SQLite na F5-05 |
| F5-05 | Operação atômica no SQLite; bloqueio de dupla finalização | **Feito:** confirmação ligada ao SQLite, comparação com a conferência, rollback, concorrência e caixa separado. 327 testes aprovados |
| F5-06 | Impedir gravações em finalizada no ViewModel/repositório | **Feito:** consulta imediata e bloqueio das mutações, inclusive com estado carregado antes da finalização. 330 testes Flutter e 27 no Samsung em modo avião |

**Explicações didáticas:** transação, invariantes, concorrência, por que não basta desabilitar botões na UI.

## Fase 6 — Histórico para consulta

**Objetivo:** consultar compras passadas sem alterar seus valores.

| Tarefa | Entrega | Critério de conclusão |
| --- | --- | --- |
| F6-01 | Listar compras finalizadas por data | **Feito:** nome, conclusão e total registrado em consulta offline. Mais recentes primeiro, com desempate por ID. 340 testes Flutter e 28 no Samsung em modo avião |
| F6-02 | Detalhe histórico somente leitura com itens e entradas | **Feito:** itens, quantidades, faltantes, entradas e subtotais recuperados pelo ID da compra finalizada. CT-012, CT-017, FIN-007 e FIN-016 cobertos. 343 testes Flutter e 29 no Samsung em modo avião |
| F6-03 | Preservar total calculado, orçamento e valor pago no caixa | **Feito:** valores persistidos exibidos separadamente, com distinção entre zero e campo ausente. FIN-022/FIN-023 e 345 testes aprovados |
| F6-04 | Pesquisa simples por nome de produto no histórico | **Feito:** busca por trecho do nome, resultados por compra e data com preços originais e acesso ao detalhe. 349 testes aprovados |
| F6-05 | Validar imutabilidade após nova compra em outro mês | **Feito:** CT-044/046 com comparação dos registros originais, recusa de alterações e consulta após reabrir o SQLite. 350 testes Flutter e 30 no Samsung em modo avião |

**Explicações didáticas:** consultas SQL, relacionamentos, diferenças entre dado persistido e dado derivado, `FutureBuilder`/estado assíncrono conforme implementação.

## Fase 7 — Robustez, regressão e entrega do MVP

**Objetivo:** estabilizar uma versão útil e confiável em aparelho real.

| Tarefa | Entrega | Critério de conclusão |
| --- | --- | --- |
| F7-01 | Testes offline, perda/reentrada de rede, reinício | **Feito:** perda e retorno no mesmo processo, cadastro offline e recuperação após reinício no Samsung. Histórico offline verificado na integração da F6 |
| F7-02 | Migrações, restauração de banco e falhas simuladas | **Feito:** cópias temporárias v2 e v3 recuperadas, integridade verificada e regressão de rollback. 119 testes de banco aprovados |
| F7-03 | Testes de limite, overflow, entradas inválidas e nomes longos | **Feito:** subtotal longo ganha linha própria conforme a largura. Limite e rejeição de overflow verificados pela interface. 354 testes aprovados |
| F7-04 | Testes de usabilidade, contrastes e desempenho em Android | **Feito:** 100 produtos no Samsung com fonte 1,3×, rodapé fixo e cadastro. Contraste dos dois temas e teclado real inspecionados |
| F7-05 | Regressão completa e correções | **Feito:** 356 testes Flutter, 31 no Samsung e abertura do APK normal de depuração |
| F7-06 | Gerar APK de distribuição de teste/release conforme ambiente e assinatura | **Feito:** APK 0.1.0+1 compilado em modo release com assinatura de depuração verificada. Instalação, abertura e navegação ao Histórico aprovadas |
| F7-07 | Revisar `docs/` e relatório final de aprendizado | Documentação reflete exatamente a implementação |

**Atenção:** usar armazenamento local sem sincronização tem risco de perda por desinstalação ou perda do aparelho. **Backup/exportação é evolução separada**, não prometer segurança de dados externos inexistente.

## Futuro / fora do MVP

- Duplicar lista anterior (CT-042): requer aprovação posterior.
- Sincronizar aparelhos/contas, backend/login e solução de conflitos offline.
- Publicar versão iOS: novo ciclo de build/teste/distribuição, sem reescrever o domínio.
- Backup/exportação, reconhecimento de código de barras, gráficos e relatórios de preços.

## Próxima tarefa recomendada ao Codex

**Fase 7 em andamento.** A F7-06 está concluída. O próximo item do plano é **F7-07**, documentação e relatório de aprendizado.

**Estado atual:** Fases 0 a 6 implementadas. O histórico permite consultar compras finalizadas e procurar preços de produtos por nome em modo offline. O banco de compras continua na versão 3. Evidências em `TESTING.md`.

## Retomada da pausa — 10/11/2026

O usuário retomou a partir do commit de pausa 0088dff e autorizou avançar à Fase 4. Os seis testes de inclusão atômica guardados no patch local foram reaplicados na F3-07.
