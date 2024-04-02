import Foundation
import Security

public enum KeychainError: Error {
    case brokenData
    case unhandledError(OSStatus)
}

public struct Keychain {
    private let configuration: KeychainConfiguration
    private var service: String {
        return configuration.service
    }

    private var accessGroup: String? {
        return configuration.accessGroup
    }

    private var synchronizable: Bool {
        return configuration.synchronizable
    }

    public init(configuration: KeychainConfiguration) {
        self.configuration = configuration
    }

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
    // MARK: - read

    func read<T: Decodable>(_: T.Type, for key: String) throws -> T? {
        return try read(for: key)
    }

    func read<T: Decodable>(for key: String) throws -> T? {
        if let data = try read(dataFor: key) {
            return try configuration.decoder.decode(T.self, from: data)
        }
        return nil
    }

    func read(stringFor key: String) throws -> String? {
        if let data = try read(dataFor: key) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

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

    // MARK: - write

    func write(_ value: some Encodable, for key: String) throws {
        let data = try configuration.encoder.encode(value)
        try write(data: data, for: key)
    }

    func write(string: String, for key: String) throws {
        if let data = string.data(using: .utf8) {
            try write(data: data, for: key)
        }
    }

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

    // MARK: - clear

    func clear() throws {
        let query = makeQuery(for: nil)
        let status = SecItemDelete(query as CFDictionary)
        if status != noErr, status != errSecItemNotFound {
            throw KeychainError.unhandledError(status)
        }
    }

    func clear(for key: String) throws {
        let query = makeQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        if status != noErr, status != errSecItemNotFound {
            throw KeychainError.unhandledError(status)
        }
    }
}
