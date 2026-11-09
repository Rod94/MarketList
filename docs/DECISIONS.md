# DECISIONS.md — Registro de decisões e dúvidas abertas

**Versão:** 0.1  
**Data:** 07/11/2026

Este documento registra *o que decidimos* e separa essas decisões de propostas de implementação. Quando uma decisão mudar, adicionar motivo, data e impacto; não apagar silenciosamente o histórico.

## 1. Decisões de produto aprovadas

| ID | Decisão | Motivo / consequência |
| --- | --- | --- |
| D-001 | App permite planejar em casa e registrar preços no mercado | Evita surpresa no caixa |
| D-002 | Nome obrigatório; quantidade planejada opcional | Carne/peixe podem ser itens sem quantidade |
| D-003 | Marca, foto e categoria não são obrigatórias nem campos do fluxo principal | Cadastro rápido e sem excesso de burocracia |
| D-004 | Mesmo item aceita várias entradas quantidade × preço | Sabonete 3 × R$ 3,50 + 2 × R$ 4,20 |
| D-005 | Pode registrar valor direto sem quantidade | `Carne: R$ 47,82` |
| D-006 | Produtos não planejados podem ser inseridos pelo `+` durante a compra | Compra real não se limita à lista |
| D-007 | Usuário pode remover item, alterar preço e comprar mais/menos que o planejado | Flexibilidade sem bloqueios |
| D-008 | Preço confirmado e salvo entra imediatamente no total | Total acumulado é o propósito principal |
| D-009 | Orçamento por lista é opcional; excedê-lo não bloqueia | Informa saldo/excedente, sem impor restrições |
| D-010 | Total da compra fica sempre visível na tela principal | Consulta rápida a qualquer momento |
| D-011 | A tela principal mantém a ordem original dos produtos | Interface previsível; sem itens "pulando" |
| D-012 | Filtro `A comprar` mostra pendentes e parciais, sem alterar total | Foco sem perda do contexto financeiro |
| D-013 | Formulário compacto com Produto, Quantidade e Preço juntos | Menos navegação e toques |
| D-014 | Toque no item abre detalhes e ação `Adicionar outro preço` | Evita criar produtos duplicados por marca |
| D-015 | Dark AMOLED usa preto principal real `#000000`, com versão clara | Conforto visual e identidade limpa |
| D-016 | Sempre revisar antes de confirmar finalização | Compra ficará somente para consulta |
| D-017 | Revisão mostra total, pendências e compras parciais sem bloquear | Usuário decide finalizar |
| D-018 | Se houver orçamento, revisão mostra saldo ou excedente | Conferência financeira completa |
| D-019 | Campo opcional para valor efetivamente cobrado no caixa | Permite comparar com total registrado |
| D-020 | Diferença entre caixa e app é informativa; não altera preços dos produtos | Integridade histórica |
| D-021 | Finalizada = somente leitura; sem reabrir para editar no MVP | Histórico estável e confiável |
| D-022 | Histórico simples para consulta de preços/quantidades por data | Ex.: comparar arroz 5 kg de 2026 com 2027 |
| D-023 | Funcionamento offline e persistência de dados desde a primeira versão | Uso em mercado sem rede |
| D-024 | Android APK inicial, com caminho previsto para iOS | Entrega inicial focada sem reescrita futura |
| D-025 | Flutter + Dart | Base compartilhável para Android/iOS |
| D-026 | Cada etapa atende requisitos e testes antes de ser considerada concluída | Desenvolvimento incremental com regressão |
| D-027 | Código organizado e explicado didaticamente | Projeto também serve para aprender programação |

## 2. Propostas técnicas e validação no scaffold

