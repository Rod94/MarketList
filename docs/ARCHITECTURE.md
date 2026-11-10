# ARCHITECTURE.md — Aplicativo de Supermercado

**Versão:** 0.2 — proposta técnica para validação durante o scaffold  
**Data:** 07/11/2026  
**Plataforma do MVP:** Android (APK)  
**Portabilidade desejada:** iOS, futuramente  
**Documentos relacionados:** `SPEC.md`, `DESIGN.md`, `TESTING.md`, `TASKS.md`, `DECISIONS.md` e `../AGENTS.md`

> **Princípio central:** arquitetura clara e testável, sem transformar um aplicativo simples em um sistema excessivamente complexo. A aplicação deve funcionar integralmente offline e explicar seus comportamentos ao usuário, sem impor obstáculos à compra.

## 1. Objetivos arquiteturais

1. Permitir preparar uma lista em casa, adicionar preços no mercado e acompanhar imediatamente o **total registrado**.
2. Preservar corretamente dados e centavos ao fechar/reabrir o app, mesmo sem internet.
3. Aceitar quantidades opcionais, múltiplos preços por produto, compras parciais e itens adicionados espontaneamente.
4. Suportar conferência final de orçamento, pendências e valor **opcional** efetivamente cobrado no caixa.
5. Manter listas finalizadas **somente para consulta**, sem alterar valores históricos.
6. Facilitar testes automatizados, manutenção, explicação didática do código e futura construção iOS.
7. Evitar servidor, conta, autenticação ou sincronização no MVP.

## 2. Tecnologias e justificativas

| Responsabilidade | Tecnologia proposta | Por quê |
| --- | --- | --- |
| Interface Android/iOS | **Flutter + Dart** | Código de interface compartilhável, bom desempenho para o escopo e suporte a testes. |
| Organização | **MVVM enxuto, por funcionalidade** | Separa interface, estado, regras e persistência; facilita aprender e testar. |
| Estado e dependências | **ChangeNotifier + Provider** | Solução simples para o tamanho do MVP, com atualizações reativas e injeção de dependências. |
| Persistência | **SQLite, via `sqflite`** | Banco local relacional, transações e suporte a Android/iOS. |
| Cálculo de dinheiro | **`int` em centavos** | Evita erros comuns de ponto flutuante. |
| Formatação de valores/datas | `intl`, se necessário | Exibir `R$ 12,66` e datas locais sem misturar formato com cálculo. |
| Navegação | `Navigator` inicialmente; avaliar `go_router` ao crescer | Não adicionar dependência só por antecipação; manter rotas concentradas em `app/`. |
| Testes | `flutter_test`, `integration_test` e testes de banco | Cobrir regras, widgets, persistência e jornada no dispositivo. |

**Observação:** confirmar versões compatíveis de Flutter/Dart e bibliotecas ao criar o projeto. Não fixar versões hipotéticas neste documento.

### Por que não usar algo mais complexo agora?

Não há motivo inicial para introduzir backend, sincronização, BLoC, múltiplos bancos, dezenas de `use cases` ou uma biblioteca grande de geração de código. Podemos acrescentar abstrações **quando houver um problema concreto que justifique isso**.

## 3. Camadas e fluxo de dados

```text
Toque do usuário
       |
       v
Widget / Screen  (ex.: ShoppingScreen)
       |
       v
ViewModel        (ex.: ShoppingViewModel)
       |
       +-- Regras de domínio puras (ex.: calcular subtotal)
       |
       v
ShoppingRepository (contrato de leitura/gravação)
       |
       v
SqliteShoppingRepository (implementação)
       |
       v
AppDatabase / sqflite
       |
       v
SQLite no dispositivo
```

**Responsabilidades:**

