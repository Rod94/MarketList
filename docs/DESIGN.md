# DESIGN.md — Interface e experiência do aplicativo de supermercado

**Versão:** 0.1 — proposta de execução, baseada nos fluxos aprovados  
**Data:** 07/11/2026  
**Referências:** `SPEC.md`, `ARCHITECTURE.md`, `TESTING.md`, `DECISIONS.md`  
**Plataforma inicial:** Android; componentes e regras projetados para futura versão iOS.

> **Objetivo de experiência:** estar no supermercado, registrar o que entrou no carrinho e saber o total acumulado com o menor esforço possível. Clareza é mais importante que efeitos visuais.

## 1. Princípios aprovados

1. **Uso rápido e com uma mão.** Ações comuns próximas da parte inferior e com áreas de toque confortáveis.
2. **Uma compra real, não uma lista rígida.** Planejar em casa, inserir itens espontâneos no mercado, remover, comprar mais/menos e informar vários preços por produto.
3. **Preço confirmado atualiza o total.** A prévia enquanto digita não modifica o total oficial; a confirmação salva e atualiza imediatamente.
4. **Poucos campos.** Produto obrigatório; quantidade e preço opcionais; nenhuma exigência de marca, foto ou categoria.
5. **Previsibilidade.** Itens mantêm ordem de inclusão; o filtro `A comprar` não muda valores, nem reordena a lista.
6. **AMOLED verdadeiro.** Fundo principal `#000000` no modo escuro, sem gradientes decorativos; contraste e hierarquia continuam essenciais.
7. **Avisar, não impedir.** Pendências, compras parciais e orçamento excedido não bloqueiam a finalização.
8. **Final é final.** A última revisão deixa claro que a lista encerrada ficará disponível apenas para consulta.

## 2. Arquitetura da navegação

```text
Minhas listas
    ├── Criar lista (nome; orçamento opcional)
    ├── Compra em andamento
    │     ├── Todos | A comprar
    │     ├── Toque no item → painel para registrar/editar entradas de compra
    │     ├── + Adicionar → formulário compacto
    │     ├── Editar/remover item
    │     └── Finalizar → conferência final → confirmação → histórico
    └── Histórico
          ├── Listas finalizadas por data
          └── Detalhe da lista → itens e preços anteriores (somente leitura)
```

- Evitar pedir informações desnecessárias antes da primeira compra.
- Botões e rótulos devem usar linguagem comum: `Adicionar`, `Registrar preço`, `Adicionar outro preço`, `Voltar e revisar`, `Confirmar finalização`.
- O nome "Total registrado" diferencia a soma dos produtos do valor efetivamente cobrado no caixa.

## 3. Tela principal da compra

### 3.1 Hierarquia visual

1. **Cabeçalho discreto:** nome da lista e acesso a opções essenciais.
2. **Filtros:** `Todos` e `A comprar`; contagens visíveis quando couberem.
3. **Área rolável de itens:** linhas compactas com nome, estado, detalhes da quantidade e subtotal à direita.
4. **Área inferior fixa:** total acumulado, saldo de orçamento opcional e botão `+ Adicionar`.

**Regra de layout:** apenas a região da lista deve rolar normalmente. A barra do total deve continuar acessível mesmo com listas grandes; ao abrir um painel de edição, teclado e controles críticos não podem disputar o mesmo espaço.

### 3.2 Estados de item

| Estado visual | Dados | Na visualização `A comprar`? | Observação |
| --- | --- | --- | --- |
| Pendente | Nenhuma entrada de compra | Sim | Subtotal não registrado |
| Parcial | Planejado 5, comprado 3 com quantidade conhecida | Sim | Mostra `3 de 5` e subtotal parcial |
| Concluído | Compra registrada e quantidade planejada atendida, ou item sem quantidade planejada que recebeu valor direto | Não | Mostra indicador discreto de concluído |
| Quantidade não confirmada | Item com quantidade planejada e somente valor direto, sem unidades compradas conhecidas | Sim, provisoriamente | **Proposta pendente de validação:** não inferir que o planejado foi atendido |
| Removido | Usuário retirou da lista ativa | Não | Não entra no total; possível `Desfazer` ainda sem duração decidida |

**Importante:** valor registrado, mesmo parcial, **já compõe o total**. Ícones e filtros nunca controlam somas financeiras.

### 3.3 Regras da lista

