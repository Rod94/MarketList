# Fase 2 — Relatório incremental

## F2-01 — Modelo de item e quantidade planejada opcional

**Data:** 10/11/2026. **Status:** concluída. F2-02 em diante permanecem pendentes. Escopo autorizado: uma tarefa pequena, com commit e envio ao GitHub ao concluir, seguindo orientação do usuário.

### Problema e benefício

Planejar `Carne` sem saber a quantidade é diferente de planejar uma unidade. O novo modelo preserva essa diferença desde o domínio, evitando que as próximas etapas inventem uma quantidade e depois apresentem uma compra como completa sem evidência. Nesta entrega ainda não é possível cadastrar produtos na interface.

### Arquivos e responsabilidades

- `lib/features/shopping/domain/models/shopping_item.dart`: modelo imutável, enum de origem e validações. Contém exatamente os campos previstos na arquitetura, sem dependências externas.
- `test/unit/shopping_item_test.dart`: 24 cenários do modelo, incluindo null versus 1, validações e representação dos campos.
- `docs/TASKS.md`: F2-01 feita, demais tarefas pendentes e política de commit/envio por tarefa registrada.
- `docs/TESTING.md`: seção 18 com comandos, RED/GREEN, regressão e limitações reais.
- `docs/DECISIONS.md`: justificativas de representação, limites do escopo e questões ainda abertas.
- `docs/ARCHITECTURE.md`: seção 19 distingue modelo existente das futuras camadas de itens.
- `README.md`: progresso e estrutura atuais, preservando a identificação do último APK visual.
- `docs/PHASE_2_REPORT.md`: este relatório didático incremental.

### Caminho dos dados

Nesta tarefa: **chamador/teste → construtor ShoppingItem → validação → instância imutável ou ArgumentError**. Não há persistência nem ligação com widgets/ViewModel ainda. Futuramente, o repositório deverá verificar a lista ativa e salvar o modelo em transação; um identificador de lista não vazio sozinho não comprova que ela exista ou aceite alterações.

Nome obrigatório é normalizado apenas nas bordas. `plannedQuantity` aceita null ou inteiro positivo; não é preenchida automaticamente. Identidade, vínculo, origem e posição são explícitos. Posição não negativa começando em zero é uma convenção técnica documentada. `removedAt` aceita ausência ou instante normalizado em UTC; não executa remoção. Não há preço, subtotal, status de compra ou política de desfazer.

### Conceitos Dart e comparação com C#

- `int?` é um inteiro anulável, semelhante a `int?` em C#. Null significa informação ausente; não é zero nem uma unidade. Em futuras edições, retirar a quantidade deve voltar a null sem usar `?? 1`.
- `required` exige um argumento nomeado na chamada. É diferente de aceitar uma string vazia: por isso o construtor também valida IDs e nome em execução.
- `final class` impede herdar/implementar a classe fora de sua biblioteca. Campos `final` recebem valor uma vez, como um campo readonly em C#. Como todos os valores deste modelo também são imutáveis, a instância fica imutável.
- `enum ShoppingItemOrigin` restringe a origem a valores conhecidos, como enum em C#, sem strings livres espalhadas pelo domínio. O modelo não escolhe a origem automaticamente.
- A lista de inicialização do construtor prepara nome e data antes do corpo. `removedAt?.toUtc()` chama a conversão somente se houver data, como o acesso condicional `?.` em C#; o instante é preservado.
- `ArgumentError` sinaliza entrada inválida em execução, semelhante ao propósito de ArgumentException. Não usamos assert para regras que precisam continuar funcionando em release.
- Testes de domínio constroem objetos diretamente, sem iniciar tela, SQLite ou celular. O projeto usa flutter_test como runner existente, mas o arquivo de produção não importa Flutter.

### Testes e resultados reais

RED: teste novo saiu 1 porque o arquivo/tipos ainda não existiam; nenhuma asserção rodou. A primeira tentativa restrita ficou sem saída e foi interrompida; a repetição com acesso ao SDK executou de fato. GREEN: após implementar, **24 testes aprovados**, sem alterar resultados esperados.

`dart format` nos dois arquivos ajustou apenas o teste. Verificação completa `dart format --output=none --set-exit-if-changed .`: **30 arquivos sem alterações, saída 0**. `flutter analyze`: **nenhum problema**, saída 0. `flutter test --reporter expanded`: **129 aprovados, zero falhas**, saída 0 (105 anteriores + 24 novos).

Casos novos: ausência/uma/cinco unidades, quantidade zero/negativa, IDs/vínculos/nomes vazios e espaços, nomes livres/iguais, origem planejada/mercado, posição e data de remoção com dados preservados. CT-006/UX-002 estão cobertos somente na semântica do modelo; não se alega fluxo completo.

### Android, compatibilidade e pendências

Nenhuma mudança visual está disponível nesta tarefa. O usuário pode continuar usando o APK normal da Fase 1; não existe botão novo de produto ainda. Para verificar a nova regra agora, execute `flutter test test/unit/shopping_item_test.dart` na raiz.

