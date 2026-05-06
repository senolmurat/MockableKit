// MockableKitTests.swift
// MockableKitTests

import XCTest
@testable import MockableKit

// MARK: - Test Models

struct User: Mockable {
    let id: Int
    let name: String
    let email: String
    let age: Int
    let bio: String
    let isActive: Bool
}

struct Product: Mockable {
    let id: String
    let title: String
    let price: Double
    let category: String
    let inStock: Bool
    let rating: Double
}

struct Address: Mockable {
    let street: String
    let city: String
    let country: String
    let zipCode: String
}

struct Article: Mockable {
    static var mockContext: String { "News article" }

    let headline: String
    let author: String
    let publishedAt: String
    let summary: String
    let tags: [String]
}

// MARK: - Schema Extraction Tests (no API key needed)

final class SchemaExtractionTests: XCTestCase {

    func testExtractsUserFields() {
        let schema = SchemaExtractor.extract(from: User.self)

        XCTAssertFalse(schema.isEmpty, "Schema should not be empty")

        let names = schema.map { $0.name }
        XCTAssertTrue(names.contains("id"), "Should extract 'id'")
        XCTAssertTrue(names.contains("name"), "Should extract 'name'")
        XCTAssertTrue(names.contains("email"), "Should extract 'email'")
        XCTAssertTrue(names.contains("age"), "Should extract 'age'")
    }

    func testExtractsCorrectTypes() {
        let schema = SchemaExtractor.extract(from: User.self)
        let typeMap = Dictionary(uniqueKeysWithValues: schema.map { ($0.name, $0.typeName) })

        XCTAssertEqual(typeMap["id"], "Int")
        XCTAssertEqual(typeMap["name"], "String")
        XCTAssertEqual(typeMap["isActive"], "Bool")
    }

    func testProductSchema() {
        let schema = SchemaExtractor.extract(from: Product.self)
        XCTAssertEqual(schema.count, 6)
    }
}

// MARK: - Live API Tests (requires API key)

final class MockableKitLiveTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Set your API key here or via environment variable
        MockableConfiguration.shared.apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        MockableConfiguration.shared.debugLogging = true
    }

    func testGenerateSingleUser() async throws {
        guard !MockableConfiguration.shared.apiKey.isEmpty else {
            throw XCTSkip("GEMINI_API_KEY not set")
        }

        let user = try await User.mock()

        XCTAssertFalse(user.name.isEmpty, "Name should not be empty")
        XCTAssertFalse(user.email.isEmpty, "Email should not be empty")
        XCTAssertGreaterThan(user.age, 0, "Age should be positive")
    }

    func testGenerateMultipleProducts() async throws {
        guard !MockableConfiguration.shared.apiKey.isEmpty else {
            throw XCTSkip("GEMINI_API_KEY not set")
        }

        let products = try await Product.mocks(count: 3)

        XCTAssertEqual(products.count, 3)
        XCTAssertTrue(products.allSatisfy { !$0.title.isEmpty })
        XCTAssertTrue(products.allSatisfy { $0.price > 0 })
    }

    func testCustomMockContext() async throws {
        guard !MockableConfiguration.shared.apiKey.isEmpty else {
            throw XCTSkip("GEMINI_API_KEY not set")
        }

        let article = try await Article.mock()
        XCTAssertFalse(article.headline.isEmpty)
    }
}