- A posição de cada item é estável, inclusive após editar preço ou quantidade.
- Filtrar `A comprar` apenas altera a lista visível, não seus dados nem a soma.
- O item parcial só desaparece de `A comprar` ao atingir/superar a quantidade planejada conhecida.
- Preferir divisórias sutis a um cartão grande para cada produto.
- Usar texto, cor e ícone em conjunto para estados; não depender somente de uma cor.

## 4. Inclusão rápida — botão `+ Adicionar`

**Componente:** painel inferior (`bottom sheet`) compacto sobre a compra; não navegar para uma página extensa.

**Campos visíveis de uma vez:**

| Campo | Regra |
| --- | --- |
| Produto | Obrigatório, foco inicial; aceitar nomes livres como `Arroz 5 kg` |
| Quantidade | Opcional, inicia **vazia**; não supor 1 |
| Preço (R$) | Opcional; com quantidade = preço unitário; sem quantidade = valor total direto |
| Subtotal | Calculado instantaneamente como **prévia** |
| Confirmar | Persiste; fecha painel e atualiza total oficial após sucesso |

**Fluxos ilustrativos:**

- `Sabonete` + quantidade `5` + preço vazio → item planejado pendente.
- `Leite` + quantidade `3` + preço `4,22` → compra registrada, R$ 12,66 adicionados.
- `Carne` + quantidade vazia + preço `47,82` → compra com valor direto, R$ 47,82 adicionados.

**Requisitos de interação:** teclado adequado a moeda/quantidade; vírgula decimal; CTA visível com teclado aberto; botão de confirmar desabilitado durante persistência para evitar duplicação; foco e valores digitados preservados caso a gravação falhe. Evitar caixa de diálogo "tem certeza de adicionar?".

## 5. Produto existente — múltiplas entradas de preço

Ao tocar na linha do produto, exibir painel inferior com:

1. Nome, quantidade planejada (se houver), quantidade comprada conhecida e subtotal.
2. Entradas registradas: `3 × R$ 3,50 → R$ 10,50`, cada uma com edição/remoção.
3. Ação clara **`+ Adicionar outro preço`**.
4. Dois campos de registro: quantidade comprada e preço unitário, com subtotal de prévia.
5. Quantidade restante **pode ser sugerida** como atalho, sempre editável; nunca impede comprar a mais.

**Exemplo:** planejado 5 sabonetes; registrar 3 × R$ 3,50; depois 2 × R$ 4,20; subtotal R$ 18,90. Nunca exigir marca.

Correção de preço altera a entrada existente e recalcula a soma; não cria entrada adicional. A exclusão de uma entrada desconta apenas o valor daquela entrada.

## 6. Remoção e proteção contra enganos

- Remover um item da compra ativa deve ser uma operação explícita, facilmente encontrada no detalhe do item.
- Remover item com preço desconta imediatamente seu subtotal após persistência.
- Preferir uma ação `Desfazer` transitória a várias confirmações para operações reversíveis. **Duração exata e comportamento ao sair da tela ainda não aprovados.**
- Excluir uma **lista inteira** é mais destrutivo; exigir confirmação com nome da lista e aviso de impacto. Definir separadamente a política de exclusão de listas históricas.

## 7. Orçamento e total

- **Total registrado** deve ter maior hierarquia que rótulos secundários.
- Se orçamento não foi informado, não mostrar saldo fictício.
- Se informado, apresentar `R$ X disponíveis`, `Limite atingido` ou `R$ Y acima do orçamento`.
- Orçamento excedido pode usar cor de alerta moderada, mais explicação textual; jamais impedir compras.
- Total calculado com dados persistidos e em centavos inteiros. Durante edição, subtotal de prévia fica visualmente separado.

## 8. Finalização — sempre uma revisão

**Tela de conferência obrigatória antes de encerrar**, mesmo se todos os itens estiverem comprados:

1. `Total calculado pelo app` em destaque.
2. Se houver orçamento: valor disponível e diferença (saldo/excedente).
3. Itens que pedem atenção: sem compras registradas e parciais (ou quantidade não confirmada, sujeito à validação). Somente esses itens são listados na revisão.
4. **Campo opcional:** `Valor cobrado no caixa (R$)`. Se informado, mostrar `R$ X a mais/menos no caixa` ou `Valores iguais`.
5. Aviso discreto: `Após confirmar, esta compra ficará somente para consulta.`
6. Ações: `Voltar e revisar` e `Confirmar finalização`.

