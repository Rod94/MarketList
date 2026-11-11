# TESTING.md — Estratégia e casos de teste do aplicativo de supermercado

**Versão:** 1.3 — Fases 0/1/2 e F3-01 a F3-03 testadas no escopo implementado

**Data:** 10/11/2026 (catálogo original: 07/11/2026)
**Referências:** `SPEC.md`, `DESIGN.md`, `ARCHITECTURE.md`, `TASKS.md`

> **Definição de pronto:** funcionalidade implementada + requisitos/critério de aceite atendidos + testes aplicáveis executados e aprovados + regressão sem falhas relevantes + documentação atualizada. Testes não executados nunca devem ser relatados como aprovados.

## 1. Estratégia incremental

- **TDD no domínio:** começar por exemplos e limites dos cálculos, estados e transições; teste RED → implementação GREEN → refatoração.
- **Testes de ViewModel:** filtros, atualização do total após gravação, erros preservando formulários e controle de ações duplicadas.
- **Testes de widgets:** acessibilidade, cadastro rápido, teclado, total fixo e fluxo de revisão.
- **Testes SQLite:** leitura/escrita, transações, integridade, migrações, exclusão lógica e histórico somente leitura.
- **Testes de integração/E2E:** jornada em dispositivo/emulador Android, offline, reinício, finalização e consulta.
- **Regressão:** executar suite acumulada a cada mudança funcional. Teste manual em celular complementa, não substitui, os automatizados.

Prioridade: **P0** impede lançar se falhar (valor, integridade, perda de dados, histórico), **P1** impacto alto de experiência e fluxo, **P2** refinamentos. A classificação representa planejamento inicial; atualizá-la com riscos reais.

## 2. Dados de referência e resultados exatos

- `Sabonete`: planejado 5; compra 3 × R$ 3,50 = R$ 10,50; segunda compra 2 × R$ 4,20 = R$ 8,40; subtotal = **R$ 18,90**.
- `Leite` não planejado: 3 × R$ 4,22 = **R$ 12,66**.
- `Carne`: sem quantidade; preço direto = **R$ 47,82**.
- Somando esses três itens: **R$ 79,38**.
- Orçamento R$ 100,00 + total R$ 125,00: excedente **R$ 25,00**, compra permitida.
- Total calculado R$ 527,80 + caixa R$ 530,20: diferença **R$ 2,40 a mais**.
- Dinheiro no domínio: **inteiros em centavos** (`350`, `420`, `52780`). Testar entrada e exibição em `pt-BR`; não calcular com ponto flutuante.

## 3. Catálogo funcional — listas e itens

| ID | Prioridade | Cenário | Resultado esperado |
| --- | --- | --- | --- |
| CT-001 | P0 | Criar lista com nome válido | Lista aparece ativa, com identificação e data |
| CT-002 | P1 | Remover lista ativa | Sai da listagem após confirmação; dependências tratadas corretamente |
| CT-003 | P0 | Fechar e reabrir o app após criar lista | Lista e dados confirmados preservados |
| CT-004 | P0 | Adicionar produto à lista ativa | Item adicionado uma única vez por confirmação |
| CT-005 | P1 | Remover produto pendente | Some da lista ativa e dos filtros |
| CT-006 | P1 | Informar, alterar ou retirar quantidade planejada | Quantidade atualizada; nulo não vira 1 |
| CT-007 | P1 | Informar valor válido em um item | Entrada gravada e exibida corretamente |
| CT-008 | P0 | Multiplicar preço unitário pela quantidade | 3 × R$ 4,22 = R$ 12,66 |
| CT-009 | P0 | Registrar dois preços no mesmo item | 3 × 3,50 + 2 × 4,20 = R$ 18,90 |
| CT-010 | P0 | Somar valores de vários itens | Total é soma de subtotais, incluindo direto |
| CT-011 | P0 | Finalizar lista com valor registrado | Total e datas finalizados corretamente |
| CT-012 | P0 | Reconsultar compra finalizada no histórico | Dados originais íntegros, sem edição |
| CT-013 | P1 | Planejar 5, comprar 3 | Mostra `faltaram 2` na revisão |
| CT-014 | P1 | Planejar 5, comprar 5 | Sem aviso de compra parcial |
| CT-015 | P1 | Planejar 5, comprar 6 | Registra 6 sem bloquear |
| CT-016 | P0 | Finalizar com compra parcial | Finalização permitida e subtotal preservado |
| CT-017 | P0 | Consultar histórico parcial | Exibe planejado 5, comprado 3, faltaram 2 |
| CT-018 | P1 | Produto espontâneo com quantidade e preço | Leite adicionado e R$ 12,66 contabilizados |
| CT-019 | P1 | Produto espontâneo sem preço | Item pendente; total inalterado |
| CT-020 | P1 | Produto sem quantidade com valor direto | Carne R$ 47,82 entra uma vez no total |
| CT-021 | P1 | Renomear item com compras registradas | Entradas e valores continuam vinculados |

## 4. Catálogo funcional — cálculo, orçamento e edição

| ID | Prioridade | Cenário | Resultado esperado |
| --- | --- | --- | --- |
| CT-022 | P0 | Corrigir preço de entrada existente | Substitui o valor; não duplica a soma |
| CT-023 | P0 | Remover só a segunda entrada de sabonete | Subtotal passa de R$ 18,90 para R$ 10,50 |
| CT-024 | P0 | Remover item já comprado | Total diminui exatamente seu subtotal |
| CT-025 | P0 | Alterar quantidade registrada | Subtotal e total recalculados corretamente |
| CT-026 | P0 | Usar valores com centavos | `0,10 + 0,20` = `0,30`, sem erro binário |
| CT-027 | P0 | Corrigir 25,90 para 23,90 | Total diminui R$ 2,00, não soma duas entradas |
| CT-028 | P1 | Não definir orçamento | Todos os fluxos funcionam sem saldo exibido |
| CT-029 | P1 | Orçamento 800, compra 600 | Mostra R$ 200 disponíveis |
| CT-030 | P1 | Orçamento 800, compra 850 | Mostra R$ 50 acima; não bloqueia |
| CT-031 | P1 | Mudar orçamento com compra ativa | Saldo atualizado, total de produtos igual |
| CT-032 | P0 | Alterar preços com filtro `A comprar` ativo | Total considera também itens ocultos |
| CT-033 | P1 | Preço incompleto enquanto digitado | Atualiza apenas prévia; não muda total persistido |
| CT-034 | P0 | Salvar preço com sucesso | Valor confirmado refletido no total imediatamente |
| CT-035 | P0 | Tocar duas vezes em `Registrar preço` | Apenas uma entrada por confirmação |

## 5. Persistência, offline e histórico

| ID | Prioridade | Cenário | Resultado esperado |
| --- | --- | --- | --- |
| CT-036 | P0 | Abrir lista em modo avião | Tudo disponível sem conexão |
| CT-037 | P0 | Criar lista e registrar preço offline | Gravação local completa |
| CT-038 | P0 | Encerrar e reabrir offline | Dados já confirmados recuperados |
| CT-039 | P0 | Internet cair durante uso | Inclusões e cálculos continuam normalmente |
| CT-040 | P0 | Encerramento inesperado após salvar | Dados confirmados permanecem íntegros |
| CT-041 | P0 | Consultar lista finalizada offline | Histórico disponível com itens e valores |
| CT-042 | P2 / Pós-MVP | Duplicar uma lista anterior | Nova lista sem reutilizar preços e entradas anteriores; **funcionalidade ainda fora do MVP** |
| CT-043 | P0 | Finalizar compra de nov/2026 com `Arroz 5 kg` | Preço dessa compra registrado no histórico |
| CT-044 | P0 | Nova compra do mesmo arroz em 2027 | Histórico de 2026 permanece imutável |
| CT-045 | P1 | Localizar produto por nome no histórico | Resultados mostram listas/datas e preços antigos corretos |
| CT-046 | P0 | Repositório tenta editar lista finalizada | Operação é recusada, mesmo sem interface |
| CT-047 | P0 | Duas finalizações simultâneas | Apenas uma transição para finalizada, sem duplicação |
| CT-048 | P0 | Falha no meio da transação de finalização | Não deixa lista parcialmente finalizada |
| CT-049 | P0 | Migração de banco entre versões | Dados existentes preservados |
| CT-050 | P1 | Remoção lógica de item comprado | Não conta no total e não confunde com não comprado |

## 6. Casos de UX

