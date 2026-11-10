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
