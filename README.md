# StorageKit
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNikSativa%2FStorageKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/NikSativa/StorageKit)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FNikSativa%2FStorageKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/NikSativa/StorageKit)

Swift library for saving and retrieving data from any kind storage.

### Defaults
Wrapper for UserDefaults that allows you to store and retrieve Codable objects.

```swift
import FoundationKit
struct User: Codable {
    let name: String
    let email: String
    let age: Int
}

final class UserViewModel {
    @Defaults("user", defaultValue: nil)
    var user: User? {
        didSet {
            print("new user: \(user)")
        }
    }
}
```

## UserDefaultsStorage

A storage that provides methods to save and retrieve data from UserDefaults.

```swift
let storage = UserDefaultsStorage<Int?>(key: "MyKey")
storage.value = 1
```

## FileStorage

A storage that provides methods to save and retrieve data from file system. It uses `FileManager` to interact with file system.
Default path mask is: ./*userDomainMask*/*cachesDirectory*/**Storages**/*fileName*.stg

```swift
let storage = FileStorage<Int>(fileName: "TestFile.txt")
storage.value = 1
```

## InMemoryStorage

A storage that provides methods to save and retrieve data in memory.

```swift
let storage = InMemoryStorage<Int>(value: 1)
storage.value = 1
```

## KeychainStorage

A storage that provides methods to save and retrieve data from OS Keychain.
Most safety storage, but with limitations by [SDK](https://developer.apple.com/documentation/security).  

```swift
let storage = KeychainStorage(key: "MyKey", configuration: .init(service: Bundle.main.bundleIdentifier ?? "MyService")
storage.value = auth.token
```

## AnyStorage

Type-erased storage that provides methods to save and retrieve data from any kind storage. Each storage has `toAny()` method which is used to convert specific storage to `AnyStorage`.

```swift
let storage = UserDefaultsStorage<Int?>(key: "MyKey").toAny()
storage.value = 1
```

## Composition

`AnyStorage<Value>` conforms to `Storage` protocol and can be used in composition with other storages by method `combine()` or global function `zip(storages:)`

```swift
let userDefaultsStorage = UserDefaultsStorage<Int?>(value: 1)
let inMemoryStorage = InMemoryStorage<Int>(value: 1)

let combined = inMemoryStorage.combine(userDefaultsStorage) // AnyStorage<Int>
combined.value = 1
```

`zip<Value>(storages: [any Storage<Value>])` is only available in iOS 16 or newer
```swift
let combined = zip(storages: [
    InMemoryStorage<Int?>(value: 1),
    UserDefaultsStorage(key: "MyKey")
])
```

`zip<Value>(storages: [AnyStorage<Value>])` is deprecated in iOS 16 or newer 
```swift
let combined = zip(storages: [
    InMemoryStorage<Int?>(value: 1).toAny(),
    UserDefaultsStorage(key: "MyKey").toAny()
])
```

### Expirable
Property wrapper that allows you to set expiration time for the value.

```swift
@Expirable(lifetime: .oneHour) var token: String?
```
