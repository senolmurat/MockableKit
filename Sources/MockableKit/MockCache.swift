// MockCache.swift
// MockableKit

import Foundation

/// Disk-backed cache for Gemini API responses.
/// Keyed by a deterministic hash of type name, schema, count, locale, and model.
/// Cache entries never expire and persist across app launches.
internal actor MockCache {

    static let shared = MockCache()

    private let cacheDirectory: URL?
    private let fileManager = FileManager.default

    private init() {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        let dir = caches?.appendingPathComponent("MockableKit", isDirectory: true)
        cacheDirectory = dir

        if let dir {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Read / Write

    func get(key: String) -> String? {
        guard let url = cacheURL(for: key) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func set(key: String, value: String) {
        guard let url = cacheURL(for: key) else { return }
        try? value.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Cache Invalidation

    /// Removes all cached mock responses from disk.
    func clear() {
        guard let dir = cacheDirectory else { return }
        try? fileManager.removeItem(at: dir)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: - Key Generation

    /// Builds a stable, filesystem-safe cache key from the call parameters.
    /// Uses FNV-1a so the key is identical across process launches.
    static func buildKey(
        typeName: String,
        schema: [FieldDescriptor],
        count: Int,
        locale: String,
        model: String
    ) -> String {
        // Sort fields so key is stable regardless of Mirror reflection order
        let schemaString = schema
            .map { "\($0.name):\($0.typeName):\($0.isOptional)" }
            .sorted()
            .joined(separator: "|")
        let raw = "\(typeName)|\(schemaString)|count=\(count)|locale=\(locale)|model=\(model)"
        let hash = fnv1a(raw)
        return String(format: "mock_%016llx", hash)
    }

    // MARK: - Helpers

    private func cacheURL(for key: String) -> URL? {
        cacheDirectory?.appendingPathComponent("\(key).json")
    }

    /// FNV-1a 64-bit hash — deterministic across runs, no crypto dependency needed.
    private static func fnv1a(_ string: String) -> UInt64 {
        let offsetBasis: UInt64 = 14695981039346656037
        let prime: UInt64 = 1099511628211
        return string.utf8.reduce(offsetBasis) { hash, byte in
            (hash ^ UInt64(byte)) &* prime
        }
    }
}