| ID | Proposta | Por que ainda é proposta |
| --- | --- | --- |
| P-001 | MVVM enxuto organizado por features — adotado na fundação F0 | Uso e limites registrados na seção 6; camadas futuras serão introduzidas conforme a tarefa |
| P-002 | `Provider` + `ChangeNotifier` — adotado na fundação F0 | Estado de tema e reconstruções testados; reavaliar se a complexidade exigir |
| P-003 | SQLite com `sqflite` — adotado na F1-02 | Banco/migração inicial testados em Windows/Android; detalhes na seção 8 |
| P-004 | Usar `int` em centavos, com parser e formatação `pt-BR` | Regra técnica de precisão; detalhar limites e validação |
| P-005 | Navegação com `Navigator` no início | Avaliar `go_router` só se rotas realmente demandarem |
| P-006 | Soft delete para item removido, com possibilidade de desfazer | Precisamos fechar o comportamento de UX |

**Recomendação:** essas propostas constam em `ARCHITECTURE.md`; confirmar durante Fase 0/1 e atualizar status aqui, sem adicionar bibliotecas por hábito.

## 3. Questões abertas — não implementar assumindo resposta

| ID | Pergunta | Momento de resolução | Impacto |
| --- | --- | --- | --- |
| Q-001 | Preço igual a `R$ 0,00` deve ser aceito como produto gratuito? | Antes de F3-01 | Validação e soma |
| Q-002 | Se item tem quantidade planejada, mas compra registrada apenas por valor direto, como mostrar quantidade não confirmada? | Antes de F3-06 | Estado e filtro/revisão |
| Q-003 | Ao digitar nome já existente, sugerir reaproveitá-lo sem impedir duplicatas legítimas? | Antes de F3-07 | Cadastro rápido |
| Q-004 | Qual duração e comportamento do `Desfazer` após remover item? | Antes do polimento F4 | Recuperação de erro |
| Q-005 | É permitido apagar do aparelho uma lista histórica finalizada? Em caso positivo, qual confirmação? | Antes de F6 | Exclusão vs. imutabilidade |
| Q-006 | Tema inicial segue o sistema ou tema selecionado na primeira execução? | Antes de F4-05 | Preferência visual |
| Q-007 | Precisaremos de exportação/backup local no primeiro lançamento público? | Antes do release para público mais amplo | Risco de perda de dados por desinstalação/aparelho |

**Como resolver:** registrar opção escolhida, justificativa, efeito em `SPEC.md`, `DESIGN.md`, `TESTING.md`, testes novos e eventuais migrações. O Codex não deve transformar uma pergunta aberta em regra sem antes documentar a hipótese e apresentar a alternativa.

## 4. Fora do MVP

- Sincronização entre dois celulares e contas de usuário.
- App iOS distribuído no primeiro ciclo.
- Marca obrigatória, fotos, leitura de código de barras, análise automática de inflação.
- Duplicar lista anterior (ideia útil, porém não aprovada como requisito da primeira versão).

## 5. Modelo de registro de mudanças futuras

```text
D-0XX — Título
Data: AAAA-MM-DD
Status: aprovado | revisado | substituído
Contexto: problema que motivou a decisão
Decisão: comportamento escolhido
Alternativas: opções avaliadas
Consequências: UX, banco, testes, migração, manutenção
Documentos e testes atualizados: ...
```

## 6. Registro técnico da Fase 0 — 09/11/2026

