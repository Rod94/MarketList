# SPEC.md — Aplicativo de Lista de Supermercado

**Versão:** 0.3 (referências documentais consolidadas em 07/11/2026)  
**Status:** Requisitos principais consolidados; detalhes específicos ainda sujeitos a revisão. Não é uma implementação  
**Objetivo:** orientar o desenvolvimento incremental e os testes, sem antecipar decisões técnicas.

## 1. Visão do produto

Aplicativo simples para preparar uma lista em casa, registrar os preços conforme os produtos entram no carrinho e acompanhar o **total acumulado em tempo real**, reduzindo surpresas no caixa. Deve permitir adaptações espontâneas durante a compra, funcionar offline e preservar um histórico consultável de valores pagos.

**Princípio:** o sistema informa e organiza; não obriga o usuário a seguir o planejamento nem bloqueia a finalização por pendências ou excesso de orçamento.

## 2. Jornada principal

1. **Em casa:** criar uma lista e adicionar produtos com quantidade planejada opcional. Preços não são exigidos.
2. **No mercado:** registrar quantidade efetivamente comprada e preço; ver subtotal e total atualizarem imediatamente.
3. **Durante a compra:** incluir itens que não estavam planejados, retirar itens e corrigir valores ou quantidades livremente.
4. **Ao finalizar:** conferir total registrado, orçamento e saldo (se informado), pendências e compras parciais, com opção de informar o valor cobrado no caixa; confirmar ou voltar à edição.
5. **Depois:** consultar listas anteriores e os valores pagos, inclusive offline, sem editar uma compra finalizada.

## 3. Requisitos funcionais aprovados

### RF-01 — Listas
- Criar lista com nome e data de criação.
- Consultar listas, editar seu conteúdo enquanto estiver em andamento e remover uma lista.
- Persistir listas e alterações confirmadas, inclusive sem internet.
- Ao finalizar, registrar data de conclusão e total da compra.

### RF-02 — Produtos planejados
- Adicionar e remover itens por nome.
- A **quantidade planejada é opcional**. Ausência de quantidade não equivale a uma unidade.
- Permitir editar nome e quantidade planejada.
- Não exigir marca, foto, código de barras nem categoria para cadastrar um item.
- O nome pode incluir apresentação/embalagem, como `Arroz 5 kg`, sem criar campos adicionais obrigatórios.

### RF-03 — Registros de compra e preços
- Um item pode conter **várias entradas de compra**, cada uma com sua quantidade e preço unitário.
- Cada entrada calcula `quantidade comprada × preço unitário`; o subtotal do item soma todas as entradas.
- Permitir **valor direto sem quantidade** (ex.: `Carne: R$ 47,82`); esse valor entra uma vez no subtotal.
- Permitir corrigir/excluir uma entrada de compra; subtotal e total devem ser recalculados sem duplicar valores.
- Quantidade planejada e quantidade efetivamente comprada são informações distintas.
- Usar cálculos monetários exatos em centavos, sem erros de ponto flutuante.
- Preço/valor direto **zero explícito** representa compra gratuita; campo vazio continua sem registro de preço (D-028, aprovado em 10/11/2026).
- Rejeitar valores, produtos ou somas que não caibam em centavos inteiros assinados de 64 bits, sem teto comercial adicional (D-029).
- Item com quantidade planejada e entrada de valor direto fica como **quantidade não confirmada**, inclusive se misturado com entradas por unidade que já atinjam o planejado. Valores entram na soma; item permanece em A comprar (D-030).

### RF-04 — Itens descobertos no mercado
- O usuário pode adicionar, pelo botão `+`, qualquer item que não estava na lista original.
- Se informar preço e quantidade (ou valor direto), o item entra na compra com valor contabilizado.
- Se adicionar sem preço, permanece pendente, sem impedir a compra.
- Não exigir indicação manual de marca ou motivo da compra.

### RF-05 — Flexibilidade
- Permitir comprar quantidade menor, igual ou maior que a planejada.
- Permitir remover itens durante a compra, inclusive itens planejados que o usuário decidiu não levar.
- Nenhuma diferença entre planejado e comprado impede o andamento.

### RF-06 — Total e orçamento
- Exibir o **total registrado** sempre visível durante o uso da lista, inclusive ao rolar uma lista longa.
- Atualizar o total imediatamente ao adicionar, alterar ou remover preços/entradas/itens.
- O **orçamento é opcional** por lista.
- Quando existir orçamento, mostrar gasto atual e saldo restante (ou valor excedido).
- Se excedido, apenas alertar; jamais bloquear novos registros ou finalização.

