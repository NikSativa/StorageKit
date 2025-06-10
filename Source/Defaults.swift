import Combine
import Foundation

#if swift(>=6.0)
@MainActor
#endif
/// A property wrapper that stores and observes values in `UserDefaults` with support for encoding and decoding.
///
/// `Defaults` synchronizes with `UserDefaults`, enabling automatic storage, retrieval, and observation
/// of values using Combine. It supports any type conforming to `Codable` and `Equatable`.
///
/// You can customize the encoder and decoder or use default JSON-based ones.
/// Value changes from external sources are monitored and published via `projectedValue`.
@propertyWrapper
public final class Defaults<Value: Codable & Equatable> {
    private let userDefaults: UserDefaults

    private let key: String
    private let defaultValue: Value
    private let defaultsObserver: DefaultsObserver

    #if swift(>=6.0)
    private nonisolated(unsafe) var notificationToken: (any NSObjectProtocol)?
    #else
    private var notificationToken: (any NSObjectProtocol)?
    #endif

    private let decoderGenerator: () -> JSONDecoder
    private lazy var decoder: JSONDecoder = decoderGenerator()
    private let encoderGenerator: () -> JSONEncoder
    private lazy var encoder: JSONEncoder = encoderGenerator()

    private lazy var eventier: ValueSubject<Value> = .init(wrappedValue)
    /// A Combine publisher that emits the current value and all subsequent changes.
    ///
    /// Use this publisher to observe updates reactively.
    public private(set) lazy var projectedValue: AnyPublisher<Value, Never> = {
        return eventier.removeDuplicates().eraseToAnyPublisher()
    }()

    /// The value stored in `UserDefaults`.
    ///
    /// If the stored value cannot be decoded, the default value is returned.
    /// Assigning a new value encodes and stores it in `UserDefaults`.
    public var wrappedValue: Value {
        get {
            do {
                if let value = userDefaults.value(forKey: key) as? Value {
                    return value
                }

                if let data = userDefaults.data(forKey: key) {
                    let value = try decoder.decode(Value.self, from: data)
                    return value
                }

                return defaultValue
            } catch {
                assertionFailure(error.localizedDescription)
                return defaultValue
            }
        }

        set {
            assert(Thread.isMainThread, "shpuld be used only in main thread")
            do {
                let data = try encoder.encode(newValue)
                userDefaults.set(data, forKey: key)
                userDefaults.synchronize()
            } catch {
                assertionFailure(error.localizedDescription)
            }
        }
    }

    /// Creates a new `Defaults` property wrapper instance.
    ///
    /// - Parameters:
    ///   - wrappedValue: The default value used when no value is stored.
    ///   - key: The `UserDefaults` key used for storage.
    ///   - decoder: An optional closure that provides a custom `JSONDecoder`.
    ///   - encoder: An optional closure that provides a custom `JSONEncoder`.
    ///   - userDefaults: The `UserDefaults` instance to use (defaults to `.standard`).
    public required init(wrappedValue defaultValue: Value,
                         key: String,
                         decoder: (() -> JSONDecoder)? = nil,
                         encoder: (() -> JSONEncoder)? = nil,
                         userDefaults: UserDefaults = .standard) {
        self.key = key
        self.userDefaults = userDefaults
        self.defaultValue = defaultValue
        self.encoderGenerator = encoder ?? { .init() }
        self.decoderGenerator = decoder ?? { .init() }

        self.defaultsObserver = .init(key: key, userDefaults: userDefaults)
        defaultsObserver.updateHandler = { [weak self] _ in
            self?.syncMain()
        }

        // sometimes KVO is not working
        self.notificationToken = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                                                        object: userDefaults,
                                                                        queue: .main) { [weak self] _ in
            self?.syncMain()
        }
    }

    deinit {
        if let notificationToken {
            NotificationCenter.default.removeObserver(notificationToken)
        }
    }

    private nonisolated func syncMain() {
        assert(Thread.isMainThread, "Should be used only in main thread")

        #if swift(>=6.0)
        MainActor.assumeIsolated {
            notifyAboutChanges()
        }
        #else
        notifyAboutChanges()
        #endif
    }

    private func notifyAboutChanges() {
        guard let new = userDefaults.object(forKey: key) else {
            eventier.send(defaultValue)
            return
        }

        let newRestored: Value
        if let new = new as? Value {
            newRestored = new
        } else if new is NSNull {
            newRestored = defaultValue
        } else if let new = new as? Data {
            do {
                newRestored = try decoder.decode(Value.self, from: new)
            } catch {
                newRestored = defaultValue
            }
        } else {
            assertionFailure("somehow value in defaults was overridden with wrong type")
            newRestored = defaultValue
        }

        eventier.send(newRestored)
    }
}