| ID | Prioridade | Cenário | Resultado esperado |
| --- | --- | --- | --- |
| UX-001 | P1 | Um toque em `+ Adicionar` | Painel compacto abre com três campos visíveis |
| UX-002 | P1 | Adicionar apenas nome | Item pendente criado sem quantidade implícita |
| UX-003 | P1 | Adicionar 3 unidades e preço 4,22 | Prévia R$ 12,66 e gravação correta |
| UX-004 | P1 | Adicionar item com valor direto | Sem quantidade, rótulo indica `Valor total` |
| UX-005 | P0 | Teclado do Android aberto | Campo e botão de confirmação continuam acessíveis |
| UX-006 | P1 | Confirmar inclusão | Volta à lista, valor e estado atualizados |
| UX-007 | P0 | Toque duplo em Adicionar | Não duplica produto/compra |
| UX-008 | P0 | Falha de persistência | Campos mantêm conteúdo e exibem erro claro |
| UX-009 | P1 | Tema AMOLED em aparelho OLED | Fundo principal `#000000` e textos legíveis |
| UX-010 | P0 | Cadastro completo offline | Comportamento funcional igual ao online |
| UX-011 | P1 | Comprar item que está no meio | Preserva posição na ordem original |
| UX-012 | P1 | Ativar `A comprar` | Oculta concluídos, mostra pendentes e parciais |
| UX-013 | P1 | Comprados 3 de 5 | Item ainda visível em `A comprar` |
| UX-014 | P1 | Registrar 2 restantes | Item sai de `A comprar`, continua em `Todos` |
| UX-015 | P1 | Voltar para `Todos` | Ordem original restaurada |
| UX-016 | P0 | Alternar filtros | Não altera o total |
| UX-017 | P1 | Rolar 100 produtos | Barra do total continua visível e rolagem utilizável |
| UX-018 | P1 | Fonte aumentada / tela pequena | Texto e controles acessíveis, sem sobreposição crítica |
| UX-019 | P1 | Leitor de tela | Item anuncia nome, estado, quantidade e subtotal |
| UX-020 | P1 | Compras com 2 preços | Usuário adiciona outra entrada tocando no item existente |

## 7. Casos de finalização (FIN)

| ID | Prioridade | Cenário | Resultado esperado |
| --- | --- | --- | --- |
| FIN-001 | P0 | Todos os itens concluídos | Exibe tela de confirmação antes de finalizar |
| FIN-002 | P1 | Azeite sem compra registrada | Revisão destaca item sem preço |
| FIN-003 | P1 | Sabonete 3 de 5 | Revisão informa `faltaram 2` |
| FIN-004 | P0 | Escolher `Voltar e revisar` | Lista permanece ativa, dados preservados |
| FIN-005 | P0 | Corrigir preço e retornar à revisão | Total recalculado usando o valor corrigido |
| FIN-006 | P0 | Escolher `Confirmar finalização` com pendências | Finaliza normalmente |
| FIN-007 | P0 | Consultar a compra finalizada | Valores, pendências e status corretos |
| FIN-008 | P0 | Dois toques rápidos no botão final | Não finaliza duas vezes |
| FIN-009 | P0 | Abrir conferência final | Total calculado sempre visível |
| FIN-010 | P1 | Orçamento maior que total | Exibe saldo correto |
| FIN-011 | P1 | Orçamento menor que total | Exibe excedente correto |
| FIN-012 | P1 | Sem orçamento | Não exige orçamento para finalizar |
| FIN-013 | P1 | Pendentes + parciais na mesma lista | Um aviso consolidado, todos os casos visíveis |
| FIN-014 | P0 | Voltar à edição da compra | Nenhum item é alterado pela mera revisão |
| FIN-015 | P0 | Finalização confirmada | Lista passa a somente leitura |
| FIN-016 | P0 | Tentar alterar preço no histórico | Interface e repositório impedem |
| FIN-017 | P0 | Falha de gravação ao finalizar | Lista continua ativa e pode tentar novamente |
| FIN-018 | P0 | Valor do caixa igual ao total | Diferença R$ 0,00 |
| FIN-019 | P0 | Caixa R$ 530,20; total R$ 527,80 | Mostra R$ 2,40 a mais |
| FIN-020 | P0 | Caixa menor que total | Mostra valor a menos corretamente |
| FIN-021 | P1 | Valor do caixa em branco | Finaliza normalmente, armazenando `null` |
| FIN-022 | P0 | Consultar histórico com valor de caixa | Preserva calculado e pago separadamente |
| FIN-023 | P0 | Informar total de caixa diferente | Não altera preços nem subtotais dos itens |
| FIN-024 | P0 | Valor inválido no campo caixa | Não confirmar entrada inválida; oferecer correção |

## 8. Exemplos de testes completos (modelo para automação)

### TEST-MONEY-01 — Vários preços no mesmo item

**Dado** um item `Sabonete` com quantidade planejada de 5 e sem entradas, **quando** registrar 3 × R$ 3,50 e 2 × R$ 4,20, **então**:

- quantidade comprada = 5;
- subtotal do item = 1.890 centavos;
- total da lista aumenta em 1.890 centavos;
- nenhuma marca precisa ser informada.

**Camada:** domínio (teste unitário); integração do repositório para persistência.

### TEST-EDIT-01 — Corrigir preço sem duplicar

**Dado** um item com entrada 1 × R$ 25,90 e total de R$ 25,90, **quando** corrigir a mesma entrada para R$ 23,90, **então** subtotal e total serão R$ 23,90 e haverá **uma única entrada**.

**Camada:** domínio, repositório e ViewModel.

### TEST-CHECKOUT-01 — Finalizar com pendente, parcial e caixa

**Dado** item `Azeite` pendente; `Sabonete` planejado 5/comprado 3; total registrado 52.780 centavos; orçamento 50.000 centavos, **quando** abrir revisão e informar caixa 53.020 centavos, **então** mostrar:

- total calculado R$ 527,80;
- acima do orçamento R$ 27,80;
- diferença do caixa R$ 2,40 a mais;
- `Azeite` pendente; `Sabonete` faltaram 2;
- confirmação disponível.

**Quando** confirmar, lista finalizada com esses mesmos dados, sem novas edições.

### TEST-OFFLINE-01 — Reiniciar sem conexão

**Dado** dispositivo em modo avião, **quando** criar lista, incluir arroz, registrar 2 × R$ 24,90, encerrar o processo e abrir novamente, **então** a lista e o total R$ 49,80 permanecem consultáveis e editáveis se ainda estiver ativa.

**Camada:** integração/E2E com banco real e dispositivo/emulador.

## 9. Casos de borda e decisões a validar

Não converter suposições em regras aprovadas. Antes de implementar a validação correspondente, resolver e registrar em `DECISIONS.md`:

1. Preço unitário/valor direto igual a zero: item gratuito, erro de digitação ou estado inválido?
2. Quantidade planejada com valor direto sem quantidade comprada: estado e revisão.
3. Nome duplicado: apenas sugerir usar item existente ou permitir adicionar diretamente?
4. Exclusão de lista histórica finalizada; confirmação e impacto no histórico.
5. `Desfazer` da remoção: tempo e semântica.
6. Entradas extremas e limite de valores para prevenir overflow de centavos.

**Testes adicionais recomendados:** nomes vazios ou só espaços; valores negativos; letras em preço; separadores inválidos; quantidade zero ou negativa; produto com nome longo; centenas de registros; voltar durante persistência; app em segundo plano; preferências de tema; migração com interrupção controlada.

## 10. Ferramentas e execução (quando houver projeto Flutter)

```bash
dart format .
flutter analyze
flutter test
flutter test integration_test --no-uninstall
flutter build apk
```

- `flutter test` cobre os testes convencionais; integração em Android requer SDK/emulador/aparelho configurado.
- O sistema deve informar **comandos efetivamente executados**, quantidade de testes e falhas; não inventar resultados.
- Em cada entrega documentar: `Requisito → Casos de teste → Execução → Resultado → Limitações → Evidência`.
- Cobertura de testes é auxiliar; perseguir 100% sem avaliação de risco não é objetivo.

## 11. Critério de saída por fase

- [ ] Requisitos e decisões aprovadas implementados.
- [ ] Testes unitários e de integração relevantes aprovados.
- [ ] Testes de regressão anteriores aprovados.
- [ ] Smoke test manual em Android para fluxos UI afetados, quando ambiente disponível.
- [ ] Sem perda de dados nem divergência financeira conhecida.
- [ ] Documentação e `TASKS.md` atualizados.
- [ ] Entrega explica arquivos alterados, conceitos Dart/Flutter, comandos reais e limitações.

## 12. Execução da Fase 0 — 09/11/2026