- **View/Widget:** apresenta a lista, inputs e botões; não executa SQL nem decide regras financeiras.
- **ViewModel:** controla carregamento, filtros, erros e operações acionadas pela tela; chama o repositório e expõe estado para a View.
- **Domínio:** representa listas, itens e entradas de compra; calcula subtotais, total, diferenças e estados de compra. Deve ser testável sem Flutter.
- **Repositório:** é a fonte confiável de dados confirmados; oferece operações como `adicionarEntrada()`, `listarCompras()` e `finalizarCompra()`.
- **Serviço de banco:** abre SQLite, aplica migrações e fornece conexão e transações.

**Importante:** o usuário pode visualizar o subtotal enquanto digita, mas **o total oficial da lista só muda após confirmar e salvar o registro**. A confirmação de sucesso só aparece depois do retorno bem-sucedido do banco. Se salvar falhar, os dados digitados permanecem na tela para tentar novamente.

## 4. Scaffold proposto

```text
supermercado/
├── android/                      # Gerado pelo Flutter
├── ios/                          # Gerado pelo Flutter; sem entrega iOS no MVP
├── lib/
│   ├── main.dart                 # Inicialização da aplicação
│   ├── app/
│   │   ├── app.dart              # MaterialApp, configuração global
│   │   ├── app_router.dart       # Rotas e navegação
│   │   └── theme/
│   │       ├── app_colors.dart
│   │       ├── app_theme.dart    # Temas claro e AMOLED
│   │       └── app_spacing.dart
│   ├── core/
│   │   ├── database/
│   │   │   ├── app_database.dart
│   │   │   └── migrations/       # v1, v2... sem destruir dados
│   │   ├── money/
│   │   │   ├── money.dart
│   │   │   └── money_formatter.dart
│   │   └── errors/
│   │       └── app_failure.dart
│   └── features/
│       ├── shopping/
│       │   ├── domain/
│       │   │   ├── models/
│       │   │   │   ├── shopping_list.dart
│       │   │   │   ├── shopping_item.dart
│       │   │   │   └── purchase_entry.dart
│       │   │   ├── shopping_calculator.dart
│       │   │   └── shopping_repository.dart # Contrato
│       │   ├── data/
│       │   │   └── sqlite_shopping_repository.dart
│       │   └── presentation/
│       │       ├── view_models/
│       │       │   └── shopping_view_model.dart
│       │       ├── screens/
│       │       │   ├── shopping_lists_screen.dart
│       │       │   └── shopping_screen.dart
│       │       └── widgets/
│       │           ├── shopping_item_row.dart
│       │           ├── quick_add_sheet.dart
│       │           └── total_bar.dart
│       ├── checkout/
│       │   └── presentation/      # Conferência e finalização
│       │       ├── checkout_screen.dart
│       │       └── checkout_view_model.dart
│       └── history/
│           └── presentation/      # Consulta sem edição
│               ├── history_screen.dart
│               ├── history_detail_screen.dart
│               └── history_view_model.dart
├── test/
│   ├── unit/                     # Domínio e ViewModels
│   ├── widget/                   # Tela e componentes
│   └── database/                 # Persistência/migrações
├── integration_test/            # Fluxos no dispositivo/emulador
├── docs/
│   ├── SPEC.md
│   ├── ARCHITECTURE.md
│   ├── DESIGN.md
│   ├── DECISIONS.md
│   ├── TESTING.md
│   └── TASKS.md
├── AGENTS.md
└── pubspec.yaml
```

**Regra de organização:** pastas e arquivos da árvore são um **alvo de evolução**, não uma obrigação de criar diretórios vazios no primeiro commit. Uma feature pequena pode começar com poucos arquivos e crescer quando necessário.

## 5. Modelo de dados do domínio

### `ShoppingList`

- `id` — identificador estável.
- `name` — nome da lista.
- `createdAt` e `finalizedAt?` — datas da criação e finalização.
- `status` — `active` ou `finalized`.
- `budgetCents?` — valor disponível/orçamento opcional.
- `finalizedRegisteredTotalCents?` — total dos produtos no instante da finalização.
- `checkoutPaidCents?` — valor informado pelo usuário como cobrado no caixa, opcional.

### `ShoppingItem`

