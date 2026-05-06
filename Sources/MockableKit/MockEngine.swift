// MockEngine.swift
// MockableKit

import Foundation

/// Internal engine that uses Mirror reflection to extract field metadata
/// and calls the Google Gemini API to generate realistic JSON mock data.
internal class MockEngine {

    static let shared = MockEngine()
    private init() {}

    // MARK: - Public Interface

    func generate<T: Mockable>(
        for type: T.Type,
        configuration: MockableConfiguration,
        cacheEnabled: Bool? = nil
    ) async throws -> T {
        let schema = extractSchema(from: type)
        let shouldCache = cacheEnabled ?? configuration.cacheEnabled

        let json = try await resolveJSON(
            typeName: type.mockContext,
            schema: schema,
            count: 1,
            configuration: configuration,
            shouldCache: shouldCache
        )

        if configuration.debugLogging {
            print("[MockableKit] Generated JSON:\n\(json)")
        }

        guard let data = json.data(using: .utf8) else {
            throw MockableError.invalidResponse("Could not convert response to Data")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw MockableError.decodingFailed(json, error)
        }
    }

    func generateArray<T: Mockable>(
        for type: T.Type,
        count: Int,
        configuration: MockableConfiguration,
        cacheEnabled: Bool? = nil
    ) async throws -> [T] {
        let schema = extractSchema(from: type)
        let shouldCache = cacheEnabled ?? configuration.cacheEnabled

        let json = try await resolveJSON(
            typeName: type.mockContext,
            schema: schema,
            count: count,
            configuration: configuration,
            shouldCache: shouldCache
        )

        if configuration.debugLogging {
            print("[MockableKit] Generated JSON:\n\(json)")
        }

        guard let data = json.data(using: .utf8) else {
            throw MockableError.invalidResponse("Could not convert response to Data")
        }

        do {
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            throw MockableError.decodingFailed(json, error)
        }
    }

    // MARK: - Cache-aware JSON Resolution

    private func resolveJSON(
        typeName: String,
        schema: [FieldDescriptor],
        count: Int,
        configuration: MockableConfiguration,
        shouldCache: Bool
    ) async throws -> String {
        if shouldCache {
            let key = MockCache.buildKey(
                typeName: typeName,
                schema: schema,
                count: count,
                locale: configuration.locale,
                model: configuration.model
            )

            if let cached = await MockCache.shared.get(key: key) {
                if configuration.debugLogging {
                    print("[MockableKit] Cache hit for key: \(key)")
                }
                return cached
            }

            let json = try await callLLM(
                typeName: typeName,
                schema: schema,
                count: count,
                configuration: configuration
            )
            await MockCache.shared.set(key: key, value: json)
            return json
        }

        return try await callLLM(
            typeName: typeName,
            schema: schema,
            count: count,
            configuration: configuration
        )
    }

    // MARK: - Schema Extraction

    private func extractSchema<T: Mockable>(from type: T.Type) -> [FieldDescriptor] {
        return SchemaExtractor.extract(from: type)
    }

    // MARK: - Gemini API Call

    private func callLLM(
        typeName: String,
        schema: [FieldDescriptor],
        count: Int,
        configuration: MockableConfiguration
    ) async throws -> String {
        guard !configuration.apiKey.isEmpty else {
            throw MockableError.missingAPIKey
        }

        let fullPrompt = systemPrompt + "\n\n" + buildPrompt(
            typeName: typeName,
            schema: schema,
            count: count,
            locale: configuration.locale
        )

        // Gemini REST endpoint: POST with API key as query param
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(configuration.model):generateContent?key=\(configuration.apiKey)"
        guard let url = URL(string: urlString) else {
            throw MockableError.networkError("Invalid Gemini URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Gemini request body format
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": fullPrompt]
                    ]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": configuration.maxTokens,
                "temperature": 0.8,        // Some variation so mocks aren't identical
                "responseMimeType": "application/json" // Ask Gemini to return JSON directly
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MockableError.networkError("Invalid response type")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw MockableError.apiError(httpResponse.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let text = decoded.candidates.first?.content.parts.first?.text else {
            throw MockableError.invalidResponse("Empty content from Gemini API")
        }

        return stripMarkdown(from: text)
    }

    // MARK: - Prompt Building

    private var systemPrompt: String {
        """
        You are a mock data generator. Your only job is to return valid JSON.
        - Never include explanations, markdown, or code fences.
        - Never add fields that weren't asked for.
        - Generate realistic, varied data that fits the field names and types.
        - For arrays, return a JSON array. For single objects, return a JSON object.
        - Match the exact field names provided (case-sensitive).
        """
    }

    private func buildPrompt(typeName: String, schema: [FieldDescriptor], count: Int, locale: String) -> String {
        let fieldsDescription = schema.map { field in
            "  - \(field.name): \(field.typeName)\(field.isOptional ? " (optional, can be null)" : "")"
        }.joined(separator: "\n")

        if count == 1 {
            return """
            Generate a single mock JSON object for a Swift struct called "\(typeName)".
            Use \(locale) locale for names, addresses, and locale-specific content.

            Fields:
            \(fieldsDescription)

            Return only the JSON object.
            """
        } else {
            return """
            Generate \(count) mock JSON objects for a Swift struct called "\(typeName)".
            Use \(locale) locale for names, addresses, and locale-specific content.
            Make each object distinct and varied.

            Fields:
            \(fieldsDescription)

            Return only a JSON array of \(count) objects.
            """
        }
    }

    private func stripMarkdown(from text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```json") {
            result = String(result.dropFirst(7))
        } else if result.hasPrefix("```") {
            result = String(result.dropFirst(3))
        }
        if result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Gemini Response Models

private struct GeminiResponse: Decodable {
    let candidates: [Candidate]

    struct Candidate: Decodable {
        let content: Content
    }

    struct Content: Decodable {
        let parts: [Part]
    }

    struct Part: Decodable {
        let text: String
    }
}
