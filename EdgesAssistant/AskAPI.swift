import Combine
import Foundation

/// 公网默认地址，不含 `/api/ask`。要换编译进 App 的默认 base，只改这一处。
enum APIConfig {
    static let defaultBaseURL = "https://edges-rag.viruspc.tech"
    static let storageKey = "edgesAssistant.apiBaseURL"
}

struct AskRequest: Encodable {
    let question: String
}

struct Citation: Decodable, Identifiable {
    let path: String
    let snippet: String
    let score: Double
    let id: UUID

    init(path: String, snippet: String, score: Double) {
        self.path = path
        self.snippet = snippet
        self.score = score
        self.id = UUID()
    }

    private enum CodingKeys: String, CodingKey {
        case path, snippet, score
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        snippet = try container.decode(String.self, forKey: .snippet)
        score = try container.decode(Double.self, forKey: .score)
        id = UUID()
    }
}

struct AskResponse: Decodable {
    let answer: String
    let citations: [Citation]

    init(answer: String, citations: [Citation]) {
        self.answer = answer
        self.citations = citations
    }

    private enum CodingKeys: String, CodingKey {
        case answer, citations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        answer = try container.decode(String.self, forKey: .answer)
        citations = try container.decodeIfPresent([Citation].self, forKey: .citations) ?? []
    }
}

/// 本地短示例，不访问网络。文案只用来看界面，不是服务器回答。
enum SampleAnswer {
    static let response = AskResponse(
        answer: "Edges 把讨论、任务和实践留在目录里，并用 Git 管理。下一个 Agent 可以沿着索引找到相关材料，接着往下做。",
        citations: [
            Citation(
                path: "README.md",
                snippet: "Harness any directory. Your brain is one too.",
                score: 0.860
            ),
            Citation(
                path: "README.md",
                snippet: "讨论留下理由，任务留下目标，实践留下方法。",
                score: 0.742
            )
        ]
    )
}

enum AskError: Error {
    case failed(String)

    var message: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

enum AskClient {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 90
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    static func describeEndpoint(base: String) -> String {
        (try? endpoint(from: base).absoluteString) ?? "地址无效"
    }

    static func ask(question: String, baseURL: String) async throws -> AskResponse {
        let url = try endpoint(from: baseURL)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 90
        request.httpBody = try JSONEncoder().encode(AskRequest(question: question))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            if error.code == .cancelled {
                throw CancellationError()
            }
            throw AskError.failed(message(for: error))
        }

        guard let http = response as? HTTPURLResponse else {
            throw AskError.failed("服务器没有返回有效的 HTTP 响应。")
        }
        guard (200..<300).contains(http.statusCode) else {
            if let detail = serverMessage(from: data) {
                throw AskError.failed("请求失败（HTTP \(http.statusCode)）。\(detail)")
            }
            throw AskError.failed("请求失败（HTTP \(http.statusCode)）。")
        }

        do {
            return try JSONDecoder().decode(AskResponse.self, from: data)
        } catch {
            throw AskError.failed("服务器返回的内容无法识别。")
        }
    }

    /// 接受 `https://host` 或已经写全的 `https://host/api/ask`。空字符串用默认公网地址。
    static func endpoint(from base: String) throws -> URL {
        var raw = base.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            raw = APIConfig.defaultBaseURL
        }
        while raw.hasSuffix("/") {
            raw.removeLast()
        }
        if !raw.lowercased().hasSuffix("/api/ask") {
            raw += "/api/ask"
        }

        guard
            let components = URLComponents(string: raw),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host,
            !host.isEmpty,
            let url = components.url
        else {
            throw AskError.failed("接口地址不正确。请填写以 http:// 或 https:// 开头的地址。")
        }
        return url
    }

    private static func message(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return "网络不可用。请检查连接后再试。"
        case .timedOut:
            return "请求超时。索引回答有时较慢，可以再试一次。"
        case .cannotFindHost:
            return "找不到服务器。请检查接口地址。"
        case .cannotConnectToHost:
            return "连不上服务器。请检查接口地址和网络。"
        case .appTransportSecurityRequiresSecureConnection:
            return "系统拦截了这个明文 HTTP 地址。公网 HTTPS 可以直接用；若要用 HTTP，请看 README 里的 ATS 说明。"
        case .secureConnectionFailed, .serverCertificateUntrusted:
            return "安全连接失败。请确认接口地址和证书。"
        default:
            return "网络请求失败（\(error.code.rawValue)）。"
        }
    }

    private static func serverMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["detail", "message", "error"] {
                if let text = object[key] as? String {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        return clip(trimmed)
                    }
                }
            }
            if let details = object["detail"] as? [[String: Any]] {
                let messages = details.compactMap { $0["msg"] as? String }
                if !messages.isEmpty {
                    return clip(messages.joined(separator: "；"))
                }
            }
        }
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("<") {
            return nil
        }
        return clip(trimmed)
    }

    private static func clip(_ text: String) -> String {
        if text.count <= 180 {
            return text
        }
        return String(text.prefix(180)) + "…"
    }
}

@MainActor
final class AskModel: ObservableObject {
    @Published var question = ""
    @Published var baseURL: String
    @Published private(set) var answer: String?
    @Published private(set) var citations: [Citation] = []
    @Published private(set) var isSample = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let defaults: UserDefaults
    private var task: Task<Void, Never>?
    private var generation = UUID()

    var canAsk: Bool {
        !isLoading && !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: APIConfig.storageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        baseURL = stored.isEmpty ? APIConfig.defaultBaseURL : stored
    }

    func updateBaseURL(_ value: String) {
        baseURL = value
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == APIConfig.defaultBaseURL {
            defaults.removeObject(forKey: APIConfig.storageKey)
        } else {
            defaults.set(trimmed, forKey: APIConfig.storageKey)
        }
    }

    func restoreDefaultBaseURL() {
        updateBaseURL(APIConfig.defaultBaseURL)
    }

    func showSample() {
        generation = UUID()
        task?.cancel()
        isLoading = false
        errorMessage = nil
        isSample = true
        answer = SampleAnswer.response.answer
        citations = SampleAnswer.response.citations
    }

    func ask() {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else {
            errorMessage = "请先输入问题。"
            return
        }
        guard !isLoading else { return }

        let token = UUID()
        generation = token
        task?.cancel()
        isLoading = true
        errorMessage = nil
        isSample = false
        answer = nil
        citations = []

        let base = baseURL
        task = Task {
            do {
                let response = try await AskClient.ask(question: trimmedQuestion, baseURL: base)
                guard generation == token else { return }
                answer = response.answer
                citations = response.citations
                isSample = false
                isLoading = false
            } catch is CancellationError {
                guard generation == token else { return }
                isLoading = false
            } catch let error as AskError {
                guard generation == token else { return }
                errorMessage = error.message
                isLoading = false
            } catch {
                guard generation == token else { return }
                errorMessage = "提问失败。"
                isLoading = false
            }
        }
    }
}