- `id`, `shoppingListId`, `name`.
- `plannedQuantity?` — quantidade planejada opcional; nulo **não** significa 1.
- `origin` — planejado em casa ou adicionado durante a compra (informação interna, não campo obrigatório na interface).
- `sortOrder` — posição fixa de inclusão, sem ordenar automaticamente após registrar preço.
- `removedAt?` — para remoção lógica durante compra; fica invisível na interface e sai dos cálculos.

### `PurchaseEntry`

- `id`, `shoppingItemId`.
- `quantity?` — número de unidades compradas, quando utilizado.
- `unitPriceCents?` — preço de uma unidade.
- `directAmountCents?` — valor direto quando não há quantidade.

**Uma entrada tem exatamente um formato válido:**

1. **Por unidade:** `quantity > 0` e `unitPriceCents >= 0`; subtotal `quantity × unitPriceCents`.
2. **Valor direto:** `quantity = null`, `unitPriceCents = null` e `directAmountCents >= 0`; subtotal igual ao valor informado.

Não armazenar marca como requisito. Se desejar, o usuário escreve `Sabonete Dove` no próprio nome.

### Regras derivadas (não duplicar estado desnecessariamente)

- **Subtotal do item:** soma das entradas de compra válidas.
- **Total atual:** soma dos subtotais dos itens não removidos.
- **Pendente:** nenhuma entrada de compra registrada.
- **Parcial:** quantidade planejada conhecida e quantidade comprada conhecida, menor que a planejada.
- **Comprado:** existe registro; se houver quantidade planejada, ela foi atingida ou ultrapassada.
- **Filtro `A comprar`:** mostra pendentes, parciais e casos cuja quantidade ainda não pôde ser confirmada; não altera o total.

Caso misto a tratar com atenção: **uma entrada de valor direto em um produto que tem quantidade planejada não prova quantas unidades foram compradas**. Não presumir conclusão. Mostrar `quantidade não confirmada` na revisão, ou orientar o usuário a registrar quantidade e preço unitário. Este refinamento fica pendente de validação de UX.

## 6. Esquema SQLite inicial (conceitual)

```sql
CREATE TABLE shopping_lists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('active','finalized')),
  created_at_utc TEXT NOT NULL,
  finalized_at_utc TEXT,
  budget_cents INTEGER,
  finalized_registered_total_cents INTEGER,
  checkout_paid_cents INTEGER
);

CREATE TABLE shopping_items (
  id TEXT PRIMARY KEY,
  shopping_list_id TEXT NOT NULL REFERENCES shopping_lists(id),
  name TEXT NOT NULL,
  planned_quantity INTEGER CHECK (planned_quantity IS NULL OR planned_quantity > 0),
  origin TEXT NOT NULL CHECK (origin IN ('planned','at_store')),
  sort_order INTEGER NOT NULL,
  removed_at_utc TEXT
);

CREATE TABLE purchase_entries (
  id TEXT PRIMARY KEY,
  shopping_item_id TEXT NOT NULL REFERENCES shopping_items(id),
  quantity INTEGER,
  unit_price_cents INTEGER,
  direct_amount_cents INTEGER,
  CHECK (
    (quantity IS NOT NULL AND quantity > 0 AND unit_price_cents IS NOT NULL AND unit_price_cents >= 0 AND direct_amount_cents IS NULL)
    OR
    (quantity IS NULL AND unit_price_cents IS NULL AND direct_amount_cents IS NOT NULL AND direct_amount_cents >= 0)
  )
);
```

**Requisitos da implementação do banco:**

- Habilitar chaves estrangeiras (`PRAGMA foreign_keys = ON`) e índices por `shopping_list_id`, `shopping_item_id` e `(shopping_list_id, sort_order)`.
- Usar consultas parametrizadas, jamais interpolar nomes/entradas do usuário em SQL.
- Criar migrações versionadas e testá-las com bancos de versões anteriores.
- Utilizar transações nas alterações compostas, em especial a finalização.
- Tratar strings temporais em UTC no banco e converter para horário local apenas na apresentação.
- Considerar restrições adicionais para integridade de `status` e campos finais durante a implementação.

