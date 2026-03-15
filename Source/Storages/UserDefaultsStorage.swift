import Combine
import Foundation

/// A storage backend that persists `Codable` values using `UserDefaults`.
///
/// `UserDefaultsStorage` allows storing and retrieving values with support for Combine-based observation.
/// It encodes values as JSON before storing and decodes them on retrieval.
///
/// Use this class to manage lightweight settings, preferences, or any other persistable data.
///
/// - Note: The `Value` must conform to `Codable` and `ExpressibleByNilLiteral`.
public final class UserDefaultsStorage<Value: Codable>: Storage {
    private lazy var subject: CurrentValueSubject<Value, Never> = .init(get())
    /// A publisher that emits the current value and all subsequent changes.
    ///
    /// Use this publisher to observe value updates in real-time.
    public private(set) lazy var eventier: AnyPublisher<Value, Never> = subject.eraseToAnyPublisher()

    private let defaults: UserDefaults
    private let key: String
    private lazy var decoder: JSONDecoder = .init()
    private lazy var encoder: JSONEncoder = .init()
    private let defaultValue: Value

    /// The current value stored in `UserDefaults`.
    ///
    /// Setting a new value encodes and writes it to `UserDefaults`.
    /// Getting the value decodes it from stored data or returns `nil` if unavailable.
    public var value: Value {
        get {
            return get()
        }
        set {
            set(newValue)
        }
    }

    /// Creates a new storage instance using the specified key and `UserDefaults`.
    ///
    /// - Parameters:
    ///   - key: The key used to store and retrieve the value.
    ///   - defaults: The `UserDefaults` instance to use. Defaults to `.standard`.
    public init(key: String, defaultValue: Value, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
        self.defaultValue = defaultValue
    }

    private func get() -> Value {
        if let data = defaults.data(forKey: key),
           let result = try? decoder.decode(Value.self, from: data) {
            return result
        }
        return defaultValue
    }

    private func set(_ newValue: Value) {
        let result: Value
        if let data = try? encoder.encode(newValue) {
            defaults.set(data, forKey: key)
            result = newValue
        } else {
            defaults.removeObject(forKey: key)
            result = defaultValue
        }

        defaults.synchronize()
        objectWillChange.send()
        subject.send(result)
    }
}

/// Convenience initializer that uses `nil` as the default value.
public extension UserDefaultsStorage where Value: ExpressibleByNilLiteral {
    convenience init(key: String, defaults: UserDefaults = .standard) {
        self.init(key: key, defaultValue: nil, defaults: defaults)
    }
}

/// Convenience initializer that uses an empty array as the default value.
public extension UserDefaultsStorage where Value: ExpressibleByArrayLiteral {
    convenience init(key: String, defaults: UserDefaults = .standard) {
        self.init(key: key, defaultValue: [], defaults: defaults)
    }
}

/// Convenience initializer that uses an empty dictionary as the default value.
public extension UserDefaultsStorage where Value: ExpressibleByDictionaryLiteral {
    convenience init(key: String, defaults: UserDefaults = .standard) {
        self.init(key: key, defaultValue: [:], defaults: defaults)
    }
}

/// Convenience initializer that uses `false` as the default value.
public extension UserDefaultsStorage where Value: ExpressibleByBooleanLiteral {
    convenience init(key: String, defaults: UserDefaults = .standard) {
        self.init(key: key, defaultValue: false, defaults: defaults)
    }
}

#if swift(>=6.0)
extension UserDefaultsStorage: @unchecked Sendable {}
#endif
