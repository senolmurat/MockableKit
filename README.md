# MockableKit

A Swift framework that lets any `Decodable` struct generate realistic mock data using Gemini. It reads your struct's field names and types automatically via the `Decodable` protocol, no manual setup per struct.

---

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 13.0+          |
| macOS    | 13.0+          |
| watchOS  | 9.0+           |
| tvOS     | 16.0+          |

Requires **Swift 5.9+** and **Xcode 15+**.

---

## How It Works

MockableKit uses a **probe decoder**, a fake `Decoder` that intercepts all `decode(...)` calls when Swift tries to decode your struct. This captures every field name and its Swift type without needing a real JSON payload or a live instance. That schema is sent to Gemini, which returns fitting JSON, and the result is decoded back into your type.

Responses are **cached to disk** by default so repeated calls with the same type, schema, count, locale, and model never hit the API again, making tests and previews fast after the first run.

---

## Installation

### Swift Package Manager

1. In Xcode: **File → Add Package Dependencies**
2. Enter your local path or GitHub URL
3. Add `MockableKit` to your test target

Or add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/senolmurat/MockableKit", from: "1.0.0")
],
targets: [
    .testTarget(
        name: "YourAppTests",
        dependencies: ["MockableKit"]
    )
]
```

---

## Setup

Set your Gemini API key once, best done in your test `setUp()` or `AppDelegate`:

```swift
import MockableKit

MockableConfiguration.shared.apiKey = "YOUR_GEMINI_API_KEY"
```

Get a free key at [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey).

### Optional settings

```swift
MockableConfiguration.shared.model        = "gemini-2.5-flash-lite" // default
MockableConfiguration.shared.locale       = "English"                // affects names, addresses
MockableConfiguration.shared.debugLogging = true                     // prints generated JSON
MockableConfiguration.shared.cacheEnabled = true                     // disk cache on by default
MockableConfiguration.shared.maxTokens   = 1024                     // max LLM response tokens
```

---

## Usage

### 1. Conform your struct

```swift
import MockableKit

struct User: Mockable {
    let id: Int
    let name: String
    let email: String
    let age: Int
    let isActive: Bool
}
```

That's it. No extra code needed.

### 2. Generate mocks, async/await

```swift
// Single instance
let user = try await User.mock()
print(user.name)   // "John Doe"
print(user.email)  // "john.doe@example.com"
print(user.age)    // 28

// Multiple instances
let users = try await User.mocks(count: 5)
```

### 3. Generate mocks, completion handlers (iOS 13+)

Use the completion-based overloads when you're in a synchronous context or targeting iOS 13 where structured concurrency may not be available in all call sites:

```swift
// Single instance, completion receives Self? (nil on failure)
User.mock { user in
    guard let user else { return }
    self.currentUser = user
}

// Multiple instances, completion receives [Self]? (nil on failure)
User.mocks(count: 5) { users in
    guard let users else { return }
    self.userList = users
}

// Per-call cache control
User.mock(cacheEnabled: false) { user in
    // Always fetches fresh data, ignoring the global cacheEnabled setting
    self.currentUser = user
}
```

> **Note:** The completion is called on an arbitrary background thread. Dispatch to the main queue if you're updating UI.

### 4. Use in SwiftUI Previews

```swift
struct UserCard_Previews: PreviewProvider {
    static var previews: some View {
        AsyncPreviewWrapper {
            let user = try await User.mock()
            return UserCard(user: user)
        }
    }
}
```

### 5. Use in XCTest

```swift
final class UserTests: XCTestCase {
    func testUserDisplayName() async throws {
        let user = try await User.mock()
        XCTAssertFalse(user.name.isEmpty)
    }
}
```

---

## Cache

MockableKit includes a **disk-backed cache** that stores Gemini responses in the system caches directory under `MockableKit/`. Cache keys are a stable FNV-1a hash of the type name, schema, count, locale, and model, so the key changes automatically whenever any of those inputs change.

### Behaviour

- Cache is **enabled by default** (`cacheEnabled = true` on `MockableConfiguration.shared`).
- A cache hit skips the network call entirely and returns the stored JSON immediately.
- Cache entries **never expire** and persist across app/test process launches.
- When `debugLogging` is on, cache hits are logged: `[MockableKit] Cache hit for key: mock_<hash>`.

### Disabling the cache globally

```swift
MockableConfiguration.shared.cacheEnabled = false
```

### Disabling the cache per call

```swift
let freshUser = try await User.mock(cacheEnabled: false)

User.mock(cacheEnabled: false) { user in
    self.currentUser = user
}
```

### Clearing the cache

```swift
// Deletes all cached responses from disk
MockableConfiguration.clearCache()
```

---

## Custom Context

Override `mockContext` to give the LLM more hints about what your type represents:

```swift
struct Article: Mockable {
    static var mockContext: String { "Tech news article" }

    let headline: String
    let author: String
    let publishedAt: String  // LLM will generate a date string
    let readTimeMinutes: Int
}
```

---

## Supported Types

MockableKit automatically handles:

| Swift Type          | Generated Example         |
|---------------------|---------------------------|
| `String`            | Context-aware text        |
| `Int` / `Double` / `Float` | Realistic numbers  |
| `Bool`              | `true` or `false`         |
| `[String]`          | Array of strings          |
| Nested `Decodable`  | Nested JSON object        |
| `Optional<T>`       | May be `null` or a value  |

---

## Error Handling

```swift
do {
    let user = try await User.mock()
} catch MockableError.missingAPIKey {
    print("Set MockableConfiguration.shared.apiKey first")
} catch MockableError.apiError(let code, let body) {
    print("API error \(code): \(body)")
} catch MockableError.decodingFailed(let json, let error) {
    print("Bad JSON: \(json)")
    print("Decode error: \(error)")
} catch {
    print(error.localizedDescription)
}
```

---

## Project Structure

```
MockableKit/
├── Package.swift
├── Sources/
│   └── MockableKit/
│       ├── MockableKit.swift            # Public protocol + extensions (async & completion)
│       ├── MockableConfiguration.swift  # API key, model, locale, cache settings
│       ├── MockEngine.swift             # LLM call, prompt building, cache integration
│       ├── MockCache.swift              # Disk-backed FNV-1a keyed cache
│       ├── SchemaExtractor.swift        # Probe decoder + field extraction
│       └── MockableError.swift          # Error types
└── Tests/
    └── MockableKitTests/
        └── MockableKitTests.swift
```

---

## Important Notes

- **Test targets only**, Don't ship MockableKit in your production app target. Add it only to test and preview targets.
- **API key security**, Never hardcode your key. Use `ProcessInfo.processInfo.environment["GEMINI_API_KEY"]` in CI.
- **Async**, All `async throws` overloads require iOS 13+ with Swift Concurrency back-deployment or a wrapping `Task {}`.
- **Completion handlers**, The `(Self?) -> Void` overloads are available for all supported platforms and require no concurrency runtime support at the call site.
- **Thread safety**, `MockCache` is an `actor`; all reads and writes are safe from any thread or task.
