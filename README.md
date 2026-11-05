# Destinia iOS — port pessoal experimental

**Status: o IPA experimental já foi compilado no GitHub Actions, mas a execução física no iPhone ainda precisa ser validada.**

A primeira compilação usou a revisão `3410901fe980497d7cab8283af50dc65ea26a73d` (05/11/2026). Agora o workflow consulta a `main` mais recente de `sugyua/destinia` a cada compilação; gera IPA apenas depois de verificar que os adaptadores do iOS continuam compatíveis.

Projeto independente que encapsula a implementação Web/WASM do [Destinia para PC/Web](https://github.com/sugyua/destinia) em um aplicativo iOS horizontal, offline, executado via `WKWebView`. Reusa a `.so` ARM32 Android através de Unicorn.js/WASM (não executa o binário Android diretamente em arm64), e copia os assets do APK já extraído no repositório de origem.

## Recursos implementados no projeto iOS

- Aplicativo SwiftUI + `WKWebView`, orientação horizontal e tela cheia, com controles touch existentes no port Web.
- Servidor HTTP embutido **somente em `127.0.0.1:19406`** (porta fixa). Não requer internet durante o jogo. Usa HTTP local porque `Worker`, `importScripts`, `fetch` e módulos precisam ser servidos por uma origem adequada.
- `GET /api/save?format=json`, `POST /api/save` e `DELETE /api/save` compatíveis com o esquema de saves da Web. Escritas atômicas no diretório **Documents/DestiniaSaves**; dados só confirmados após a gravação local.
- `localStorage` da Web preservado entre inicializações, desde que a origem `127.0.0.1:19406` seja mantida (inclusive em atualizações).
- Preparação reproduzível dos assets via `web/tools/pack_game.py` do projeto original. Falha se a biblioteca ARM tiver SHA-256 diferente do esperado.
- Workflow macOS que compila um **IPA não assinado**, para posterior assinatura pessoal no Windows por Sideloadly. A execução manual usa a fonte mais recente e a execução automática diária só compila quando o commit do repositório principal muda.

**Limites da versão 0.1 experimental:** a jogabilidade, o FPS, o áudio, o suporte a gamepad e o restauro real de saves em iPhone ainda não foram confirmados. O port Web anterior documenta áudio desativado; este projeto **não adiciona áudio nativo**. O jogo precisa ser salvo pelos comandos do próprio Destinia; fechar o app sem salvar ainda pode perder o progresso recente. Um novo app instalado com outro identificador/conta pode perder acesso aos saves antigos. Não desinstale sem backup.

## Fonte AltStore Classic (metadados públicos)

A fonte [source.json](source.json) foi criada no repositório público e pode ser adicionada ao AltStore Classic pelo endereço:

```text
https://raw.githubusercontent.com/sugyua/Destinia_IOS/main/source.json
```

**Situação:** a fonte atualmente não lista nenhum aplicativo, pois ainda não existe um `downloadURL` público, estável e autorizado para um IPA do Destinia. O arquivo da compilação antiga do GitHub Actions não é um endereço de download direto e permanente. Não apresentar um link hipotético como se houvesse um jogo instalável.

**Atenção aos direitos autorais:** o IPA inclui código e recursos originais da GAMEVIL/Everple. A fonte pública não distribui esses arquivos, e o workflow existente impede compilar esses recursos em um repositório público. Tornar o repositório público não equivale a ter autorização para distribuir os conteúdos do jogo. Para uso exclusivamente pessoal, mantenha a compilação/distribuição do IPA em ambiente privado e faça a instalação pela sua própria conta Apple.

Quando houver um IPA que possa ser legitimamente disponibilizado com URL HTTPS estável, a fonte pode ganhar o registro do app com `bundleIdentifier`, `iconURL`, `versions`, `downloadURL`, `size` e informações de permissões compatíveis com o formato oficial da AltStore.

## Atualizações automáticas e compilação manual

Repositório iOS **atualmente público**: [sugyua/Destinia_IOS](https://github.com/sugyua/Destinia_IOS).

- **Manual**: abra [Actions](https://github.com/sugyua/Destinia_IOS/actions), escolha **Compilar Destinia iOS (IPA pessoal, sem assinatura)** e clique em **Run workflow**. Sempre busca a última revisão da `main` do repositório do PC, mesmo que ela não tenha mudado.
- **Automática**: todos os dias, às **08:15 (horário de Brasília, UTC-3)**, o GitHub verifica a revisão da `main` do PC. Se for igual à última fonte compilada com sucesso, o job macOS não é executado. Se mudou, tenta construir um novo IPA. O GitHub pode atrasar o início dos agendamentos.
- **Registro de sucesso**: após a compilação e disponibilização do artefato, o workflow atualiza `.github/last-successful-source.txt` no repositório privado. Se o motor, os recursos ou os adaptadores forem incompatíveis, o build falha e **não marca a fonte como compilada**.
- **Versão do aplicativo**: utiliza `VERSION` do projeto principal no `CFBundleShortVersionString`, se estiver em formato `X.Y.Z`; o `CFBundleVersion` aumenta a cada execução. Isto **não significa que mudanças feitas apenas no host Windows C++ funcionem no iOS**: o app usa principalmente `web/dist` e os dados originais.
- **Privacidade**: os dados proprietários são empacotados somente durante o build no repositório privado, e o IPA é disponibilizado como artefato privado por 30 dias, nunca em uma release pública.
- **Permissões**: o job de registro usa `GITHUB_TOKEN` com `contents:write` exclusivamente para manter o arquivo de controle no repositório privado. Se estiver bloqueado, confira Settings → Actions → General → Workflow permissions.

### Instalar a atualização no iPhone

1. Abra a execução concluída e baixe o artefato `Destinia-iOS-unsigned-<sha>`; ele contém `Destinia-iOS-unsigned.ipa`, `BUILD_INFO.txt` e `SHA256SUMS.txt`.
2. Extraia o ZIP, abra [Sideloadly](https://sideloadly.io/) no Windows, assine com a **mesma conta Apple** e instale sobre o app existente, mantendo o mesmo bundle ID `br.sugyua.destinia.private`.
3. **Não desinstale o aplicativo antes de atualizar.** Os saves ficam em `Documents/DestiniaSaves`, fora do bundle, mas preservar os dados depende de uma instalação como atualização (não remoção/reinstalação). Faça backup antes, principalmente enquanto o port não está validado no iPhone.
4. Na conta Apple gratuita a assinatura normalmente precisa ser renovada a cada 7 dias.

A atualização do código e a geração do IPA podem ser automáticas; **a instalação no seu iPhone não é automática**. O iOS não executa diretamente as alterações do host Windows em C++; elas precisam estar implementadas também no código Web que a versão iOS utiliza.

## Compilar com um Mac (alternativo)

Requisitos: macOS + Xcode, `python3`, `git`, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/sugyua/destinia.git upstream
python3 scripts/prepare_web.py --repo upstream
python3 scripts/check_prepared.py
xcodegen generate --spec project.yml
open DestiniaIOS.xcodeproj
```

Escolha o scheme `DestiniaIOS`, um iPhone e sua equipe pessoal em **Signing & Capabilities**. Compilar e instalar diretamente pelo Xcode com Apple ID gratuito é uma alternativa ao IPA/Sideloadly.

## Origem e segurança dos dados

- A pasta do jogo é montada **no build** e incluída no app bundle. Não é servida pela internet; o servidor liga-se a `127.0.0.1`.
- O build roda um empacotador do projeto original para gerar `game/assets.bin` e `game/libdestinia_jni.so` a partir do seu checkout.
- Os recursos originais da GAMEVIL/Everple são de terceiros. Não distribua publicamente a versão empacotada sem autorização e análise de licenças.
- O código da ponte Unicorn.js possui licenciamento GPL-2.0 conforme `web/dist/vendor/UNICORN-LICENSE.txt` no projeto original; a redistribuição exigiria conformidade com as respectivas licenças.
- **Não é um port nativo ARM64 da engine.** É uma versão iOS da implementação WebAssembly já existente, cujo desempenho é incerto sem testes físicos.
- Não foi modificado nem realizado commit no repositório `sugyua/destinia`.

## Estrutura

```text
Destinia-iOS/
├── DestiniaIOS/
│   ├── Sources/
│   │   ├── DestiniaIOSApp.swift
│   │   ├── GameScreen.swift
│   │   └── LoopbackServer.swift
│   └── Info.plist
├── Web/                     # empacotado como pasta de recursos
├── scripts/
│   ├── prepare_web.py
│   └── check_prepared.py
├── project.yml             # XcodeGen
├── .github/workflows/ios-ipa.yml
├── tests/
└── CHECKLIST_TESTES.md
```

## Desenvolvimento e testes

```bash
python3 -m unittest discover -s tests -v
```

`prepare_web.py` não altera fontes originais do Windows/Web: adapta a cópia para iOS, inclusive exclusão de saves, mensagens de status e CSS de tela horizontal. Se o código original de `engine.mjs` mudar de forma incompatível, o build interrompe em vez de aplicar uma substituição silenciosa incorreta.

O programa é destinado ao uso pessoal do proprietário. Sem publicação na App Store, sem upload de credenciais, sem publicação automática de artefatos.
