import Foundation
import Network

enum OAuthCallbackError: Error {
    case listenerNotStarted
    case callbackTimeout
    case callbackCancelled
    case invalidRequest
    case stateMismatch
    case authorizationFailed(String)
    case missingAuthorizationCode
}

extension OAuthCallbackError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .listenerNotStarted:
            return "OAuth callback server is not started."
        case .callbackTimeout:
            return "OAuth callback timeout."
        case .callbackCancelled:
            return "OAuth callback cancelled."
        case .invalidRequest:
            return "Invalid OAuth callback request."
        case .stateMismatch:
            return "OAuth callback state mismatch."
        case .authorizationFailed(let message):
            return "OAuth authorization failed: \(message)"
        case .missingAuthorizationCode:
            return "No authorization code in callback."
        }
    }
}

struct OAuthCallbackResult: Equatable {
    let code: String
    let state: String
}

final class OAuthCallbackServer {
    private let queue = DispatchQueue(label: "com.antigravity.proxy.oauth.callback")
    private var listener: NWListener?
    private var port: UInt16?
    private var continuation: CheckedContinuation<OAuthCallbackResult, Error>?
    private var expectedState: String?
    private var timeoutTask: Task<Void, Never>?

    var redirectURI: String {
        guard let port else {
            return ""
        }
        return "http://\(OAuthConstants.callbackHost):\(port)\(OAuthConstants.callbackPath)"
    }

    func start() async throws {
        if listener != nil {
            return
        }

        let nwListener = try NWListener(using: .tcp, on: .any)
        listener = nwListener

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            final class ResumeGate {
                private var hasResumed = false
                private let lock = NSLock()

                func tryMarkResumed() -> Bool {
                    lock.lock()
                    defer { lock.unlock() }
                    if hasResumed {
                        return false
                    }
                    hasResumed = true
                    return true
                }
            }

            let gate = ResumeGate()
            nwListener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.port = nwListener.port?.rawValue
                    if gate.tryMarkResumed() {
                        cont.resume()
                    }
                case .failed(let error):
                    if gate.tryMarkResumed() {
                        cont.resume(throwing: error)
                    }
                default:
                    break
                }
            }

            nwListener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            nwListener.start(queue: queue)
        }
    }

    func waitForCallback(expectedState: String, timeout: TimeInterval = OAuthConstants.authTimeoutSeconds) async throws -> OAuthCallbackResult {
        guard listener != nil else {
            throw OAuthCallbackError.listenerNotStarted
        }

        self.expectedState = expectedState

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<OAuthCallbackResult, Error>) in
                continuation = cont
                timeoutTask = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    self?.finishWithError(OAuthCallbackError.callbackTimeout)
                }
            }
        }, onCancel: {
            self.finishWithError(OAuthCallbackError.callbackCancelled)
        })
    }

    func stop() {
        timeoutTask?.cancel()
        timeoutTask = nil
        expectedState = nil

        listener?.cancel()
        listener = nil
        port = nil
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, _ in
            guard let self, let data else {
                connection.cancel()
                return
            }

            let requestText = String(decoding: data, as: UTF8.self)
            guard let requestLine = requestText.split(separator: "\r\n").first else {
                self.respond(connection: connection, status: "400 Bad Request", body: "Bad request")
                self.finishWithError(OAuthCallbackError.invalidRequest)
                return
            }

            let parts = requestLine.split(separator: " ")
            guard parts.count >= 2 else {
                self.respond(connection: connection, status: "400 Bad Request", body: "Bad request")
                self.finishWithError(OAuthCallbackError.invalidRequest)
                return
            }

            let rawPath = String(parts[1])
            guard rawPath.hasPrefix(OAuthConstants.callbackPath) else {
                self.respond(connection: connection, status: "404 Not Found", body: "Not Found")
                return
            }

            let full = rawPath.hasPrefix("http") ? rawPath : "http://\(OAuthConstants.callbackHost)\(rawPath)"
            guard let url = URL(string: full), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                self.respond(connection: connection, status: "400 Bad Request", body: "Invalid callback")
                self.finishWithError(OAuthCallbackError.invalidRequest)
                return
            }

            let values = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

            if let error = values["error"] {
                let description = values["error_description"] ?? error
                self.respond(connection: connection, status: "200 OK", body: "Authorization failed, you can close this tab.")
                self.finishWithError(OAuthCallbackError.authorizationFailed(description))
                return
            }

            guard let code = values["code"], !code.isEmpty else {
                self.respond(connection: connection, status: "200 OK", body: "Missing authorization code, you can close this tab.")
                self.finishWithError(OAuthCallbackError.missingAuthorizationCode)
                return
            }

            guard let callbackState = values["state"], callbackState == self.expectedState else {
                self.respond(connection: connection, status: "200 OK", body: "State mismatch, you can close this tab.")
                self.finishWithError(OAuthCallbackError.stateMismatch)
                return
            }

            self.respond(connection: connection, status: "200 OK", body: "Authorization successful, you can close this tab.")
            self.finishWithResult(OAuthCallbackResult(code: code, state: callbackState))
        }
    }

    private func respond(connection: NWConnection, status: String, body: String) {
        let payload = """
HTTP/1.1 \(status)
Content-Type: text/plain; charset=utf-8
Content-Length: \(body.utf8.count)
Connection: close

\(body)
"""
        connection.send(content: payload.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func finishWithResult(_ result: OAuthCallbackResult) {
        timeoutTask?.cancel()
        timeoutTask = nil

        continuation?.resume(returning: result)
        continuation = nil
    }

    private func finishWithError(_ error: Error) {
        timeoutTask?.cancel()
        timeoutTask = nil

        continuation?.resume(throwing: error)
        continuation = nil
    }
}