- **P-001 adotada nesta fundação:** organização por feature, com uma tela de demonstração em `features/shopping/presentation/screens/`. Domínio, repositórios e banco serão introduzidos nas suas fases; nenhuma pasta vazia foi criada para simular arquitetura.
- **P-002 adotada:** Provider 6.1.5+1 e `ChangeNotifier` coordenam a preferência visual em memória. O Provider cria/descarta o ViewModel e a tela somente apresenta/encaminha a escolha. Testes verificam estado, notificação e atualização do tema.
- **Ferramentas verificadas:** Flutter 3.47.9 stable / Dart 3.13.7. Projeto gerado com `flutter create --empty --platforms=android,ios --project-name=market_list --org=br.com.rodolpho --android-language=kotlin --no-pub .`. Identificadores nativos normalizados para `br.com.rodolpho.marketlist`; nome exibido MarketList. São identificadores de desenvolvimento, ainda sem publicação.
- **Dependências mínimas:** Provider, Flutter e localização pt-BR via `flutter_localizations` (SDK). `flutter_test`, `integration_test` e `flutter_lints` são ferramentas de desenvolvimento. `intl` é transitivo da localização, sem conversor monetário implementado.
- **Q-006 permanece aberta:** para demonstrar os dois temas foi necessário um estado inicial. A demonstração segue o sistema, oferece seleção temporária e não grava preferência. Alternativa: tema inicial fixo. Esta escolha provisória não define a experiência definitiva da F4-05 nem adiciona persistência antecipada.
- **P-003/P-004/P-005/P-006 e questões Q-001 a Q-005/Q-007:** não resolvidas nesta entrega. Não houve mudança de regra de negócio, esquema ou migração de banco.
- Tokens visuais de `DESIGN.md` foram usados nos temas. Cores de inicialização Android têm recursos dia/noite próprios porque são exibidas antes de o Flutter desenhar a tela. Inspeção física de contraste/OLED permanece pendente.

Evidências, limitações e instruções didáticas: `PHASE_0_REPORT.md`.

## 7. Registro técnico F1-01 — 09/11/2026

- `ShoppingList` é um modelo Dart puro, com todos os campos da seção 5 de `ARCHITECTURE.md`, sem serialização, SQL, métodos de finalizar/reabrir ou `copyWith` genérico. Campos `final` e valores imutáveis impedem alterar a instância. Isso não substitui a futura proteção transacional do repositório.
- ID é uma string opaca não vazia, fornecida pelo chamador e preservada exatamente. Sua geração/garantia de unicidade ficará com a camada de criação na F1-03; não se acrescentou biblioteca de UUID nem se usou data como identificador.
- Data de criação também é fornecida pelo chamador; criação/conclusão são normalizadas com `toUtc()`, preservando o instante. Isso evita relógio global e permite testes determinísticos.
- Nome obrigatório rejeita conteúdo vazio após `trim()`; somente espaços externos são removidos, sem limite de tamanho ou política de unicidade inventados. A validação concretiza RF-01 e os casos de borda de TESTING; nomes iguais não são bloqueados no modelo.
- Invariantes de representação: ativa não contém dados finais; finalizada exige data e total calculado, com conclusão não anterior à criação. O mesmo instante é permitido. São verificações do construtor em execução, não `assert` desabilitável em release. Implementação da finalização/concorrência permanece para F5.
- Valores presentes são `int` em centavos não negativos; ausentes permanecem `null`. Zero de orçamento, total agregado ou caixa é representável sem equivaler à ausência. Um total zero pode representar finalização com todos os itens pendentes, permitida pelo produto. Isso **não resolve Q-001** sobre preço zero de uma entrada de produto, nem define limites de entrada/overflow da F3.
- Orçamento não bloqueia o estado e valor cobrado não é obrigado a igualar o total calculado, conforme D-009/D-019/D-020. O modelo não calcula nem corrige esses valores.

Nenhuma regra aprovada foi substituída. Não há migração nem alteração de dados existentes. Q-001 a Q-007 continuam abertas nos seus momentos previstos. Evidência: `PHASE_1_REPORT.md` e seção 13 de `TESTING.md`.

## 8. Registro técnico F1-02 — 09/11/2026

