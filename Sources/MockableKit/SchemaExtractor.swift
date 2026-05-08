// SchemaExtractor.swift
// MockableKit

import Foundation

/// Describes a single field of a struct, optionally with nested fields.
public struct FieldDescriptor {
    public let name: String
    public let typeName: String
    public let isOptional: Bool
    public let nestedFields: [FieldDescriptor]  // populated for nested Decodable types

    public init(name: String, typeName: String, isOptional: Bool, nestedFields: [FieldDescriptor] = []) {
        self.name = name
        self.typeName = typeName
        self.isOptional = isOptional
        self.nestedFields = nestedFields
    }
}

/// Extracts field names and types from a `Decodable` type without needing
/// a live instance. Uses a probe decoder that intercepts all decode() calls.
internal enum SchemaExtractor {

    static func extract<T: Decodable>(from type: T.Type, depth: Int = 0) -> [FieldDescriptor] {
        guard depth < 4 else { return [] } // prevent infinite recursion on circular types

        let probe = CodingKeyProbeDecoder(depth: depth)
        _ = try? T(from: probe)
        return probe.collectedKeys
    }
}

// MARK: - Probe Decoder

internal class CodingKeyProbeDecoder: Decoder {

    private(set) var collectedKeys: [FieldDescriptor] = []
    let depth: Int

    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]

    init(depth: Int = 0) {
        self.depth = depth
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(ProbeKeyedContainer<Key>(probe: self))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return ProbeUnkeyedContainer(probe: self)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return ProbeSingleValueContainer(probe: self)
    }

    func record(_ descriptor: FieldDescriptor) {
        guard !collectedKeys.contains(where: { $0.name == descriptor.name }) else { return }
        collectedKeys.append(descriptor)
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
        // nil check means optional — record it but let decoding continue
        probe.record(FieldDescriptor(name: key.stringValue, typeName: "Any", isOptional: true))
        return false
    }

    func decode(_ type: Bool.Type,   forKey key: K) throws -> Bool   { probe.record(.init(name: key.stringValue, typeName: "Bool",   isOptional: false)); return false }
    func decode(_ type: String.Type, forKey key: K) throws -> String { probe.record(.init(name: key.stringValue, typeName: "String", isOptional: false)); return "" }
    func decode(_ type: Double.Type, forKey key: K) throws -> Double { probe.record(.init(name: key.stringValue, typeName: "Double", isOptional: false)); return 0 }
    func decode(_ type: Decimal.Type, forKey key: K) throws -> Decimal { probe.record(.init(name: key.stringValue, typeName: "Decimal", isOptional: false)); return 0 }
    func decode(_ type: Float.Type,  forKey key: K) throws -> Float  { probe.record(.init(name: key.stringValue, typeName: "Float",  isOptional: false)); return 0 }
    func decode(_ type: Int.Type,    forKey key: K) throws -> Int    { probe.record(.init(name: key.stringValue, typeName: "Int",    isOptional: false)); return 0 }
    func decode(_ type: Int8.Type,   forKey key: K) throws -> Int8   { probe.record(.init(name: key.stringValue, typeName: "Int8",   isOptional: false)); return 0 }
    func decode(_ type: Int16.Type,  forKey key: K) throws -> Int16  { probe.record(.init(name: key.stringValue, typeName: "Int16",  isOptional: false)); return 0 }
    func decode(_ type: Int32.Type,  forKey key: K) throws -> Int32  { probe.record(.init(name: key.stringValue, typeName: "Int32",  isOptional: false)); return 0 }
    func decode(_ type: Int64.Type,  forKey key: K) throws -> Int64  { probe.record(.init(name: key.stringValue, typeName: "Int64",  isOptional: false)); return 0 }
    func decode(_ type: UInt.Type,   forKey key: K) throws -> UInt   { probe.record(.init(name: key.stringValue, typeName: "UInt",   isOptional: false)); return 0 }
    func decode(_ type: UInt8.Type,  forKey key: K) throws -> UInt8  { probe.record(.init(name: key.stringValue, typeName: "UInt8",  isOptional: false)); return 0 }
    func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 { probe.record(.init(name: key.stringValue, typeName: "UInt16", isOptional: false)); return 0 }
    func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 { probe.record(.init(name: key.stringValue, typeName: "UInt32", isOptional: false)); return 0 }
    func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 { probe.record(.init(name: key.stringValue, typeName: "UInt64", isOptional: false)); return 0 }

    func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
        let rawName = friendlyTypeName(for: type)

        // Recurse into nested Decodable types to extract their fields too
        let nested = CodingKeyProbeDecoder(depth: probe.depth + 1)
        _ = try? T(from: nested)

        probe.record(FieldDescriptor(
            name: key.stringValue,
            typeName: rawName,
            isOptional: false,
            nestedFields: nested.collectedKeys
        ))

        throw ProbeError.skipField
    }

    func nestedContainer<NK: CodingKey>(keyedBy type: NK.Type, forKey key: K) throws -> KeyedDecodingContainer<NK> {
        KeyedDecodingContainer(ProbeKeyedContainer<NK>(probe: probe))
    }
    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer { ProbeUnkeyedContainer(probe: probe) }
    func superDecoder() throws -> Decoder { probe }
    func superDecoder(forKey key: K) throws -> Decoder { probe }
}

