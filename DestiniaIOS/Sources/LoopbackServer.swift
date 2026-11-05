import Foundation
import Network

/// Servidor HTTP local acessível somente em 127.0.0.1. Necessário para que
/// Worker, fetch, ES modules e WebAssembly usem uma origem HTTP consistente.
/// Não transmite dados do jogo pela rede externa.
final class LoopbackServer {
    private let queue = DispatchQueue(label: "br.destinia.http", qos: .userInitiated)
    private let listener: NWListener
    private let webRoot: URL
    private let savesRoot: URL
    private let maxRequestBytes = 10 * 1024 * 1024
    private let port: UInt16 = 19406
    private var didReportStart = false

    init(webRoot: URL) throws {
        self.webRoot = webRoot.standardizedFileURL
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "Destinia", code: 1, userInfo: [NSLocalizedDescriptionKey: "Diretório Documents indisponível"])
        }
        self.savesRoot = documentDirectory.appendingPathComponent("DestiniaSaves", isDirectory: true)
        try FileManager.default.createDirectory(at: savesRoot, withIntermediateDirectories: true)

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!)
        listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
    }

    func start(_ completion: @escaping (Result<URL, Error>) -> Void) {
        listener.newConnectionHandler = { [weak self] connection in
            guard let self = self else { connection.cancel(); return }
            connection.start(queue: self.queue)
            self.read(connection, collected: Data())
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self = self, !self.didReportStart else { return }
            switch state {
            case .ready:
                self.didReportStart = true
                completion(.success(URL(string: "http://127.0.0.1:\(self.port)/index.html")!))
            case .failed(let error):
                self.didReportStart = true
                completion(.failure(error))
            default:
                break
            }
        }
        listener.start(queue: queue)
    }

    func stop() { listener.cancel() }

    private func read(_ connection: NWConnection, collected: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] bytes, _, complete, error in
            guard let self = self else { connection.cancel(); return }
            if error != nil { connection.cancel(); return }
            var buffer = collected
            if let bytes = bytes { buffer.append(bytes) }
            if buffer.count > self.maxRequestBytes {
                self.respond(connection, status: 413, contentType: "text/plain; charset=utf-8", body: Data("Payload excessivo".utf8))
                return
            }
            if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let head = String(decoding: buffer[..<end.lowerBound], as: UTF8.self)
                let lengthLine = head.components(separatedBy: "\r\n").first { $0.lowercased().hasPrefix("content-length:") }
                let expected = lengthLine.flatMap { Int($0.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? "") } ?? 0
                if expected < 0 || expected > self.maxRequestBytes {
                    self.respond(connection, status: 413, contentType: "text/plain; charset=utf-8", body: Data())
                    return
                }
                let available = buffer.count - end.upperBound
                if available >= expected {
                    let body = buffer.subdata(in: end.upperBound..<(end.upperBound + expected))
                    self.route(connection, header: head, body: body)
                    return
                }
            }
            if complete { connection.cancel(); return }
            self.read(connection, collected: buffer)
        }
    }

    private func route(_ connection: NWConnection, header: String, body: Data) {
        let first = header.components(separatedBy: "\r\n").first ?? ""
        let parts = first.split(separator: " ")
        guard parts.count == 3 else { respond(connection, status: 400); return }
        let method = String(parts[0])
        let target = String(parts[1])
        guard (method == "GET" || method == "HEAD" || method == "POST" || method == "DELETE"),
              target.hasPrefix("/"), let components = URLComponents(string: "http://127.0.0.1\(target)") else {
            respond(connection, status: 400)
            return
        }

        if components.path == "/api/save" {
            handleSave(connection, method: method, body: body)
            return
        }
        guard method == "GET" || method == "HEAD" else { respond(connection, status: 405); return }

        let path = components.path == "/" ? "/index.html" : components.path
        let segments = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !segments.isEmpty && segments.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\\") && !$0.contains("\0") }) else {
            respond(connection, status: 403)
            return
        }
        let file = segments.reduce(webRoot) { $0.appendingPathComponent($1) }.standardizedFileURL
        guard file.path.hasPrefix(webRoot.path + "/"), !file.hasDirectoryPath,
              let data = try? Data(contentsOf: file, options: [.mappedIfSafe]) else {
            respond(connection, status: 404)
            return
        }
        let ext = file.pathExtension.lowercased()
        let mime: String
        switch ext {
        case "html": mime = "text/html; charset=utf-8"
        case "css": mime = "text/css; charset=utf-8"
        case "mjs", "js": mime = "text/javascript; charset=utf-8"
        case "json": mime = "application/json; charset=utf-8"
        case "wasm": mime = "application/wasm"
        case "png": mime = "image/png"
        case "jpg", "jpeg": mime = "image/jpeg"
        case "svg": mime = "image/svg+xml"
        case "ogg": mime = "audio/ogg"
        case "mp3": mime = "audio/mpeg"
        case "txt": mime = "text/plain; charset=utf-8"
        default: mime = "application/octet-stream"
        }
        respond(connection, status: 200, contentType: mime, body: method == "HEAD" ? Data() : data)
    }

    private func saveName(_ candidate: String) -> String? {
        guard candidate.count > 0 && candidate.count <= 80,
              candidate.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 46 || $0 == 95 }),
              !candidate.contains(".."), !candidate.hasPrefix("."),
              (candidate.lowercased().contains("save") || candidate.lowercased().contains("codex")) else { return nil }
        return candidate
    }

    private func handleSave(_ connection: NWConnection, method: String, body: Data) {
        switch method {
        case "GET", "HEAD":
            do {
                var saves: [String: String] = [:]
                for url in try FileManager.default.contentsOfDirectory(at: savesRoot, includingPropertiesForKeys: [.isRegularFileKey]) {
                    guard let name = saveName(url.lastPathComponent),
                          (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
                    saves[name] = try Data(contentsOf: url).base64EncodedString()
                }
                let payload = try JSONSerialization.data(withJSONObject: ["ok": true, "saves": saves])
                respond(connection, status: 200, contentType: "application/json; charset=utf-8", body: method == "HEAD" ? Data() : payload)
            } catch {
                respondJSONError(connection, status: 500, error: "Não foi possível ler os saves")
            }
        case "POST", "DELETE":
            guard let request = try? JSONSerialization.jsonObject(with: body) as? [String: String],
                  let rawName = request["name"], let name = saveName(rawName) else {
                respondJSONError(connection, status: 400, error: "Nome do save inválido")
                return
            }
            let destination = savesRoot.appendingPathComponent(name)
            do {
                if method == "POST" {
                    guard let rawData = request["data"], let decoded = Data(base64Encoded: rawData), decoded.count <= 6 * 1024 * 1024 else {
                        respondJSONError(connection, status: 400, error: "Conteúdo do save inválido")
                        return
                    }
                    try decoded.write(to: destination, options: .atomic)
                } else if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                let response = try JSONSerialization.data(withJSONObject: ["ok": true])
                respond(connection, status: 200, contentType: "application/json; charset=utf-8", body: response)
            } catch {
                respondJSONError(connection, status: 500, error: "Falha ao gravar save")
            }
        default:
            respond(connection, status: 405)
        }
    }

    private func respondJSONError(_ connection: NWConnection, status: Int, error: String) {
        let payload = (try? JSONSerialization.data(withJSONObject: ["ok": false, "error": error])) ?? Data()
        respond(connection, status: status, contentType: "application/json; charset=utf-8", body: payload)
    }

    private func respond(_ connection: NWConnection, status: Int, contentType: String = "text/plain; charset=utf-8", body: Data = Data()) {
        let reason: String
        switch status {
        case 200: reason = "OK"
        case 400: reason = "Bad Request"
        case 403: reason = "Forbidden"
        case 404: reason = "Not Found"
        case 405: reason = "Method Not Allowed"
        case 413: reason = "Payload Too Large"
        default: reason = "Internal Server Error"
        }
        let headers = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n"
        var payload = Data(headers.utf8)
        payload.append(body)
        connection.send(content: payload, completion: .contentProcessed { _ in connection.cancel() })
    }
}
