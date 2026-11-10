# MarketList

Repositório: [Rod94/MarketList](https://github.com/Rod94/MarketList). Branch principal: `main`.

Aplicativo de supermercado Flutter/Dart, com Android como primeira plataforma e base nativa iOS preparada. Permite criar listas com orçamento opcional e planejar produtos por nome/quantidade opcional, editar e remover, preservando ordem e dados em SQLite offline. Temas Claro/AMOLED com fundo preto verdadeiro. Preços, total de compra, finalização e histórico pertencem às próximas fases.

**Fases 0, 1 e 2 concluídas:** quantidade ausente permanece null; edição mantém identidade/posição; remoção lógica oculta o produto somente após persistir. Erro mantém os campos e retry reutiliza o ID. Listas finalizadas são protegidas no repositório. Banco v2 migra listas v1 sem reset. Regressão final: **189 testes convencionais, 17 testes nativos Android e 1 reinício offline com produtos aprovados**, análise sem problemas. Consulte os comandos, evidências e limites no [relatório da Fase 2](docs/PHASE_2_REPORT.md).

**F3-01 concluída:** conversor puro de moeda, preço zero distinto de ausência e proteção de soma/produto contra overflow. **206 testes aprovados**, análise sem problemas. Orçamento compartilha o conversor sem mudar sua experiência. UI de preços ainda não implementada. Progresso em [PHASE_3_REPORT.md](docs/PHASE_3_REPORT.md).

**F3-02 concluída:** modelo puro de entrada por unidades ou valor direto, subtotal validado e gratuito explícito. Regressão atual **224 aprovados**, análise sem problemas; sem nova UI/APK nesta tarefa. Próxima F3-03, calculadora.

**F3-03 concluída:** calculadora pura de subtotais/total e estados, incluindo gratuito, parcial e quantidade não confirmada. Removidos não somam. **246 testes aprovados**, análise sem problemas. Próxima F3-04, persistência de entradas; preços ainda não disponíveis na interface.

**F3-04:** banco v3 e repositório de entradas, com correção/exclusão, fotografia confirmada e rollback por erro/overflow. **269 testes aprovados**, análise sem problemas. Preços ainda não ligados à UI; próxima F3-05. APKs antigos v1/v2 recusam banco v3, sem apagar dados.

**F3-05:** ViewModel mantém total confirmado separado de prévias, preserva campos/ID no erro e só aceita fotografia após commit. **281 testes aprovados**, análise sem problemas, **8 nativos aprovados** após disponibilizar o aparelho desbloqueado. Painel visual de preço é a próxima tarefa.

## Ambiente usado

- Flutter **3.47.9 stable**, Dart **3.13.7**; Provider **6.1.5+1**.
- SQLite: `sqflite` **2.4.5+1**, `path` **1.9.1**; testes de computador com `sqflite_common_ffi` **2.4.6** (dependência de desenvolvimento).
- Identificadores: `uuid` **4.6.0**; cada inclusão deve manter o mesmo ID durante suas tentativas.
- Nome exibido: **MarketList**; pacote Dart: `market_list`.
- Identificador Android e bundle iOS: `br.com.rodolpho.marketlist` (identidade de desenvolvimento, sem publicação).
- SDK Flutter instalado em `C:\Users\Rodolpho\develop\flutter`, sem modificar o PATH global.
- Consulte [o relatório da Fase 0](docs/PHASE_0_REPORT.md) para resultados reais e limitações do ambiente Android.

Para outra máquina, instale a versão indicada pelo [arquivo oficial do Flutter](https://docs.flutter.dev/install/archive). O lockfile das dependências do aplicativo é versionável.

## Executar e verificar

Na raiz do projeto, em uma sessão PowerShell local:

```powershell
$env:Path = 'C:\Users\Rodolpho\develop\flutter\bin;' + $env:Path
$env:JAVA_HOME = 'C:\Program Files\Android\openjdk\jdk-21.0.8'
$env:ANDROID_HOME = 'C:\Users\Rodolpho\AppData\Local\Android\Sdk'
flutter doctor -v
flutter pub get
dart format .
flutter analyze
flutter test
flutter devices
```

Ajuste os caminhos se necessário. Com um dispositivo Android conectado ou emulador em execução, substitua `ID_ANDROID` pelo identificador mostrado por `flutter devices`:

```powershell
flutter run -d ID_ANDROID
flutter test integration_test --no-uninstall -d ID_ANDROID
flutter build apk --debug
```

O APK normal mais recente fica em `build/app/outputs/flutter-apk/app-debug.apk`, com cópia `marketlist-f3-05-debug.apk` na mesma pasta, compatível com esquema v3. Sua UI ainda é de planejamento. Artefatos anteriores foram preservados. Após abrir v3, APKs antigos v1/v2 recusam a versão superior; não servem como rollback. São builds debug, sem entrega de release. Builds podem baixar Gradle/componentes Android; licenças pendentes precisam ser revisadas no ambiente de desenvolvimento.

Use `--no-uninstall` na integração: o Flutter 3.47.9 desinstala o pacote por padrão ao encerrar o teste. A opção preserva a instalação e seus dados; ao terminar, gere/instale o APK normal para substituir a variante de teste. Os testes de banco/repositório usam exclusivamente arquivos temporários próprios.

Validação da Fase 0: 7 testes convencionais e 1 teste de integração aprovados, APK normal instalado/aberto no Samsung SM-S936B, Android 17; tela confirmada pelo usuário. O diagnóstico daquela entrega ainda aponta cmdline-tools ausente.

Validação final da Fase 1: `flutter analyze` sem problemas, `flutter test` com **105 aprovados**, **9 testes nativos aprovados** no Samsung e **1 roteiro offline/reinício aprovado** no app normal. Houve interrupções do runner antes da execução bem-sucedida; causa não comprovada. As expectativas não foram relaxadas. Detalhes e comandos reais no [relatório da Fase 1](docs/PHASE_1_REPORT.md).

## Usar no Android

Em Minhas listas, toque em **Nova lista**, informe nome e orçamento opcional (ex.: `250,00`, sem pontos), e confirme **Criar lista**. A lista aparece somente após salvar. Em caso de erro, os campos ficam preenchidos para nova tentativa. Cancelar descarta apenas o rascunho. O ícone de excluir abre confirmação com nome; Aparência permite Claro/AMOLED/Sistema. A preferência de tema ainda não é gravada.

Toque na lista → **Adicionar produto** → nome e quantidade opcional → **Salvar produto**. Quantidade vazia não vira uma unidade. Toque num produto para editar nome/quantidade ou **Remover produto**. Removido sai da tela e permanece marcado no banco; não há Desfazer enquanto sua política não for decidida. A ordem de cadastro permanece mesmo ao renomear. Não há preços ou total de compra nesta fase.

## Verificação de reinício offline

O roteiro `tool/verify_android_offline.py` exige Python/ADB, celular desbloqueado e app normal instalado/aberto. `--inspect` só inspeciona; `--run` altera temporariamente rede/tela, cria e remove uma lista própria. Leia o roteiro antes de executar; a conexão do aparelho fica interrompida durante o teste. Configurações capturadas são restauradas em finally. Exemplo com caminhos ajustados ao seu ambiente:

```powershell
python tool/verify_android_offline.py --adb CAMINHO_ADB --serial ID_ANDROID --inspect
python tool/verify_android_offline.py --adb CAMINHO_ADB --serial ID_ANDROID --run
python tool/verify_android_offline.py --adb CAMINHO_ADB --serial ID_ANDROID --run --items
```

Resultado/capturas de listas ficam em `build/offline_verification/`; `--items` usa `build/offline_verification_f2/`, cria três produtos, remove um e confere quantidades/ordem/ocultação após novo processo offline. Ambos ficam fora do Git, removem somente a própria lista e restauram rede/tela. O roteiro nunca limpa o banco nem desinstala o aplicativo.

## Estrutura atual

```text
lib/
  main.dart
  app/
    app.dart
    theme/                      # Tokens, ThemeData e estado da demonstração
  core/
    preferences/                # Preferência de tema compartilhada
    database/
      app_database.dart         # Abertura/versão e configuração da conexão
      migrations/v1.dart        # Somente tabela de listas e índice
      migrations/v2.dart        # Tabela de itens, FK/cascade e posição única
      migrations/v3.dart        # Entradas de compra e proteção de integridade
    money/money.dart            # Conversão e operações exatas verificadas
  features/shopping/presentation/screens/
    shopping_lists_screen.dart  # Tela inicial e confirmação de exclusão
    shopping_screen.dart        # Produtos da lista e conjunto visível
    scaffold_screen.dart        # Aparência, via AppBar
  features/shopping/presentation/view_models/
    shopping_lists_view_model.dart # Carga, rascunho, erros e operações
    shopping_items_view_model.dart # Planejamento, ordem, erro/retry e remoção
  features/shopping/presentation/widgets/
    create_list_sheet.dart      # Formulário e ações acima do teclado
    item_form_sheet.dart        # Inclusão/edição/remoção de produto
  features/shopping/presentation/item_quantity_input.dart # Parser puro de quantidade
  features/shopping/domain/models/
    shopping_list.dart          # Modelo imutável, com validação e datas UTC
    shopping_item.dart          # Modelo puro; quantidade planejada opcional
    purchase_entry.dart         # Unidade × preço OU valor direto
  features/shopping/domain/
    shopping_repository.dart    # Contrato Dart puro e erros de operação
  features/shopping/data/
    sqlite_shopping_repository.dart # Listas/itens, transações e mapeamento
test/
  unit/                         # Estado e notificações do ViewModel
  widget/                       # Inicialização, temas e fonte ampliada
  database/                     # SQLite real em arquivos temporários
integration_test/               # Aparência e SQLite nativo no dispositivo
tool/verify_android_offline.py   # Roteiro host de reinício real sem conexão
android/                        # Projeto Kotlin/Gradle gerado pelo Flutter
ios/                            # Projeto Swift/Xcode; não testado no Windows
docs/                           # Requisitos, decisões, tarefas e evidências
```

Não há diretórios vazios antecipando banco, dinheiro, checkout ou histórico. Eles serão criados nas tarefas correspondentes.

## Documentação e escopo

Leia `AGENTS.md` e os documentos de requisitos, design, arquitetura, decisões, testes e tarefas em `docs/` antes de implementar. Autorizado prosseguir da F3 em diante fase por fase; F3-01 a F3-04 entregues, próxima F3-05. Preço zero/limites e quantidade não confirmada foram aprovados pelo usuário. Cada tarefa concluída tem commit/envio individual. Questões abertas ainda exigem decisão no momento indicado em DECISIONS.

`AGENTS.md` contém instruções locais, está no `.gitignore` por escolha do usuário e não é enviado ao GitHub. A documentação em `docs/` é versionada.

Na demonstração, o tema começa seguindo o sistema e pode ser alterado para Claro/AMOLED. Essa seleção vive somente na memória e reinicia com o app. A decisão definitiva de preferência inicial/persistência (Q-006) continua aberta.