**Observação:** este SQL é um **modelo de partida**, não uma migração revisada para produção. Esquema, índices e política de remoção lógica terão testes próprios antes do primeiro APK.

## 7. Regras transacionais mais importantes

### Registrar uma compra

1. Validar quantidade, preço e estado `active` da lista.
2. Inserir ou atualizar a entrada de compra numa operação persistida.
3. Recarregar/atualizar o estado da tela a partir do resultado confirmado.
4. Recalcular subtotais e o total, **sem adicionar o valor antigo novamente**.
5. Preservar a posição visual do produto; mudar apenas seu indicador/valor.

### Remover um item

- Se a compra estiver ativa, ocultar o item logicamente e excluir seu subtotal do total da lista.
- Permitir desfazer, se a remoção for recente e a operação de UX estiver disponível.
- O item removido não deve ser confundido com item pendente **não comprado**.
- Não permitir remover/editar conteúdo de compra finalizada.

### Finalizar uma lista

1. Recalcular o total a partir das entradas confirmadas.
2. Exibir **sempre** conferência com total, orçamento e diferença (quando houver), itens pendentes/parciais e campo opcional do valor cobrado no caixa.
3. Oferecer **Voltar e revisar** ou **Confirmar finalização**. Pendências nunca bloqueiam.
4. Ao confirmar, executar **uma transação SQLite**: verificar `status = active`, persistir total registrado final, valor pago opcional, `finalized_at` e `status = finalized`.
5. Impedir dupla finalização (toque repetido e segunda chamada ao repositório).
6. Depois da transação, abrir somente o histórico de consulta. Operações de gravação devem recusar listas finalizadas **também no repositório**, não apenas desabilitar botões.

**Diferenças financeiras independentes:**

```text
saldo do orçamento = orçamento - total registrado
acerto do caixa = valor cobrado no caixa - total registrado
```

- Orçamento opcional; não confundir com total efetivamente pago.
- Valor do caixa opcional; não alterar preços históricos para fazer a soma coincidir.
- Finalização preserva **valor calculado** e **valor cobrado no caixa** separadamente.

## 8. Tema e usabilidade como requisitos de arquitetura

- Dark mode AMOLED com **fundo principal `#000000`**, contraste e acentos discretos; light mode equivalente.
- Tokens centrais de cores, tamanhos, espaços e tipografia em `app/theme/` (evitar valores espalhados pelos widgets).
- Linhas compactas, não uma sequência de cartões gigantes; botões com áreas confortáveis de toque.
- O total fica fixo em área inferior enquanto a **lista** rola. Abrir teclado/painéis não deve esconder campos nem ações críticas.
- Formulário `+` compacto com **Produto, Quantidade opcional e Preço opcional** no mesmo painel inferior.
- Produto permanece na posição original; filtros `Todos` e `A comprar` não alteram o total.
- Para adicionar outro preço: tocar no produto existente e adicionar nova entrada; sem nome de marca obrigatório.
- Mudanças de estado/erros de persistência devem ter feedback discreto e compreensível.
- Testar contraste, escalonamento de texto, teclado e operação com uma mão em aparelho real.

Detalhamento de telas e componentes está em `DESIGN.md`; **validar a usabilidade da tela principal antes de tratar a UI como definitiva**.

## 9. Testes desde a primeira fase

| Nível | O que valida | Exemplos |
| --- | --- | --- |
| **Unitário (TDD)** | Cálculos e regras puras | 3 × R$ 3,50 + 2 × R$ 4,20 = R$ 18,90; valor direto; orçamento; compra parcial. |
| **ViewModel** | Estado e coordenação de ações | Salvar atualiza UI; falha conserva digitação; filtro não altera total. |
| **Widget** | Interações e acessibilidade | Formulário `+`, teclado, total fixo, tema AMOLED, revisão final. |
| **Banco/integração** | SQLite, transações e migrações | Reiniciar e recuperar compra; finalização atômica; bloquear edição de finalizada. |
| **E2E no Android** | Jornada no dispositivo real | Criar → comprar offline → fechar/reabrir → conferir → finalizar → histórico. |

