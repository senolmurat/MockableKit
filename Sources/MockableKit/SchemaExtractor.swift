// SchemaExtractor.swift
// MockableKit

import Foundation

/// Describes a single field of a struct.
public struct FieldDescriptor {
    public let name: String
    public let typeName: String
    public let isOptional: Bool
}

/// Extracts field names and types from a `Decodable` type without needing
/// a live instance. Uses a two-pass approach:
///
/// 1. **CodingKeys probe** — Decodes from a JSON with all fields set to null.
///    The decoder will walk all CodingKeys and report what it sees.
/// 2. **Mirror fallback** — If a live instance can be created from the probe,
///    Mirror gives us the runtime type names.
internal enum SchemaExtractor {

    static func extract<T: Decodable>(from type: T.Type) -> [FieldDescriptor] {
        // Strategy 1: Use the CodingKeyProbe decoder to collect keys
        let probe = CodingKeyProbeDecoder()
        _ = try? T(from: probe)
        let keys = probe.collectedKeys

        if !keys.isEmpty {
            return keys.map { key in
                FieldDescriptor(
                    name: key.name,
                    typeName: key.typeName,
                    isOptional: key.isOptional
                )
            }
        }

        // Strategy 2: Fallback — parse type description string
        return parseTypeDescription(for: type)
    }

    // MARK: - Fallback Parser

    private static func parseTypeDescription<T>(for type: T.Type) -> [FieldDescriptor] {
        // Swift's String(reflecting:) gives us something like:
        // "MyModule.User(id: Swift.Int, name: Swift.String, ...)"
        // We can't always get this without an instance, so return empty
        // and let the LLM work from the type name only.
        return []
    }
}

// MARK: - Coding Key Probe Decoder

/// A fake `Decoder` that intercepts all `decode(...)` calls and records
/// the key names and Swift type names without actually decoding anything.
internal class CodingKeyProbeDecoder: Decoder {

    struct CollectedKey {
        let name: String
        let typeName: String
        let isOptional: Bool
    }

    private(set) var collectedKeys: [CollectedKey] = []

    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(ProbeKeyedContainer<Key>(probe: self))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return ProbeUnkeyedContainer(probe: self)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return ProbeSingleValueContainer(probe: self)
    }

    func record(name: String, typeName: String, isOptional: Bool) {
        // Avoid duplicates
        guard !collectedKeys.contains(where: { $0.name == name }) else { return }
        collectedKeys.append(CollectedKey(name: name, typeName: typeName, isOptional: isOptional))
    }
}

// MARK: - Probe Keyed Container

private struct ProbeKeyedContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K

    let probe: CodingKeyProbeDecoder
    var codingPath: [CodingKey] = []
    var allKeys: [K] = []

    func contains(_ key: K) -> Bool { true }

    func decodeNil(forKey key: K) throws -> Bool {
        probe.record(name: key.stringValue, typeName: "null", isOptional: true)
        return false // Return false so the decoder keeps trying to decode
    }

    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        probe.record(name: key.stringValue, typeName: "Bool", isOptional: false)
        return false
    }

    func decode(_ type: String.Type, forKey key: K) throws -> String {
        probe.record(name: key.stringValue, typeName: "String", isOptional: false)
        return ""
    }

    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        probe.record(name: key.stringValue, typeName: "Double", isOptional: false)
        return 0
    }
    
    func decode(_ type: Decimal.Type, forKey key: K) throws -> Decimal {
        probe.record(name: key.stringValue, typeName: "Decimal", isOptional: false)
        return 0
    }

    func decode(_ type: Float.Type, forKey key: K) throws -> Float {
        probe.record(name: key.stringValue, typeName: "Float", isOptional: false)
        return 0
    }

    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        probe.record(name: key.stringValue, typeName: "Int", isOptional: false)
        return 0
    }

    func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 {
        probe.record(name: key.stringValue, typeName: "Int8", isOptional: false)
        return 0
    }

    func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 {
        probe.record(name: key.stringValue, typeName: "Int16", isOptional: false)
        return 0
    }

    func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 {
        probe.record(name: key.stringValue, typeName: "Int32", isOptional: false)
        return 0
    }

    func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
        probe.record(name: key.stringValue, typeName: "Int64", isOptional: false)
        return 0
    }

    func decode(_ type: UInt.Type, forKey key: K) throws -> UInt {
        probe.record(name: key.stringValue, typeName: "UInt", isOptional: false)
        return 0
    }

    func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 {
        probe.record(name: key.stringValue, typeName: "UInt8", isOptional: false)
        return 0
    }

    func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
        probe.record(name: key.stringValue, typeName: "UInt16", isOptional: false)
        return 0
    }

    func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
        probe.record(name: key.stringValue, typeName: "UInt32", isOptional: false)
        return 0
    }

    func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
        probe.record(name: key.stringValue, typeName: "UInt64", isOptional: false)
        return 0
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
        let typeName = friendlyTypeName(for: type)
        probe.record(name: key.stringValue, typeName: typeName, isOptional: false)

        // Try to recurse into nested Decodable types
        let nested = CodingKeyProbeDecoder()
        _ = try? T(from: nested)
        // We don't merge nested keys — they belong to the nested type

        // Return a dummy value
        if let result = try? T(from: DummyDecoder()) {
            return result
        }
        throw ProbeError.skipField
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
        return KeyedDecodingContainer(ProbeKeyedContainer<NestedKey>(probe: probe))
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        return ProbeUnkeyedContainer(probe: probe)
    }

    func superDecoder() throws -> Decoder { return probe }
    func superDecoder(forKey key: K) throws -> Decoder { return probe }
}

