# MarketList

Repositório: [Rod94/MarketList](https://github.com/Rod94/MarketList). Branch principal: `main`.

Aplicativo de supermercado Flutter/Dart, com Android como primeira plataforma e base nativa iOS preparada. A **Fase 0** entregou uma tela de demonstração dos temas. A tarefa **F1-01** acrescentou o modelo de lista em Dart puro e 21 testes de domínio. A interface ainda demonstra temas; cadastro, persistência SQLite, produtos, cálculos e histórico serão implementados nas tarefas seguintes.

## Ambiente usado

- Flutter **3.47.9 stable**, Dart **3.13.7**; Provider **6.1.5+1**.
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
flutter test integration_test -d ID_ANDROID
flutter build apk --debug
```

O APK de desenvolvimento foi gerado em `build/app/outputs/flutter-apk/app-debug.apk`, com uma cópia identificada em `build/app/outputs/flutter-apk/marketlist-0.1.0-debug.apk`. Essa variante usa assinatura de debug e não é uma entrega de release. Builds podem baixar Gradle e componentes do Android SDK. Licenças pendentes precisam ser revisadas no ambiente de desenvolvimento.

Validação da Fase 0: 7 testes convencionais e 1 teste de integração aprovados, APK normal instalado/aberto no Samsung SM-S936B, Android 17; tela confirmada pelo usuário. O diagnóstico daquela entrega ainda aponta cmdline-tools ausente.

Validação mais recente, F1-01: `flutter analyze` sem problemas e `flutter test` com **28 aprovados** (21 novos + 7 anteriores). Não foi gerado novo APK nem repetida integração, pois o modelo ainda não está ligado à interface. Veja [o relatório incremental da Fase 1](docs/PHASE_1_REPORT.md).

## Estrutura atual

```text
lib/
  main.dart
  app/
    app.dart
    theme/                      # Tokens, ThemeData e estado da demonstração
  core/preferences/             # Preferência de tema compartilhada
  features/shopping/presentation/screens/
    scaffold_screen.dart        # Apenas demonstração; ainda sem listas
  features/shopping/domain/models/
    shopping_list.dart          # Modelo imutável, com validação e datas UTC
test/
  unit/                         # Estado e notificações do ViewModel
  widget/                       # Inicialização, temas e fonte ampliada
integration_test/               # Smoke test para dispositivo
android/                        # Projeto Kotlin/Gradle gerado pelo Flutter
ios/                            # Projeto Swift/Xcode; não testado no Windows
docs/                           # Requisitos, decisões, tarefas e evidências
```

Não há diretórios vazios antecipando banco, dinheiro, checkout ou histórico. Eles serão criados nas tarefas correspondentes.

## Documentação e escopo

Leia `AGENTS.md` e, em `docs/`, `SPEC.md`, `DESIGN.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `TESTING.md` e `TASKS.md` antes de implementar. Regras de negócio permanecem as documentadas. A Fase 1 foi autorizada; F1-01 está feita e as próximas tarefas devem continuar em entregas pequenas.

`AGENTS.md` contém instruções locais, está no `.gitignore` por escolha do usuário e não é enviado ao GitHub. A documentação em `docs/` é versionada.

Na demonstração, o tema começa seguindo o sistema e pode ser alterado para Claro/AMOLED. Essa seleção vive somente na memória e reinicia com o app. A decisão definitiva de preferência inicial/persistência (Q-006) continua aberta.