**Ciclo por tarefa:** requisito e exemplo → escrever teste que falha quando for adequado → implementar → passar testes → refatorar → executar regressão → verificar no celular → atualizar documentação.

**Comandos de referência, quando existir projeto Flutter:**

```bash
dart format .
flutter analyze
flutter test
flutter test integration_test --no-uninstall
flutter build apk
```

O teste em `integration_test` e o build dependem de SDKs, emulador/dispositivo e configuração de ambiente. Um teste só será declarado **aprovado** se realmente tiver sido executado e passado.

## 10. Evolução e riscos

### Fora do MVP

- Login, servidor e sincronização entre celulares.
- OCR, código de barras, marca obrigatória, foto obrigatória.
- Gráficos e análise de preços sofisticados.
- Publicação iOS imediata.

### Riscos que devem ser tratados

- **Perda do aparelho/desinstalação:** sem backup remoto, um banco local pode ser perdido. Não prometer recuperação automática; pensar em exportação/backup como evolução.
- **Persistência e interrupções:** salvar a cada ação confirmada e usar transações; nunca depender de um botão final de “salvar tudo”.
- **Histórico somente leitura:** travas em ViewModel **e** repositório; testar condições de corrida e toque duplo.
- **Apresentação de dinheiro:** converter input brasileiro para centavos inteiros; evitar `double` como fonte de verdade.
- **Portabilidade iOS:** manter código de domínio, banco e interface compartilháveis; evitar APIs Android sem isolamento.
- **Desempenho:** validar listas grandes (100+ produtos) e centenas de entradas em aparelhos intermediários antes de otimizar prematuramente.

## 11. Guia didático para cada implementação

Ao concluir cada tarefa, incluir uma explicação curta em linguagem simples:

1. **O problema resolvido:** o que o usuário ganha.
2. **Arquivos alterados:** por que existem e o que fazem.
3. **Fluxo dos dados:** de um toque na interface até o SQLite e de volta.
4. **Conceitos de Dart/Flutter:** `class`, `final`, `Future`, `async/await`, `Widget`, `ChangeNotifier` etc., à medida que surgirem.
5. **Testes executados:** comando, resultado e eventuais limitações.
6. **Pequeno exercício opcional:** algo que o usuário possa tentar modificar para consolidar o aprendizado.

**Critério de conclusão:** uma tarefa não está pronta se apenas “parece funcionar”; precisa cumprir seu requisito, passar os testes aplicáveis e estar compreensível e documentada.

## 12. Pontos ainda sujeitos a validação

1. Comportamento do **valor direto em item com quantidade planejada** (não inferir quantidade automaticamente).
2. Sugestão de aproveitar item existente quando o nome já foi cadastrado, sem bloquear duplicatas legítimas.
3. Política exata de remoção lógica e prazo do botão *Desfazer*.
4. Priorização de duplicar listas anteriores e exportar backup em fases futuras.
5. Qual a navegação mais enxuta (`Navigator` vs. `go_router`) após desenhar todas as rotas.

Esses detalhes não impedem começar o scaffold e os testes iniciais; **não devem ser tratados como regras de produto aprovadas sem validação**.

## 13. Referências técnicas

- Flutter — Guide to app architecture: https://docs.flutter.dev/app-architecture/guide
- Flutter — Architecture recommendations: https://docs.flutter.dev/app-architecture/recommendations
- Flutter — Persist data with SQLite: https://docs.flutter.dev/cookbook/persistence/sqlite
- Flutter — Testing overview: https://docs.flutter.dev/testing/overview
- Plugin `sqflite`: https://pub.dev/packages/sqflite

## 14. Fundação efetivamente criada — Fase 0, 09/11/2026

Este registro preserva o estado da entrega F0. A evolução F1-01 está na seção 15.

