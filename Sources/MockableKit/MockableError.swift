// MockableError.swift
// MockableKit

import Foundation

/// Errors thrown by MockableKit during mock generation.
public enum MockableError: Error, LocalizedError {

    /// The API key was not set in `MockableConfiguration.shared`.
    case missingAPIKey

    /// The network request failed.
    case networkError(String)

    /// The API returned a non-200 status code.
    case apiError(Int, String)

    /// The API returned a response that couldn't be parsed.
    case invalidResponse(String)

    /// The JSON returned by the LLM couldn't be decoded into your type.
    case decodingFailed(String, Error)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "[MockableKit] API key not set. Set MockableConfiguration.shared.apiKey before calling .mock()."
        case .networkError(let message):
            return "[MockableKit] Network error: \(message)"
        case .apiError(let code, let body):
            return "[MockableKit] API error \(code): \(body)"
        case .invalidResponse(let message):
            return "[MockableKit] Invalid response: \(message)"
        case .decodingFailed(let json, let error):
            return "[MockableKit] Decoding failed.\nJSON: \(json)\nError: \(error.localizedDescription)"
        }
    }
}
