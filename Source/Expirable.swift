import Foundation

/// A property wrapper that automatically invalidates its value after a specified duration.
///
/// Use `Expirable` to store values that should become `nil` after a defined time interval has elapsed.
/// This is useful for implementing token expiration, temporary caching, or any use case where time-based invalidation is needed.
///
/// The wrapper resets the expiration timer whenever a new value is set.
///
/// ### Example
/// ```swift
/// @Expirable(lifetimeInterval: 3600)
/// var token: String?
/// ```
@propertyWrapper
public struct Expirable<Value> {
    private var _value: Value
    private let lifetime: Lifetime
    private var savedDate = Date()
    private let defaultValue: Value

    private var hasExpired: Bool {
        return lifetime.hasExpired(from: savedDate, currentDate: Date())
    }

    /// The currently stored value, or `nil` if the expiration interval has elapsed.
    ///
    /// Getting this value returns `nil` if the lifetime has expired.
    /// Setting a new value resets the expiration timer and stores the new value.
    public var wrappedValue: Value {
        get {
            return hasExpired ? defaultValue : _value
        }
        set {
            savedDate = Date()
            _value = newValue
        }
    }

    /// Creates an expirable wrapper using a custom expiration interval.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value to store.
    ///   - interval: The number of seconds the value remains valid before expiring.
    public init(wrappedValue: Value,
                defaultValue: Value,
                lifetimeInterval interval: TimeInterval) {
        self.lifetime = Lifetime(expiresInSeconds: interval)
        self._value = wrappedValue
        self.defaultValue = defaultValue
    }

    /// Creates an expirable wrapper using a predefined `Lifetime`.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value to store.
    ///   - lifetime: A `Lifetime` object that defines how long the value remains valid.
    public init(wrappedValue: Value,
                defaultValue: Value,
                lifetime: Lifetime) {
        self.lifetime = lifetime
        self._value = wrappedValue
        self.defaultValue = defaultValue
    }
}

/// Convenience initializers for optional-like values using `nil` as the expired fallback.
public extension Expirable where Value: ExpressibleByNilLiteral {
    init(wrappedValue: Value,
         lifetimeInterval interval: TimeInterval) {
        self.init(wrappedValue: wrappedValue, defaultValue: nil, lifetimeInterval: interval)
    }

    init(wrappedValue: Value,
         lifetime: Lifetime) {
        self.init(wrappedValue: wrappedValue, defaultValue: nil, lifetime: lifetime)
    }
}

/// Convenience initializers for array literal values using an empty array as the expired fallback.
public extension Expirable where Value: ExpressibleByArrayLiteral {
    init(wrappedValue: Value,
         lifetimeInterval interval: TimeInterval) {
        self.init(wrappedValue: wrappedValue, defaultValue: [], lifetimeInterval: interval)
    }

    init(wrappedValue: Value,
         lifetime: Lifetime) {
        self.init(wrappedValue: wrappedValue, defaultValue: [], lifetime: lifetime)
    }
}

/// Convenience initializers for dictionary literal values using an empty dictionary as the expired fallback.
public extension Expirable where Value: ExpressibleByDictionaryLiteral {
    init(wrappedValue: Value,
         lifetimeInterval interval: TimeInterval) {
        self.init(wrappedValue: wrappedValue, defaultValue: [:], lifetimeInterval: interval)
    }

    init(wrappedValue: Value,
         lifetime: Lifetime) {
        self.init(wrappedValue: wrappedValue, defaultValue: [:], lifetime: lifetime)
    }
}

/// Convenience initializers for boolean literal values using `false` as the expired fallback.
public extension Expirable where Value: ExpressibleByBooleanLiteral {
    init(wrappedValue: Value,
         lifetimeInterval interval: TimeInterval) {
        self.init(wrappedValue: wrappedValue, defaultValue: false, lifetimeInterval: interval)
    }

    init(wrappedValue: Value,
         lifetime: Lifetime) {
        self.init(wrappedValue: wrappedValue, defaultValue: false, lifetime: lifetime)
    }
}

extension Expirable: Codable where Value: Codable {}
extension Expirable: Equatable where Value: Equatable {}

#if swift(>=6.0)
extension Expirable: @unchecked Sendable {}
#endif
