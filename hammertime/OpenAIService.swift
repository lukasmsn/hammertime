//
//  OpenAIService.swift
//  hammertime
//

import Foundation

enum OpenAIError: Error {
    case missingApiKey
    case http(status: Int, body: String?)
    case decoding
    case network(underlying: Error)
}

final class OpenAIService {
    static let shared = OpenAIService()
    private init() {}

    struct ChatRequest: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        let model: String
        let temperature: Double
        let messages: [Message]
        let max_tokens: Int
    }

    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let role: String; let content: String }
            let index: Int
            let message: Message
        }
        let choices: [Choice]
    }

    func singleShotReply(contextLines: [String], userMessage: String) async throws -> String {
        let bundleKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String
        let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        let apiKey = (bundleKey?.isEmpty == false ? bundleKey : nil) ?? (envKey?.isEmpty == false ? envKey : nil)
        #if DEBUG
        if let bundleKey, !bundleKey.isEmpty { print("[OpenAI] Found key in Info.plist (len=\(bundleKey.count))") }
        if let envKey, !envKey.isEmpty { print("[OpenAI] Found key in ENV (len=\(envKey.count))") }
        #endif
        let system = "You are a concise, encouraging personal trainer. Be specific and actionable."
        let contextJoined = contextLines.joined(separator: "\n\n")
        let messages = [
            ChatRequest.Message(role: "system", content: system),
            ChatRequest.Message(role: "system", content: "Context block (METRICS_JSON) follows. Use it for analysis and coaching.\n\n\(contextJoined)"),
            ChatRequest.Message(role: "user", content: userMessage)
        ]

        guard let key = apiKey, !key.isEmpty else {
            #if DEBUG
            print("[OpenAI] Missing API key. Set OPENAI_API_KEY in Secrets.xcconfig (Base Configuration) or environment.")
            if let dict = Bundle.main.infoDictionary { print("[OpenAI] Info.plist keys: \(dict.keys.sorted())") }
            throw OpenAIError.missingApiKey
            #else
            // Deterministic offline fallback in Release
            return "Got it. Based on your recent sessions, consider a progressive overload and prioritize recovery. What is your goal for today?"
            #endif
        }

        let req = ChatRequest(model: "gpt-4o-mini", temperature: 0.4, messages: messages, max_tokens: 600)
        var urlReq = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlReq.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        urlReq.httpBody = try JSONEncoder().encode(req)

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await URLSession.shared.data(for: urlReq)
        } catch {
            #if DEBUG
            print("[OpenAI] Network error: \(error)")
            #endif
            throw OpenAIError.network(underlying: error)
        }

        guard let http = resp as? HTTPURLResponse else {
            throw OpenAIError.http(status: -1, body: nil)
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)
            #if DEBUG
            print("[OpenAI] HTTP \(http.statusCode): \(body ?? "<no body>")")
            #endif
            throw OpenAIError.http(status: http.statusCode, body: body)
        }

        do {
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            if let first = decoded.choices.first?.message.content, !first.isEmpty { return first }
            throw OpenAIError.decoding
        } catch {
            #if DEBUG
            print("[OpenAI] Decoding error: \(error)")
            #endif
            throw OpenAIError.decoding
        }
    }

    // Chat with history. History should be ordered oldest→newest.
    func replyWithHistory(contextLines: [String], history: [(role: String, content: String)]) async throws -> String {
        let bundleKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String
        let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        let apiKey = (bundleKey?.isEmpty == false ? bundleKey : nil) ?? (envKey?.isEmpty == false ? envKey : nil)
        #if DEBUG
        if let bundleKey, !bundleKey.isEmpty { print("[OpenAI] Found key in Info.plist (len=\(bundleKey.count))") }
        if let envKey, !envKey.isEmpty { print("[OpenAI] Found key in ENV (len=\(envKey.count))") }
        #endif

        guard let key = apiKey, !key.isEmpty else {
            #if DEBUG
            print("[OpenAI] Missing API key. Set OPENAI_API_KEY in Secrets.xcconfig (Base Configuration) or environment.")
            if let dict = Bundle.main.infoDictionary { print("[OpenAI] Info.plist keys: \(dict.keys.sorted())") }
            throw OpenAIError.missingApiKey
            #else
            return "Got it. Based on your recent sessions, consider a progressive overload and prioritize recovery. What is your goal for today?"
            #endif
        }

        let system = "You are a concise, encouraging personal trainer. Be specific and actionable."
        let contextJoined = contextLines.joined(separator: "\n\n")

        var messages: [ChatRequest.Message] = [
            ChatRequest.Message(role: "system", content: system)
        ]
        if !contextJoined.isEmpty {
            messages.append(ChatRequest.Message(role: "system", content: "Context block (METRICS_JSON) follows. Use it for analysis and coaching.\n\n\(contextJoined)"))
        }
        for m in history {
            let role = (m.role == "assistant" ? "assistant" : "user")
            messages.append(ChatRequest.Message(role: role, content: m.content))
        }

        let req = ChatRequest(model: "gpt-4o-mini", temperature: 0.4, messages: messages, max_tokens: 600)
        var urlReq = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlReq.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        urlReq.httpBody = try JSONEncoder().encode(req)

        let data: Data
        let resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: urlReq) } catch {
            #if DEBUG
            print("[OpenAI] Network error: \(error)")
            #endif
            throw OpenAIError.network(underlying: error)
        }

        guard let http = resp as? HTTPURLResponse else { throw OpenAIError.http(status: -1, body: nil) }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)
            #if DEBUG
            print("[OpenAI] HTTP \(http.statusCode): \(body ?? "<no body>")")
            #endif
            throw OpenAIError.http(status: http.statusCode, body: body)
        }

        do {
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            if let first = decoded.choices.first?.message.content, !first.isEmpty { return first }
            throw OpenAIError.decoding
        } catch {
            #if DEBUG
            print("[OpenAI] Decoding error: \(error)")
            #endif
            throw OpenAIError.decoding
        }
    }
}


