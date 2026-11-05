import SwiftUI
import WebKit

@MainActor
final class GameRuntime: ObservableObject {
    @Published private(set) var address: URL?
    @Published private(set) var errorMessage: String?
    private var server: LoopbackServer?

    func start() {
        guard server == nil else { return }
        guard let resources = Bundle.main.resourceURL else {
            errorMessage = "O pacote de recursos do aplicativo não está disponível."
            return
        }
        let web = resources.appendingPathComponent("Web", isDirectory: true)
        let required = ["index.html", "worker.js", "engine.mjs", "game/assets.bin", "game/libdestinia_jni.so", "vendor/unicorn_arm.js"]
        guard required.allSatisfy({ FileManager.default.fileExists(atPath: web.appendingPathComponent($0).path) }) else {
            errorMessage = "Arquivos do jogo ausentes no aplicativo. Execute scripts/prepare_web.py antes de compilar."
            return
        }
        do {
            let listener = try LoopbackServer(webRoot: web)
            server = listener
            listener.start { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success(let url):
                        self.address = url
                        self.errorMessage = nil
                    case .failure(let error):
                        self.address = nil
                        self.errorMessage = "Falha ao iniciar o servidor interno: \(error.localizedDescription)"
                        self.server = nil
                    }
                }
            }
        } catch {
            errorMessage = "Não foi possível preparar os arquivos locais: \(error.localizedDescription)"
        }
    }

    func retry() {
        address = nil
        errorMessage = nil
        server?.stop()
        server = nil
        start()
    }
}

struct GameScreen: View {
    @StateObject private var runtime = GameRuntime()

    var body: some View {
        ZStack {
            Color.black
            if let address = runtime.address {
                EmbeddedGameView(address: address)
                    .ignoresSafeArea()
            } else if let error = runtime.errorMessage {
                VStack(spacing: 16) {
                    Text("DESTINIA").font(.system(size: 27, weight: .bold, design: .monospaced)).foregroundColor(.yellow)
                    Text(error).multilineTextAlignment(.center).font(.footnote)
                    Button("Tentar novamente") { runtime.retry() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(28)
            } else {
                VStack(spacing: 14) {
                    ProgressView().tint(.yellow)
                    Text("Preparando Destinia offline…")
                        .font(.system(.footnote, design: .monospaced))
                }
                .foregroundColor(.white)
            }
        }
        .onAppear { runtime.start() }
        .statusBarHidden()
    }
}

struct EmbeddedGameView: UIViewRepresentable {
    let address: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // localStorage permanece estável com a porta fixa.
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.scrollView.bounces = false
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: address, cachePolicy: .reloadIgnoringLocalCacheData))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }
    func makeCoordinator() -> Coordinator { Coordinator(address: address) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let address: URL
        init(address: URL) { self.address = address }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            // O aplicativo não navega para sites externos.
            let allowed = url.scheme == "http" && url.host == "127.0.0.1" && url.port == address.port
            decisionHandler(allowed ? .allow : .cancel)
        }
    }
}