| Requisito/caso | Arquivo | Execução e resultado |
| --- | --- | --- |
| F0-03/F0-05: estado inicial, mudança/notificação, escolha repetida | `test/unit/theme_view_model_test.dart` | `flutter test`: **3 aprovados**. |
| F0-04/F0-05: smoke de abertura, Claro/AMOLED, tema do sistema, tela pequena com fonte 2× | `test/widget/app_test.dart` | `flutter test`: **4 aprovados**. UX-009/UX-018 cobertos apenas na demonstração. |
| F0-06: abrir app e selecionar AMOLED no Android | `integration_test/app_smoke_test.dart` | `flutter test integration_test -d RXCY300NZZH`: **1 aprovado** no Samsung SM-S936B, Android 17/API 37. |

- `dart format .`: 11 arquivos, 2 ajustados inicialmente; segunda execução sem alterações. Verificação final `dart format --output=none --set-exit-if-changed .`: saída 0, 11 arquivos sem alterações.
- `flutter analyze`: duas execuções, ambas com **No issues found!**.
- Primeira execução de `flutter test`: 5 aprovados/2 falhas por seletor genérico incorreto no teste. Corrigido para `DropdownButton<ThemePreference>` sem alterar expectativas; execução seguinte: **7 aprovados/0 falhas**.
- Primeira tentativa `flutter test integration_test -d android`: não encontrou alvo; **não executou testes**. Após conexão/autorização do aparelho, o comando com ID acima executou e passou.
- `flutter build apk --debug`: sucesso, APK de desenvolvimento gerado. APK normal preservado antes do build de integração, restaurado no caminho padrão e instalado/aberto no aparelho após o teste. Usuário confirmou a tela e captura foi inspecionada sem sobreposição aparente.
- `flutter doctor -v`: diagnóstico inicial/final executados. Ainda alerta sobre ausência de cmdline-tools/estado de licenças desconhecido, embora os componentes requeridos pelo build tenham sido instalados usando licenças já existentes.

**Limitações:** sem build iOS ou release; sem auditoria completa de acessibilidade/OLED, teclado, dados/offline ou banco. Os testes CT/FIN e demais UX de funcionalidades futuras continuam **planejados, não executados**. Não existem regras de domínio nesta fundação; TDD de dinheiro/compra será aplicado na fase correspondente.

Relatório com ambiente, APK, comandos e aprendizado: `PHASE_0_REPORT.md`.

## 13. Execução F1-01 — 09/11/2026

**Escopo:** modelo Dart puro `ShoppingList`, sem banco, ações de compra ou interface nova. O arquivo de produção não importa Flutter. Os testes usam o runner `flutter_test` já instalado, sem criar dependências adicionais.

| Requisito/caso | Evidência em `test/unit/shopping_list_test.dart` | Resultado |
| --- | --- | --- |
| F1-01 / CT-001 (somente domínio) | Identificação/nome, estado ativo inicial, opcionais nulos e rejeição de identificador/nome vazios | 8 testes aprovados |
| F1-01 / ARCHITECTURE seção 6 | Criação e conclusão convertidas para UTC preservando o instante | 2 testes aprovados |
| F1-01 / RF-01 / D-021 (representação) | Ativa sem dados finais; finalizada com data/total; rejeição de data anterior à criação; conclusão no mesmo instante permitida | 6 testes aprovados |
| F1-01 / D-009 / D-019 / D-020 | Centavos independentes, orçamento excedido permitido, zero distinto de ausência e valores negativos recusados | 5 testes aprovados |

**RED:** `flutter test test/unit/shopping_list_test.dart` executado antes da implementação, saída 1 por arquivo/classe ausentes; houve falha de compilação/carregamento, não 21 falhas de asserção. **GREEN:** o mesmo comando após a implementação aprovou **21 testes**. Revisão manteve a classe pequena, sem exigir abstrações adicionais.

**Regressão executada nesta tarefa:**

- `dart format lib/features/shopping/domain/models/shopping_list.dart test/unit/shopping_list_test.dart`: 2 arquivos formatados.
- `flutter analyze`: **No issues found!**.
- `flutter test`: **28 aprovados, 0 falhas** (21 novos + 3 do ViewModel de tema + 4 de widget).
- `dart format --output=none --set-exit-if-changed .`: saída 0; **13 arquivos, nenhuma alteração**.

**Limitações:** CT-001 completo (criação na interface e persistência), CT-003, CT-046 e fluxos FIN continuam pendentes. Campos finais são representação de dados, não operação de finalização. Repositório ainda não existe para recusar gravações em listas finalizadas. Não foram repetidos integração Android, build APK nem smoke manual: o modelo ainda não é usado pela interface e nenhuma tela/plataforma/dependência foi alterada. Os resultados Android da seção 12 são evidência histórica da Fase 0. Sem novo APK nesta entrega.

Detalhes, decisões técnicas e exercício: `PHASE_1_REPORT.md`.

## 14. Execução F1-02 — 09/11/2026

| Requisito/caso | Evidência | Resultado final |
| --- | --- | --- |
| F1-02: abertura/versão/esquema mínimo, índice e aberturas concorrentes | `test/database/app_database_test.dart` | Incluídos nos **15 testes de banco aprovados** |
| F1-02: integridade referencial | FK habilitada; tabela-filha de fixture recusa referência órfã e remoção do pai referenciado | SQLite real, sem mock |
| F1-02: restrições | Identificação/nome/estado, sufixo UTC, tipo dos centavos, zero/null e coerência de dados finais | Restrições testadas sem implementar repositório/UI |
| F1-02 / CT-049 parcial | Reabrir preserva campos; tentativa de versão 2→1 recusa sem apagar dados | A fixture v2 não é migração de produto v1→v2 |
| F1-02: atomicidade da migração | Erro na criação do índice reverte a tabela criada e mantém versão 0/dados antigos; tentativa após remover conflito passa | Não equivale a CT-048 de finalização, que permanece pendente |
| F1-02: validação Android nativa | `integration_test/database_smoke_test.dart`: abertura/FK/reabertura, rollback da migração e downgrade | **3 aprovados** no Samsung SM-S936B |
| Regressão da aparência | `integration_test/app_smoke_test.dart` | **1 aprovado** no mesmo aparelho |

**Comandos efetivamente executados:**

- `flutter pub add sqflite path` e `flutter pub add --dev sqflite_common_ffi`: sucesso; versões no lockfile.
- `flutter test test/database/app_database_test.dart` RED: saída 1 por AppDatabase ausente; não houve asserções executadas nessa etapa. GREEN: **15 aprovados**.
- `dart format lib/core/database test/database` e `dart format .`: executados. Ajuste final do nome de um teste exigiu formatar novamente `test/database/app_database_test.dart`.
- Primeira análise: 1 informação de lint `prefer_initializing_formals`. Construtor ajustado; `flutter analyze` seguinte: **No issues found!**.
- `flutter test`: duas execuções, **43 aprovados/0 falhas** em ambas (15 banco + 28 anteriores).
- Primeira execução `flutter test integration_test -d RXCY300NZZH`: os três testes de banco passaram, mas aparência/tearDownAll ficaram `did not complete`; saída 1. Não foi reproduzida uma causa comprovada para a interrupção.
- Nova execução `flutter test integration_test --concurrency=1 -d RXCY300NZZH`: **4 aprovados/0 falhas**, saída 0. Flutter informou que ignora a opção; o código da ferramenta 3.47.9 já define concorrência 1 para integração. Portanto, não se atribui a aprovação à opção nem se declara corrigido um defeito de paralelismo.
- `flutter build apk --debug`: sucesso; APK normal reconstruído após integração, instalado e aberto com `adb install -r`/`am start -W` (**Success / Status: ok**).
- A tentativa final de formatação no sandbox ficou sem resposta e foi interrompida. Reexecução fora dele detectou um arquivo a ajustar; após aplicar o formatter, `dart format --output=none --set-exit-if-changed .`: **saída 0, 17 arquivos sem alterações**.

Os logs de colisão de índice e downgrade são erros provocados e capturados pelos testes, não falhas da execução GREEN. **Limitações:** não há jornada de listas, reinício do processo/offline E2E, mapper/repositório, proteção completa de listas finalizadas, migração v1→v2 de produto, build iOS ou release. CT-001/003/046/048 e demais fluxos futuros não foram marcados como completos. Dados normais do app não foram usados; fixtures foram removidas após fechar conexões e validar o destino de limpeza.

## 15. Execução F1-03 — 09/11/2026