/// A convenience initializer for optional values.
///
/// Initializes the property wrapper with `nil` as the default value.
public extension Defaults where Value: ExpressibleByNilLiteral {
    convenience init(_ key: String,
                     decoder: (() -> JSONDecoder)? = nil,
                     encoder: (() -> JSONEncoder)? = nil,
                     userDefaults: UserDefaults = .standard) {
        self.init(wrappedValue: nil,
                  key: key,
                  decoder: decoder,
                  encoder: encoder,
                  userDefaults: userDefaults)
    }
}

/// A convenience initializer for array literal types.
///
/// Initializes the property wrapper with an empty array as the default value.
public extension Defaults where Value: ExpressibleByArrayLiteral, Value.ArrayLiteralElement: Codable {
    convenience init(_ key: String,
                     decoder: (() -> JSONDecoder)? = nil,
                     encoder: (() -> JSONEncoder)? = nil,
                     userDefaults: UserDefaults = .standard) {
        self.init(wrappedValue: [],
                  key: key,
                  decoder: decoder,
                  encoder: encoder,
                  userDefaults: userDefaults)
    }
}

/// A convenience initializer for dictionary literal types.
///
/// Initializes the property wrapper with an empty dictionary as the default value.
public extension Defaults where Value: ExpressibleByDictionaryLiteral, Value.Key: Codable, Value.Value: Codable {
    convenience init(_ key: String,
                     decoder: (() -> JSONDecoder)? = nil,
                     encoder: (() -> JSONEncoder)? = nil,
                     userDefaults: UserDefaults = .standard) {
        self.init(wrappedValue: [:],
                  key: key,
                  decoder: decoder,
                  encoder: encoder,
                  userDefaults: userDefaults)
    }
}

#if swift(>=6.0)
extension Defaults: @unchecked Sendable {}
#endif

private final class DefaultsObserver: NSObject {
    private let userDefaults: UserDefaults
    private let key: String

    #if swift(>=6.0)
    var updateHandler: (@Sendable (_ new: Any?) -> Void)?
    #else
    var updateHandler: ((_ new: Any?) -> Void)?
    #endif

    required init(key: String,
                  userDefaults: UserDefaults) {
        self.key = key
        self.userDefaults = userDefaults
        super.init()
        userDefaults.addObserver(self, forKeyPath: key, options: [.old, .new], context: nil)
    }

    deinit {
        userDefaults.removeObserver(self, forKeyPath: key, context: nil)
    }

    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let change, keyPath == key else {
            return
        }

        let new = UnsafeSendable(change[.newKey])
        if Thread.isMainThread {
            updateHandler?(new.value)
        } else {
            DispatchQueue.main.sync {
                updateHandler?(new.value)
            }
        }
    }
}

#if swift(>=6.0)
extension DefaultsObserver: @unchecked Sendable {}

private struct UnsafeSendable<T>: @unchecked Sendable {
    let value: T
}
#else
struct UnsafeSendable<T> {
    let value: T
}
#endif

extension UnsafeSendable {
    init(_ value: T) {
        self.value = value
    }
}
