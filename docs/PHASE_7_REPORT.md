# Fase 7 — validação do MVP no Android

O MarketList cria e edita listas offline, registra entradas de compra, compara orçamento com gasto, finaliza com conferência e permite consultar preços antigos por produto. Os testes da fase usaram o Samsung conectado por USB e bancos de teste isolados. Os comandos e resultados detalhados estão em [TESTING.md](TESTING.md).

## O que a fase verificou

| Tarefa | Evidência |
| --- | --- |
| F7-01 | A compra permaneceu no mesmo processo durante retorno e nova perda de rede. Outro processo recuperou o total de R$ 60,48 após o encerramento forçado. |
| F7-02 | Uma cópia v2 migrou para v3 preservando os registros. Uma cópia v3 recuperou entradas, total e caixa. As verificações de integridade e chaves estrangeiras passaram. |
| F7-03 | O texto de subtotais largos passou a ocupar uma linha abaixo do estado. O teste verificou o maior valor em centavos, rejeição de um centavo acima e correção do rascunho. |
| F7-04 | No Samsung, a rolagem chegou ao produto 100 com fonte 1,3×, e a inclusão do produto 101 atualizou o rodapé fixo. Os pares de contraste avaliados passaram nos dois temas. |
| F7-05 | `flutter analyze` sem apontamentos, 356 testes Flutter e 31 testes Android aprovados. O APK debug foi instalado e abriu a frio. |
| F7-06 | O APK em modo release foi verificado e instalado com a assinatura de depuração do Gradle para distribuição de teste. |

## Como os dados chegam à tela

1. O formulário envia texto e ações ao ViewModel. Ele valida quantidade e converte o preço para centavos inteiros. A prévia acompanha o rascunho.
2. O repositório grava no SQLite e devolve um retrato confirmado da compra. A transação garante que as escritas que fazem parte da mesma operação sejam confirmadas juntas ou revertidas juntas.
3. O ViewModel usa `ChangeNotifier` para sinalizar a mudança. Widgets que observam esse estado exibem o total confirmado. Os filtros escolhem as linhas visíveis a partir do mesmo retrato.
4. A finalização grava data, total calculado e caixa. A busca do histórico usa um `JOIN` pelo ID do produto e da lista para ler as entradas da época. As telas com `FutureBuilder` representam espera, resultado e falha da leitura.

Como exercício, compare mentalmente três unidades de R$ 4,22 com uma entrada direta de R$ 47,82. Os valores são 1.266 e 4.782 centavos, e a soma inteira é 6.048. Você pode conferir os casos equivalentes em [money_test.dart](../test/unit/money_test.dart) e [shopping_calculator_test.dart](../test/unit/shopping_calculator_test.dart).

## APK e validação manual

O artefato está em `build/app/outputs/flutter-apk/marketlist-f7-release.apk`. A [seção de distribuição de teste](TESTING.md) registra a versão, as ABIs e o SHA-256. Para conferir a navegação, abra **Minhas listas → Histórico → lupa**, busque um produto e toque no resultado correspondente.

Validações ainda pendentes incluem leitura em voz alta com TalkBack, medição de FPS e build iOS. A assinatura registrada destina o APK à distribuição de teste. As decisões sobre exclusão histórica e exportação permanecem em [DECISIONS.md](DECISIONS.md).