| Casos/requisitos | Cobertura nesta entrega | Evidência |
| --- | --- | --- |
| CT-001 / F1-03 | Criação ativa persistida, nome validado, UTC, identidade/orçamento; nomes iguais permitidos | `test/database/shopping_repository_test.dart` |
| CT-002 / F1-03 | Remoção somente da ativa indicada, repetição sem falso sucesso, falha por FK preserva pai/filho | Mesmo arquivo |
| CT-003 parcial | Fechar/reabrir arquivo e nova instância recuperam dados | Não é reinício do processo nem jornada em modo avião |
| CT-046 parcial / D-021 | Criar com ID finalizado e remover finalizada recusam; histórico permanece idêntico | Operações futuras de edição/preços ainda não existem |
| F1-03 / AGENTS concorrência | Mesmo ID/dados repete sem duplicar; conflito não sobrescreve; criações/remoções simultâneas; finalização de fixture já iniciada impede remoção | Transações SQLite reais |
| F1-03 / integridade temporal | Formatos UTC legados, microssegundos, ordem temporal; calendário inválido/precisão excessiva falham sem correção automática | Leitura pelo repositório; migração v1 intacta |
| F1-03 Android | Persistência/reabertura/remoção, idempotência, proteção de finalizadas e falhas de gravação | 3 novos cenários em `integration_test/database_smoke_test.dart` |

**Resultados/comandos reais:**

- `flutter pub add uuid`: sucesso, uuid 4.6.0 e fixnum 1.1.1 transitivo.
- RED `flutter test test/database/shopping_repository_test.dart`: saída 1 por contrato/implementação ausentes (sem asserções executadas). GREEN inicial: **24 aprovados**.
- `dart format lib/features/shopping test/database/shopping_repository_test.dart` e `dart format .`: executados; 20 arquivos Dart ao final.
- `flutter analyze`: duas execuções nesta tarefa, ambas **No issues found!**.
- `flutter test`: **67 aprovados** inicialmente; após dois casos adicionais de formato temporal, **69 aprovados/0 falhas** (26 repositório + 43 anteriores).
- Primeiro `flutter test integration_test/app_smoke_test.dart -d RXCY300NZZH`: saída 79, teste/tearDownAll `did not complete`; a sequência parou antes de executar o segundo comando. Aparelho estava conectado/desbloqueado na checagem posterior; causa não comprovada.
- `flutter test integration_test/database_smoke_test.dart -d RXCY300NZZH`: **6 aprovados/0 falhas** (3 banco existentes + 3 repositório novos).
- `flutter test integration_test/app_smoke_test.dart -d RXCY300NZZH --verbose`, registrado em `build/f1-03-app-integration.log`: **1 aprovado**, saída 0. Nenhuma expectativa foi relaxada.
- O log revelou uninstall automático ao encerrar integração. Leitura do SDK confirmou opção `uninstall` padrão true. Após adotar `--no-uninstall`, `flutter test integration_test/database_smoke_test.dart --no-uninstall -d RXCY300NZZH`: **6 aprovados**, com pacote ainda instalado confirmado por `adb ... shell pm path br.com.rodolpho.marketlist`.
- Resultado nativo de casos distintos: **7 aprovados** (6 persistência + aparência), incluindo regressão. A interrupção intermitente de aparência continua documentada, sem declaração de causa corrigida.
- `flutter build apk --debug`: sucesso; app normal restaurado com `adb install -r` e `am start -W` (**Success / Status: ok**).
- Verificação final `dart format --output=none --set-exit-if-changed .`: **saída 0, 20 arquivos sem alterações**. `git diff --check -- lib test integration_test pubspec.yaml pubspec.lock`: sem erros nos diffs rastreados; fontes novas também passaram pelo formatter/analyzer.

**Correção de orientação anterior:** `install -r` foi usado na restauração manual, mas isso não exclui a desinstalação automática realizada pelo runner nas execuções antigas. A interface ainda não gravava listas/banco normal. Doravante usar `--no-uninstall`, conforme comandos atualizados, e continuar isolando fixtures.

**Limites:** CT-001/002 estão concluídos na camada de repositório, sem formulário/diálogo de confirmação; CT-003/046 têm cobertura parcial explicitada acima. UI, preservação visual de inputs/toque duplo, reinício real/offline E2E, novas tabelas, finalização de produção, iOS e release permanecem nas tarefas futuras. Não há nova migração nem modificação de registros existentes para converter datas.

## 16. Execução F1-04 — interface de listas, 09/11/2026

| Caso/requisito | Evidência nova | Resultado |
| --- | --- | --- |
| CT-001 / F1-04 | Nome/orçamento, retorno à lista, estado/datas e dados confirmados | Widget e Android SQLite real |
| CT-002 / DESIGN seção 6 | Diálogo com nome/impacto, cancelamento sem remover, item só sai após persistir | Widget e Android |
| UX-007/008 aplicados ao formulário de lista | Salvar bloqueia segunda chamada/cancelar/voltar; erro mantém inputs/ID; retry sem duplicação | ViewModel e widget; falha SQL real no Android |
| UX-005/018 parcial | Rodapé acima do teclado, campos roláveis, tela 320×568 e texto 2× | Widget; coordenadas e captura real no Android |
| F1-04: estados/lifecycle | Carga, retry, cache preservado, ausência distinta de falha, dispose durante Future | Testes ViewModel/widget |
| F1-04: orçamento opcional | Vazio/null, zero, centavos, sintaxe inválida e limite de representação inteira sem overflow | 10 testes puros de orçamento |

**Arquivos:** `test/unit/list_budget_input_test.dart` (**10**), `test/unit/shopping_lists_view_model_test.dart` (**13**) e `test/widget/shopping_lists_screen_test.dart` (**13**). `test/support/fake_shopping_repository.dart` é usado só pelos testes. Os quatro testes de tema existentes passaram a navegar pela nova home com repositório injetado. Integração de UI agora usa banco isolado em `market_list_ui_test_*`.

**Execução real:**

- RED dos dois arquivos unitários: falha de compilação por implementação ausente; GREEN: **23 aprovados**.
- RED do novo teste de widget: parâmetro de injeção ainda ausente. Primeiro GREEN parcial: 10 aprovados/1 falha por `pageBack()` procurar tooltip inglês. Ajustado seletor para `Voltar`, sem mudar expectativas; depois **15 widgets aprovados** (11 novos + 4 existentes).
- Dois testes adicionais confirmaram que toques no mesmo ponto são interceptados pela barreira do modal e não empilham painéis/diálogos. A tentativa inicial com finder já oculto gerou aviso; coordenadas derivadas do próprio controle corrigiram o gesto de teste, sem mudança na UI.
- Uma execução de `dart format .` parou com saída 65 por import colocado após declarações no teste Android; import corrigido antes da análise. Execuções seguintes formataram normalmente.
- `flutter analyze`: duas execuções aprovadas, **No issues found!**.
- `flutter test`: **103 aprovados** inicialmente; após os dois testes de gesto adicionais, **105 aprovados/0 falhas**. Composição final: 69 anteriores + 23 unitários + 13 widgets novos.
- Primeira integração de UI com `--no-uninstall`: saída 79, testes incompletos e erro de limpeza de diretório temporário do runner; segundo comando não iniciou. Diagnóstico `--no-dds --verbose`: saída 1, `streamListen` inválido para stream golden do SDK; opção descartada.
- `flutter test integration_test/app_smoke_test.dart --no-uninstall -d RXCY300NZZH --verbose`, log em `build/f1-04-ui-dds.log`: **3 aprovados** com DDS normal (tema, criar/excluir e falha real com inputs mantidos/retry).
- `flutter test integration_test/database_smoke_test.dart --no-uninstall -d RXCY300NZZH`: **6 aprovados**. Total nativo de casos distintos: **9 aprovados**. Interrupção inicial continua sem causa comprovada; não foi tratada como correção de produto.
- `flutter build apk --debug`: sucesso, 13,5 s; APK normal instalado com `adb install -r` e aberto com `am start -W` (**Success / Status: ok**).

## 17. Execução F1-05 — processo real offline, 09/11/2026

**Roteiro:** `tool/verify_android_offline.py`, Python padrão + ADB, no app normal instalado, sem Flutter test runner. CT-003 e recuperação offline foram verificados para os campos existentes da fase de listas, não para produtos/preços futuros.

1. `python -m py_compile tool/verify_android_offline.py`: sucesso.
2. Primeira inspeção não encontrou o app visível; estado confirmou aparelho dozing/bloqueado. Nenhuma rede/lista alterada. Usuário desbloqueou e abriu o app; nova `--inspect` identificou controles e capturou a home.
3. Execução aprovada pelo usuário: `python tool/verify_android_offline.py --adb C:\Users\Rodolpho\AppData\Local\Android\Sdk\platform-tools\adb.exe --serial RXCY300NZZH --run`: **saída 0**.
4. Modo avião ativo, Wi-Fi desligado e **Active default network: none** confirmados antes de criar uma lista própria com orçamento R$ 123,45.
5. `am force-stop` encerrou o processo; novo lançamento mudou PID **11518→15073**. Nome/orçamento recuperados na interface e captura revisada.
6. Somente a própria lista foi removida pelo diálogo de confirmação. `cleanup_ok=true`; modo avião voltou **0**, Wi-Fi **1** e stay-on **0**, iguais aos originais. Checagem posterior confirmou rede padrão reconectada.