### RF-07 — Finalização
- **Sempre** exibir tela de confirmação antes de finalizar, mesmo sem pendências, pois a lista se tornará somente leitura.
- Exibir o total calculado e, quando houver orçamento, a diferença entre orçamento e total.
- Se houver itens sem registro de compra, exibir aviso consolidado indicando os nomes.
- Se a quantidade comprada for menor que a planejada, informar quantas unidades faltaram.
- O aviso não deve aparecer como uma sequência de perguntas individuais.
- Oferecer **Voltar e revisar** e **Confirmar finalização**.
- A finalização deve ser possível mesmo com itens pendentes, compras parciais ou orçamento excedido.
- Itens sem compras registradas ao finalizar ficam identificados como **não comprados** no histórico.
- Compras parciais preservam quantidades planejada, comprada e faltante.
- Itens registrados com valor permanecem contabilizados no total, mesmo se a quantidade planejada não foi totalmente atendida.
- Incluir campo **opcional** para valor efetivamente cobrado no caixa; quando informado, mostrar a diferença para o total calculado. Não alterar preços dos itens para fazê-los coincidir.
- Após confirmação, não permitir alterações nos itens, preços, quantidades nem valores da lista finalizada pelo fluxo normal.

### RF-08 — Histórico somente para consulta
- Guardar listas finalizadas com nome, datas, itens, quantidades planejadas e compradas, entradas de preço, subtotais, total e estados de compra.
- Permitir consultar compras anteriores por lista/data e localizar produtos pelo nome.
- Preservar o **total calculado pelos produtos** e, quando informado, o **valor efetivamente cobrado no caixa**, sem substituir nenhum valor por preços de compras posteriores.
- Exemplo: consultar em 2027 quanto custou `Arroz 5 kg` em novembro de 2026.
- O objetivo inicial é **consulta simples**, não relatórios ou gráficos sofisticados.
- Histórico deve funcionar sem internet.
- Listas finalizadas ficam em modo **somente leitura**; não existe função de reabrir a compra para edição no MVP.

### RF-09 — Offline e persistência
- Criar listas, registrar itens e preços, calcular totais, finalizar e consultar o histórico sem conexão.
- Ao fechar e reabrir o aplicativo, recuperar todas as alterações previamente confirmadas.
- Uma queda de internet não pode interromper a compra em andamento.
- Não exigir login/conexão para executar a jornada principal no MVP.


### RF-10 — Tela principal e inclusão rápida
- Formulário compacto ao tocar em `+`: nome, quantidade opcional e preço opcional aparecem juntos, sem marca ou fotografia obrigatórias.
- Tocar num produto existente abre suas entradas de preço; o botão **Adicionar outro preço** insere uma segunda entrada no mesmo item.
- Ao confirmar uma entrada de preço, incluir seu valor imediatamente no total da compra; durante a digitação, mostrar apenas uma prévia do subtotal.
- Produtos não mudam de lugar ao serem comprados; preservar a ordem original de cadastro.
- Filtro **Todos** mostra todos os itens não removidos; **A comprar** mostra pendentes e parcialmente comprados. A seleção do filtro não altera o total.
- O total fica sempre visível enquanto a lista rola.
- Tema claro e modo escuro AMOLED, com fundo principal preto verdadeiro (`#000000`) e excelente contraste e legibilidade.

### RF-11 — Diretrizes de qualidade do projeto
- Flutter e Dart, construindo APK Android primeiro, com base de código preparada para iOS.
- Código organizado por funcionalidades, legível e com responsabilidades separadas.
- Cada funcionalidade terá critérios de aceite e testes aplicáveis antes de ser considerada concluída.
- Testes incrementais e regressão a cada fase; explicações didáticas dos conceitos de Dart/Flutter e dos arquivos alterados.

## 4. Regras de negócio e exemplos

| Regra | Situação | Comportamento esperado |
|---|---|---|
| RN-01 | `Sabonete`: 3 × R$ 3,50 + 2 × R$ 4,20 | Subtotal R$ 18,90 |
| RN-02 | Item `Carne` sem quantidade, valor R$ 47,82 | Subtotal R$ 47,82 |
| RN-03 | `Leite` não planejado: 3 × R$ 4,22 | Adicionar à lista e ao total R$ 12,66 |
| RN-04 | Planejado 5, comprado 3 | Avisar `faltaram 2` na revisão; finalizar permitido |
| RN-05 | Planejado 5, comprado 6 | Aceitar sem bloquear; preservar ambos os números |
| RN-06 | `Azeite` sem valor ao finalizar | Avisar; se usuário confirmar, guardar como não comprado |
| RN-07 | Corrigir preço de R$ 25,90 para R$ 23,90 | Substituir o preço, não somar os dois |
| RN-08 | Orçamento R$ 100, total R$ 125 | Mostrar excedente de R$ 25; compra continua permitida |
| RN-09 | Reabrir app em modo avião | Lista e dados confirmados permanecem disponíveis |
| RN-10 | Consultar arroz comprado em outro mês | Exibir preço da compra histórica, não o mais recente |
| RN-11 | Preço registrado + confirmado | Atualizar imediatamente o valor total, sem exigir um segundo check de compra |
| RN-12 | Compra calculada R$ 527,80; caixa cobrou R$ 530,20 | Mostrar diferença R$ 2,40 e preservar ambos no histórico |
| RN-13 | Finalizar compra completa | Mostrar confirmação final e depois tornar somente leitura |
| RN-14 | Filtrar `A comprar` | Não reorganizar os itens nem alterar o total |