Integração Android, build de APK, roteiro offline e iOS não foram repetidos: o novo domínio ainda não é usado pelo app e nenhuma camada nativa, UI ou persistência mudou. Resultados físicos anteriores continuam históricos. Esquema v1, dados existentes e dependências permaneceram intactos. A migração para itens e proteção transacional de listas finalizadas serão necessárias na F2-02, sem limpar/recriar bancos existentes.

Q-001 a Q-007 permanecem abertas nos seus momentos previstos. Não há decisão nova de negócio, nomes únicos obrigatórios, preço/compra ou política de desfazer. F2-04/05 não foram implementadas pela simples presença de campos de posição/remoção.

### Exercício opcional

Numa branch de treino ou cópia, escreva um teste criando `Ovos` com quantidade 12 e outro sem quantidade. Confira que os valores são 12 e null. Rode apenas o teste do modelo; não é necessário alterar o aplicativo nem seus dados.

**Próxima tarefa pequena sugerida:** F2-02 — persistência de itens com migração incremental e testes de integridade. Não iniciada nesta entrega.

## F2-02 — Persistência de itens

**Data:** 10/11/2026. **Status:** concluída no backend. F2-03/04/05 permanecem pendentes. Relato F2-01 acima é histórico; esta seção descreve o avanço posterior.

### Problema resolvido e escopo

O aplicativo ganhou a base para guardar nomes/quantidades de produtos sem rede e recuperá-los depois. A UI ainda é a de listas; o cadastro visual será conectado na F2-03. Quantidade ausente continua null em todo o percurso, inclusive ao retirar um planejamento existente. Renomear não troca identidade, vínculo, origem ou posição.

### Arquivos alterados

- `lib/core/database/migrations/v2.dart`: tabela de itens, restrições, FK/cascade e índice único de posição por lista.
- `lib/core/database/app_database.dart`: versão 2 e aplicação incremental de v1/v2, dentro das transações do sqflite. A migração v1 publicada não foi alterada.
- `lib/features/shopping/domain/shopping_repository.dart`: contrato de criar/ler/editar/remover item, gerar ID e erros específicos de ausência/conflito/remoção.
- `lib/features/shopping/data/sqlite_shopping_repository.dart`: implementação transacional, mapeamento privado, ID estável e recusa de alteração em finalizadas.
- `test/database/items_migration_test.dart`: 6 testes de preservação/compatibilidade/esquema/restrições.
- `test/database/shopping_items_repository_test.dart`: 25 testes de CRUD, falhas, concorrência, reabertura e invariantes.
- `test/database/app_database_test.dart`: regressão adaptada à versão corrente e fixture de versão futura, mantendo a finalidade das asserções.
- `integration_test/database_smoke_test.dart`: regressão e quatro novos cenários SQLite nativos.
- `test/support/fake_shopping_repository.dart`: operações de itens explicitamente não suportadas no fake exclusivo de listas.
- README, TASKS, TESTING, ARCHITECTURE, DECISIONS e este relatório: progresso, contratos, decisões técnicas, comandos e limites reais.

### Caminho dos dados e escolhas técnicas

**Chamador/teste → ShoppingRepository → modelo valida → transação SQLite verifica lista ativa → grava → commit → resultado confirmado.** A futura tela/ViewModel vai usar esse contrato, sem SQL em widgets. Cada tentativa da mesma inclusão mantém o ID; mesmo ID/dados retorna o registro já salvo, enquanto conteúdo/vínculo diferente gera conflito, sem upsert/replace. Um novo item legítimo usa outro ID, mesmo se o nome se repetir.

`updateItem` exige `plannedQuantity` na chamada, mas aceita null para limpá-la. Somente nome/quantidade são alterados. Se lista estiver finalizada, mesmo um retry ou remoção de item ausente é recusado antes de gravar. Ausência de lista não é tratada como coleção vazia. Erros SQL propagam; ninguém recebe sucesso antes do commit.

Posição é MAX+1 por lista dentro da transação, incluindo removidos; índice único e verificação de int64 protegem colisão/overflow. Isso é base de armazenamento, sem implementar comportamento visual de ordem F2-04. Remoção marca a data UTC, preservando os demais campos; repetição retorna false sem regravar o instante. A leitura devolve todos os registros, inclusive removidos, em coleção imutável. F2-05 ligará essa marca à ocultação no conjunto visível; cálculo de preços/totais continua para fases posteriores. Não há método Desfazer nem decisão sobre prazo.

### Migração, dados existentes e compatibilidade

V2 acrescenta somente `shopping_items` e seu índice; não reescreve listas nem força igualdade de caixa/calculado. Instalação nova executa v1 e v2; upgrade da v1 executa apenas v2. Transação do callback sqflite inclui DDL e versão. O teste provoca colisão do nome do índice após a tabela criar: a abertura falha, a versão continua 1, listas sobrevivem e uma nova tentativa após corrigir **somente a fixture** funciona. Não se introduziu reparo destrutivo em produção.