Evidência local em `build/offline_verification/result.json`, `form_keyboard.png` e `after_restart_offline.png`, ignorados pelo Git. Capturas inspecionadas: ações acima do teclado físico/IME e dados preservados em AMOLED após novo processo. **Resultado: 1 roteiro E2E aprovado**, além dos 105/9 testes Flutter.

**Saída da Fase 1:** modelo/banco/repositório/UI/reinício aprovados; erros não produzem sucesso nem apagam inputs, exclusão exige confirmação e app funciona offline no escopo implementado. Não há novo esquema nem limpeza de banco para reparar migração. Limites reais: runner intermitente, preferências de tema não persistidas, sem auditoria completa TalkBack/OLED ou build iOS/release. Produtos, preços, finalização e histórico ainda não implementados.

Verificação final: `dart format --output=none --set-exit-if-changed .` retornou **0, 28 arquivos sem alterações**; `python -m py_compile tool/verify_android_offline.py` retornou 0. O fetch confirmou que origin/main e HEAD estavam alinhados antes do novo commit. Capturas, JSON, APK e AGENTS.md permaneceram ignorados.

## 18. Execução F2-01 — modelo puro de item, 10/11/2026

Requisitos: RF-02/D-002 e campos da seção 5 de ARCHITECTURE. CT-006/UX-002 são cobertos **apenas no domínio**: null não vira 1; ainda não há CRUD, formulário ou persistência de itens. Origem/posição/remoção são representação, sem marcar F2-04/05 como prontas.

`test/unit/shopping_item_test.dart`: **24 testes novos**, cobrindo quantidade ausente/explícita/uma/cinco unidades, rejeição de zero/negativos, identidade/vínculo/nome vazios, trim/nome livre, nomes iguais, origens, posição e data de remoção UTC preservando os dados.

Comandos efetivamente executados, SDK Flutter 3.47.9/Dart 3.13.7 instalado:

- Primeira tentativa restrita de `flutter test test/unit/shopping_item_test.dart` não produziu saída e foi interrompida; não contou como execução aprovada. Repetida com acesso ao SDK fora da workspace.
- **RED:** `flutter test test/unit/shopping_item_test.dart` saiu 1 por arquivo/tipos ainda ausentes. Nenhuma asserção executada nessa etapa.
- `dart format lib/features/shopping/domain/models/shopping_item.dart test/unit/shopping_item_test.dart`: 2 arquivos, 1 formatado.
- **GREEN:** `flutter test test/unit/shopping_item_test.dart`: saída 0, **24 aprovados**.
- `dart format --output=none --set-exit-if-changed .`: saída 0, **30 arquivos, nenhum alterado**.
- `flutter analyze`: saída 0, **No issues found!**, 13,9 s.
- `flutter test --reporter expanded`: saída 0, **129 aprovados/0 falhas** (105 anteriores + 24 novos).

Não houve falha de asserção nem mudança de expectativa para acomodar implementação. Integração Android, novo build/APK, teste offline físico e iOS **não executados nesta tarefa**: somente domínio ainda não ligado ao app foi acrescentado, sem alteração de UI, banco ou código nativo. Os resultados nativos da Fase 1 são históricos, não execuções desta entrega. O APK anterior continua sendo o último visualmente utilizável.

## 19. Execução F2-02 — migração e repositório de itens, 10/11/2026

Requisitos: RF-02/09, CT-004/006/049, integridade de lista ativa CT-046. CT-005 valida marcação persistida, não ocultação em UI. CT-021 valida vínculo/identidade ao renomear, ainda sem entradas de compra. F2-03/04/05 continuam pendentes nos seus critérios visuais/completos.

- `test/database/items_migration_test.dart`: **6 novos casos** com SQLite real. V1 publicada→v2 mantém todas as colunas/totais/datas, instalação nova tem mesmo esquema que upgrade, falha após tabela criada reverte DDL/versão e preserva v1, FK/cascade, CHECKs e unicidade. Não há exclusão/recriação de banco como recuperação.
- `test/database/shopping_items_repository_test.dart`: **25 novos casos**, incluindo criação/retry/conflito/UUID, null→1→5→null, renomeação com identidade/posição/origem preservadas, remoção UTC idempotente, isolamento por lista, ausentes/finalizadas, reabertura, falha SQL/retry, cascade atômico, concorrência, limite de posição e dado corrompido sem reparo destrutivo.
- Testes de banco anteriores passam a conferir a versão atual e duas tabelas; fixture de downgrade usa versão atual+1. Asserções sobre preservação, rollback, FK e falhas continuam. O arquivo v1 não mudou.
- `test/support/fake_shopping_repository.dart` declara as novas operações não suportadas: continua exclusivo dos testes de UI de listas, sem simular itens com uma implementação alternativa.

Execuções reais:

1. **RED:** `flutter test test/database/shopping_items_repository_test.dart --reporter expanded`: saída 1 por métodos/tipos ainda ausentes, nenhuma asserção executada. Log `build/f2-02-red.log`.
2. `dart format lib test/database/shopping_items_repository_test.dart test/database/items_migration_test.dart test/support/fake_shopping_repository.dart`: 22 arquivos processados/5 ajustados. Depois `dart format lib test integration_test`: 33/2 ajustados.
3. `flutter test test/database/shopping_items_repository_test.dart test/database/items_migration_test.dart --reporter expanded`: **31 aprovados**, saída 0. Log `build/f2-02-green.log`.
4. `flutter analyze`: **No issues found!**, 13,8 s, saída 0.
5. `flutter test --reporter expanded`: **160 aprovados/0 falhas** (129 anteriores + 31 novos), saída 0. Log `build/f2-02-regression.log`.
6. ADB encontrou Samsung SM-S936B `RXCY300NZZH` disponível. `flutter test integration_test/database_smoke_test.dart --no-uninstall -d RXCY300NZZH --verbose`: **10 aprovados**, saída 0. São 6 regressões + 4 novos cenários: upgrade/preservação, rollback/retry, CRUD/reabertura/null/concorrência/cascade e falha SQL/bloqueio de finalizada. Log `build/f2-02-android-db.log`.
7. `flutter test integration_test/app_smoke_test.dart --no-uninstall -d RXCY300NZZH --verbose`: primeira execução incompleta, saída **79**, sem testes concluídos e erro secundário de limpeza de temporário. Diagnóstico mostrou tela Awake/desbloqueada e nenhum crash AndroidRuntime no trecho consultado; não comprova causa. Repetição **do mesmo comando**, sem mudar código, flags ou expectativas: **3 aprovados**, saída 0. Logs `build/f2-02-android-ui.log` e `build/f2-02-android-ui-retry.log`. Causa original da interrupção continua sem confirmação.

Total nativo desta entrega: **13 casos distintos aprovados** (10 banco + 3 interface). A tentativa incompleta não é contada como aprovada.

8. `flutter build apk --debug`: aprovado em **15,0 s**. Cópia normal `marketlist-f2-02-debug.apk` com 193.741.371 bytes; SHA-256 `7ac45a8515255c176bd16f8229ac8c80bc5529126d8b3a07f07aae5e84f19fc2`. `adb install -r` retornou **Success** e `am start -W` **Status: ok / COLD**. Artefatos anteriores preservados.
9. `python tool/verify_android_offline.py --adb C:\Users\Rodolpho\AppData\Local\Android\Sdk\platform-tools\adb.exe --serial RXCY300NZZH --inspect`: saída 0, árvore identificou Minhas listas/Nova lista/Aparência, sem erro de carga. Inspeção somente de leitura, sem modificar rede/listas e sem alegar novo teste offline.
10. `dart format --output=none --set-exit-if-changed .`: saída 0, **33 arquivos sem alterações**.

Integração usa subpasta temporária exclusiva sob getDatabasesPath, com resolução/validação de raiz antes da limpeza. Não abre nem apaga o banco normal; `--no-uninstall` mantém a instalação e seus dados. Mudança de status para finalizada é fixture, não implementação da F5. Testes de interrupção de rede em aparelho normal/iOS não foram repetidos nesta tarefa. Não há preço, total de compra, formulário de item ou política de Desfazer implementados.

## 20. F2-03 — formulário de planejamento, 10/11/2026

