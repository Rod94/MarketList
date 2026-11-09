# Fase 0 — Fundação Flutter

**Data:** 09/11/2026. **Escopo autorizado:** F0-01 a F0-06, em sequência. A Fase 1 não foi iniciada.

## 1. Problema resolvido e entrega

O projeto deixou de ser somente documentação: agora tem inicialização Flutter, projetos nativos Android/iOS, uma tela simples de demonstração, temas Claro/AMOLED e ambiente de testes automatizados. Isso prepara uma base verificável para construir, nas próximas fases, o aplicativo de compras sem misturar regras financeiras com interface.

A tela mostra MarketList, o título Aparência e um seletor Sistema/Claro/AMOLED. AMOLED usa fundo principal **#000000**; claro usa **#FFFFFF**. Não há contador de template, listas fictícias nem ações de compras sem implementação.

Não foram implementados modelos de compra, cadastro de listas/produtos, dinheiro, SQLite, orçamento, checkout, histórico, login ou rede. As regras de produto não mudaram. Não existe migração nem banco para preservar nesta fase.

## 2. Ambiente e preparação

O diagnóstico inicial encontrou Git, Android SDK 33/34 e JDK 21, mas não encontrou Flutter/Dart no PATH nem instalação existente na busca realizada. O diretório do projeto não contém `.git`: por isso `git status --short` falhou com “not a git repository”; não foram criados commits nem inicializado um repositório Git.

Após solicitação explícita de permissão para instalação, Flutter **3.47.9 stable** com Dart **3.13.7** foi baixado do manifesto oficial e o SHA-256 foi comparado ao manifesto antes da extração em `C:\Users\Rodolpho\develop\flutter`. O arquivo ZIP baixado permanece na pasta `develop`. O PATH global não foi alterado; os comandos usam caminhos absolutos ou variáveis temporárias por processo.

O `flutter doctor -v` executado depois da instalação reconheceu Flutter/Dart e o SDK Android, mas apontou ausência de `cmdline-tools` e estado de licenças desconhecido. O ADB iniciou e não listou Android conectado; `flutter emulators` informou nenhum emulador disponível. Chrome, Edge e Windows foram encontrados, mas não substituem uma validação Android.

JDK utilizado no build: `C:\Program Files\Android\openjdk\jdk-21.0.8`. SDK Android: `C:\Users\Rodolpho\AppData\Local\Android\Sdk`.

O build solicitou automaticamente NDK **28.2.13676358**, Build-Tools **36.0.0**, plataforma **android-36 (revisão 2)** e CMake **3.22.1**. Esses componentes foram instalados pelo Gradle após a permissão para build/download de componentes; suas licenças já estavam aceitas no SDK. Não foi executado comando de aceitação automática de licenças.

Após o usuário conectar e autorizar depuração USB, foi identificado **Samsung SM-S936B, Android 17/API 37**. O teste de integração passou nesse aparelho. O diagnóstico final reconheceu Android SDK 36, mas ainda manteve a advertência de cmdline-tools/licenças: essa pendência de configuração não impediu a compilação nem a execução no aparelho.

## 3. Arquivos criados ou modificados e motivos