Se houver pendências, o usuário ainda pode finalizar. Itens sem entradas ficam como não comprados no histórico. As compras parciais preservam o valor efetivo registrado e as unidades faltantes. O valor pago no caixa **não altera preços unitários**.

**Finalização atômica:** quando o banco confirmar a operação, navegar para a compra finalizada. Evitar múltiplas confirmações e duplicação de histórico.

## 9. Histórico somente para consulta

- Listar compras finalizadas com nome, data e total registrado.
- Detalhe com itens, quantidades planejadas/compradas, entradas por preço, subtotais e itens não comprados.
- Quando informado, mostrar separadamente `Total calculado` e `Valor pago no caixa`.
- Permitir procurar nome de produto para consultar preços anteriores (ex.: `Arroz 5 kg` em novembro/2026).
- Nenhum botão de alteração, adicionar preço ou reabrir compra no detalhe histórico.
- Não incluir gráficos, rankings nem análise automática no MVP.

## 10. Temas e sistema visual

**Direção visual:** minimalismo utilitário, sem elementos decorativos redundantes. Um layout deve funcionar igualmente bem nos dois temas.

| Token semântico | AMOLED | Claro | Uso |
| --- | --- | --- | --- |
| Fundo principal | `#000000` | `#FFFFFF` | Telas |
| Superfície elevada | `#141414` | `#F5F5F5` | Painéis, inputs, superfícies necessárias |
| Divisória | `#292929` | `#E7E7E7` | Separar itens, não criar cartões desnecessários |
| Texto principal | `#F5F5F5` | `#171717` | Nomes e valores |
| Texto secundário | `#B0B0B0` | `#616161` | Quantidades e descrição |
| Ênfase/confirmado | `#78DCC2` | `#137962` | Elementos de ação e estados |

Esses valores são **tokens iniciais propostos**: passarão por verificação real de contraste, legibilidade e aparência no dispositivo antes da aprovação final. Evitar codificar cores literais em cada widget. Não depender exclusivamente da cor para indicar o estado.

### Tipografia e medidas

- Usar fonte legível e disponível no ecossistema; não adicionar fonte por estética sem teste.
- Sistema de espaçamento consistente, preferencialmente múltiplos de 4 ou 8 dp.
- Alvos de toque confortáveis (meta inicial de **48 × 48 dp**, quando aplicável).
- Testar textos escalados, nomes longos, valores grandes e aparelhos com largura reduzida.
- Considerar áreas seguras, barra de navegação, gestos do Android e teclado.

## 11. Acessibilidade e comportamento real

- Contraste adequado para títulos, valores e textos secundários nos dois temas.
- Leitores de tela devem anunciar nome, estado, quantidade e subtotal por item.
- Estados compreensíveis sem depender de cores ou gestos secretos.
- Feedback de sucesso discreto e erro acionável; não perder o preenchimento.
- Testar com modo avião, reinício, teclado aberto, fonte ampliada e pelo menos um aparelho físico.
- Interface responsiva: rolagem suave com 100 itens e centenas de registros históricos.

## 12. Critérios de aceite de UX

- [ ] Um toque em `+` abre diretamente nome/quantidade/preço.
- [ ] Nome sozinho cria item pendente; quantidade em branco não vira `1`.
- [ ] Preço confirmado entra imediatamente no total, sem segundo check.
- [ ] Produto existente recebe um segundo preço sem exigir marca.
- [ ] Filtro `A comprar` mostra pendentes e parciais e não muda a soma.
- [ ] Confirmar preço não altera a ordem visual dos itens.
- [ ] Total continua visível ao rolar lista longa.
- [ ] Nenhum controle crítico fica inacessível com o teclado aberto.
- [ ] Revisão final exibe total, diferença opcional de orçamento e de caixa, e pendências.
- [ ] Histórico está em modo somente leitura.
- [ ] Dark AMOLED usa preto puro na região principal e permanece legível.

## 13. Questões de UX em aberto (não presumir aprovação)

1. Como sinalizar `quantidade não confirmada` para item com quantidade planejada e preço direto.
2. Duração/forma do botão `Desfazer` ao remover um produto.
3. Política para nomes duplicados; sugerir item existente sem proibir duplicatas legítimas.
4. Se o app deve sugerir uma preferência de tema ou seguir automaticamente o sistema na primeira execução.
5. Se será possível excluir **listas históricas finalizadas** e, se sim, que confirmação apresentar.

Estas questões podem ser resolvidas na fase relevante. Não devem impedir o scaffold, os cálculos ou o cadastro de listas e itens.