- Novos testes: shopping_items_view_model_test.dart (9) e shopping_screen_test.dart (7): **16 aprovados**. Nome/quantidade, null, edição, erro/retry com mesmo ID, confirmação aguardada, bloqueio de salvar/cancelar/voltar, carga falha sem falso vazio, dispose e teclado simulado em 320×568/fonte 2×.
- Primeira análise encontrou 5 avisos de chaves em if; corrigidos antes dos testes. Análise seguinte: **No issues found**, saída 0. Não houve teste RED de domínio nesta tarefa; regras de modelo já estavam cobertas, os testes novos foram escritos junto à UI/coordenação.
- `dart format .`: **39 arquivos**, 1 ajustado na integração; a execução anterior lib/test formatou os arquivos novos.
- `flutter test test/unit/shopping_items_view_model_test.dart test/widget/shopping_screen_test.dart --reporter expanded`: **16 aprovados**.
- `flutter test --reporter expanded`: **176 aprovados/0 falhas**, log build/f2-03-regression.log.
- Integração app_smoke_test recebeu dois novos casos com SQLite isolado: criação/edição/null/retorno à rota e falha SQL real preservando campos/retry. Resultado nativo e build registrados no relatório da fase.

UX-001 está coberto na fatia de planejamento (nome/quantidade juntos); campo de preço só F3. Sem migração ou alteração das regras de dinheiro, sem alegar UX de compra completa.

Resultado F2-03 no Samsung: `flutter test integration_test/app_smoke_test.dart --no-uninstall -d RXCY300NZZH --verbose` → **5 aprovados**, saída 0. `flutter build apk --debug` → aprovado em 12,7 s; APK normal F2-03 instalado (**Success**) e aberto (**Status: ok**), preservando dados. Sem build iOS/release ou repetição de modo avião. Logs/artefatos ignorados pelo Git.

## 21. F2-04 — ordem estável, 10/11/2026

RED: `flutter test test/unit/shopping_item_test.dart --reporter expanded` saiu 1 porque o comparador ainda não existia, sem executar asserções (build/f2-04-red.log). Após implementar, `flutter analyze` passou sem problemas e `flutter test --reporter expanded` aprovou **181 testes/0 falhas** (176 anteriores + 5 novos), log build/f2-04-regression.log.

Novos casos: 2 de comparador (posição antes de nome/quantidade e desempate), 1 de ViewModel com carga fora de ordem/edição, 1 widget verificando posição vertical após renomear/recarregar e 1 SQLite com edição/reabertura/posição seguinte. `dart format .`: 39 arquivos, 4 formatados nos testes. Integração acrescentou um cenário visual equivalente com SQLite real; resultado no relatório da fase. Sem alterações no esquema, entrada de compra ou cálculo. UX-011 após **comprar** depende de F3; aqui se comprova estabilidade durante planejamento/edição.

F2-04 Android: `flutter test integration_test/app_smoke_test.dart --no-uninstall -d RXCY300NZZH --verbose` → **6 aprovados**, saída 0, log build/f2-04-android-ui.log. `flutter build apk --debug` → aprovado em 11,2 s; APK normal F2-04 instalado/aberto com Success/Status: ok.

## 22. F2-05 — remoção e fechamento da fase, 10/11/2026

RED: teste de ViewModel saiu 1 porque removeEditingItem/visibleItems/isRemoving ainda não existiam, sem executar asserções. GREEN: **26 testes** dos arquivos de estado/widget de produtos aprovados, incluindo **8 novos** (5 de estado + 3 widgets). Casos novos: projeção preserva ordem, confirmação aguardada/sem repetição, falha mantém campos, ausente não declara sucesso, finalizada bloqueia, ocultação na recarga e remoção explícita na UI.

`dart format .`: 39 arquivos, 5 ajustados na primeira execução; integração formatada na seguinte. `flutter analyze`: **No issues found!**, saída 0. `flutter test --reporter expanded`: **189 aprovados/0 falhas**, saída 0, build/f2-final-regression.log. `python -m py_compile tool/verify_android_offline.py`: aprovado. Nenhuma expectativa foi alterada para esconder bug.

Integração recebeu um cenário com erro SQL de remoção, rascunho mantido, retry, registro preservado e ocultação ao reabrir. Roteiro host estendido com --items para checar os produtos em novo processo offline. CT-050 de subtotal comprado, UX-001 completo com preço, UX-011 após compra e filtros/total continuam dependentes das fases seguintes.

Execução final real:

| Comando | Resultado |
| --- | --- |
| `flutter test integration_test/app_smoke_test.dart --no-uninstall -d RXCY300NZZH --verbose` | **7 aprovados**, saída 0, build/f2-final-android-ui.log |
| `flutter test integration_test/database_smoke_test.dart --no-uninstall -d RXCY300NZZH --verbose` | **10 aprovados**, saída 0, build/f2-final-android-db.log |
| `flutter build apk --debug` | Aprovado em **12,9 s**, APK normal Fase 2 instalado com install -r (Success) e aberto (Status: ok / COLD) |
| `python tool/verify_android_offline.py --adb C:\Users\Rodolpho\AppData\Local\Android\Sdk\platform-tools\adb.exe --serial RXCY300NZZH --inspect` | Aprovado; app normal visível, antes do roteiro offline |
| Mesmo roteiro com `--run --items` | **1 E2E aprovado**, saída 0; sem rede padrão, lista/produtos/quantidades/ordem/remoção recuperados após novo PID |
| `dart format --output=none --set-exit-if-changed .` | Saída 0, **39 arquivos sem alterações** |

JSON real: lista própria `TesteOfflineF2_11924b48`, PID **17532→19921**, offline_confirmed/items_persisted/removed_item_hidden/order_preserved/persisted_after_restart/cleanup_ok/network_settings_restored/screen_setting_restored **true**. Modo avião **0→1→0**, Wi-Fi **1→0→1**, stay-on restaurado **0**; nova inspeção confirmou rede padrão **251**. Só a lista própria foi excluída; nenhuma tabela/banco foi apagada/resetada. Evidências em build/offline_verification_f2, separadas da evidência F1.

Capturas de teclado e após reinício foram inspecionadas: ações acessíveis acima do IME real, nomes/quantidades legíveis em AMOLED e removido ausente. Não é auditoria completa de contraste/TalkBack. Resultado final: **189 convencionais + 17 nativos + 1 E2E offline aprovados**. Sem build iOS/release, preços/compra/finalização/histórico. Interrupções antigas do runner permanecem documentadas como históricas; execuções finais desta entrega passaram sem relaxar expectativas.

## 23. F3-01 — moeda exata e limites, 10/11/2026

Decisões D-028/029/030 aprovadas pelo usuário antes da implementação. money_test.dart acrescentou **17 testes**: parsing/roundtrip, zero versus ausência, 11 formatos/limites inválidos, formatação negativa/int64 mínimo, CT-026 e produto/soma sem overflow. Métodos puros, sem Flutter no domínio.

RED: `flutter test test/unit/money_test.dart --reporter expanded` saiu 1 por arquivo/métodos ausentes, sem asserções. `dart format` processou 3 arquivos, ajustou 2; `flutter analyze` passou sem problemas. Primeira regressão: **205 aprovados/1 falha** devido à mudança indevida de mensagem do orçamento; mensagem original restaurada sem alterar o teste. `flutter test --reporter expanded` seguinte: **206 aprovados/0 falhas**, saída 0, build/f3-01-regression-final.log.

Orçamento delega ao conversor e todos os 10 testes anteriores/fluxos widget continuam. Não houve banco, UI nova, build APK ou teste Android nesta tarefa; resultados nativos F2 são históricos. Novos cenários aprovados de produto gratuito/quantidade não confirmada serão exercitados no modelo/calculadora/UI nas tarefas seguintes, sem alegar compra implementada pelo parser.

## 24. F3-02 — entrada de compra, 10/11/2026

purchase_entry_test.dart: **18 novos testes** de modos exclusivos, valores/quantidades, identidade/vínculo, zero gratuito e subtotal com overflow recusado. RED saiu 1 por implementação ausente, sem asserções. `dart format` processou/ajustou 2 arquivos. `flutter analyze`: sem problemas. `flutter test --reporter expanded`: **224 aprovados/0 falhas**, saída 0, build/f3-02-regression.log. Sem alteração de banco/UI, teste Android ou novo APK nesta tarefa pura.

## 25. F3-03 — calculadora pura, 10/11/2026

shopping_calculator_test.dart: **22 novos testes**, cobrindo exemplos 1890/1266/4782→7938 centavos, pendente/parcial/completo/excedido, zero gratuito, direto/misto com quantidade não confirmada, removido fora do total, correção/exclusão de entrada, ordem/imutabilidade, IDs/vínculos inválidos e overflow monetário/de quantidade.