- Adotados `sqflite` **2.4.5+1** e `path` **1.9.1** no app; `sqflite_common_ffi` **2.4.6** somente como dependência de desenvolvimento para testes Windows com SQLite real. O lockfile resolveu `sqflite_common` 2.5.16 e `sqlite3` 3.5.2. Não há implementação FFI importada no código de produção. O build debug continua sendo artefato de desenvolvimento, sem promessa de tamanho otimizado de release.
- `AppDatabase.open()` devolve `Future<Database>`, usando a factory nativa por padrão e caminho `getDatabasesPath()/market_list.db`. Factory/caminho injetáveis isolam os testes. `singleInstance: true` compartilha a conexão para o mesmo caminho, inclusive nas aberturas concorrentes testadas. O futuro dono da conexão será a camada de dados; widgets não devem abri-la/fechá-la por ação.
- `onConfigure` habilita foreign_keys antes de criar/abrir o esquema. A migração v1 fica em arquivo próprio e cria **somente shopping_lists** e o índice `(status, created_at_utc)`. Tabelas/índices de produtos e entradas exigirão novas migrações nas fases correspondentes. Isso evita decidir preço zero ou formato de entrada antes de Q-001/Q-002.
- `onCreate` já é transacional no [sqflite](https://pub.dev/packages/sqflite); não aninhar uma transação chamando `db` por dentro. Tabela, índice e versão são confirmados juntos. O teste provoca colisão de índice após criar a tabela e comprova rollback de DDL/versão, preservação de uma tabela anterior e nova tentativa bem-sucedida. Isso foi verificado em SQLite FFI e Android nativo.
- Não há reset, exclusão de banco, `IF NOT EXISTS` para esconder esquema conflitante nem downgrade destrutivo. `onDowngrade: onDatabaseVersionChangeError` recusa versão superior e preserva seus dados. Ainda não existe migração de produção v1→v2: quando necessário, adicionar novo arquivo e `onUpgrade` sequencial, sem alterar v1 já publicada, com teste da compatibilidade.
- Restrições reforçam ID não nulo/único e texto não vazio após trim SQL, estados conhecidos, inteiros não negativos e combinação coerente de dados finais. SQLite tem afinidade de tipos; `typeof(...) = 'integer'` impede armazenar frações/texto em campos de centavos. Nomes duplicados permanecem permitidos, orçamento pode ser excedido e caixa/calculado permanecem independentes.
- O banco exige sufixo UTC `Z`, mas **não substitui** a validação semântica completa de data/nome do domínio. Datas inválidas terminadas em Z e textos só com outros caracteres de espaço não são integralmente validados pelo SQL. A F1-03 deve mapear dados pelo modelo, validar entradas e adotar serialização UTC canônica para ordenação; cronologia continua validada em `ShoppingList`.
- **Imutabilidade investigada:** o CHECK de estado valida representação, não bloqueia toda alteração em registro finalizado. F1-03 deve condicionar gravações de lista ativa a `status = 'active'`, verificando linhas afetadas e estado dentro da transação; a implementação/testes completos de finalização/concorrência permanecem na F5. Não foi imposto trigger de exclusão histórica, pois Q-005 continua aberta.
- Testes criam apenas fixtures próprias; a limpeza resolve os caminhos, verifica raiz/prefixo e exclui exclusivamente a pasta temporária criada pelo teste. O banco normal `market_list.db` não foi usado nem limpo pelos testes.

Referência de testes FFI: [documentação do pacote](https://pub.dev/packages/sqflite_common_ffi). Q-001 a Q-007 permanecem abertas. Os reforços de esquema concretizam o modelo F1-01; nenhuma regra de negócio aprovada foi substituída. Detalhes de compatibilidade e execução em `PHASE_1_REPORT.md`.

## 9. Registro técnico F1-03 — 09/11/2026

- Contrato `ShoppingRepository` em Dart puro: gerar novo ID, criar lista, listar ativas e remover ativa. A implementação SQLite concentra consultas, serialização e transações; não há SQL nem instanciação nova de repositório em widgets nesta tarefa.
- Identificadores novos usam UUID v4 pelo pacote [uuid](https://pub.dev/packages/uuid), versão resolvida **4.6.0**. `newListId()` é chamado uma vez por intenção de inclusão; `createList` exige esse ID para que repetições reutilizem a mesma operação. IDs externos continuam opacos, sem exigir formato UUID de registros anteriores.
- Criação é transacional: ID inexistente insere; ID ativo com mesmo nome normalizado/orçamento retorna a instância persistida, mantendo data original; dados diferentes produzem `ShoppingListCreationConflict`; ID finalizado produz `FinalizedShoppingListException`. Não há replace/upsert que sobrescreva dados. Nomes iguais com IDs distintos continuam permitidos. Essa regra compara identidade de operação, não resolve Q-003 sobre nomes de produtos duplicados.
- O relógio é injetável, com `DateTime.now` por padrão; `ShoppingList` valida e converte criação para UTC antes da escrita. Sucesso da chamada só é entregue após o commit. Erros de banco/validação são propagados, sem descarte ou tentativa automática destrutiva.
- Remoção lê estado e apaga por `id = ? AND status = 'active'` na mesma transação. Retorna true para uma exclusão confirmada, false se já ausente e erro específico se finalizada. Remover duas vezes confirma somente uma exclusão. Há teste de remoção aguardando uma transação de finalização já iniciada (apenas fixture, sem implementar fluxo F5).
- Dependência referencial impeditiva faz a remoção falhar atomicamente, preservando pai/filho; não se desabilita FK. As futuras tabelas de produtos/entradas precisarão definir remoção das dependências na migração/tarefa correspondente. Não há SQL para tabelas futuras nem escolha de exclusão histórica Q-005.
- A listagem retorna apenas ativas, como coleção imutável. Ordem técnica inicial: criação mais recente primeiro, desempate por ID. A ordenação usa os instantes Dart após leitura, pois strings v1 válidas com `.000Z`/`.000001Z` têm ordem textual diferente da temporal. Isso não altera a regra de posição estável dos **itens**, que ainda não existem.
- Datas novas são ISO UTC com seis casas de fração; leitura aceita segundos completos com fração opcional de até seis casas e as representações completas de ano do Dart. A normalização para comparação detecta calendário inválido sem reescrever a linha. [DateTime.parse permite overflow](https://api.dart.dev/dart-core/DateTime/parse.html); por isso parse isolado não seria validação estrita. [toIso8601String omite parte da fração quando zero](https://api.dart.dev/dart-core/DateTime/toIso8601String.html), justificando o preenchimento canônico.
- A migração v1 e a versão do banco permaneceram intactas. Leitura de dado inválido falha de forma explícita e preserva o arquivo, sem ocultar linhas como se não existissem. Não há atualização de dados legados nesta tarefa.
- **Limite da idempotência:** o chamador deve manter o ID enquanto uma inclusão está pendente e usar novo ID para uma nova inclusão. Repetições com IDs diferentes não podem ser distinguidas de inclusões legítimas. IDs removidos não devem ser reutilizados; não foi introduzido log/tombstone de operações. Bloqueio de botão e preservação de input ficarão no ViewModel/tela F1-04.

As três operações disponíveis recusam alterações em listas finalizadas conforme seu contrato: criar não reabre, listagem ativa não as expõe e remoção recusa. Não existem ainda métodos de editar produtos/preços/finalizar; a cobertura completa CT-046/F5 dependerá dessas operações. Q-001 a Q-007 continuam abertas. Resultados e didática em `PHASE_1_REPORT.md`.

**Execução de integração e dados:** o log detalhado desta tarefa revelou que Flutter 3.47.9 executa uninstall por padrão ao encerrar a integração. Isso é implementado em `packages/flutter_tools/lib/src/commands/test.dart` (opção uninstall padrão true) e `src/test/integration_test_device.dart` (limpeza final). A partir desta descoberta, os comandos recomendados usam `--no-uninstall`, suportado pelo SDK instalado. A flag não dispensa o isolamento dos arquivos de teste nem a restauração do APK normal; evita que a limpeza do runner apague o armazenamento do pacote. Nesta etapa a interface ainda não gravava listas/banco normal. Os registros antigos de `install -r` descrevem a restauração manual, não provam ausência de uninstall automático durante a integração.

## 10. Registro técnico F1-04/F1-05 — 09/11/2026

- Inicialização abre `Minhas listas`, com repositório SQLite real configurado em `app/app.dart` e ViewModel via Provider. O carregamento é assíncrono, sem bloquear `main.dart`; erro exibe retry e não simula uma lista vazia. O repositório pode ser injetado para testes, sem fallback falso em produção.
- `ShoppingListsViewModel` controla carga, coleção confirmada, rascunho, erros e operação pendente. Carga/criação/remoção não se sobrepõem. ID é gerado uma vez por inclusão e retido em falha; o retry mantém identidade. Cancelamento explícito descarta apenas rascunho. Sucesso atualiza cache com modelo confirmado, sem duplicar ID; notificações após dispose são impedidas.
- Comparador de listas extraído para método puro do modelo e compartilhado com repositório/ViewModel. É uma refatoração restrita para manter a ordem já adotada, sem duplicar regra ou alterar a ordenação futura dos itens.
- Formulário de criação contém nome e orçamento opcional (fluxo aprovado em DESIGN). `StatefulWidget` possui somente controladores de texto; parsing/coordenação ficam fora dele. Rodapé com ações fica acima de viewInsets do teclado e campos rolam separadamente. Durante gravação, inputs/cancelamento/voltar ficam bloqueados; na falha, texto e ID permanecem.
- Conversão específica de **orçamento de lista** fica na apresentação da feature, em função Dart pura. Aceita inteiros ou vírgula com uma/duas casas, sem pontos de milhar; vazio→null, zero→0. Compõe a string de centavos e usa int.tryParse, sem double nem multiplicação sujeita a overflow. A rejeição de valor não representável é limite técnico do int nativo, não teto de negócio escolhido. Parser/validação geral de preços, limites de domínio e Q-001 continuam para F3.
- Lista exibe nome, data local, estado textual e orçamento quando presente. Excluir exige diálogo com nome e impacto; o item permanece até a gravação confirmar. Histórico não é exposto nem excluído. Aparência continua acessível por navegação; Q-006 permanece aberta e a seleção ainda é temporária, seguindo sistema ao reiniciar.
- Integração de interface agora injeta SQLite em subpasta temporária própria, pois `MarketListApp()` passou a usar o banco normal. Os testes não consultam nem limpam esse banco; todos os comandos atuais mantêm `--no-uninstall`.
- F1-05 usa `tool/verify_android_offline.py`, um roteiro host ADB com seletores lidos da árvore de acessibilidade. `--inspect` somente inspeciona. `--run` exige ação explícita, captura configurações, mantém tela acesa via USB, ativa modo avião/desliga Wi-Fi e verifica ausência de rede padrão. Cria lista própria com nome único, encerra o processo, reabre, exige PID diferente e verifica nome/orçamento. Remove somente a própria lista via confirmação e restaura rede/tela em finally. Não há reset, uninstall nem exclusão direta de banco.
- O teste real confirmou restauração dos estados anteriores e reconexão da rede padrão. Capturas e JSON ficam em build, ignorados pelo Git. Não foi adicionada dependência Python externa nem funcionalidade de rede ao aplicativo.
- Interrupção do runner permanece sem causa comprovada. O diagnóstico `--no-dds` produziu erro de stream do comparador golden do SDK e foi descartado; a suíte passou com DDS normal e expectativas intactas. Não se atualizou nem alterou o SDK para mascarar o problema.

Nenhuma regra de compra/preço foi alterada; Q-001 a Q-007 seguem abertas para suas fases. Evidência de encerramento da Fase 1 em `PHASE_1_REPORT.md` e seções 16/17 de `TESTING.md`.
