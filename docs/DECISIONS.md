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
| P-003 | SQLite com `sqflite` | Verificar versão e suporte no ambiente Flutter escolhido |
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
