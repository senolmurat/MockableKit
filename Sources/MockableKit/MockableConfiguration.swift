// MockableConfiguration.swift
// MockableKit

import Foundation

/// Configure MockableKit globally or per-call.
///
/// Set your API key once at app start:
/// ```swift
/// MockableConfiguration.shared.apiKey = "YOUR_GEMINI_API_KEY"
/// ```
/// Get your key at: https://aistudio.google.com/app/apikey
public class MockableConfiguration {

    /// The shared (default) configuration. Set this up once in your app/test target.
    public static var shared = MockableConfiguration()

    /// Your Google Gemini API key.
    /// Get one at: https://aistudio.google.com/app/apikey
    public var apiKey: String = ""

    /// The Gemini model to use for generating mock data.
    /// Available models: "gemini-2.0-flash", "gemini-2.0-flash-lite", "gemini-1.5-pro"
    public var model: String = "gemini-2.5-flash-lite"

    /// Maximum tokens for the LLM response.
    public var maxTokens: Int = 1024

    /// The locale hint sent to the LLM (e.g. "Turkish", "American English", "German").
    /// This affects generated names, addresses, phone numbers, etc.
    public var locale: String = "English"

    /// If true, prints the generated JSON to the console. Useful during development.
    public var debugLogging: Bool = false

    public init() {}
}