| Arquivo/grupo | Finalidade |
| --- | --- |
| `lib/main.dart` | Ponto de entrada; entrega o widget raiz a `runApp`. |
| `lib/app/app.dart` | Provider, `MaterialApp`, localização pt-BR e seleção de temas. |
| `lib/app/theme/app_colors.dart` | Tokens de cor de `DESIGN.md`. |
| `lib/app/theme/app_spacing.dart` | Espaçamentos e área mínima de toque de 48 dp. |
| `lib/app/theme/app_theme.dart` | `ThemeData` claro/AMOLED, superfícies e AppBar sem tonalização do preto. |
| `lib/app/theme/theme_view_model.dart` | Preferência visual em memória e notificações somente quando muda. |
| `lib/core/preferences/theme_preference.dart` | Enum compartilhado de preferências; sem dependência de plataforma. |
| `lib/features/shopping/presentation/screens/scaffold_screen.dart` | Demonstração com rolagem, área segura e seletor de tema. |
| `test/unit/theme_view_model_test.dart` | Três testes do estado/notificações. |
| `test/widget/app_test.dart` | Quatro testes de abertura, temas, sistema e tela pequena/fonte 2×. |
| `integration_test/app_smoke_test.dart` | Um smoke test Android pronto para execução em dispositivo. |
| `pubspec.yaml` / `pubspec.lock` | Nome, versão 0.1.0+1, SDKs, Provider e resolução reprodutível das dependências. |
| `analysis_options.yaml` | Análise estática com `flutter_lints`. |
| `.gitignore` | Artefatos Flutter/IDE e exclusão de bancos locais/chaves de assinatura. |
| `.metadata` | Metadados do projeto gerados e mantidos pelo Flutter. |
| `android/` | Projeto Kotlin/Gradle, manifests, wrapper, ícones e recursos gerados pelo Flutter. |
| `ios/` | Projeto Swift/Xcode, Runner, testes nativos e assets gerados, sem execução nesta máquina. |
| `README.md` | Ambiente, comandos reproduzíveis, estrutura e escopo atual. |
| `docs/ARCHITECTURE.md` | Distingue árvore futura da fundação realmente criada. |
| `docs/DECISIONS.md` | Registra adoção inicial de Provider/MVVM, ferramentas, identidade e Q-006 provisória. |
| `docs/TESTING.md` / `docs/TASKS.md` | Casos/executados e status real das tarefas. |
| `docs/PHASE_0_REPORT.md` | Este relatório de implementação, evidências e aprendizado. |

Os arquivos nativos ajustados após a geração foram `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/br/com/rodolpho/marketlist/MainActivity.kt`, `android/app/src/main/res/values/styles.xml`, `android/app/src/main/res/values-night/styles.xml`, `android/app/src/main/res/drawable/launch_background.xml`, `android/app/src/main/res/drawable-v21/launch_background.xml`, `ios/Runner/Info.plist` e `ios/Runner.xcodeproj/project.pbxproj`. Foram acrescentados `android/app/src/main/res/values/colors.xml` e `android/app/src/main/res/values-night/colors.xml` para os fundos nativos dia/noite. Nome exibido **MarketList** e identificador Android/iOS **br.com.rodolpho.marketlist** definidos explicitamente.

Configurações pessoais `.idea/`, arquivos `*.iml`, `android/local.properties`, caches e arquivos iOS gerados também podem existir localmente, mas são ignorados para versionamento. `AGENTS.md`, `SPEC.md` e `DESIGN.md` foram preservados.

## 4. Caminho do estado

```text
Toque em Claro/AMOLED/Sistema
  → widget encaminha a escolha
  → ThemeViewModel.selectTheme altera o enum
  → notifyListeners avisa ao Provider
  → context.watch solicita reconstrução
  → MaterialApp aplica ThemeData à tela
```

O Provider cria e descarta o ViewModel. `context.read` acessa a ação sem assinar mudanças; `context.watch` acompanha o estado. Escolher novamente o tema atual não dispara notificação desnecessária. Não há chamada ao repositório/SQLite: isso pertence à Fase 1 em diante. A seleção reinicia ao encerrar o app, pois Q-006 permanece aberta.

## 5. Execuções reais e rastreabilidade

Os comandos abaixo foram executados no projeto com o SDK instalado; o executável foi invocado pelo caminho absoluto quando não havia PATH configurado.