A árvore da seção 4 continua sendo um alvo de evolução. O código atual contém `main.dart`, `app/app.dart`, tokens e temas em `app/theme/`, `ThemeViewModel`, o enum compartilhado `core/preferences/theme_preference.dart` e uma única `ScaffoldScreen` na apresentação de shopping. Não há modelos de compra, rotas adicionais, repositórios, SQL nem cálculos monetários.

O fluxo atual é: seleção do tema → `ThemeViewModel.selectTheme` → `notifyListeners` → Provider → reconstrução do `MaterialApp` e da tela. O Provider controla o ciclo de vida do ViewModel. Os widgets são `StatelessWidget`; estado mutável fica fora deles. A escolha é temporária, sem banco ou preferência persistida.

Plataformas Android/Kotlin e iOS/Swift foram geradas pelo Flutter 3.47.9. O código Dart não importa APIs exclusivas do Android. Compilar/assinar e validar iOS exigirá macOS/Xcode em uma entrega futura. O relatório `PHASE_0_REPORT.md` registra o que realmente foi executado nesta máquina.

## 15. Modelo de lista efetivamente criado — F1-01, 09/11/2026

`lib/features/shopping/domain/models/shopping_list.dart` contém `ShoppingList` e `ShoppingListStatus` em Dart puro. O construtor recebe identidade e criação, normaliza datas para UTC e valida coerência dos campos da seção 5. A instância é imutável e representa os estados ativo/finalizado sem realizar transição, persistência ou cálculo.

O fluxo atual do modelo é entrada explícita de dados → normalização/validação no construtor → objeto válido ou `ArgumentError`. UI, ViewModel e repositório ainda não usam o modelo. Não foram criados contratos de banco, mapeadores, geradores de ID ou telas antecipadamente. As fronteiras/invariantes estão registradas em `DECISIONS.md`, seção 7; execução e didática em `PHASE_1_REPORT.md`.

## 16. Banco efetivamente criado — F1-02, 09/11/2026

`core/database/app_database.dart` concentra abertura, caminho, versão, factory e configuração de foreign_keys. `core/database/migrations/v1.dart` cria somente `shopping_lists` com os campos do modelo, restrições e índice por estado/data. O esquema conceitual da seção 6 permanece como alvo futuro; `shopping_items` e `purchase_entries` ainda não existem na migração de produção.

Fluxo desta camada: chamador → `AppDatabase.open()` → sqflite configura a conexão → cria v1 atomicamente se necessário ou reabre a versão suportada → devolve a conexão. Falhas são propagadas; não há recuperação que apague arquivos. Reabertura da v1 e recusa da v2 de fixture foram testadas; evolução v1→v2 ainda precisa de migração/testes próprios.

Não há conexão nova no `main.dart`, Provider ou widget. O banco é usado apenas pelos testes até F1-03/F1-04 integrarem as camadas. `test/database/app_database_test.dart` executa SQLite FFI em Windows; `integration_test/database_smoke_test.dart` usa o plugin nativo no Android. As tabelas-filhas usadas nos testes de foreign_keys são fixtures, não modelos de produtos antecipados. Limites das validações e proteção futura de listas finalizadas: `DECISIONS.md`, seção 8.

## 17. Repositório efetivamente criado — F1-03, 09/11/2026

`features/shopping/domain/shopping_repository.dart` define o contrato puro e erros específicos para lista finalizada/conflito de criação. `features/shopping/data/sqlite_shopping_repository.dart` implementa ID, criação, leitura de ativas e remoção. O mapeamento linha↔modelo fica privado na própria implementação, sem abstração genérica de mapper ou repositório-base.

Fluxo atual: chamador (testes) → repositório → modelo para validar → AppDatabase → transação SQLite → resultado confirmado. Leituras materializam modelos imutáveis e ordenam por instante real; criação/remoção usam somente consultas parametrizadas e o executor da transação. Erros são propagados. `main.dart` e a tela ainda não usam a camada de listas; essa ligação será feita na F1-04.

