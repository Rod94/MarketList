# Fase 1 — Relatório incremental

## F1-01 — Modelo ShoppingList, identidade e datas UTC

**Data:** 09/11/2026. **Status:** feita. Este registro descreve a entrega F1-01; a evolução F1-02 aparece na próxima seção principal.

### Problema resolvido

Criamos a representação de uma lista de compras antes de ligá-la à interface ou ao banco. Ela impede representar nome vazio, datas incoerentes ou um estado finalizado sem data/total. Isso prepara a próxima tarefa para salvar dados consistentes e preservar o histórico, sem afirmar que já existe persistência.

### Arquivos alterados

- `lib/features/shopping/domain/models/shopping_list.dart`: novo modelo e enum de estados, sem importações/dependências Flutter.
- `test/unit/shopping_list_test.dart`: 21 testes de validação, datas, estados e valores independentes.
- `docs/TASKS.md`: F1-01 feita e próximas tarefas pendentes.
- `docs/TESTING.md`: rastreabilidade, execução RED/GREEN, regressão e limites.
- `docs/DECISIONS.md`: registra escolhas de representação, ID externo, normalização e limites da tarefa.
- `docs/ARCHITECTURE.md`: registra modelo realmente existente e separação de responsabilidades.
- `README.md`: atualiza estado atual e comandos/resultados, preservando a evidência histórica da Fase 0.
- `docs/PHASE_1_REPORT.md`: este relatório com explicação e validação.

### Caminho dos dados

```text
ID, nome, data e valores fornecidos pelo chamador
  → construtor ShoppingList
  → trim apenas no nome + conversão das datas para UTC
  → validações de identificação, valores e estado
  → instância imutável válida ou ArgumentError
```

Hoje o chamador é o teste. Nas próximas tarefas será a camada de criação/leitura do repositório. O modelo não acessa o relógio, não gera ID, não salva banco e não exibe mensagens ao usuário. A garantia de unicidade dos IDs virá com a criação/persistência. As exceções permitirão que as camadas superiores tratem entradas inválidas sem declarar sucesso.

### Regras de representação

- ID não vazio, preservado sem transformação; nome obrigatório com espaços externos removidos, sem alterar espaços internos/capitalização.
- Datas `DateTime` são convertidas por `toUtc()`, sem deslocar o instante real.
- Estado padrão ativo; sem data de conclusão, total final ou valor confirmado de caixa.
- Representação finalizada exige data de conclusão e total calculado, mantendo caixa opcional. A conclusão não pode preceder a criação; igualdade é permitida.
- Campos em centavos são `int?`: ausentes permanecem `null`, presentes não podem ser negativos. Nenhuma soma usa `double`.
- Zero de total, orçamento ou caixa é distinto de ausência; preço zero de produto segue sendo Q-001, ainda aberta.
- Orçamento excedido e total calculado diferente do caixa são aceitos sem modificar os números. O modelo não executa a finalização; apenas valida os dados que a representam.

### Conceitos Dart, com comparações a C#

- **Classe de domínio:** representa informação e suas invariantes, sem depender da tecnologia de tela/banco. É semelhante a um objeto de domínio C# que não referencia WPF/Entity Framework.
- **Construtor e parâmetros nomeados:** `required` obriga informar ID, nome e criação na chamada. `this.id` inicializa diretamente o campo; `name = name.trim()` na lista de inicialização prepara o valor antes do corpo de validação.
- **`final`:** um campo não pode ser reatribuído, semelhante a `readonly` em C#. Como todos os campos também têm tipos imutáveis, esta instância é imutável. `final class` impede subtipos externos à biblioteca, preservando o contrato do modelo.
- **`enum`:** `active`/`finalized` tornam estados explícitos, evitando strings digitadas incorretamente no domínio. Mapeamento para SQL virá na tarefa correspondente.
- **`int?` e `DateTime?`:** `?` aceita `null`, parecido com `int?`/referências anuláveis em C#. Não informar caixa não é o mesmo que informar zero.
- **UTC e hora local:** `toUtc()` muda a representação do fuso, preservando o momento; equivale em propósito a converter um instante para UTC com APIs de data do C#. Horário local serve para exibição futura; armazenamento usará UTC.
- **`ArgumentError`:** falha de validação em execução, inclusive release; não depende de `assert`, que pode estar desabilitado.

Não há `Future`, `async/await`, ViewModel de listas ou SQLite novo nesta tarefa; esses conceitos serão introduzidos quando houver operação assíncrona real.

### Testes realmente executados