| Comando | Resultado real |
| --- | --- |
| `git status --short` | Falhou: diretório sem `.git`. |
| `flutter doctor -v` / `dart --version` antes da instalação | Comandos não encontrados no PATH. |
| `flutter --version` após instalação | Flutter 3.47.9, Dart 3.13.7. |
| `flutter doctor -v` | Executou; advertências Android descritas acima. |
| `adb devices -l` | Executou após liberação do sandbox; lista Android vazia. |
| `flutter devices` / `flutter emulators` | Sem Android conectado; nenhum emulador configurado. |
| `flutter create --empty --platforms=android,ios --project-name=market_list --org=br.com.rodolpho --android-language=kotlin --no-pub .` | Sucesso; base nativa oficial gerada sem substituir a documentação. |
| `flutter pub add provider` | Sucesso; Provider 6.1.5+1 e dependências/lockfile resolvidos. |
| `dart format .` | 11 arquivos Dart; 2 formatados na primeira execução, 0 alterações na segunda. |
| `flutter analyze` | Duas execuções aprovadas, `No issues found!`. |
| `flutter test` — primeira execução | 5 passaram, 2 falharam por seletor de tipo genérico incorreto nos testes de widget. |
| `flutter test` — após correção | **7 passaram, 0 falhas**: 3 unitários de ViewModel + 4 de widget. |
| `flutter test integration_test -d android` | Saída 1 na seleção do alvo: nenhum Android disponível; **0 testes de integração executados**. |
| `flutter build apk --debug` | **Sucesso**, Gradle assembleDebug em 258,2 s; APK normal de desenvolvimento gerado. |
| `flutter test integration_test -d RXCY300NZZH` | **1 aprovado/0 falhas** no Android conectado; compilou, instalou e executou o smoke test. |
| `dart format --output=none --set-exit-if-changed .` | Saída 0; 11 arquivos sem alterações. |
| `aapt dump badging build/app/outputs/flutter-apk/app-debug.apk` | Nome MarketList, pacote `br.com.rodolpho.marketlist`, versão 0.1.0/código 1, minSdk 24 e target/compile SDK 36. |
| `adb -s RXCY300NZZH install -r build/app/outputs/flutter-apk/marketlist-0.1.0-debug.apk` | **Success**; restaurou o app normal após a integração. |
| `adb -s RXCY300NZZH shell am start -W -n br.com.rodolpho.marketlist/.MainActivity` | **Status: ok**; usuário confirmou tela visível após desbloquear o celular. |

**Resultado final:** 3 testes unitários de ViewModel + 4 de widget + 1 de integração Android = **8 testes aprovados**. Nenhuma alegação de teste de domínio, banco ou fluxo de compras nesta fase.

**APK normal entregue:** `build/app/outputs/flutter-apk/marketlist-0.1.0-debug.apk`, também restaurado em `build/app/outputs/flutter-apk/app-debug.apk` após a integração. São 153.625.132 bytes, variante debug com assinatura de desenvolvimento, contendo arm64-v8a/armeabi-v7a/x86_64. SHA-256: `79b6ca7ba2893fe62c5cb8403c9f5baa80efb734e4e143dfea1f1c712acc104a`. Build iOS/release não realizado. A captura `build/phase0-android.png` foi inspecionada: tela normal, tema do sistema escuro, fundo preto e seletor visíveis. O usuário também confirmou a exibição correta.

Correção feita: `find.byType(DropdownButton)` procura um tipo em tempo de execução diferente de `DropdownButton<ThemePreference>`. Os seletores agora usam o tipo completo. Não foram alterados os resultados esperados de cor, estado ou layout.

| Requisito/tarefa | Casos e evidência | Limite |
| --- | --- | --- |
| F0-03 / F0-05 | Três testes de inicialização, mudança/notificação e escolha repetida do ViewModel | Sem regras de domínio implementadas; TDD de cálculos será aplicado na fase correspondente. |
| F0-04 / F0-05 | Smoke test abre MarketList e Aparência | Renderização em ambiente de widget, sem Android físico. |
| D-015 / RF-10 / UX-009 (parcial) | Widget verifica AMOLED `Brightness.dark`, fundo e superfície `0xFF000000`/claro branco; integração também verifica AMOLED no aparelho | Captura da tela normal inspecionada; medição física de contraste/OLED não realizada. |
| F0-04 | Brilho simulado do sistema alterna o tema | Política de preferência definitiva continua em aberto. |
| UX-018 (parcial da demonstração) | Tela 320×568 com texto 2× e seleção do menu sem exceção de layout | Não cobre formulários/teclado das próximas fases. |
| F0-06 | Smoke test de integração executado e aprovado em Android físico | 1 teste adicional aos 7 convencionais; não cobre funcionalidades futuras. |

## 6. Conceitos Dart e Flutter utilizados

