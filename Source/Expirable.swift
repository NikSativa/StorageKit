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
public struct Expirable<Value: ExpressibleByNilLiteral> {
    private var _value: Value
    private let lifetime: Lifetime
    private var savedDate = Date()

    private var hasExpired: Bool {
        return lifetime.hasExpired(from: savedDate, currentDate: Date())
    }

    /// The currently stored value, or `nil` if the expiration interval has elapsed.
    ///
    /// Getting this value returns `nil` if the lifetime has expired.
    /// Setting a new value resets the expiration timer and stores the new value.
    public var wrappedValue: Value {
        get {
            return hasExpired ? nil : _value
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
    public init(wrappedValue: Value = nil,
                lifetimeInterval interval: TimeInterval) {
        self.lifetime = Lifetime(expiresInSeconds: interval)
        self._value = wrappedValue
    }

    /// Creates an expirable wrapper using a predefined `Lifetime`.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value to store.
    ///   - lifetime: A `Lifetime` object that defines how long the value remains valid.
    public init(wrappedValue: Value = nil,
                lifetime: Lifetime) {
        self.lifetime = lifetime
        self._value = wrappedValue
    }
}

extension Expirable: Codable where Value: Codable {}
extension Expirable: Equatable where Value: Equatable {}

#if swift(>=6.0)
extension Expirable: @unchecked Sendable {}
#endif