1. **RED:** `flutter test test/unit/shopping_list_test.dart` antes da implementação: saída 1 por classe/arquivo ausentes. A falha foi de carregamento/compilação, não de 21 asserções executadas.
2. `dart format lib/features/shopping/domain/models/shopping_list.dart test/unit/shopping_list_test.dart`: 2 arquivos formatados.
3. **GREEN:** `flutter test test/unit/shopping_list_test.dart`: **21 aprovados, 0 falhas**.
4. `flutter analyze`: **No issues found!**.
5. `flutter test`: **28 aprovados, 0 falhas**, incluindo os sete testes convencionais da Fase 0.
6. `dart format --output=none --set-exit-if-changed .`: saída 0, **13 arquivos sem alterações**.

O código foi revisto após GREEN; não houve necessidade de novas abstrações/refatorações. Os comandos foram invocados com os executáveis instalados em `C:\Users\Rodolpho\develop\flutter\bin`, pois o PATH global não foi alterado. `git status --short` confirmou que a pasta continua sem `.git`; não há commits nesta entrega.

### Limitações e validação no Android

Esta é uma mudança de domínio ainda não usada pelo app. No Android a tela continua sendo a demonstração de temas; não existe formulário para cadastrar uma lista. CT-001 completo, persistência após reinício e proteção do repositório para listas finalizadas ainda não foram implementados/testados. A imutabilidade do modelo não substitui a futura trava transacional no repositório.

Integração Android, build APK e smoke manual não foram repetidos nesta tarefa porque não houve mudança de interface, plataforma ou dependência e o novo modelo ainda não está ligado ao app. O APK existente é o da Fase 0; não foi substituído nem instalado novamente. Não há migração ou dados existentes alterados.

Para repetir a validação desta tarefa, execute o teste unitário indicado e a suíte completa. A validação manual de criação de listas no dispositivo será possível na F1-04.

### Exercício opcional

Numa cópia do projeto, acrescente um teste criando uma lista com nome contendo acentos e data UTC. Verifique que o nome é preservado, a data continua UTC e o estado inicial é ativo. Execute `flutter test test/unit/shopping_list_test.dart`; não enfraqueça validações nem altere testes existentes para esconder falhas.

**Próxima tarefa indicada na entrega F1-01:** F1-02 — AppDatabase e primeira migração SQLite. Executada abaixo.

## F1-02 — AppDatabase e migração SQLite inicial

**Data:** 09/11/2026. **Status:** feita. Registro da entrega F1-02; F1-03 está descrita na próxima seção principal.

### Problema resolvido e escopo

Preparada a camada que abre um arquivo SQLite, cria a primeira tabela de listas de forma atômica e recusa alterações de versão incompatíveis sem apagar dados. Isso fornece a base para que as futuras ações confirmadas sejam persistidas com segurança.

A versão 1 cria somente `shopping_lists`, com os oito campos de `ShoppingList`, e um índice por estado/data. Não há tabelas de produtos/entradas, repositório, mapper ou cadastro na interface. A conexão normal ainda não é aberta por `main.dart`; testes exercitam a implementação em arquivos próprios. O código da tela de aparência foi preservado.

### Arquivos criados/modificados

- `lib/core/database/app_database.dart`: abertura com factory nativa/injetável, caminho padrão, versão, foreign_keys e recusa de downgrade.
- `lib/core/database/migrations/v1.dart`: criação da tabela, CHECKs e índice.
- `test/database/app_database_test.dart`: 15 testes SQLite FFI reais no Windows, com pastas temporárias isoladas.
- `integration_test/database_smoke_test.dart`: 3 testes no plugin nativo Android.
- `pubspec.yaml` / `pubspec.lock`: sqflite 2.4.5+1, path 1.9.1 e sqflite_common_ffi 2.4.6 para desenvolvimento. sqlite3 3.5.2 é transitivo do FFI.
- README, `docs/TASKS.md`, `docs/TESTING.md`, `docs/DECISIONS.md`, `docs/ARCHITECTURE.md` e este relatório: estado atual, limites, critérios e evidências.

### Caminho dos dados e responsabilidades

```text
Chamador (hoje, teste)
  → await AppDatabase.open()
  → sqflite escolhe/reutiliza a conexão do caminho
  → onConfigure habilita foreign_keys
  → banco novo: cria tabela + índice + versão em transação
  → banco v1: reabre preservando dados
  → banco mais novo: propaga erro, sem reset
  → devolve Database para a futura camada de repositório
```