**Nota:** o total representa os valores **registrados** no aplicativo. Se algum produto não foi lançado ou houver descontos/encargos não informados, o valor do caixa poderá diferir.

## 5. Modelo conceitual inicial (sem impor banco ou linguagem)

- **Lista**: identificador, nome, criação, conclusão opcional, status, orçamento opcional, total final calculado e valor opcional cobrado no caixa.
- **Item da lista**: identificador, nome, quantidade planejada opcional, origem (planejado ou adicionado durante a compra), status derivado/registrado conforme contexto.
- **Entrada de compra**: identificador, item vinculado, quantidade comprada opcional, preço unitário opcional, valor direto opcional, subtotal.
- **Valores agregados**: subtotal por item e total por lista calculados a partir das entradas válidas.

As regras de apresentação e de persistência estão detalhadas em `DESIGN.md` e `ARCHITECTURE.md`; as decisões em aberto estão registradas em `DECISIONS.md`.

## 6. Critérios de aceite essenciais

- O usuário consegue montar a lista em casa sem cadastrar preço.
- Em poucos passos, consegue registrar o preço ao colocar um produto no carrinho.
- O sistema aceita valores diferentes no mesmo item e compra sem quantidade.
- O total é confiável, atualiza de imediato e fica visível durante a compra.
- É possível inserir itens espontâneos e retirar itens sem bloqueios.
- Finalização com pendências ou compra parcial apenas avisa e oferece escolha.
- Histórico preserva as condições, preços e eventual valor do caixa de cada compra realizada, em somente leitura.
- A confirmação final sempre mostra o total e permite revisar antes de tornar a lista somente leitura.
- Produtos mantêm a ordem original, filtros não alteram o total e o modo AMOLED usa preto verdadeiro.
- Jornada principal funciona offline e mantém informações após reinicialização.

## 7. Qualidade e estratégia de testes

- Cada funcionalidade deve ter critérios de aceite verificáveis antes de ser considerada concluída.
- Usar **TDD preferencialmente nas regras de cálculo e de negócio**; testes de integração para persistência; testes de interface para fluxos reais no celular.
- Cada etapa deverá executar testes novos e testes de regressão pertinentes.
- Testar valores fracionários, alterações, exclusões, registros duplicados por toque repetido, compras parciais, finalizar com pendências, orçamento excedido, reabertura offline e interrupções inesperadas.
- Ao fim de cada etapa: disponibilizar uma versão utilizável para validação, apresentar testes executados e resultados, e atualizar a documentação.
- Detalhes e identificadores de casos de teste serão mantidos em `TESTING.md`.

## 8. Fora do escopo inicial / evoluções possíveis

- Reconhecimento de produtos por foto, código de barras, marcas obrigatórias ou catálogos extensos.
- Gráficos avançados, comparações automáticas complexas e análises de inflação.
- Sincronização simultânea entre dois celulares ou contas de usuário.
- Importação de notas fiscais e comparação automática com preços online.
- Duplicação de listas anteriores como atalho: ideia útil, mas pode ser planejada como evolução se necessário.

## 9. Decisões tomadas e detalhes ainda abertos

**Já decididos:**

- MVP em Flutter/Dart, APK Android, com compatibilidade futura com iOS.
- Banco SQLite local e funcionamento sem internet.
- Interface compacta, AMOLED preto verdadeiro, total fixo, itens na ordem de inclusão e filtro `A comprar`.
- Confirmação final sempre visível, com total, pendências, orçamento opcional e valor opcional do caixa.
- Histórico após a finalização **somente leitura**.
- Sem campo de marca obrigatório.

**Ainda a validar:**

1. Ao remover um produto durante a compra, quanto tempo a interface oferece **Desfazer**? (O item sai imediatamente do total.)
2. Quando se digita um nome igual a produto existente, oferecer reaproveitar o item sem bloquear duplicatas legítimas.
3. Se houver preço direto em um item com quantidade planejada, como apresentar que a quantidade comprada não foi confirmada?
4. Atalho para duplicar lista anterior: adiar para evolução após MVP.
5. Exportação/backup local dos dados: analisar depois, considerando perda em desinstalação/troca de aparelho.

## 10. Documentação complementar e fluxo

- `ARCHITECTURE.md`: arquitetura técnica proposta para validar no scaffold.
- `DESIGN.md`: experiência de uso, telas e diretrizes visuais.
- `DECISIONS.md`: decisões aprovadas, propostas técnicas e questões abertas.
- `TESTING.md`: catálogo de testes, prioridades e critérios de aceite.
- `TASKS.md`: entregas pequenas e validáveis por fase.
- `../AGENTS.md`: orientações para o Codex, incluindo explicações didáticas.

**Progresso de implementação** — As Fases 0 a 7 estão concluídas para o APK de teste Android. Consulte [TASKS.md](TASKS.md) para o estado das entregas e o [relatório da Fase 7](PHASE_7_REPORT.md) para as evidências e os limites da validação.