Repositório recebeu 26 testes FFI e três cenários adicionais no teste nativo de banco. A migração v1 não mudou. CT-001/002/003 estão cobertos nesta camada; experiência de confirmação, reinício completo e preservação visual de inputs continuam dependentes de F1-04/F1-05. Não há edição/finalização de compras nem consulta histórica implementada. Regras de identidade, retry e precisão temporal: `DECISIONS.md`, seção 9.

## 18. Interface e reinício offline — F1-04/F1-05, 09/11/2026

`app/app.dart` compõe repositório SQLite, ThemeViewModel e ShoppingListsViewModel. `ShoppingListsScreen` apresenta as listas e encaminha ações; `CreateListSheet` mantém controladores de texto e layout do teclado. `list_budget_input.dart` converte/exibe somente orçamento de lista, em centavos inteiros. O parser geral de moeda/preços permanece para F3. Tela de aparência existente é acessada pelo AppBar.

Fluxo de criação: campo → rascunho no ViewModel → validação/centavos → repositório com ID estável → transação SQLite → modelo confirmado → coleção imutável → atualização da tela e fechamento do painel. Erro mantém painel, textos e identidade. Exclusão: diálogo com nome → ViewModel → remoção transacional ativa → atualização visual somente após confirmação. Model/repositório compartilham o comparador temporal já adotado.

O app normal agora usa `market_list.db`. Por isso, a integração injeta outro repositório em banco temporário próprio, sem fallback em produção. A F1-05 foi verificada no app normal pelo host, com modo avião, Wi-Fi desligado, nenhuma rede padrão, novo processo e recuperação real dos dados. O roteiro ADB remove apenas sua lista e restaura as configurações capturadas. Ele não é parte do runtime Flutter. A migração v1 não mudou; futuras tabelas ainda requerem migração/testes próprios.

## 19. Modelo de item — F2-01, 10/11/2026

`features/shopping/domain/models/shopping_item.dart` representa `ShoppingItem` e `ShoppingItemOrigin` em Dart puro, sem imports Flutter/SQLite. Os campos são os da seção 5: identidade, vínculo, nome, quantidade opcional, origem, posição e remoção opcional. Campos final e tipos imutáveis preservam a instância; validações do construtor usam erros em execução, não asserts.

Quantidade é `int?`: ausente permanece null; presente deve ser positiva. Origem e posição são fornecidas explicitamente pelo chamador. A posição usa índice não negativo, começando em zero; gerar/manter a ordem e executar remoção lógica continuam para F2-02/04/05. `removedAt` apenas representa o instante em UTC, sem implementar exclusão/desfazer. Não há estados de compra, entradas ou cálculos antecipados. O contrato do repositório e o esquema v1 permanecem intactos; o novo modelo ainda não integra o fluxo do app.

## 20. Persistência de itens — F2-02, 10/11/2026

`migrations/v2.dart` acrescenta a tabela de itens, FK com cascade na exclusão da lista e posição única por lista. `AppDatabase` abre v2 e aplica migrações incrementalmente; `v1.dart` não muda. A tabela de entradas de compra ainda não existe. Os CHECKs validam quantidade INTEGER positiva/ausente, posição INTEGER não negativa, origem e campos obrigatórios; datas exigem Z no SQL e validação semântica no mapeamento Dart.

O contrato existente `ShoppingRepository` ganhou operações de item; `SqliteShoppingRepository` concentra implementação/mapeamento, sem camada genérica nova. Inclusão usa ID estável e posição MAX+1 transacional. Edição altera somente nome/quantidade, preservando vínculo/origem/posição. Remoção marca data UTC e não apaga o item. Cada escrita verifica lista ativa na mesma transação; ausência/estado finalizado geram erro, e o retorno só ocorre depois do commit.

Fluxo nesta entrega: chamador/teste → repositório → domínio valida → transação verifica lista e grava item → modelo/resultado confirmado. Leitura é uma coleção imutável de registros, **incluindo removidos**, sem implementar filtros/visibilidade da compra. A UI continua sendo a de listas; ligação/formulário será F2-03, comportamento visual de posição F2-04 e ocultação de removidos F2-05. CT-021 cobre agora preservação de identidade ao renomear; preservação de entradas depende da F3.

