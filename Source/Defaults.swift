import Combine
import Foundation

@propertyWrapper
public final class Defaults<Value: Codable> {
    private let userDefaults: UserDefaults

    private let key: String
    private let defaultValue: Value
    private let defaultsObserver: DefaultsObserver

    private let decoderGenerator: () -> JSONDecoder
    private lazy var decoder: JSONDecoder = decoderGenerator()
    private let encoderGenerator: () -> JSONEncoder
    private lazy var encoder: JSONEncoder = encoderGenerator()

    private lazy var eventier: CurrentValueSubject<Value, Never> = .init(wrappedValue)
    public lazy var projectedValue: AnyPublisher<Value, Never> = {
        return eventier.eraseToAnyPublisher()
    }()

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

    public required init(_ key: String,
                         defaultValue: Value,
                         decoder: (() -> JSONDecoder)? = nil,
                         encoder: (() -> JSONEncoder)? = nil,
                         userDefaults: UserDefaults = .standard) {
        self.key = key
        self.userDefaults = userDefaults
        self.defaultValue = defaultValue
        self.encoderGenerator = encoder ?? { .init() }
        self.decoderGenerator = decoder ?? { .init() }

        self.defaultsObserver = .init(key: key, userDefaults: userDefaults)
        defaultsObserver.updateHandler = { [weak self] new in
            guard let self else {
                return
            }

            let newRestored: Value
            if let new = new as? Value {
                newRestored = new
            } else if new is NSNull {
                newRestored = defaultValue
            } else if let new = new as? Data {
                do {
                    newRestored = try self.decoder.decode(Value.self, from: new)
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
}

private final class DefaultsObserver: NSObject {
    private let userDefaults: UserDefaults
    private let key: String
    var updateHandler: ((_ new: Any?) -> Void)?

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

        if Thread.isMainThread {
            updateHandler?(change[.newKey])
        } else {
            DispatchQueue.main.sync {
                updateHandler?(change[.newKey])
            }
        }
    }
}

public extension Defaults where Value: ExpressibleByNilLiteral {
    convenience init(_ key: String,
                     decoder: (() -> JSONDecoder)? = nil,
                     encoder: (() -> JSONEncoder)? = nil,
                     userDefaults: UserDefaults = .standard) {
        self.init(key,
                  defaultValue: nil,
                  decoder: decoder,
                  encoder: encoder,
                  userDefaults: userDefaults)
    }
}

public extension Defaults where Value: ExpressibleByArrayLiteral, Value.ArrayLiteralElement: Codable {
    convenience init(_ key: String,
                     decoder: (() -> JSONDecoder)? = nil,
                     encoder: (() -> JSONEncoder)? = nil,
                     userDefaults: UserDefaults = .standard) {
        self.init(key,
                  defaultValue: [],
                  decoder: decoder,
                  encoder: encoder,
                  userDefaults: userDefaults)
    }
}

public extension Defaults where Value: ExpressibleByDictionaryLiteral, Value.Key: Codable, Value.Value: Codable {
    convenience init(_ key: String,
                     decoder: (() -> JSONDecoder)? = nil,
                     encoder: (() -> JSONEncoder)? = nil,
                     userDefaults: UserDefaults = .standard) {
        self.init(key,
                  defaultValue: [:],
                  decoder: decoder,
                  encoder: encoder,
                  userDefaults: userDefaults)
    }
}