// MARK: - Probe Unkeyed Container

private struct ProbeUnkeyedContainer: UnkeyedDecodingContainer {
    let probe: CodingKeyProbeDecoder
    var codingPath: [CodingKey] = []
    var count: Int? = 0
    var isAtEnd: Bool = true
    var currentIndex: Int = 0

    mutating func decodeNil() throws -> Bool { true }
    mutating func decode(_ type: Bool.Type) throws -> Bool { false }
    mutating func decode(_ type: String.Type) throws -> String { "" }
    mutating func decode(_ type: Double.Type) throws -> Double { 0 }
    mutating func decode(_ type: Float.Type) throws -> Float { 0 }
    mutating func decode(_ type: Decimal.Type) throws -> Decimal { 0 }
    mutating func decode(_ type: Int.Type) throws -> Int { 0 }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { 0 }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { 0 }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { 0 }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { 0 }
    mutating func decode(_ type: UInt.Type) throws -> UInt { 0 }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { 0 }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { 0 }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { 0 }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { 0 }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T { throw ProbeError.skipField }
    mutating func nestedContainer<K: CodingKey>(keyedBy type: K.Type) throws -> KeyedDecodingContainer<K> {
        KeyedDecodingContainer(ProbeKeyedContainer<K>(probe: probe))
    }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer { self }
    mutating func superDecoder() throws -> Decoder { probe }
}

// MARK: - Probe Single Value Container

private struct ProbeSingleValueContainer: SingleValueDecodingContainer {
    let probe: CodingKeyProbeDecoder
    var codingPath: [CodingKey] = []

    func decodeNil() -> Bool { true }
    func decode(_ type: Bool.Type) throws -> Bool { false }
    func decode(_ type: String.Type) throws -> String { "" }
    func decode(_ type: Double.Type) throws -> Double { 0 }
    func decode(_ type: Float.Type) throws -> Float { 0 }
    func decode(_ type: Decimal.Type) throws -> Decimal { 0 }
    func decode(_ type: Int.Type) throws -> Int { 0 }
    func decode(_ type: Int8.Type) throws -> Int8 { 0 }
    func decode(_ type: Int16.Type) throws -> Int16 { 0 }
    func decode(_ type: Int32.Type) throws -> Int32 { 0 }
    func decode(_ type: Int64.Type) throws -> Int64 { 0 }
    func decode(_ type: UInt.Type) throws -> UInt { 0 }
    func decode(_ type: UInt8.Type) throws -> UInt8 { 0 }
    func decode(_ type: UInt16.Type) throws -> UInt16 { 0 }
    func decode(_ type: UInt32.Type) throws -> UInt32 { 0 }
    func decode(_ type: UInt64.Type) throws -> UInt64 { 0 }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { throw ProbeError.skipField }
}

// MARK: - Dummy Decoder (for returning zero values)

private class DummyDecoder: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        throw ProbeError.skipField
    }
    func unkeyedContainer() throws -> UnkeyedDecodingContainer { throw ProbeError.skipField }
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return DummySingleValueContainer()
    }
}

private struct DummySingleValueContainer: SingleValueDecodingContainer {
    var codingPath: [CodingKey] = []
    func decodeNil() -> Bool { false }
    func decode(_ type: Bool.Type) throws -> Bool { false }
    func decode(_ type: String.Type) throws -> String { "" }
    func decode(_ type: Double.Type) throws -> Double { 0 }
    func decode(_ type: Float.Type) throws -> Float { 0 }
    func decode(_ type: Decimal.Type) throws -> Decimal { 0 }
    func decode(_ type: Int.Type) throws -> Int { 0 }
    func decode(_ type: Int8.Type) throws -> Int8 { 0 }
    func decode(_ type: Int16.Type) throws -> Int16 { 0 }
    func decode(_ type: Int32.Type) throws -> Int32 { 0 }
    func decode(_ type: Int64.Type) throws -> Int64 { 0 }
    func decode(_ type: UInt.Type) throws -> UInt { 0 }
    func decode(_ type: UInt8.Type) throws -> UInt8 { 0 }
    func decode(_ type: UInt16.Type) throws -> UInt16 { 0 }
    func decode(_ type: UInt32.Type) throws -> UInt32 { 0 }
    func decode(_ type: UInt64.Type) throws -> UInt64 { 0 }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { throw ProbeError.skipField }
}

// MARK: - Helpers

private enum ProbeError: Error {
    case skipField
}

private func friendlyTypeName<T>(for type: T.Type) -> String {
    let raw = String(describing: type)
    // Clean up "Optional<X>" → "X?"
    if raw.hasPrefix("Optional<") && raw.hasSuffix(">") {
        let inner = String(raw.dropFirst(9).dropLast(1))
        return "\(inner)?"
    }
    // Clean up "Array<X>" → "[X]"
    if raw.hasPrefix("Array<") && raw.hasSuffix(">") {
        let inner = String(raw.dropFirst(6).dropLast(1))
        return "[\(inner)]"
    }
    return raw
}
