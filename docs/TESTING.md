# TESTING.md — Estratégia e casos de teste do aplicativo de supermercado

**Versão:** 0.3 — catálogo de produto planejado; Fase 0 e domínio F1-01 testados  
**Data:** 09/11/2026 (catálogo original: 07/11/2026)  
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
flutter test integration_test
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
