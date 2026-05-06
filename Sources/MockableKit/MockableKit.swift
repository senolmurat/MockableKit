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
    ///
    /// - Parameters:
    ///   - configuration: The `MockableConfiguration` to use. Defaults to `.shared`.
    ///   - cacheEnabled: Override the global `configuration.cacheEnabled` for this call.
    ///     Pass `true` to force caching, `false` to always fetch fresh data,
    ///     or `nil` (default) to use `configuration.cacheEnabled`.
    static func mock(
        configuration: MockableConfiguration = .shared,
        cacheEnabled: Bool? = nil
    ) async throws -> Self {
        return try await MockEngine.shared.generate(
            for: Self.self,
            configuration: configuration,
            cacheEnabled: cacheEnabled
        )
    }

    /// Generate multiple mock instances.
    ///
    /// - Parameters:
    ///   - count: Number of instances to generate.
    ///   - configuration: The `MockableConfiguration` to use. Defaults to `.shared`.
    ///   - cacheEnabled: Override the global `configuration.cacheEnabled` for this call.
    ///     Pass `true` to force caching, `false` to always fetch fresh data,
    ///     or `nil` (default) to use `configuration.cacheEnabled`.
    static func mocks(
        count: Int,
        configuration: MockableConfiguration = .shared,
        cacheEnabled: Bool? = nil
    ) async throws -> [Self] {
        return try await MockEngine.shared.generateArray(
            for: Self.self,
            count: count,
            configuration: configuration,
            cacheEnabled: cacheEnabled
        )
    }

    /// Generate a single mock instance using a completion handler.
    ///
    /// - Parameters:
    ///   - configuration: The `MockableConfiguration` to use. Defaults to `.shared`.
    ///   - cacheEnabled: Override the global `configuration.cacheEnabled` for this call.
    ///   - completion: Called with the result on an arbitrary thread.
    static func mock(
        configuration: MockableConfiguration = .shared,
        cacheEnabled: Bool? = nil,
        completion: @escaping (Result<Self, Error>) -> Void
    ) {
        Task {
            do {
                let result = try await MockEngine.shared.generate(
                    for: Self.self,
                    configuration: configuration,
                    cacheEnabled: cacheEnabled
                )
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Generate multiple mock instances using a completion handler.
    ///
    /// - Parameters:
    ///   - count: Number of instances to generate.
    ///   - configuration: The `MockableConfiguration` to use. Defaults to `.shared`.
    ///   - cacheEnabled: Override the global `configuration.cacheEnabled` for this call.
    ///   - completion: Called with the result on an arbitrary thread.
    static func mocks(
        count: Int,
        configuration: MockableConfiguration = .shared,
        cacheEnabled: Bool? = nil,
        completion: @escaping (Result<[Self], Error>) -> Void
    ) {
        Task {
            do {
                let result = try await MockEngine.shared.generateArray(
                    for: Self.self,
                    count: count,
                    configuration: configuration,
                    cacheEnabled: cacheEnabled
                )
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
