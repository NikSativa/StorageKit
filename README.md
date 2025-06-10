# StorageKit
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNikSativa%2FStorageKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/NikSativa/StorageKit)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNikSativa%2FStorageKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/NikSativa/StorageKit)
[![NikSativa CI](https://github.com/NikSativa/StorageKit/actions/workflows/swift_macos.yml/badge.svg)](https://github.com/NikSativa/StorageKit/actions/workflows/swift_macos.yml)
[![License](https://img.shields.io/github/license/Iterable/swift-sdk)](https://opensource.org/licenses/MIT)

**StorageKit** is a Swift library that provides a unified, type-safe interface for storing and retrieving data across multiple backends. It supports declarative property wrappers and integrates with Combine for reactive state updates. Ideal for modern app architectures requiring persistent, transient, or secure storage.

## Key Features

- Type-safe read/write access to stored values
- Reactive integration with Combine for observing value changes
- Support for multiple storage backends:
  - UserDefaults
  - File system
  - Keychain
  - In-memory
- Property wrappers for declarative usage
- Support for composable storage layers
- Built-in expiration handling for time-sensitive values

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/NikSativa/StorageKit.git", from: "1.0.0")
]
```

## Usage

### Property Wrappers

#### @Defaults
Property wrapper that provides type-safe access to values persisted in UserDefaults. Supports Codable types:

```swift
import StorageKit

struct User: Codable {
    let name: String
    let email: String
    let age: Int
}

final class UserViewModel {
    @Defaults("user", defaultValue: nil)
    var user: User? {
        didSet {
            print("User updated: \(user)")
        }
    }
}
```

#### @Expirable
Property wrapper that adds expiration to stored values:

```swift
@Expirable(lifetime: .oneHour) var token: String?
```

### Storage Types

#### UserDefaultsStorage
Persistent storage using UserDefaults:

```swift
let storage = UserDefaultsStorage<Int?>(key: "MyKey")
storage.value = 1
```

#### FileStorage
Persistent storage using the file system. Supports customizable file paths:

```swift
let storage = FileStorage<Int>(fileName: "TestFile.txt")
storage.value = 1
```

#### KeychainStorage
Secure storage using the Keychain:

```swift
let storage = KeychainStorage(
    key: "MyKey",
    configuration: .init(service: Bundle.main.bundleIdentifier ?? "MyService")
)
storage.value = auth.token
```

#### InMemoryStorage
Transient storage using in-memory values:

```swift
let storage = InMemoryStorage<Int>(value: 1)
storage.value = 1
```

### Storage Composition

Combine multiple storage layers for advanced scenarios:

```swift
// Combine two storages
let combined = inMemoryStorage.combine(userDefaultsStorage)

// Combine multiple storages (iOS 16+)
let combined = zip(storages: [
    InMemoryStorage<Int?>(value: 1),
    UserDefaultsStorage(key: "MyKey")
])
```

### Reactive Updates

All storage types provide Combine publishers for observing value changes:

```swift
let storage = UserDefaultsStorage<String>(key: "MyKey")
let cancellable = storage.sink { value in
    print("Value updated: \(value)")
}
```

## Requirements

- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+
- Swift 5.5+
- Xcode 13.0+

## License

StorageKit is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