## 21. Tela de planejamento — F2-03, 10/11/2026

ShoppingListsScreen abre ShoppingScreen via Navigator. Cada rota possui ShoppingItemsViewModel/ChangeNotifier, que carrega registros confirmados e controla rascunho/erros/ID estável. ItemFormSheet possui somente TextEditingControllers/layout; item_quantity_input.dart faz parsing puro. O repositório e o banco v2 não mudaram.

Fluxo: toque na lista → Provider cria ViewModel → carga SQLite → tela; Adicionar/toque no produto → formulário → ViewModel valida → repositório confirma → cache imutável → fechamento/sucesso. Falha mantém os campos, sem confirmação antecipada. A ordenação explícita/projeção de removidos serão acrescentadas nas tarefas seguintes. O fake de testes agora fornece operações de itens controláveis; produção continua usando SQLite real.

F2-04 acrescentou `ShoppingItem.compareBySortOrder` e ordenação de cópias na carga/cache do ViewModel. Banco mantém posições; UI usa chaves por ID. Nome/quantidade não entram no comparador. Projeção de removidos permanece para F2-05.

F2-05 liga a marca de remoção já persistida à projeção `visibleItems`, que ShoppingScreen apresenta. ItemFormSheet compartilha a instância do ViewModel e retorna enum de sucesso/removido; cancelar não retorna resultado. Remoção/edição/inclusão compartilham o bloqueio de operação pendente. Cache só retira ID após resultado confirmado; SQL/estado/transação permanecem no repositório. Nenhuma migração foi necessária nas tarefas F2-03/04/05; v1/v2 continuam intactas.

## 22. Dinheiro — F3-01, 10/11/2026

core/money/money.dart contém funções puras de parsing/formatação e operações verificadas. Entrada não usa double; centavos/resultados persistíveis são int não negativo em int64. BigInt verifica somas/produtos e formatação negativa extrema antes da conversão, sem virar tipo de coluna. list_budget_input.dart delega ao núcleo, preservando formato e mensagem existentes. Sem classe/serviço genérico ou pacote novo. Preços/entradas serão conectados nas tarefas seguintes.

F3-02 introduziu PurchaseEntry puro/imutável, com exclusividade dos modos e subtotalCents derivado/verificado na construção. Não aceita subtotal fornecido, estado visual, marca ou serialização no domínio. Repositório/banco/UI ainda não usam entradas.

F3-03 introduziu calculateShoppingList, ShoppingCalculation e ItemPurchaseSummary no domínio. Fotografia ordenada/imutável agrupa entradas por item, verifica IDs/vínculos/limites e deriva estados/quantidades. Total exclui removidos sem apagar suas entradas. Fonte para futuros repositório/ViewModel, sem armazenar totais/estados ativos redundantes.

## 23. Entradas SQLite — F3-04, 10/11/2026

AppDatabase abre v3 e aplica v1/v2/v3 incrementalmente. Purchase_entries guarda somente campos de PurchaseEntry, sem subtotal/estado duplicado, com FK/cascade e índice. O repositório mapeia dados e cria/edita/exclui em transações com guarda de lista ativa/item não removido. Retorna ShoppingCalculation calculada dentro da mesma transação, após checar limites; Future só conclui após commit. Erro no cálculo ou SQL reverte a escrita inteira. loadShoppingList lê itens/entradas consistentemente e inclui tombstones no domínio, que os exclui do total. Fake de UI ainda não implementa essas operações até a ligação F3-05.

F3-05 liga a fotografia ao ShoppingItemsViewModel. Total confirmado é nullable antes da carga, prévia deriva de rascunho separado e gravações aceitam só fotografia retornada pelo repositório. Planejamento confirmado reutiliza entradas confirmadas do cache para refletir alterações de nome/remoção sem um segundo salvamento. Operações de entrada/planejamento compartilham bloqueio pendente; nenhum SQL/cálculo baseado em double entra em widget. Fake agora permite controlar respostas de compra nos testes.