FK impede item órfão. Ao excluir uma lista ativa inteira pelo fluxo existente confirmado, cascade apaga os itens ligados a ela. Se outra dependência impede a exclusão, a transação reverte inclusive o cascade. Finalizadas continuam protegidas pelo repositório; exclusão histórica Q-005 permanece aberta. Abrir v2 torna o arquivo incompatível com APK antigo limitado à v1; o downgrade é recusado, sem apagar dados. Não reinstalar APK antigo como estratégia de recuperação.

### Conceitos Dart/Flutter/SQLite

- `Future<ShoppingItem>` representa o resultado futuro, semelhante a Task<ShoppingItem> em C#. `await` da transação entrega o objeto só quando o banco confirma.
- `abstract interface class` mantém o contrato independente do SQLite. A implementação encapsula SQL; o fake continua restrito aos testes de listas.
- `required int?` combina argumento obrigatório com valor opcional: o chamador precisa decidir se envia uma quantidade ou null. Evita confundir “limpar” com “não alterar”.
- Queries com `?`/whereArgs tratam nomes com aspas como dados, sem montar SQL com conteúdo do usuário.
- Transação é uma unidade atômica: estado da lista e escrita do item ficam juntos, impedindo que uma operação que esperou a finalização edite a compra depois.
- FK e CHECK protegem relações/tipos no banco; validação Dart explica o domínio. Os dois níveis se complementam. UNIQUE protege posição por lista, sem proibir nomes iguais.
- Remoção lógica preserva o registro com uma data. Não confunde dado removido com produto não comprado e permite evoluir a UX sem já decidir Desfazer.

### Testes executados e limitações

RED de repositório saiu 1 porque contrato/métodos/tipos ainda faltavam; nenhuma asserção rodou. Após implementar, **31 testes novos passaram**: 25 repositório e 6 migração. `flutter analyze` não encontrou problemas (13,8 s). `flutter test --reporter expanded` passou com **160/0 falhas**, mantendo os 129 anteriores. Ajustes de versão em testes refletem a migração declarada; dados esperados e invariantes não foram relaxados.

No Samsung conectado, `flutter test integration_test/database_smoke_test.dart --no-uninstall -d RXCY300NZZH --verbose` passou com **10 testes**, incluindo 4 novos da v2. Todos usam bancos temporários próprios; nenhum teste inspeciona ou limpa listas reais. Logs ficam no build ignorado.

Regressão nativa da UI: `flutter test integration_test/app_smoke_test.dart --no-uninstall -d RXCY300NZZH --verbose` inicialmente saiu **79**, testes incompletos e erro secundário de limpeza de temporário. Inspeção ADB mostrou tela Awake/desbloqueada e nenhum crash no trecho AndroidRuntime consultado, sem comprovar causa. Repetir o mesmo comando, sem alterar código/flags/expectativas, passou com **3 testes**. Resultado final: **13 casos nativos distintos aprovados** (10 banco + 3 UI). Interrupção do executor continua como limitação real documentada, não bug de produto declarado corrigido.

`flutter build apk --debug` passou em **15,0 s**, gerando a versão normal; cópia em `build/app/outputs/flutter-apk/marketlist-f2-02-debug.apk`, **193.741.371 bytes**, SHA-256 `7ac45a8515255c176bd16f8229ac8c80bc5529126d8b3a07f07aae5e84f19fc2`. Instalação `adb install -r`: **Success**; abertura `am start -W`: **Status: ok / COLD**. Cópias identificadas anteriores foram mantidas.

Inspeção somente de leitura `python tool/verify_android_offline.py --adb C:\Users\Rodolpho\AppData\Local\Android\Sdk\platform-tools\adb.exe --serial RXCY300NZZH --inspect` retornou 0; árvore do APK normal mostrou Minhas listas/Nova lista/Aparência, sem erro de carregamento. Não mudou rede/listas nem equivale a repetir o roteiro offline da Fase 1. Verificação final de formatação: **33 arquivos sem alterações, saída 0**. Não foram executados build iOS/release, auditoria de acessibilidade completa ou teste de rede desligada nesta tarefa.

Sem alterações em SPEC/DESIGN nem decisões de preço, duplicatas por sugestão, tema, exclusão histórica ou Desfazer. Q-001 a Q-007 continuam abertas. CT-021 ainda depende de entradas F3 para verificar que compras antigas permanecem ligadas ao renomear. UI de produto, filtros/visibilidade e total não foram antecipados.

### Como validar e praticar

Hoje não há controle novo no Android para cadastrar produtos. A validação desta tarefa acontece pelos testes do repositório/migração e integração nativa. Para repetir no computador: `flutter test test/database/items_migration_test.dart test/database/shopping_items_repository_test.dart`. Em Android disponível, use o comando de integração acima com --no-uninstall; depois restaure o APK normal compatível com v2.

Exercício opcional em branch de treino: acrescente um cenário criando um produto com quantidade 12, edite para null e feche/reabra o banco temporário. Confira que null permanece, sem alterar dados normais nem resultados esperados dos testes existentes.

**Próxima tarefa pequena sugerida:** F2-03 — ligação da UI e formulário de item. Não iniciada nesta entrega; nome continua obrigatório conforme SPEC/D-002.
