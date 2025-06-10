import Foundation
import Security

/// An error type representing issues encountered during Keychain operations.
public enum KeychainError: Error {
    /// Indicates corrupted or missing data in the Keychain.
    case brokenData

    /// Indicates an unhandled Keychain status code.
    ///
    /// The associated `OSStatus` value provides the underlying error code returned by the Keychain API.
    case unhandledError(OSStatus)
}

/// A utility for securely storing and retrieving values using the iOS Keychain.
///
/// The `Keychain` struct provides a type-safe interface for working with the Keychain. It supports storing and retrieving
/// `Codable`, `Data`, and `String` values, and can be customized using a `KeychainConfiguration`.
///
/// Values are stored under a given key and retrieved securely using Apple's Security framework.
public struct Keychain {
    /// The configuration that defines service name, access group, and synchronizability options.
    private let configuration: KeychainConfiguration

    /// The Keychain service name derived from the configuration.
    private var service: String {
        return configuration.service
    }

    /// The optional Keychain access group derived from the configuration.
    private var accessGroup: String? {
        return configuration.accessGroup
    }

    /// A Boolean value indicating whether Keychain items are synchronizable across devices.
    private var synchronizable: Bool {
        return configuration.synchronizable
    }

    /// Creates a new `Keychain` instance with the given configuration.
    ///
    /// - Parameter configuration: A `KeychainConfiguration` that defines service name, access group, and other options.
    public init(configuration: KeychainConfiguration) {
        self.configuration = configuration
    }

    /// Constructs a base Keychain query dictionary using the provided key and configuration.
    ///
    /// - Parameter key: The account key used for the query. Pass `nil` to match all items for the configured service.
    /// - Returns: A dictionary used in Keychain API calls.
    private func makeQuery(for key: String?) -> [CFString: AnyObject] {
        var query = [CFString: AnyObject]()
        query[kSecClass] = kSecClassGenericPassword
        query[kSecAttrService] = service as AnyObject
        query[kSecAttrAccount] = key as AnyObject
        query[kSecAttrSynchronizable] = synchronizable ? kCFBooleanTrue : kCFBooleanFalse

        if #available(iOS 13.0, *) {
            query[kSecUseDataProtectionKeychain] = kCFBooleanTrue
        }

        if let accessGroup {
            query[kSecAttrAccessGroup] = accessGroup as AnyObject?
        }

        return query
    }
}

public extension Keychain {
    /// Reads and decodes a value of the given type from the Keychain.
    ///
    /// - Parameters:
    ///   - type: The type to decode.
    ///   - key: The key used to locate the value.
    /// - Returns: The decoded value, or `nil` if no value exists.
    /// - Throws: `KeychainError` if the data is unreadable or the operation fails.
    func read<T: Decodable>(_: T.Type, for key: String) throws -> T? {
        return try read(for: key)
    }

    /// Reads and decodes a value from the Keychain.
    ///
    /// - Parameter key: The key used to locate the value.
    /// - Returns: The decoded value, or `nil` if no value exists.
    /// - Throws: `KeychainError` if the data is unreadable or the operation fails.
    func read<T: Decodable>(for key: String) throws -> T? {
        if let data = try read(dataFor: key) {
            return try configuration.decoder.decode(T.self, from: data)
        }
        return nil
    }

    /// Reads a string value from the Keychain.
    ///
    /// - Parameter key: The key used to locate the string.
    /// - Returns: The stored string, or `nil` if no value exists.
    /// - Throws: `KeychainError` if the data is unreadable or the operation fails.
    func read(stringFor key: String) throws -> String? {
        if let data = try read(dataFor: key) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    /// Reads raw data from the Keychain.
    ///
    /// - Parameter key: The key used to locate the data.
    /// - Returns: The stored data, or `nil` if no value exists.
    /// - Throws: `KeychainError` if the data is unreadable or the operation fails.
    func read(dataFor key: String) throws -> Data? {
        var query = makeQuery(for: key)

        query[kSecMatchLimit] = kSecMatchLimitOne
        query[kSecReturnAttributes] = kCFBooleanTrue
        query[kSecReturnData] = kCFBooleanTrue

        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        if status == errSecItemNotFound {
            return nil
        } else if status != noErr {
            throw KeychainError.unhandledError(status)
        }

        if let existingItem = queryResult as? [CFString: AnyObject],
           let data = existingItem[kSecValueData] as? Data {
            return data
        }
        throw KeychainError.brokenData
    }

    /// Encodes and writes an encodable value to the Keychain.
    ///
    /// - Parameters:
    ///   - value: The value to store.
    ///   - key: The key under which to store the value.
    /// - Throws: `KeychainError` if encoding or storage fails.
    func write(_ value: some Encodable, for key: String) throws {
        let data = try configuration.encoder.encode(value)
        try write(data: data, for: key)
    }

    /// Writes a string to the Keychain.
    ///
    /// - Parameters:
    ///   - string: The string to store.
    ///   - key: The key under which to store the string.
    /// - Throws: `KeychainError` if writing fails.
    func write(string: String, for key: String) throws {
        if let data = string.data(using: .utf8) {
            try write(data: data, for: key)
        }
    }

    /// Writes raw data to the Keychain.
    ///
    /// - Parameters:
    ///   - data: The data to store.
    ///   - key: The key under which to store the data.
    /// - Throws: `KeychainError` if the operation fails.
    func write(data: Data, for key: String) throws {
        var query = makeQuery(for: key)

        let status: OSStatus
        if let _ = try? read(dataFor: key) {
            let attributesToUpdate = [kSecValueData: data]
            status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        } else {
            query[kSecValueData] = data as AnyObject?
            status = SecItemAdd(query as CFDictionary, nil)
        }

        if status != noErr {
            throw KeychainError.unhandledError(status)
        }
    }

    /// Removes all items associated with the configured service from the Keychain.
    ///
    /// - Throws: `KeychainError` if deletion fails.
    func clear() throws {
        let query = makeQuery(for: nil)
        let status = SecItemDelete(query as CFDictionary)
        if status != noErr, status != errSecItemNotFound {
            throw KeychainError.unhandledError(status)
        }
    }

    /// Removes a specific item from the Keychain.
    ///
    /// - Parameter key: The key identifying the item to remove.
    /// - Throws: `KeychainError` if deletion fails.
    func clear(for key: String) throws {
        let query = makeQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        if status != noErr, status != errSecItemNotFound {
            throw KeychainError.unhandledError(status)
        }
    }
}

#if swift(>=6.0)
extension Keychain: Sendable {}
extension KeychainError: Sendable {}
#endif
