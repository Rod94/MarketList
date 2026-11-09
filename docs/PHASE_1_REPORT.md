# Fase 1 — Relatório incremental

## F1-01 — Modelo ShoppingList, identidade e datas UTC

**Data:** 09/11/2026. **Status:** feita. F1-02 a F1-05 ainda não iniciadas.

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

**Próxima tarefa pequena:** F1-02 — AppDatabase e primeira migração SQLite, ainda pendente.