Factory e caminho são parâmetros para usar o mesmo código com plugin nativo ou SQLite FFI. O padrão usa o diretório de bancos do aplicativo e `market_list.db`. `singleInstance` foi verificado em aberturas concorrentes; não foi necessário criar lock/cache/fila próprios. Fechar a conexão compartilhada afeta todos os seus consumidores, então a camada de dados deverá possuir seu ciclo de vida; widgets não devem abri-la/fechá-la por ação.

### Compatibilidade, integridade e limites

- `NOT NULL` explícito no ID evita a particularidade de SQLite aceitar null em certas chaves primárias textuais; PK garante unicidade.
- CHECKs recusam estados inválidos, campos finais incompatíveis e centavos negativos/fracionários. Caixa/calculado independentes e orçamento excedido continuam permitidos.
- Nomes/data ainda dependem de validação semântica no domínio/futuro mapper. SQL exige nome não vazio após trim SQL e sufixo UTC Z, sem prometer validar todo o calendário/Unicode. Serialização UTC canônica para ordenação será responsabilidade da F1-03.
- Uma tabela-filha apenas de fixture comprova que foreign_keys recusa órfãos; não antecipa produtos na migração.
- Inicialização v1 e índice são atômicos nos callbacks transacionais do [sqflite](https://pub.dev/packages/sqflite). Uma colisão de índice é introduzida depois de uma tabela anterior com dado sentinela. O teste verifica que a tabela nova não fica pela metade, versão continua 0, sentinela permanece e nova tentativa passa após remover exclusivamente o conflito da fixture.
- O teste v2 é banco artificial mais novo, usado para comprovar recusa de downgrade sem apagar dados. **Não existe migração de produto v1→v2 nem banco de usuário anterior a atualizar nesta entrega.** Uma evolução real deverá acrescentar arquivo/onUpgrade/testes; v1 não deve ser reescrita depois de distribuída.
- CHECK de estado não torna linhas finalizadas completamente imutáveis. Essa proteção será implementada no repositório, com gravações condicionadas a estado ativo/transações, e verificada nas tarefas de finalização. Q-005 de exclusão histórica continua aberta; nenhum trigger escolheu essa política.
- Testes fecham conexões, resolvem o destino e verificam raiz/prefixo antes de remover suas pastas. Nenhum banco normal do app foi aberto, apagado ou recriado. Não há SQL em widget.

### Conceitos Dart/Flutter introduzidos

- **`Future<Database>`:** representa uma conexão que ficará disponível depois, parecido com `Task<Database>` em C#. `await` espera a operação assíncrona sem transformar I/O em trabalho síncrono na interface; exceções continuam sendo propagadas.
- **Injeção por construtor:** receber uma `DatabaseFactory` permite trocar o mecanismo nos testes. O código de produção continua com padrão Android/iOS; não há container novo de dependências.
- **Callbacks:** `onConfigure` prepara cada conexão; `onCreate` inicializa um arquivo novo. São funções fornecidas à biblioteca, como delegates/callbacks em C#.
- **Migração e versão:** a versão identifica o esquema do arquivo. Uma nova estrutura deverá ser uma nova migração, preservando dados existentes, em vez de apagar e recriar o banco.
- **Transação:** tabela/índice/versão são confirmados juntos ou revertidos na falha. Não se adicionou transação aninhada ao callback que a biblioteca já executa atomicamente.
- **Chave estrangeira e índice:** a primeira impede vínculo com registro inexistente; o segundo acelera consultas por estado/data. A regra de nomes de tabelas fica na camada de dados.
- **Parâmetros de consulta:** testes inserem nomes com aspas usando mapas/whereArgs, preservando o texto como dado. O repositório futuro deverá manter essa separação entre SQL e entradas do usuário.

### Execuções reais

1. `flutter pub add sqflite path` e `flutter pub add --dev sqflite_common_ffi`: sucesso.
2. RED `flutter test test/database/app_database_test.dart`: saída 1 porque AppDatabase ainda não existia (falha de compilação/carregamento).
3. GREEN do mesmo comando: **15 aprovados, 0 falhas**.
4. `dart format lib/core/database test/database` e `dart format .`: executados; 17 arquivos Dart no projeto.
5. `flutter analyze`: inicialmente 1 informação de lint no construtor. Ajustado para parâmetro inicializador; execução seguinte: **No issues found!**.
6. `flutter test`: duas execuções com **43 aprovados/0 falhas**, incluindo toda a regressão convencional.
7. `flutter test integration_test -d RXCY300NZZH`: primeira tentativa aprovou 3 testes de banco, mas aparência/tearDownAll ficaram incompletos e o comando saiu com 1. Causa não comprovada.
8. `flutter test integration_test --concurrency=1 -d RXCY300NZZH`: **4 aprovados/0 falhas**, saída 0. A opção foi ignorada pelo Flutter, que já define concorrência 1 para integração. A hipótese inicial de paralelismo foi descartada após ler a implementação da ferramenta; não se afirma que a opção corrigiu a interrupção.
9. `flutter build apk --debug`: **sucesso**, compilação do app normal em 15,9 s depois da integração.
10. `adb -s RXCY300NZZH install -r build/app/outputs/flutter-apk/marketlist-f1-02-debug.apk`: **Success**. `adb ... shell am start -W -n br.com.rodolpho.marketlist/.MainActivity`: **Status: ok**. A restauração manual usou substituição sem desinstalar; ver a correção F1-03 sobre uninstall automático do runner de integração, não identificado nesta etapa.
11. A primeira verificação final de format dentro do sandbox não respondeu e foi interrompida. Fora do sandbox, detectou necessidade de reformatar um teste após simplificar seu título. Após aplicar `dart format test/database/app_database_test.dart`, a verificação `dart format --output=none --set-exit-if-changed .` retornou **0: 17 arquivos sem alterações**.

Ambiente nativo: Samsung SM-S936B, Android 17/API 37, com Flutter 3.47.9/Dart 3.13.7 e SDK Android/JDK já preparados. O doctor não foi repetido; as advertências anteriores não são declaradas resolvidas. Os erros de índice/downgrade vistos nos logs foram provocados e capturados nos testes de preservação.

### Artefato e validação no Android

APK normal: `build/app/outputs/flutter-apk/marketlist-f1-02-debug.apk`, também no caminho padrão `app-debug.apk`. Variante debug, assinatura de desenvolvimento, **193.741.371 bytes**. SHA-256: `7c8c0971746ae1efabde97bfd159a8da6b9687ccc1b87f08be92e2baba35bf5f`. O artefato histórico identificado da Fase 0 foi preservado. Nenhum APK/banco é versionado.

Para repetir os testes de banco no aparelho, use `flutter devices` e `flutter test integration_test/database_smoke_test.dart -d ID_ANDROID`; depois gere/instale o APK normal para substituir a variante de teste. A interface continua em Aparência; não existe ainda fluxo manual de criar lista. Reabertura do **arquivo** foi testada, sem alegar reinício completo do processo ou jornada offline E2E. Sem build/teste iOS ou release.

### Exercício opcional e próximo passo

Numa cópia do projeto, acrescente um teste tentando repetir um ID e confira que a primeira linha permanece após a recusa da segunda. Use somente as fixtures temporárias; não altere a migração v1 para contornar uma falha de teste.

Próxima tarefa indicada na entrega F1-02: **F1-03 — repositório para criar/listar/remover listas ativas**, executada abaixo. A F1-02 permaneceu local sem novo commit/envio nesta entrega.

## F1-03 — Repositório de listas ativas

**Data:** 09/11/2026. **Status:** feita. Registro da entrega F1-03; a conclusão F1-04/F1-05 aparece nas seções seguintes.

### Problema resolvido

O aplicativo agora tem uma camada de dados capaz de criar, recuperar e remover listas ativas com confirmação de gravação. Repetir uma inclusão com a mesma identidade não duplica; tentar reaproveitar essa identidade com outros dados não sobrescreve; uma lista finalizada não pode ser removida ou reaberta pelas operações disponíveis. A tela ainda não foi conectada a essa camada.

### Arquivos alterados

- `lib/features/shopping/domain/shopping_repository.dart`: interface pura e exceções específicas.
- `lib/features/shopping/data/sqlite_shopping_repository.dart`: implementação transacional, UUID, mapeamento e validação temporal.
- `test/database/shopping_repository_test.dart`: 26 testes com SQLite real em arquivos temporários.
- `integration_test/database_smoke_test.dart`: três casos de repositório adicionados aos três de banco existentes, reaproveitando as fixtures isoladas.
- `pubspec.yaml`/`pubspec.lock`: uuid 4.6.0 para gerar IDs, com fixnum transitivo; sem gerador próprio.
- README e documentos de arquitetura, decisões, testes, tarefas e este relatório: progresso, comandos com `--no-uninstall`, resultados e limites reais.

`main.dart`, tela, modelo e migração v1 foram preservados. Não houve alteração de esquema nem conversão/reescrita de dados antigos. Alterações desta tarefa e da F1-02 continuam locais, sem novo commit/envio ao GitHub.

### Caminho dos dados

```text
Chamador gera ID uma vez e fornece nome/orçamento
  → repositório valida construindo ShoppingList
  → AppDatabase fornece a conexão
  → transação lê identidade/estado e insere ou remove com parâmetros
  → SQLite confirma commit
  → Future retorna o modelo/resultado confirmado

Consulta de ativas
  → SQLite filtra status
  → mapeamento valida linhas e materializa modelos
  → ordenação por instante real + desempate por ID
  → coleção imutável
```

Hoje o chamador é o teste. Na F1-04 será o ViewModel; ele deverá manter o ID da inclusão pendente, bloquear toque repetido, preservar inputs em falha e só atualizar a tela após o Future concluir. A confirmação de excluir lista inteira também ficará na interface, conforme DESIGN; o repositório não abre diálogos.

### Decisões de implementação e proteção

- `ShoppingRepository` é contrato Dart puro, semelhante a uma interface C#. `SqliteShoppingRepository` implementa esse contrato, sem SQL nos widgets. Não se criou repositório-base, serviço genérico de ID nem mapper abstrato.
- `newListId()` usa [UUID v4](https://pub.dev/packages/uuid). O chamador gera uma vez e passa `id` em cada tentativa. ID ativo já salvo com os mesmos dados devolve o original; com nome/orçamento diferentes gera conflito; ID finalizado gera erro específico. Nomes iguais com IDs distintos são permitidos.
- Identidade de operação é diferente de nome. Gerar outro ID em cada retry poderia duplicar; essa disciplina será aplicada no ViewModel. Não se criou log de operações/tombstone: depois de remover uma lista, não se deve reutilizar seu ID. A regra de nomes de produtos Q-003 continua aberta.
- Relógio injetável permite testar datas sem depender do instante da máquina. O padrão é `DateTime.now`; o modelo converte para UTC. Escrita canônica usa seis casas de fração, enquanto leitura preserva formatos v1 válidos de segundos/frações até microssegundos.
- [DateTime.parse aceita overflow](https://api.dart.dev/dart-core/DateTime/parse.html), então o mapper compara a representação normalizada para recusar, por exemplo, 30/02, em vez de transformar silenciosamente a data. Frações acima de seis casas também falham, sem truncar informação.
- Listas são ordenadas mais recentes primeiro pelo DateTime real, desempate por ID. Ordenar strings `.000Z`/`.000001Z` produziria ordem errada; a opção atual mantém compatibilidade sem regravar o banco. Regras de ordenação de **itens** não foram alteradas.
- Criação e remoção usam transações e apenas o executor `txn`. A remoção exige `status = 'active'` no DELETE e confere linhas afetadas. Finalizada produz erro específico, ausente retorna false; duas remoções concorrentes confirmam uma exclusão.
- Falhas SQL não viram sucesso. Trigger de falha e FK impeditiva nas fixtures comprovam preservação dos dados; não há cascata inventada para tabelas de produtos ainda inexistentes. A política das dependências será definida quando essas tabelas forem implementadas.
- Os erros `FinalizedShoppingListException` e `ShoppingListCreationConflict` permitem tratamento futuro sem procurar palavras em mensagens. Dados inválidos ao ler produzem erro, sem descartar linhas, apagar arquivos ou reparar silenciosamente.

### TDD e resultados reais

1. `flutter pub add uuid`: sucesso (4.6.0).
2. RED `flutter test test/database/shopping_repository_test.dart`: saída 1 porque contrato/implementação não existiam. Falha de carregamento, sem asserções executadas.
3. GREEN inicial do mesmo comando: **24 aprovados, 0 falhas**.
4. `dart format lib/features/shopping test/database/shopping_repository_test.dart` e `dart format .`: executados. Foram incluídos depois dois casos de compatibilidade temporal; o projeto contém 20 arquivos Dart.
5. `flutter analyze`: duas execuções, ambas **No issues found!**.
6. `flutter test`: inicialmente **67 aprovados**; após os dois testes adicionais, **69 aprovados/0 falhas** (26 repositório + 15 banco + 21 modelo + 3 tema + 4 widget).
7. `flutter test integration_test/app_smoke_test.dart -d RXCY300NZZH`: primeira tentativa saiu com 79, teste/tearDownAll incompletos. O segundo comando da sequência não iniciou. Checagem encontrou aparelho conectado, acordado e desbloqueado, sem causa comprovada para a interrupção.
8. `flutter test integration_test/database_smoke_test.dart -d RXCY300NZZH`: **6 aprovados** (3 banco + 3 repositório).
9. `flutter test integration_test/app_smoke_test.dart -d RXCY300NZZH --verbose`, com saída em `build/f1-03-app-integration.log`: **1 aprovado**, saída 0. Não houve alteração no teste nem em suas expectativas.
10. `flutter test integration_test/database_smoke_test.dart --no-uninstall -d RXCY300NZZH`: **6 aprovados**, e `adb ... shell pm path br.com.rodolpho.marketlist` confirmou o pacote instalado ao final.
11. `flutter build apk --debug`: sucesso, 12,0 s. APK normal instalado com `adb install -r` (**Success**) e aberto com `am start -W` (**Status: ok**).
12. `dart format --output=none --set-exit-if-changed .`: saída 0, **20 arquivos sem alterações**. Conferência de diff rastreado sem erros de whitespace; AGENTS.md, APK e log detalhado continuam ignorados pelo Git.

Resultado nativo de casos distintos: **7 aprovados** (persistência 6 + aparência 1). A interrupção intermitente da aparência não recebeu causa/correção comprovadas. Os erros esperados de índice/downgrade/storage/FK são provocados e capturados nos respectivos testes; os dados dos testes são temporários e isolados.

### Correção do procedimento de integração

O log detalhado mostrou que o runner Flutter 3.47.9 desinstala o pacote por padrão no encerramento. A leitura de `commands/test.dart` e `test/integration_test_device.dart` do SDK confirmou a opção `--no-uninstall`. O comando foi testado com seis casos aprovados e verificação de que o app continuava instalado.

**Correção retrospectiva:** usar `install -r` para restaurar o APK normal não provava ausência de uninstall anterior pelo runner. A afirmação ampla da entrega F1-02 foi corrigida neste relatório. A interface ainda não gravava listas/banco normal nesta fase, mas os próximos testes precisam usar `--no-uninstall` para preservar o armazenamento do pacote. Fixtures continuam separadas e sua limpeza verifica raiz/prefixo antes de excluir somente as pastas criadas para o teste. Nenhum comando de limpeza do banco normal foi implementado.

### Artefato, validação manual e limites

APK normal em `build/app/outputs/flutter-apk/marketlist-f1-03-debug.apk`, também no caminho padrão `app-debug.apk`; **193.741.371 bytes**, variante debug. SHA-256: `f754227e20a8219b4990ecf0ea0f3a196a7b1dc8094ef4f071a9a4f7d85a84db`. Artefatos identificados anteriores foram preservados. O app normal foi restaurado no Samsung SM-S936B, Android 17/API 37.

Para repetir a validação de persistência no Android: `flutter test integration_test/database_smoke_test.dart --no-uninstall -d ID_ANDROID`. Depois gere/instale o APK normal para substituir a variante de teste. A tela continua em Aparência; cadastro manual e diálogo de remoção só estarão disponíveis na F1-04.

CT-001/002 estão cobertos na camada de repositório. CT-003 cobre reabertura de arquivo/nova instância, sem alegar reinício completo ou modo avião; F1-05 permanece pendente. CT-046 cobre as operações hoje disponíveis, não métodos futuros de preços/edição/finalização. Sem migração nova, histórico de consulta, build iOS ou release. O doctor não foi repetido; avisos anteriores não foram declarados resolvidos.

### Exercício opcional e próximo passo

Numa cópia do projeto, acrescente um teste criando duas listas com mesmo nome e IDs diferentes. Depois repita uma criação com o primeiro ID e confirme que seguem existindo duas listas. Use somente as fixtures de teste e não enfraqueça expectativas para esconder falhas.

Próxima tarefa pequena: **F1-04 — tela Minhas listas e formulário de criação**.

## F1-04 — Tela Minhas listas e criação

**Status:** feita em 09/11/2026. Executada antes da F1-05. O usuário pediu concluir a fase e depois fazer commit/envio ao GitHub.

### Entrega e arquivos

- `lib/app/app.dart`: composição do repositório real e ViewModels via Provider; nova home Minhas listas; injeção explícita nos testes.
- `lib/features/shopping/presentation/view_models/shopping_lists_view_model.dart`: carga, cache confirmado, rascunho, erros, ID estável e exclusão.
- `lib/features/shopping/presentation/screens/shopping_lists_screen.dart`: home, lista/status/data/orçamento, retry, navegação de aparência e diálogo de exclusão.
- `lib/features/shopping/presentation/widgets/create_list_sheet.dart`: nome/orçamento, controladores de texto e rodapé fixo acima do teclado.
- `lib/features/shopping/presentation/list_budget_input.dart`: conversão/exibição específica de orçamento em centavos, sem Flutter/double.
- Modelo `ShoppingList` e repositório: comparador temporal compartilhado, sem duplicar a ordem já adotada.
- Novos testes: `test/unit/list_budget_input_test.dart`, `test/unit/shopping_lists_view_model_test.dart`, `test/widget/shopping_lists_screen_test.dart`, suporte falso em `test/support/fake_shopping_repository.dart`.
- `test/widget/app_test.dart` e `integration_test/app_smoke_test.dart`: regressão de temas navega pela nova home; integração usa SQLite temporário isolado e inclui criação/remoção/falha real.
- README e docs de decisões/arquitetura/tarefas/testes/relatório: progresso e explicação atualizados. SPEC teve apenas rodapé de progresso corrigido; nenhuma regra de negócio foi modificada.

### Benefício e caminho dos dados

Já é possível montar e consultar listas pelo aplicativo, sem conta/rede. O formulário aceita nome e orçamento opcional; o item aparece somente quando SQLite confirma. Falha mantém texto/identidade para retry. Exclusão exige confirmação com nome e não retira a linha antes da gravação.

```text
Toque em Nova lista → painel/controladores → rascunho no ViewModel
  → nome/orçamento validados → repositório com mesmo ID nas tentativas
  → transação SQLite → retorno confirmado
  → cache imutável atualizado → painel fecha e UI informa sucesso
```

Carga com erro apresenta retry, sem inventar lista vazia. Durante operação, ações concorrentes são bloqueadas. Cancelar/voltar descarta o rascunho somente quando não há gravação pendente. O orçamento aceita `250`, `250,0` ou `250,00`, sem separadores de milhar. O limite verificado é a capacidade técnica do int nativo; a política de limites/preço zero de produtos continua para F3. Tema continua temporário, seguindo sistema ao iniciar; não se resolveu Q-006.

### Conceitos Dart/Flutter

- `ChangeNotifier`/Provider ligam estado à UI, semelhante ao propósito de `INotifyPropertyChanged`/injeção em C#, com reconstrução de widgets no Flutter.
- `Future`/`async`/`await` coordenam persistência como `Task` em C#. Não se declara sucesso quando a operação apenas começou.
- `StatelessWidget` apresenta a home a partir do ViewModel. `StatefulWidget` no painel possui `TextEditingController`; initState cria os controladores e dispose os libera, sem guardar regras de banco no widget.
- `mounted`/guard de dispose impedem atualizar navegação/notificações de telas já removidas. O ViewModel não cancela uma transação confirmada só porque o widget desapareceu.
- `PopScope` e botões desabilitados protegem a gravação pendente. `Flexible`/`SingleChildScrollView` mantêm campos roláveis e footer fora da rolagem; viewInsets desconta o teclado.
- Conversão textual para centavos evita ponto flutuante e multiplicação com overflow. Campo vazio permanece null; zero é explícito.
- A UI só conhece o contrato do repositório; o fake existe exclusivamente nos testes. Produção não retorna dados fictícios quando o banco falha.

### Testes e correções reais

RED unitário (implementações ausentes) seguido de **23 testes aprovados** (10 orçamento + 13 ViewModel). RED widget (injeção ainda ausente) seguido inicialmente de 10 aprovados/1 falha por seletor de Voltar em inglês. Corrigido para o controle pt-BR, preservando expectativas. Os 15 testes de widget (11 novos + 4 temas) passaram. Dois casos extras de toque duplo foram adicionados com coordenadas obtidas dos controles; confirmaram a proteção existente da barreira do modal, sem exigir refatoração artificial.

Uma formatação parou por import posicionado após declarações no teste Android; foi corrigido antes de analisar. `flutter analyze` passou nas duas execuções. `flutter test` passou inicialmente com **103** e, após os dois testes extras, com **105/0 falhas**. Projeto com 28 arquivos Dart.

Primeira integração Android ficou incompleta (saída 79). Diagnóstico sem DDS falhou com stream golden inválido do SDK; opção descartada. Com DDS normal, `flutter test integration_test/app_smoke_test.dart --no-uninstall -d RXCY300NZZH --verbose` passou **3 casos**: aparência, criação/exclusão confirmada e falha SQL real que preserva campos/retry. Log em `build/f1-04-ui-dds.log`. Em seguida, `flutter test integration_test/database_smoke_test.dart --no-uninstall -d RXCY300NZZH` passou **6 casos**. Total: **9 nativos aprovados**, sem relaxar asserções. Causa da interrupção intermitente do runner permanece sem confirmação.

`flutter build apk --debug` compilou o app normal em 13,5 s; `adb install -r` retornou Success e `am start -W` Status: ok. Todos os testes de integração atuais usam bancos próprios e `--no-uninstall`.

## F1-05 — Reinício real em modo avião

**Status:** feita em 09/11/2026, após a F1-04. Roteiro em `tool/verify_android_offline.py`, com Python padrão/ADB, sem adicionar dependência ao runtime do aplicativo.

### Procedimento e evidência

O modo `--inspect` somente lê a árvore de acessibilidade do MarketList e captura a tela; `--run` é necessário para alterar rede/tela e executar o teste. Primeira inspeção encontrou aparelho bloqueado e não mudou dados/rede. O usuário desbloqueou e deixou o app aberto; nova inspeção confirmou os controles. O roteiro foi compilado com `python -m py_compile` e a execução de rede foi explicitamente aprovada.

Comando executado: `python tool/verify_android_offline.py --adb C:\Users\Rodolpho\AppData\Local\Android\Sdk\platform-tools\adb.exe --serial RXCY300NZZH --run`.

O roteiro capturou modo avião 0, Wi-Fi 1 e stay-on 0; manteve tela acesa via USB; ativou modo avião/desligou Wi-Fi; exigiu **nenhuma rede padrão** antes de criar a própria lista com orçamento **R$ 123,45**. Após confirmar e visualizar a lista, executou `am force-stop`, abriu o app normal e comprovou PID **11518→15073**. Nome e orçamento reapareceram sem rede, vindos do banco após novo processo.

Resultado real: **saída 0**, `offline_confirmed=true`, `persisted_after_restart=true`, `cleanup_ok=true`, `network_settings_restored=true`, `screen_setting_restored=true`. Apenas a lista com nome único do roteiro foi removida pelo diálogo. A rotina finally restaurou modo avião 0, Wi-Fi 1 e stay-on 0. Nova checagem confirmou rede padrão reconectada. Não houve reset, exclusão de arquivo de banco ou uninstall.

Evidência local ignorada pelo Git: `build/offline_verification/result.json`, `form_keyboard.png`, `after_restart_offline.png`. Capturas inspecionadas: botão Criar lista acessível acima do IME real, tema AMOLED legível e dados recuperados em nova execução. A inspeção não é auditoria completa de contraste/TalkBack. O roteiro filtra controles pelo pacote e usa limites lidos da árvore, sem coordenadas fixas; não manipula registros de outras listas.

### Entrega final da Fase 1 e validação manual

APK normal final: `build/app/outputs/flutter-apk/marketlist-phase-1-debug.apk`, também em `app-debug.apk`. Variante debug, assinatura de desenvolvimento, **193.741.371 bytes**. SHA-256: `1955b5ae972fb0629c76ac2d575cc2ff8a7839f862a5aaf42126f8b001e5fb3a`. É a mesma compilação normal da F1-04, cujo código Dart não mudou durante o roteiro F1-05; as cópias identificadas anteriores foram preservadas.

Para usar: Nova lista → nome e orçamento opcional → Criar lista → conferir nome/estado/data/orçamento. Tente Cancelar no diálogo de exclusão e confirme depois, se desejar apagar. Para repetir offline, mantenha o celular disponível/desbloqueado e use o roteiro com conhecimento de que a conexão é interrompida temporariamente. O roteiro restaura as configurações e remove somente seu dado de teste; evidências ficam em build.

**Resultado final:** 105 testes convencionais + 9 nativos + 1 roteiro E2E offline aprovados, análise sem problemas e APK instalado. Fase 1 concluída no escopo de listas. Ainda não há produtos, entradas/preços, saldo de compra, finalização ou histórico. Sem iOS/release; avisos anteriores do doctor não foram reavaliados; preferência de tema continua em memória. SDK/runner teve interrupções, documentadas, sem causa original comprovada.

Verificação final de formatação: `dart format --output=none --set-exit-if-changed .`, saída 0, **28 arquivos sem alterações**. Compilação Python do roteiro também passou. O estado remoto foi consultado antes de preparar o commit, sem divergência de origem.

**Exercício opcional:** numa branch de treino ou cópia, altere o exemplo do nome no formulário e rode `flutter test test/widget`. Não mude regras de persistência/valores nem expectativas para esconder bugs.

**Próximo passo:** F2-01, somente após autorização para iniciar a Fase 2. Usuário autorizou commit/envio desta Fase 1; bancos, APKs, logs/capturas e AGENTS.md permanecem fora do versionamento.
