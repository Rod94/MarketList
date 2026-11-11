# MarketList

Aplicativo Flutter/Dart para compras de supermercado no Android. Listas, preços, orçamento e histórico são gravados no SQLite do aparelho e podem ser consultados offline. A interface oferece temas Claro, AMOLED e Sistema, com preferência persistida.

## Usar no Android

1. Em **Minhas listas**, crie uma lista com nome e orçamento opcional.
2. Toque em **Adicionar produto**. Com quantidade preenchida, o preço é unitário. Com quantidade vazia, o valor informado é o total direto. Um produto existente aceita mais de uma entrada de compra.
3. Confira o total no rodapé e use **A comprar** para filtrar a lista. Se remover um produto, o botão **Desfazer** fica disponível por cinco segundos enquanto você permanece na tela.
4. Toque no ícone **Finalizar compra**, revise os itens e informe o valor do caixa se desejar. A confirmação grava a compra para consulta.
5. Em **Histórico**, abra uma compra ou use a lupa para procurar um produto e consultar os preços da época.

## Executar e verificar

Ambiente da Fase 7 com Flutter 3.47.9 stable, Dart 3.13.7, Android SDK e JDK 21. Na raiz do projeto:

```powershell
flutter doctor -v
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter devices
flutter test integration_test --no-uninstall --concurrency=1 -d ID_ANDROID --reporter expanded
flutter build apk --release
```

Substitua `ID_ANDROID` pelo identificador exibido em `flutter devices`. A integração usa um banco temporário e `--no-uninstall` preserva os dados da instalação. Depois dela, instale o APK normal com `adb install -r`.

O APK de teste da Fase 7 é `build/app/outputs/flutter-apk/marketlist-f7-release.apk`, compilado em modo release e assinado com a chave de depuração configurada no Gradle. A versão, as ABIs e a verificação de assinatura estão no [relatório da Fase 7](docs/PHASE_7_REPORT.md).

### Perda de rede e reinício

Execute no APK normal aberto em **Minhas listas**, com o Android conectado por USB, desbloqueado e inicialmente com rede padrão:

```powershell
python -B tool/verify_android_offline.py --adb CAMINHO_ADB --serial ID_ANDROID --run --purchases --network-cycle
```

O roteiro altera temporariamente a rede, cria e remove sua própria lista e verifica a troca de processo após o reinício. O resultado fica em `build/offline_verification_f7/result.json`.

## Organização

- `lib/core/` reúne abertura do SQLite, migrações, moeda em centavos e preferência de tema.
- `lib/features/shopping/` reúne regras, repositório e telas de listas e produtos.
- `lib/features/checkout/` contém a conferência e a confirmação da compra.
- `lib/features/history/` contém listagem, detalhes e busca de compras finalizadas.
- `test/` e `integration_test/` cobrem domínio, widgets, SQLite e o Android físico.

[Requisitos](docs/SPEC.md) · [Arquitetura](docs/ARCHITECTURE.md) · [Decisões](docs/DECISIONS.md) · [Testes](docs/TESTING.md) · [Tarefas](docs/TASKS.md)