// MARK: - Probe Unkeyed Container

private struct ProbeUnkeyedContainer: UnkeyedDecodingContainer {
    let probe: CodingKeyProbeDecoder
    var codingPath: [CodingKey] = []
    var count: Int? = 0
    var isAtEnd: Bool = true
    var currentIndex: Int = 0

    mutating func decodeNil() throws -> Bool { true }
    mutating func decode(_ type: Bool.Type)   throws -> Bool   { false }
    mutating func decode(_ type: String.Type) throws -> String { "" }
    mutating func decode(_ type: Double.Type) throws -> Double { 0 }
    mutating func decode(_ type: Float.Type)  throws -> Float  { 0 }
    mutating func decode(_ type: Decimal.Type) throws -> Decimal { 0 }
    mutating func decode(_ type: Int.Type)    throws -> Int    { 0 }
    mutating func decode(_ type: Int8.Type)   throws -> Int8   { 0 }
    mutating func decode(_ type: Int16.Type)  throws -> Int16  { 0 }
    mutating func decode(_ type: Int32.Type)  throws -> Int32  { 0 }
    mutating func decode(_ type: Int64.Type)  throws -> Int64  { 0 }
    mutating func decode(_ type: UInt.Type)   throws -> UInt   { 0 }
    mutating func decode(_ type: UInt8.Type)  throws -> UInt8  { 0 }
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

    func decodeNil() -> Bool { false }
    func decode(_ type: Bool.Type)   throws -> Bool   { false }
    func decode(_ type: String.Type) throws -> String { "" }
    func decode(_ type: Double.Type) throws -> Double { 0 }
    func decode(_ type: Float.Type)  throws -> Float  { 0 }
    func decode(_ type: Decimal.Type) throws -> Decimal { 0 }
    func decode(_ type: Int.Type)    throws -> Int    { 0 }
    func decode(_ type: Int8.Type)   throws -> Int8   { 0 }
    func decode(_ type: Int16.Type)  throws -> Int16  { 0 }
    func decode(_ type: Int32.Type)  throws -> Int32  { 0 }
    func decode(_ type: Int64.Type)  throws -> Int64  { 0 }
    func decode(_ type: UInt.Type)   throws -> UInt   { 0 }
    func decode(_ type: UInt8.Type)  throws -> UInt8  { 0 }
    func decode(_ type: UInt16.Type) throws -> UInt16 { 0 }
    func decode(_ type: UInt32.Type) throws -> UInt32 { 0 }
    func decode(_ type: UInt64.Type) throws -> UInt64 { 0 }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { throw ProbeError.skipField }
}

// MARK: - Helpers

private enum ProbeError: Error { case skipField }

private func friendlyTypeName<T>(for type: T.Type) -> String {
    let raw = String(describing: type)
    if raw.hasPrefix("Optional<") && raw.hasSuffix(">") {
        return "\(String(raw.dropFirst(9).dropLast(1)))?"
    }
    if raw.hasPrefix("Array<") && raw.hasSuffix(">") {
        return "[\(String(raw.dropFirst(6).dropLast(1)))]"
    }
    return raw
}