`flutter test test/unit/shopping_calculator_test.dart --reporter expanded` RED saiu 1 por arquivo/tipos ausentes. Primeira análise parou em 1 aviso de chaves em if; corrigido. Análise seguinte sem problemas. `dart format` ajustou os 2 arquivos novos; `flutter test --reporter expanded`: **246 aprovados/0 falhas**, saída 0, build/f3-03-regression.log. Casos CT/FIN de finalização/histórico permanecem cobertos apenas no domínio matemático aplicável, não como fluxo inteiro. Sem banco/UI novos ou testes Android nesta tarefa.

## 26. F3-04 — entradas persistidas e migração v3, 10/11/2026

purchase_repository_test.dart: **18 novos testes** de idempotência/concorrência, correção/exclusão, modo trocado com nulls, vínculo, finalizada/removido, gratuito, total/quantidade, rollback SQL/overflow/cascade e reabertura. entries_migration_test.dart: **5 novos testes** de preservação v2, rollback/retry, esquema novo/upgrade idêntico e CHECK/FK/ID/cascade reais. Testes anteriores conferem versão atual/terceira tabela, preservando asserções de dados; v1/v2 não mudaram.

RED saiu 1 por APIs ausentes. `dart format .`: 48 arquivos, 3 ajustados nessa execução após formatação inicial do código. `flutter analyze`: sem problemas. Primeiro GREEN do repositório: **16 aprovados**. Primeira regressão: **267 aprovados**; após 2 novos cenários de concorrência extrema/cascade, `flutter test --reporter expanded`: **269 aprovados/0 falhas**, saída 0, build/f3-04-regression-final.log. Resultados nativos/APK no relatório da fase. Ainda sem UI de preços.

F3-04 Android: database_smoke_test com --no-uninstall/-d RXCY300NZZH/--verbose → **13 aprovados**; app_smoke_test com mesmas flags → **7 aprovados**. Logs build/f3-04-android-db.log e f3-04-android-ui.log. Build debug aprovado em 12,5 s; APK normal F3-04 instalado/aberto com Success/Status: ok. Sem uso de banco normal pelos testes. A verificação final de formatação abrange 48 arquivos Dart.

## 27. F3-05 — estado financeiro, 10/11/2026

shopping_purchase_state_test.dart acrescenta **12 casos**: total desconhecido/carregado, prévia separada, commit aguardado/toque duplo, falha com ID/texto mantidos, entradas inválidas/overflow, gratuito explícito, correção/exclusão, finalizada, remoção de produto e carga com erro preservando total anterior.

RED saiu 1 por APIs ausentes, sem asserções. Formatação dos 3 arquivos ajustou 3. Análise inicial teve 8 avisos de estilo, corrigidos por `dart fix --apply --code=curly_braces_in_flow_control_structures` em 2 arquivos; análise seguinte **No issues found**. `flutter test --reporter expanded`: **281 aprovados/0 falhas**, saída 0, build/f3-05-regression.log.

Primeira integração app_smoke_test --no-uninstall/-d RXCY300NZZH/--verbose saiu **79**, sem testes completos. Diagnóstico ADB da repetição encontrou **Dozing, showing=true, inputRestricted=true**; usuário foi solicitado a desbloquear. Não declarar a suíte aprovada enquanto não houver execução concluída. Caso novo acessa o ViewModel real pela rota e provoca falha SQL para provar que prévia não entra no total; não é ainda teste de campo de preço visual.

Segunda tentativa ainda bloqueada também saiu 79. Após resposta do usuário/desbloqueio e keep-awake USB temporário, o mesmo comando passou **8 testes**, saída 0, build/f3-05-android-ui-unlocked.log. Sem mudança de asserções. O wrapper captura stay-on e restaura em finally. Não se extrapola esse diagnóstico para explicar todas as interrupções antigas do SDK.

Build normal F3-05 aprovado em 11,0 s, install -r Success e am start Status: ok/COLD. Stay-on restaurado 0, igual ao original. 49 arquivos Dart na verificação final; sem nova migração ou iOS/release.

## 28. F3-06 — múltiplos preços no painel, 10/11/2026

purchase_entry_sheet_test.dart acrescenta **8 testes de widget**: dois preços→1890, correção/substituição/exclusão isolada, valor direto/não confirmado, gratuito, erro/retry, confirmação pendente, validação e teclado/fontes. Primeira execução **7 aprovados/1 falha**: em 320×568/fonte 2×, trailing comprimía o nome e seu ponto de toque ficava fora do viewport. Corrigido layout para valor abaixo do status em tela estreita/fonte grande, sem afrouxar expectativas; seguinte **8 aprovados**.

`dart format .`: 52 arquivos; `flutter analyze`: sem problemas. `flutter test --reporter expanded`: **289 aprovados/0 falhas**, saída 0, build/f3-06-regression.log. `flutter test integration_test/app_smoke_test.dart --no-uninstall -d RXCY300NZZH --verbose`: **10 aprovados**, saída 0, build/f3-06-android-ui.log. Novos 2 nativos registram/corrigem/excluem múltiplos preços e comprovam erro SQL com campos/total preservados. Banco/contrato não mudaram. Corpo exibe total confirmado no cabeçalho; barra inferior e filtros continuam para F4. Resultado do APK no relatório da fase.

F3-06 build debug aprovado em 11,2 s; normal instalado/aberto (Success/Status: ok/COLD), cópia marketlist-f3-06-debug.apk. Sem uninstall ou novo esquema.

## 29. Fase 4 — tela de compra e Desfazer

Os widgets cobrem os quatro estados de compra, a ordem e o total ao alternar filtros (UX-011 a UX-016), o rodapé durante a rolagem de 100 produtos (UX-017), teclado e fonte ampliada (UX-005/018) e o anúncio agrupado de nome, estado, quantidade e subtotal (UX-019). O orçamento opcional passa pelos casos CT-028 a CT-031, inclusive zero explícito, erro de gravação e edição em lista ativa.

Para D-032, os testes de widget verificam restauração do subtotal e da posição, expiração após cinco segundos e cancelamento ao voltar da lista. Os testes SQLite conferem que a restauração depende do instante de remoção correspondente, recusa lista finalizada e reverte a operação quando o total restaurado ultrapassaria o limite monetário. O esquema do banco de compras continua na versão 3.

- `dart format` nos oito arquivos Dart alterados da F4-06 deixou todos no padrão do formatador.
- `flutter analyze` terminou sem problemas.
- `flutter test --reporter expanded` passou **311 testes**.
- `flutter test integration_test --no-uninstall --concurrency=1 -d RXCY300NZZH --reporter expanded` passou **26 testes** no Samsung. A suíte incluiu filtro, orçamento, Desfazer, migrações e preferência AMOLED restaurada com fundo `#000000`.
- `flutter build apk --debug` gerou o APK normal, preservado em `build/app/outputs/flutter-apk/marketlist-f4-debug.apk`. `adb install -r` retornou `Success` e a abertura retornou `Status: ok`.
- `python tool/verify_android_offline.py --adb <caminho-adb> --serial RXCY300NZZH --run --purchases` passou no APK normal. Com modo avião ativo e sem rede padrão, o ensaio registrou três unidades de R$ 4,22 e uma compra de R$ 47,82 por valor direto. Após trocar o processo, a tela recuperou as duas compras, o total de R$ 60,48 e mostrou R$ 62,97 disponíveis. A captura com teclado real mostra o botão Salvar produto acima do teclado. O roteiro removeu a lista criada para o ensaio e confirmou a restauração da rede e da configuração de tela. Evidências em `build/offline_verification_f3/`.

A leitura em voz alta com TalkBack segue pendente de inspeção manual. Os testes de semântica verificam os dados disponibilizados ao leitor de tela.

## 30. Fase 5 — conferência e finalização

Os testes de domínio cobrem FIN-002, FIN-003 e FIN-013. Preservam a ordem e a soma quando a conferência reúne itens pendentes, parciais e com quantidade não confirmada. O teste RED da F5-01 falhou pela ausência da agregação. O teste RED da F5-05 falhou pela ausência da operação transacional.

Na interface, os testes cobrem a revisão mesmo com todos os itens comprados, orçamento opcional, saldo e excedente, retorno à edição, validação do caixa e diferença em centavos. Um teste de confirmação concorrente preserva o rascunho e exige novo toque quando os dados revisados mudam. O teste em tela de 320 × 568, fonte 2× e teclado simulado reproduziu sobreposição. Com rótulos mais curtos nesse espaço, o total e a confirmação ficam acessíveis.

Os testes SQLite conferem caixa vazio e zero, persistência separada dos valores, dupla finalização, rollback SQL e bloqueio de todas as gravações sobre uma compra finalizada. A leitura usa o total final armazenado, inclusive para compras antigas. O banco de compras continua na versão 3.

