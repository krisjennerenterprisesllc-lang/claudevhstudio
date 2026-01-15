//
//  CoachingService.swift
//  VocalHeat
//
//  AI coaching with OpenAI integration (requires backend or Keychain configuration)
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation

@MainActor
class CoachingService: ObservableObject {
    @Published var isGenerating = false
    @Published var lastError: Error?

    // MARK: - Properties

    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/chat/completions"

    // MARK: - Initialization

    /// Initialize with API key from Keychain or environment
    /// WARNING: Never hardcode API keys in source code!
    init(apiKey: String? = nil) {
        // Try to load from Keychain first
        if let key = Self.loadAPIKeyFromKeychain() {
            self.apiKey = key
        } else if let key = apiKey {
            // Fallback to provided key (should come from secure source)
            self.apiKey = key
        } else {
            // No key available
            self.apiKey = ""
            print("⚠️ WARNING: No OpenAI API key configured. Coaching features will not work.")
            print("   Please configure API key in Keychain or use backend service.")
        }
    }

    // MARK: - Public Methods

    func generateCoaching(
        for results: AnalysisResults,
        genre: MusicGenre,
        userName: String = "Singer"
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw CoachingError.noAPIKey
        }

        isGenerating = true
        lastError = nil

        defer {
            isGenerating = false
        }

        let prompt = buildPrompt(results: results, genre: genre, userName: userName)

        let requestBody: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                [
                    "role": "system",
                    "content": "You are an expert vocal coach providing personalized feedback."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 500,
            "temperature": 0.7
        ]

        guard let url = URL(string: endpoint) else {
            throw CoachingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoachingError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw CoachingError.serverError(statusCode: httpResponse.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw CoachingError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private Methods

    private func buildPrompt(results: AnalysisResults, genre: MusicGenre, userName: String) -> String {
        let genreContext = genre.coachingContext

        var prompt = """
        Analyze this vocal performance and provide encouraging, specific coaching feedback.

        Genre: \(genre.rawValue)
        \(genreContext.culturalContext)

        Performance Metrics:
        - Pitch Accuracy: \(String(format: "%.1f%%", results.pitchAccuracy))
        - Tone Consistency: \(String(format: "%.1f%%", results.toneConsistency))
        - Vibrato: \(results.vibratoStability.displayString)
        - Expression: \(results.deliveryExpression)
        - Overall Score: \(results.overallScore)/100

        """

        // Add insight highlights
        if !results.insightEvents.isEmpty {
            prompt += "\nHighlights:\n"
            for event in results.insightEvents.prefix(3) {
                prompt += "- \(event.title): \(event.description)\n"
            }
        }

        prompt += """

        Provide warm, personalized feedback (2-3 paragraphs):
        1. Start with genuine praise for specific strengths
        2. Offer constructive guidance on one area to improve
        3. End with encouragement and next steps

        """

        // Add cultural context
        if !genreContext.techniqueReferences.isEmpty {
            prompt += "\nReference these artists/techniques: \(genreContext.techniqueReferences.joined(separator: ", "))\n"
        }

        if genreContext.prefersBilingual {
            prompt += "\nMix English with Spanish phrases naturally (e.g., 'tu vibrato', 'muy bien').\n"
        }

        return prompt
    }

    // MARK: - Keychain Integration

    private static func loadAPIKeyFromKeychain() -> String? {
        // TODO: Implement Keychain loading
        // For production, store API key securely in Keychain
        // Example using Security framework:
        /*
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "VocalHeat.OpenAI.APIKey",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let apiKey = String(data: data, encoding: .utf8) {
            return apiKey
        }
        */

        return nil
    }

    static func saveAPIKeyToKeychain(_ apiKey: String) throws {
        // TODO: Implement Keychain saving
        // For production, save API key securely to Keychain
    }
}

// MARK: - Errors

enum CoachingError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your OpenAI API key in Settings."
        case .invalidURL:
            return "Invalid API endpoint URL."
        case .invalidResponse:
            return "Could not parse response from OpenAI API."
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}
