import Foundation

/// A storage backend that persists `Codable` values using `UserDefaults`.
///
/// `UserDefaultsStorage` allows storing and retrieving values with support for Combine-based observation.
/// It encodes values as JSON before storing and decodes them on retrieval.
///
/// Use this class to manage lightweight settings, preferences, or any other persistable data.
///
/// - Note: The `Value` must conform to `Codable` and `ExpressibleByNilLiteral`.
public final class UserDefaultsStorage<Value>: Storage
where Value: ExpressibleByNilLiteral & Codable {
    private lazy var subject: ValueSubject<Value> = .init(get())
    /// A publisher that emits the current value and all subsequent changes.
    ///
    /// Use this publisher to observe value updates in real-time.
    public private(set) lazy var eventier: ValuePublisher<Value> = subject.eraseToAnyPublisher()

    private let defaults: UserDefaults
    private let key: String
    private lazy var decoder: JSONDecoder = .init()
    private lazy var encoder: JSONEncoder = .init()

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
    public init(key: String, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }

    private func get() -> Value {
        if let data = defaults.data(forKey: key),
           let result = try? decoder.decode(Value.self, from: data) {
            return result
        }
        return nil
    }

    private func set(_ newValue: Value) {
        let result: Value
        if let data = try? encoder.encode(newValue) {
            defaults.set(data, forKey: key)
            result = newValue
        } else {
            defaults.removeObject(forKey: key)
            result = nil
        }

        defaults.synchronize()
        objectWillChange.send()
        subject.send(result)
    }
}

#if swift(>=6.0)
extension UserDefaultsStorage: @unchecked Sendable {}
#endif
