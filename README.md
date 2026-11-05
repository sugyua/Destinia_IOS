# Destinia iOS — port pessoal experimental

**Status: fontes iOS montados; IPA ainda não compilado nem testado em iPhone.**

Fontes de origem analisados no commit `3410901fe980497d7cab8283af50dc65ea26a73d` (05/11/2026); o workflow fixa esta revisão para evitar alterações futuras inesperadas.

Projeto independente que encapsula a implementação Web/WASM do [Destinia para PC/Web](https://github.com/sugyua/destinia) em um aplicativo iOS horizontal, offline, executado via `WKWebView`. Reusa a `.so` ARM32 Android através de Unicorn.js/WASM (não executa o binário Android diretamente em arm64), e copia os assets do APK já extraído no repositório de origem.

## Recursos implementados no projeto iOS

- Aplicativo SwiftUI + `WKWebView`, orientação horizontal e tela cheia, com controles touch existentes no port Web.
- Servidor HTTP embutido **somente em `127.0.0.1:19406`** (porta fixa). Não requer internet durante o jogo. Usa HTTP local porque `Worker`, `importScripts`, `fetch` e módulos precisam ser servidos por uma origem adequada.
- `GET /api/save?format=json`, `POST /api/save` e `DELETE /api/save` compatíveis com o esquema de saves da Web. Escritas atômicas no diretório **Documents/DestiniaSaves**; dados só confirmados após a gravação local.
- `localStorage` da Web preservado entre inicializações, desde que a origem `127.0.0.1:19406` seja mantida (inclusive em atualizações).
- Preparação reproduzível dos assets via `web/tools/pack_game.py` do projeto original. Falha se a biblioteca ARM tiver SHA-256 diferente do esperado.
- Workflow macOS que compila um **IPA não assinado**, para posterior assinatura pessoal no Windows por Sideloadly.

**Limites da versão 0.1 experimental:** a jogabilidade, o FPS, o áudio, o suporte a gamepad e o restauro real de saves em iPhone ainda não foram confirmados. O port Web anterior documenta áudio desativado; este projeto **não adiciona áudio nativo**. O jogo precisa ser salvo pelos comandos do próprio Destinia; fechar o app sem salvar ainda pode perder o progresso recente. Um novo app instalado com outro identificador/conta pode perder acesso aos saves antigos. Não desinstale sem backup.

## Gerar o IPA sem Mac, pelo GitHub Actions

**Importante:** crie um **repositório GitHub PRIVADO separado**, como `destinia-ios-private`. Não acrescente estes arquivos ao repositório Windows. O workflow precisa buscar os assets do repositório original apenas durante o build; esses arquivos entrarão no `.ipa` de uso pessoal e ficarão no artefato privado da execução.

1. Extraia este ZIP no Windows e abra PowerShell dentro da pasta extraída.
2. Crie um novo repositório vazio e privado no GitHub (não inicialize com README).
3. Com Git instalado, rode (substitua `SEU_USUARIO` e `destinia-ios-private`):

```powershell
git init
git add .
git commit -m "Destinia iOS 0.1 experimental"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/destinia-ios-private.git
git push -u origin main
```

4. No GitHub privado, abra **Actions → Compilar Destinia iOS (IPA pessoal, sem assinatura) → Run workflow**.
5. Quando a execução terminar com sucesso, abra a execução e baixe o artefato `Destinia-iOS-unsigned`. Dentro dele estarão `Destinia-iOS-unsigned.ipa` e `SHA256SUMS.txt`.
6. No Windows, use [Sideloadly](https://sideloadly.io/) para assinar o IPA com sua conta Apple gratuita e instalar no iPhone por USB. A renovação normalmente será necessária a cada **7 dias**. Jamais forneça a senha da Apple neste projeto ou no GitHub Actions.

**Nota:** não há garantia de que a primeira compilação passe ou de que o jogo rode sem erros no iPhone. O Xcode e as ferramentas Apple não estão disponíveis no ambiente em que estes fontes foram criados. Se o Actions falhar, preserve o log para corrigirmos a causa real.

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
