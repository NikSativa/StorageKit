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

public final class KeychainStorage<Value>: Storage
where Value: Equatable & Codable & ExpressibleByNilLiteral {
    private lazy var subject: ValueSubject<Value> = .init(get())
    public private(set) lazy var eventier: ValuePublisher<Value> = subject.eraseToAnyPublisher()

    private let key: String
    private let keychain: Keychain

    public var value: Value {
        get {
            return get()
        }
        set {
            set(newValue)
        }
    }

    public init(key: String, keychain: Keychain) {
        self.key = key
        self.keychain = keychain
    }

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
