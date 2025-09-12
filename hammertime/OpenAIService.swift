//
//  OpenAIService.swift
//  hammertime
//

import Foundation

enum OpenAIError: Error { case missingApiKey, invalidResponse }

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
        let apiKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String
        let system = "You are a concise, encouraging personal trainer. Be specific and actionable."
        let contextJoined = contextLines.joined(separator: "\n")
        let messages = [
            ChatRequest.Message(role: "system", content: system),
            ChatRequest.Message(role: "user", content: "Recent workouts (most recent first):\n\(contextJoined)\n\nUser: \(userMessage)")
        ]

        guard let key = apiKey, !key.isEmpty else {
            // Deterministic offline fallback
            return "Got it. Based on your recent sessions, consider a progressive overload and prioritize recovery. What is your goal for today?"
        }

        let req = ChatRequest(model: "gpt-4o-mini", temperature: 0.4, messages: messages, max_tokens: 600)
        var urlReq = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlReq.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        urlReq.httpBody = try JSONEncoder().encode(req)

        let (data, resp) = try await URLSession.shared.data(for: urlReq)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        if let first = decoded.choices.first?.message.content, !first.isEmpty { return first }
        throw OpenAIError.invalidResponse
    }
}


