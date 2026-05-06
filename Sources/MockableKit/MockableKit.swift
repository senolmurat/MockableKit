// Mockable.swift
// MockableKit
//
// A protocol that enables any Decodable struct to generate
// realistic mock data using an LLM based on its property names and types.

import Foundation

/// Conform your struct to `Mockable` to get AI-generated mock instances.
///
/// Your struct must also conform to `Decodable` so the JSON response
/// from the LLM can be decoded back into your type.
///
/// Example:
/// ```swift
/// struct User: Mockable, Decodable {
///     let id: Int
///     let name: String
///     let email: String
///     let age: Int
/// }
///
/// // In your test or preview:
/// let user = try await User.mock()
/// let users = try await User.mocks(count: 5)
/// ```
public protocol Mockable: Decodable {
    /// A human-readable description of what this type represents.
    /// Override this to give the LLM more context for better mock data.
    /// Default uses the type name.
    static var mockContext: String { get }
}

public extension Mockable {
    static var mockContext: String {
        return String(describing: Self.self)
    }

    /// Generate a single mock instance using the configured LLM.
    static func mock(configuration: MockableConfiguration = .shared) async throws -> Self {
        return try await MockEngine.shared.generate(for: Self.self, configuration: configuration)
    }

    /// Generate multiple mock instances.
    static func mocks(count: Int, configuration: MockableConfiguration = .shared) async throws -> [Self] {
        return try await MockEngine.shared.generateArray(for: Self.self, count: count, configuration: configuration)
    }

    /// Generate a single mock instance using a completion handler.
    static func mock(
        configuration: MockableConfiguration = .shared,
        completion: @escaping (Result<Self, Error>) -> Void
    ) {
        Task {
            do {
                let result = try await MockEngine.shared.generate(for: Self.self, configuration: configuration)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Generate multiple mock instances using a completion handler.
    static func mocks(
        count: Int,
        configuration: MockableConfiguration = .shared,
        completion: @escaping (Result<[Self], Error>) -> Void
    ) {
        Task {
            do {
                let result = try await MockEngine.shared.generateArray(for: Self.self, count: count, configuration: configuration)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
