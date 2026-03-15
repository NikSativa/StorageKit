import Combine
import Foundation

/// Configuration for keychain access and value encoding.
public struct KeychainConfiguration: Equatable {
    /// unique id for app. in common case is bundle id.
    public let service: String
    /// unique id for filter app scope. in common case is nil, but if service is not unique between apps, then group can help to filter values only for corresponding group.
    public let accessGroup: String?
    /// iCloud sync
    public let synchronizable: Bool

    /// Decoder used to restore values from keychain data.
    public let decoder: JSONDecoder
    /// Encoder used to serialize values before writing to keychain.
    public let encoder: JSONEncoder

    /// Secure storage
    /// - parameter service: unique id for app. in common case is bundle id.
    /// - parameter accessGroup: unique id for filter app scope. in common case is nil, but if service is not unique between apps, then group can help to filter values only for corresponding group.
    /// - parameter synchronizable: iCloud sync
    public init(service: String,
                accessGroup: String? = nil,
                synchronizable: Bool = false,
                decoder: JSONDecoder = .init(),
                encoder: JSONEncoder = .init()) {
        self.service = service
        self.accessGroup = accessGroup
        self.synchronizable = synchronizable
        self.decoder = decoder
        self.encoder = encoder
    }

    /// Compares configurations by keychain addressing fields.
    ///
    /// Decoder and encoder instances are intentionally ignored.
    public static func ==(lhs: KeychainConfiguration, rhs: KeychainConfiguration) -> Bool {
        return lhs.service == rhs.service
            && lhs.accessGroup == rhs.accessGroup
            && lhs.synchronizable == rhs.synchronizable
        // ignore coders from equality
        // && lhs.encoder === rhs.encoder
        // && lhs.decoder === rhs.decoder
    }
}

/// A storage backend that uses the iOS Keychain to persist and observe values securely.
///
/// `KeychainStorage` enables secure value storage for any type conforming to `Codable`, `Equatable`,
/// and `ExpressibleByNilLiteral`. Values are stored using a key and retrieved from the Keychain
/// using a `Keychain` interface.
///
/// You can observe changes to the stored value using the Combine-based `eventier` publisher.
///
/// ### Example
/// ```swift
/// let configuration = KeychainConfiguration(service: "com.example.app")
/// let storage = KeychainStorage<String?>(key: "auth_token", configuration: configuration)
/// storage.value = "abc123"
/// ```
public final class KeychainStorage<Value>: Storage
where Value: Equatable & Codable {
    private lazy var subject: CurrentValueSubject<Value, Never> = .init(get())
    /// A publisher that emits the current value and all future changes.
    ///
    /// Use this publisher to observe changes to the stored value reactively using Combine.
    public private(set) lazy var eventier: AnyPublisher<Value, Never> = subject.eraseToAnyPublisher()

    private let key: String
    private let keychain: Keychain
    private let defaultValue: Value

    /// The value currently stored in the Keychain.
    ///
    /// Setting a new value writes it to the Keychain. Assigning the configured default value clears the stored item.
    /// Getting the value returns the stored value, or the default value when missing or invalid.
    public var value: Value {
        get {
            return get()
        }
        set {
            set(newValue)
        }
    }

    /// Creates a Keychain-backed storage instance.
    ///
    /// - Parameters:
    ///   - key: The key used to store and retrieve the value in the Keychain.
    ///   - keychain: A `Keychain` instance that provides access to the secure storage APIs.
    public init(key: String, defaultValue: Value, keychain: Keychain) {
        self.key = key
        self.keychain = keychain
        self.defaultValue = defaultValue
    }

    /// Creates a Keychain-backed storage instance using a configuration.
    ///
    /// - Parameters:
    ///   - key: The key used to store and retrieve the value in the Keychain.
    ///   - configuration: A `KeychainConfiguration` that defines how the Keychain is accessed.
    public convenience init(key: String, defaultValue: Value, configuration: KeychainConfiguration) {
        self.init(key: key, defaultValue: defaultValue, keychain: .init(configuration: configuration))
    }

    private func get() -> Value {
        if let result = try? keychain.read(Value.self, for: key) {
            return result
        }
        return defaultValue
    }

    private func set(_ newValue: Value) {
        let empty: Value = defaultValue

        do {
            if newValue != empty {
                try keychain.write(newValue, for: key)
            } else {
                try keychain.clear(for: key)
            }
            objectWillChange.send()
            subject.send(newValue)
        } catch {
            assertionFailure("\(error)")
        }
    }
}

/// Convenience initializers that use `nil` as the default value.
public extension KeychainStorage where Value: ExpressibleByNilLiteral {
    convenience init(key: String, keychain: Keychain) {
        self.init(key: key, defaultValue: nil, keychain: keychain)
    }

    convenience init(key: String, configuration: KeychainConfiguration) {
        self.init(key: key, defaultValue: nil, keychain: .init(configuration: configuration))
    }
}

/// Convenience initializers that use an empty array as the default value.
public extension KeychainStorage where Value: ExpressibleByArrayLiteral {
    convenience init(key: String, keychain: Keychain) {
        self.init(key: key, defaultValue: [], keychain: keychain)
    }

    convenience init(key: String, configuration: KeychainConfiguration) {
        self.init(key: key, defaultValue: [], keychain: .init(configuration: configuration))
    }
}

/// Convenience initializers that use an empty dictionary as the default value.
public extension KeychainStorage where Value: ExpressibleByDictionaryLiteral {
    convenience init(key: String, keychain: Keychain) {
        self.init(key: key, defaultValue: [:], keychain: keychain)
    }

    convenience init(key: String, configuration: KeychainConfiguration) {
        self.init(key: key, defaultValue: [:], keychain: .init(configuration: configuration))
    }
}

/// Convenience initializers that use `false` as the default value.
public extension KeychainStorage where Value: ExpressibleByBooleanLiteral {
    convenience init(key: String, keychain: Keychain) {
        self.init(key: key, defaultValue: false, keychain: keychain)
    }

    convenience init(key: String, configuration: KeychainConfiguration) {
        self.init(key: key, defaultValue: false, keychain: .init(configuration: configuration))
    }
}

#if swift(>=6.0)
extension KeychainConfiguration: Sendable {}
extension KeychainStorage: @unchecked Sendable {}
#endif