- **`main.dart` e `runApp`:** `main` é o ponto de entrada, como `Main` em C#. `runApp` entrega ao Flutter a descrição inicial da interface.
- **Widget:** descrição de uma parte da interface. `build` produz uma árvore com estrutura e configuração; o Flutter atualiza a exibição quando o estado muda.
- **`StatelessWidget`:** não guarda estado mutável próprio. Pode ser reconstruído com novos dados. A tela e o app são desse tipo porque o estado reside no ViewModel.
- **`StatefulWidget`:** divide configuração e estado em um objeto `State`, útil para estado local e ciclo de vida, como animações/controladores. Não foi necessário criar um nesta fase; os componentes do Flutter gerenciam seu próprio estado interno.
- **`MaterialApp`:** configuração geral de tema, idioma e tela inicial. **`Scaffold`** fornece a estrutura de tela com AppBar e corpo; não é um repositório nem uma camada de banco.
- **`class`, `final`, `const`:** classes agrupam responsabilidades; `final` impede reatribuir a referência após inicialização (comparável a `readonly` em C#); `const` cria valores constantes em tempo de compilação. Referência `final` não torna automaticamente seu objeto imutável.
- **`enum` e `switch`:** representam escolhas finitas com segurança de tipos. O `switch` traduz cada preferência em um `ThemeMode`, verificando todas as possibilidades.
- **`ChangeNotifier`/Provider:** o primeiro avisa que o estado mudou; o segundo oferece esse estado aos widgets e gerencia seu ciclo de vida. Lembra o propósito de `INotifyPropertyChanged` com injeção de dependências em C#, embora a reconstrução de widgets siga o modelo do Flutter.
- **`pubspec.yaml`:** manifesto com versão, dependências, requisitos de SDK e assets; tem papel semelhante a partes de um `.csproj`. O lockfile fixa a resolução usada; `analysis_options.yaml` configura lint/análise, não comportamento do app.
- **Testes:** unitários chamam o ViewModel diretamente. Testes de widget constroem a interface num ambiente controlado; `pump`/`pumpAndSettle` processam reconstruções/animações. Integração executa no dispositivo e precisa de alvo nativo real ou emulado.
- **`android/` e `ios/`:** hospedam o código Flutter no sistema operacional e suas ferramentas de build. A interface compartilhada está em `lib/`; pastas nativas geradas não significam que ambas as plataformas foram testadas.

## 7. Validação Android realizada e roteiro para repetir

O app foi instalado e aberto no aparelho citado; usuário confirmou tela normal e seletor, e a captura mostra a tela legível em tema do sistema escuro. A integração automatizada validou a escolha AMOLED. Os passos abaixo permitem repetir/ampliar a inspeção; não se alega que todos os itens de revisão manual foram executados.

1. Conecte um Android autorizado para depuração USB ou configure/inicie um emulador. Execute `flutter devices` e confirme o ID Android.
2. Use os caminhos e comandos do README para executar `flutter run -d ID_ANDROID`.
3. Confira título MarketList, tela Aparência e seletor com Sistema, Claro e AMOLED.
4. Selecione AMOLED: fundo principal preto; selecione Claro: fundo branco. Verifique legibilidade, modo paisagem e fonte ampliada.
5. Volte para Sistema e altere o modo claro/escuro do Android. Reinicie o app: a demonstração volta a acompanhar o sistema.
6. Execute `flutter test integration_test -d ID_ANDROID`. A execução desta entrega já passou no aparelho conectado; use o ID do seu alvo para repetir.

Não há campos de compras nesta fase; testes de teclado, persistência/offline e total pertencem às funcionalidades futuras. iOS não foi compilado nem executado: requer ambiente macOS/Xcode.

## 8. Exercício opcional

Em uma cópia da pasta ou branch própria, altere somente o texto de apresentação da tela, execute `dart format .`, `flutter analyze` e `flutter test`, e observe quais testes verificam texto e quais verificam comportamento. Descarte a cópia após praticar. Não altere o token preto AMOLED nem os testes para esconder falhas.

**Pendências reais:** completar cmdline-tools/revisão de licenças do ambiente; inspeção física ampliada de contraste, leitor de tela e orientações nas fases apropriadas. Q-006 continua aberta, com seleção de tema temporária. A Fase 1 permanece pendente de autorização explícita; próxima tarefa de produto sugerida, somente após autorização: F1-01.
