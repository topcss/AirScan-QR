//
//  WebReceiverServer.swift
//  ios-cfc-client
//
//  极简本地静态 HTTP 服务（路线 B / v1.2.0）
//
//  作用：在 127.0.0.1 上以「同源」方式提供 WebResources（harness.html + cimbar-deps），
//  使 WKWebView 内的 Web Worker、fetch(wasm)、getUserMedia(secure context) 均能正常工作。
//  —— 不能用 file:// 加载：file:// 是 opaque origin，Worker 与 getUserMedia 都会失败。
//
//  实现：Network.framework (NWListener)，零第三方依赖。
//

import Foundation
import Network

//  隔离说明：本模块 SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor，默认会把这个类
//  也推成 MainActor 隔离。但它整套逻辑都跑在自己的串行队列 `queue` 上——
//  newConnectionHandler / receive / stateUpdateHandler 全由 Network.framework
//  在该队列回调，压根不碰主线程，而且把 HTTP 收发搬到主线程反而会和 WKWebView
//  的解码抢 CPU。所以这里显式 nonisolated，退出默认隔离；跨线程安全由 `queue`
//  的串行性保证，故仍标 @unchecked Sendable。
nonisolated final class WebReceiverServer: @unchecked Sendable {

    enum ServerError: Error {
        case resourceNotFound
        case listenerFailed
    }

    private let queue = DispatchQueue(label: "com.airscan.cfc.webserver")
    private var listener: NWListener?
    private(set) var rootDirectory: URL?
    private(set) var port: UInt16 = 0

    /// 启动服务并返回监听端口（异步等待 .ready）
    func start(root: URL) async throws -> UInt16 {
        self.rootDirectory = root

        let params = NWParameters.tcp
        // 绑定 127.0.0.1，端口 0 表示由系统分配空闲端口
        params.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host("127.0.0.1"),
            port: NWEndpoint.Port(rawValue: 0)!
        )

        let listener = try NWListener(using: params)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }

        // 等待监听就绪并拿到真实端口。
        // stateUpdateHandler 由 listener.start(queue:) 的串行队列投递，访问天然串行；
        // 用引用类型持有"已 resume"标记，避免捕获 var（Swift 6 语言模式下是错误）。
        // nonisolated：本模块默认 MainActor 隔离，而该标记只在网络队列上访问
        nonisolated final class ResumeOnce: @unchecked Sendable { var done = false }
        let once = ResumeOnce()

        let assignedPort: UInt16 = try await withCheckedThrowingContinuation { cont in
            listener.stateUpdateHandler = { state in
                let finish: (Result<UInt16, Error>) -> Void = { result in
                    guard !once.done else { return }
                    once.done = true
                    cont.resume(with: result)
                }
                switch state {
                case .ready:
                    finish(.success(listener.port?.rawValue ?? 0))
                case .failed(let err):
                    NSLog("[WebServer] 监听失败: \(err)")
                    finish(.failure(ServerError.listenerFailed))
                case .cancelled:
                    // stop() 与启动竞态时也必须 resume，否则调用方永久挂起
                    NSLog("[WebServer] 监听在就绪前被取消")
                    finish(.failure(ServerError.listenerFailed))
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }

        self.port = assignedPort
        NSLog("[WebServer] 已启动 http://127.0.0.1:\(assignedPort)  root=\(root.path)")
        return assignedPort
    }

    func stop() {
        listener?.cancel()
        listener = nil
        NSLog("[WebServer] 已停止")
    }

    // MARK: - 连接处理

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        receiveRequest(conn: conn, buffer: Data())
    }

    /// 循环读取，直到拿到完整的请求头（以 \r\n\r\n 结束；GET 无请求体）
    private func receiveRequest(conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self = self else { conn.cancel(); return }

            var buf = buffer
            if let data = data, !data.isEmpty { buf.append(data) }

            if let range = buf.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = buf.subdata(in: buf.startIndex..<range.lowerBound)
                let requestLine = String(data: headerData, encoding: .utf8)?
                    .components(separatedBy: "\r\n").first ?? ""
                self.respond(to: requestLine, on: conn)
                return
            }

            if error != nil || isComplete {
                self.respond(code: 400, body: Data("Bad Request".utf8),
                             contentType: "text/plain", on: conn)
                return
            }
            self.receiveRequest(conn: conn, buffer: buf)
        }
    }

    private func respond(to requestLine: String, on conn: NWConnection) {
        // 形如 "GET /harness.html HTTP/1.1"
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            respond(code: 405, body: Data("Method Not Allowed".utf8),
                    contentType: "text/plain", on: conn)
            return
        }

        var path = String(parts[1])
        if let q = path.firstIndex(of: "?") { path = String(path[..<q]) }
        path = path.removingPercentEncoding ?? path
        if path == "/" { path = "/harness.html" }

        guard let root = rootDirectory else {
            respond(code: 500, body: Data("No Root".utf8), contentType: "text/plain", on: conn)
            return
        }

        // 防目录穿越：标准化后必须仍在 root 之内。
        // 前缀必须带尾部分隔符，否则 WebResourcesBackup/ 这类同前缀兄弟目录能绕过。
        let fileURL = root.appendingPathComponent(String(path.dropFirst()))
            .standardizedFileURL
        let rootStd = root.standardizedFileURL
        var isDir: ObjCBool = false
        guard fileURL.path.hasPrefix(rootStd.path + "/"),
              FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir),
              !isDir.boolValue
        else {
            respond(code: 404, body: Data("Not Found".utf8), contentType: "text/plain", on: conn)
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            respond(code: 200, body: data,
                    contentType: Self.contentType(for: fileURL.pathExtension), on: conn)
        } catch {
            respond(code: 500, body: Data("Read Error".utf8), contentType: "text/plain", on: conn)
        }
    }

    private func respond(code: Int, body: Data, contentType: String, on conn: NWConnection) {
        let reason: String
        switch code {
        case 200: reason = "OK"
        case 404: reason = "Not Found"
        case 405: reason = "Method Not Allowed"
        default:  reason = "Error"
        }
        var head = "HTTP/1.1 \(code) \(reason)\r\n"
        head += "Content-Type: \(contentType)\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Cache-Control: no-store\r\n"
        head += "Access-Control-Allow-Origin: *\r\n"
        head += "Connection: close\r\n\r\n"

        var out = Data(head.utf8)
        out.append(body)

        conn.send(content: out, completion: .contentProcessed { _ in
            conn.cancel()
        })
    }

    private static func contentType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs":   return "application/javascript"
        case "wasm":        return "application/wasm"
        case "json":        return "application/json"
        case "css":         return "text/css"
        case "png":         return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "svg":         return "image/svg+xml"
        default:            return "application/octet-stream"
        }
    }
}