- `dart format` nos oito arquivos Dart da F5-06 deixou todos no padrão do formatador.
- `flutter analyze` terminou sem apontamentos.
- `flutter test --reporter expanded` passou **330 testes**.
- `flutter test integration_test --no-uninstall --concurrency=1 -d RXCY300NZZH --reporter expanded` passou **27 testes** no Samsung. O aparelho estava em modo avião, com Wi-Fi desligado e sem rede padrão antes e depois da suíte. O caso F5 provocou falha SQL, manteve a compra ativa e preservou o caixa digitado. A nova tentativa abriu a compra somente para consulta e retirou a lista das ativas. Ao reabrir o SQLite, o total registrado de R$ 10,50, o caixa de R$ 11,50 e as duas unidades faltantes permaneceram disponíveis.
- `flutter build apk --debug` gerou `build/app/outputs/flutter-apk/marketlist-f5-debug.apk`. Instalação com `adb install -r` retornou `Success` e abertura a frio retornou `Status: ok`. As configurações de rede e tela foram restauradas.

A listagem de compras anteriores e a navegação de histórico pertencem à Fase 6.

## 31. F6-01 — listagem do histórico

Em **Minhas listas**, o ícone **Histórico** abre a lista de compras finalizadas com nome, data e horário locais e total registrado na finalização. O SQLite seleciona as listas pelo estado finalizado. O repositório compara os instantes de conclusão em Dart, do mais recente ao mais antigo, e usa o ID em ordem crescente como desempate. Isso preserva a ordem com datas gravadas em versões antigas, que podem ter frações de segundo com larguras diferentes. A consulta lê somente os registros das listas e mantém o esquema na versão 3.

- RED de `flutter test test/database/shopping_repository_test.dart --reporter expanded` falhou pela ausência de `listFinalizedLists`.
- Os dois novos casos de SQLite conferem exclusão de ativas, ordem, empate, frações de segundo, reabertura e integridade dos registros. Quatro testes unitários cobrem ordenação, carga simultânea, falha e descarte do ViewModel.
- `flutter test test/widget/history_screen_test.dart --reporter expanded` passou quatro casos após corrigir o atalho na tela inicial. Os widgets verificam conteúdo, ordem, erro com nova tentativa, vazio e fonte 2× em tela de 320 × 568.
- `dart format` verificou os 11 arquivos Dart da entrega. `flutter analyze` terminou sem apontamentos e `flutter test --reporter expanded` passou **340 testes**.
- `flutter test integration_test --no-uninstall --concurrency=1 -d RXCY300NZZH --reporter expanded` passou **28 testes** no Samsung. O novo cenário abriu o histórico pela tela inicial, exibiu duas compras de meses diferentes na ordem esperada e recuperou os mesmos dados após reabrir o SQLite. Modo avião, Wi-Fi desligado e ausência de rede padrão foram confirmados durante o ensaio. As configurações de rede e tela foram restauradas.
- `flutter build apk --debug` gerou `build/app/outputs/flutter-apk/marketlist-f6-01-debug.apk`. A instalação com `adb install -r` retornou `Success` e a abertura a frio retornou `Status: ok`.

Q-005 sobre exclusão histórica permanece pendente. A consulta da F6-01 usa os registros já finalizados.

## 32. F6-02 — detalhe histórico somente para consulta

Ao tocar em uma compra no Histórico, o app carrega a fotografia SQLite pelo ID e exibe produtos e entradas da compra selecionada. As quantidades e os subtotais são obtidos da calculadora existente. Uma compra parcial de cinco unidades planejadas, com duas a R$ 3,50 e uma a R$ 4,20, mostra três compradas, duas faltantes e subtotal de R$ 11,20. Entradas de valor direto mantêm a indicação de quantidade não confirmada quando existe planejamento, conforme D-030. Itens removidos ficam fora da tela.

Os três novos testes de widget cobrem CT-012, CT-017, FIN-007 e FIN-016 na interface, além de erro com nova tentativa, compra vazia e tentativa de abrir um registro ativo pelo histórico. A tela usa a leitura existente do repositório e o esquema do banco de compras permanece na versão 3.

- `dart format` formatou os cinco arquivos Dart da entrega.
- `flutter analyze` terminou sem apontamentos.
- `flutter test --reporter expanded` passou **343 testes**.
- `flutter test integration_test --no-uninstall --concurrency=1 -d RXCY300NZZH --reporter expanded` passou **29 testes** no Samsung, em modo avião com Wi-Fi desligado. O novo caso fechou e reabriu o SQLite, abriu o detalhe pelo Histórico, conferiu quantidades, preços e subtotal e verificou que o repositório recusou alterar a entrada finalizada. As configurações de rede e tela foram restauradas.
- `flutter build apk --debug` gerou `build/app/outputs/flutter-apk/marketlist-f6-02-debug.apk`. A instalação com `adb install -r` retornou `Success` e a abertura a frio retornou `Status: ok`.

## 33. F6-03 e F6-04 — valores registrados e busca de produtos

Na F6-03, o detalhe mostra o total calculado gravado, o orçamento e o valor do caixa em campos separados. Dois testes de widget cobrem FIN-022/023, inclusive valores opcionais ausentes, zero e total persistido que difere da soma das entradas. `flutter analyze` terminou sem apontamentos e `flutter test --reporter expanded` passou **345 testes**.

Na F6-04, uma consulta SQLite reúne produtos comprados de listas finalizadas e suas entradas. O filtro em Dart usa trecho literal, ignora maiúsculas e preserva acentos. Os resultados são ordenados pela conclusão, com desempate pela lista e posição do item. O teste RED falhou pela ausência do método. Um teste SQLite cobriu CT-043/045, inclusive preços múltiplos, exclusão de compras ativas e itens removidos, e caracteres literais. Três testes de widget cobriram navegação, busca vazia, falha com retry e resposta atrasada. `flutter analyze` terminou sem apontamentos e `flutter test --reporter expanded` passou **349 testes**.

## 34. F6-05 — preservação do histórico entre compras

O teste SQLite de CT-044 e CT-046 finaliza duas compras de Arroz 5 kg, em novembro de 2026 e janeiro de 2027, com preços unitários de R$ 19,00 e R$ 24,00. O repositório recusa edição de preço, edição de orçamento e exclusão da compra antiga. Após reabrir o banco, as linhas da compra, do produto e da entrada de 2026 são idênticas às originais. A busca recupera os dois preços e a compra antiga mantém total de R$ 38,00, orçamento de R$ 50,00 e caixa de R$ 40,00.

- `dart format` formatou os dois arquivos Dart da F6-05.
- `flutter analyze` terminou sem apontamentos.
- `flutter test --reporter expanded` passou **350 testes**.
- `flutter test integration_test --no-uninstall --concurrency=1 -d RXCY300NZZH --reporter expanded` passou **30 testes** no Samsung, com modo avião ativo, Wi-Fi desligado e ausência de rede padrão confirmada antes e depois. O novo caso reabriu o SQLite, buscou o produto, mostrou os dois preços e recuperou total, orçamento e caixa da compra antiga no detalhe. As configurações do aparelho foram restauradas.
- `flutter build apk --debug` gerou `build/app/outputs/flutter-apk/marketlist-f6-debug.apk`. A instalação com `adb install -r` retornou `Success` e a abertura a frio retornou `Status: ok`.

## 35. F7-01 — rede e reinício

`python -B tool/verify_android_offline.py --adb <caminho-adb> --serial RXCY300NZZH --run --purchases --network-cycle` passou no APK normal da F6. O Samsung criou a lista e registrou R$ 12,66 sem rede, recuperou a rede padrão com a compra aberta e voltou a ficar offline no mesmo processo. Registrou então R$ 47,82 sem rede. Um `am force-stop` encerrou o processo. Após abrir novamente em modo avião, outro PID recuperou orçamento, compras e total de R$ 60,48. O roteiro removeu a lista de teste e restaurou rede e tela. Evidência em `build/offline_verification_f7/result.json`.

Esse ensaio cobre CT-036 a CT-040 e UX-010. A integração Android da seção 34 cobre CT-041 com histórico e detalhe finalizado offline.

## 36. F7-02 — recuperação e integridade

Dois testes abrem cópias de arquivos SQLite temporários após fechar a última conexão. A cópia v2 migra para v3, preserva lista, itens e valores finais e deixa o arquivo de origem idêntico. A cópia v3 recupera uma compra com entrada confirmada, total de R$ 10,50 e caixa de R$ 11,00. As duas passam `PRAGMA integrity_check` e `foreign_key_check`. O ensaio valida a recuperação em teste, enquanto a decisão Q-007 sobre exportação no app segue aberta.

`dart format` formatou os dois testes, `flutter analyze` terminou sem apontamentos e `flutter test test/database --reporter expanded` passou **119 testes**, incluindo falha de migração, rollback de finalização e nova tentativa.
