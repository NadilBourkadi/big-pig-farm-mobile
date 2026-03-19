#if DEBUG || INTERNAL
/// DebugServer — Embedded HTTP debug server for querying debug logs.
///
/// Listens on TCP port 8361 via NWListener. Only compiled in DEBUG builds.
/// Routes:
///   GET /events?category=&level=&pig_id=&since=&until=&limit=&offset=
///   GET /categories
///   GET /export
///   GET /
import Foundation
import Network

// MARK: - DebugServer

/// Lightweight HTTP server for querying the debug log from external tools.
@MainActor
final class DebugServer {
    private var listener: NWListener?
    private let port: UInt16 = 8361
    private let logger: DebugLogger

    init(logger: DebugLogger) {
        self.logger = logger
    }

    /// Start listening. Idempotent — does nothing if already started.
    func start() {
        guard listener == nil else { return }
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        do {
            listener = try NWListener(using: .tcp, on: nwPort)
        } catch {
            print("[DebugServer] Failed to create listener: \(error)")
            return
        }
        listener?.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                print("[DebugServer] Listening on port \(self.port)")
            case .failed(let error):
                print("[DebugServer] Failed: \(error)")
            default:
                break
            }
        }
        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in
                self?.handleConnection(connection)
            }
        }
        listener?.start(queue: .main)
    }

    /// Stop listening. Idempotent.
    func stop() {
        listener?.cancel()
        listener = nil
    }
}

// MARK: - Connection Handling

extension DebugServer {
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: 8192
        ) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else {
                connection.cancel()
                return
            }
            Task { @MainActor in
                await self.processRequest(data: data, connection: connection)
            }
        }
    }

    private func processRequest(
        data: Data, connection: NWConnection
    ) async {
        let (path, params) = parseRequest(data)
        let result = await routeRequest(path: path, params: params)
        let response = buildHTTPResponse(
            statusCode: result.statusCode,
            contentType: result.contentType,
            body: result.body
        )
        connection.send(
            content: response, completion: .contentProcessed { _ in
                connection.cancel()
            }
        )
    }
}

// MARK: - Request Parsing

extension DebugServer {
    private func parseRequest(
        _ data: Data
    ) -> (path: String, params: [String: String]) {
        guard let requestLine = String(data: data, encoding: .utf8)?
            .components(separatedBy: "\r\n").first else {
            return ("/", [:])
        }
        // Parse "GET /path?key=val HTTP/1.1"
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return ("/", [:]) }
        let fullPath = String(parts[1])

        guard let components = URLComponents(string: fullPath) else {
            return (fullPath, [:])
        }
        let path = components.path
        var params: [String: String] = [:]
        for item in components.queryItems ?? [] {
            if let value = item.value, !value.isEmpty {
                params[item.name] = value
            }
        }
        return (path, params)
    }
}

// MARK: - Routing

extension DebugServer {
    private struct HTTPResult {
        let statusCode: Int
        let contentType: String
        let body: Data
    }

    private func routeRequest(
        path: String, params: [String: String]
    ) async -> HTTPResult {
        switch path {
        case "/events":
            let body = await handleEvents(params: params)
            return HTTPResult(statusCode: 200, contentType: "application/json", body: body)
        case "/categories":
            let body = await handleCategories()
            return HTTPResult(statusCode: 200, contentType: "application/json", body: body)
        case "/export":
            let body = await handleExport()
            return HTTPResult(statusCode: 200, contentType: "application/json", body: body)
        case "/":
            let body = handleRoot()
            return HTTPResult(statusCode: 200, contentType: "text/html", body: body)
        default:
            let error = #"{"error":"Not found"}"#
            return HTTPResult(statusCode: 404, contentType: "application/json", body: Data(error.utf8))
        }
    }

    private func handleEvents(
        params: [String: String]
    ) async -> Data {
        let category = params["category"].flatMap {
            DebugCategory(rawValue: $0)
        }
        let level = params["level"].flatMap {
            DebugLevel(rawValue: Int($0) ?? -1)
        }
        let pigId = params["pig_id"].flatMap { UUID(uuidString: $0) }
        let since = params["since"].flatMap { Int($0) }
        let until = params["until"].flatMap { Int($0) }
        let limit = params["limit"].flatMap { Int($0) } ?? 100
        let offset = params["offset"].flatMap { Int($0) } ?? 0

        logger.flush()
        let events = await logger.query(
            category: category, level: level, pigId: pigId,
            sinceGameDay: since, untilGameDay: until,
            limit: limit, offset: offset
        )
        return (try? JSONEncoder().encode(events)) ?? Data("[]".utf8)
    }

    private func handleCategories() async -> Data {
        logger.flush()
        let cats = await logger.categories()
        var dict: [String: Int] = [:]
        for (cat, count) in cats { dict[cat] = count }
        return (try? JSONEncoder().encode(dict)) ?? Data("{}".utf8)
    }

    private func handleExport() async -> Data {
        logger.flush()
        return await logger.exportJSON()
    }

    private func handleRoot() -> Data {
        let html = """
        <html><body>
        <h2>Big Pig Farm Debug Server</h2>
        <ul>
        <li><a href="/events?limit=50">/events</a> — query events</li>
        <li><a href="/categories">/categories</a> — event counts</li>
        <li><a href="/export">/export</a> — export all events</li>
        </ul>
        <p>Query params for /events: category, level, pig_id, \
        since, until, limit, offset</p>
        </body></html>
        """
        return Data(html.utf8)
    }
}

// MARK: - HTTP Response Builder

extension DebugServer {
    private func buildHTTPResponse(
        statusCode: Int,
        contentType: String,
        body: Data
    ) -> Data {
        let statusText: String = switch statusCode {
        case 200: "OK"
        case 400: "Bad Request"
        case 404: "Not Found"
        default: "Error"
        }
        let header = """
        HTTP/1.1 \(statusCode) \(statusText)\r\n\
        Content-Type: \(contentType)\r\n\
        Content-Length: \(body.count)\r\n\
        Connection: close\r\n\
        Access-Control-Allow-Origin: *\r\n\
        \r\n
        """
        var response = Data(header.utf8)
        response.append(body)
        return response
    }
}
#endif
