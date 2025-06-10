import Foundation

public struct KeychainConfiguration: Equatable {
    /// unique id for app. in common case is bundle id.
    public let service: String
    /// unique id for filter app scope. in common case is nil, but if service is not unique between apps, then group can help to filter values only for corresponding group.
    public let accessGroup: String?
    /// iCloud sync
    public let synchronizable: Bool

    public let decoder: JSONDecoder
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
where Value: Equatable & Codable & ExpressibleByNilLiteral {
    private lazy var subject: ValueSubject<Value> = .init(get())
    /// A publisher that emits the current value and all future changes.
    ///
    /// Use this publisher to observe changes to the stored value reactively using Combine.
    public private(set) lazy var eventier: ValuePublisher<Value> = subject.eraseToAnyPublisher()

    private let key: String
    private let keychain: Keychain

    /// The value currently stored in the Keychain.
    ///
    /// Setting a new value writes it to the Keychain. Assigning `nil` clears the stored value.
    /// Getting the value returns the most recently stored value, or `nil` if unavailable or invalid.
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
    public init(key: String, keychain: Keychain) {
        self.key = key
        self.keychain = keychain
    }

    /// Creates a Keychain-backed storage instance using a configuration.
    ///
    /// - Parameters:
    ///   - key: The key used to store and retrieve the value in the Keychain.
    ///   - configuration: A `KeychainConfiguration` that defines how the Keychain is accessed.
    public convenience init(key: String, configuration: KeychainConfiguration) {
        self.init(key: key, keychain: .init(configuration: configuration))
    }

    private func get() -> Value {
        if let result = try? keychain.read(Value.self, for: key) {
            return result
        }
        return nil
    }

    private func set(_ newValue: Value) {
        let empty: Value = nil

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

#if swift(>=6.0)
extension KeychainConfiguration: Sendable {}
extension KeychainStorage: @unchecked Sendable {}
#endif
