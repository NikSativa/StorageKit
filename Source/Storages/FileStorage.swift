import Combine
import Foundation

/// A storage backend that saves values to a file on disk using JSON encoding.
///
/// `FileStorage` provides persistence for `Codable` and `ExpressibleByNilLiteral` values by
/// reading and writing JSON-encoded data to a specific file location. It supports observation
/// through Combine publishers.
///
/// The file is stored in the app's Caches directory under a "Storages" folder.
public final class FileStorage<Value: Codable>: Storage {
    private lazy var subject: CurrentValueSubject<Value, Never> = .init(get())
    /// A publisher that emits the current value and all subsequent updates.
    ///
    /// Use this publisher to observe value changes reactively.
    public private(set) lazy var eventier: AnyPublisher<Value, Never> = subject.eraseToAnyPublisher()

    private let fileName: String
    private let filePath: URL
    private let fileManager: FileManager
    private let defaultValue: Value

    private lazy var decoder: JSONDecoder = .init()
    private lazy var encoder: JSONEncoder = .init()

    /// The current value stored in the file.
    ///
    /// Setting this value will save it to disk. Retrieving it reads from the file if available.
    /// If the file does not exist or decoding fails, this returns `nil`.
    public var value: Value {
        get {
            return get()
        }
        set {
            set(newValue)
        }
    }

    /// Creates a new file-backed storage using the specified file name.
    ///
    /// - Parameters:
    ///   - fileName: The name of the file used for storage. The file will be saved with a `.stg` extension.
    ///   - fileManager: The file manager to use for reading and writing. Defaults to `.default`.
    ///
    /// The file is created in the app's Caches directory inside a "Storages" folder.
    public convenience init(fileName: String,
                            defaultValue: Value,
                            fileManager: FileManager = .default) {
        var folderUrl = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
            .first
            .unsafelyUnwrapped
            .appendingPathComponent("Storages", isDirectory: true)

        if !fileManager.fileExists(atPath: folderUrl.path) {
            do {
                try fileManager.createDirectory(atPath: folderUrl.path,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
            } catch {
                folderUrl = folderUrl.deletingLastPathComponent()
            }
        }

        let filePath = folderUrl.appendingPathComponent(fileName).appendingPathExtension("stg")
        self.init(fileName: fileName,
                  fileManager: fileManager,
                  filePath: filePath,
                  defaultValue: defaultValue)
    }

    /// Initializes a `FileStorage` instance with a specified file name and path.
    ///
    /// - Parameters:
    ///   - fileName: The name used to identify the storage file.
    ///   - fileManager: The file manager responsible for file operations.
    ///   - filePath: The full URL of the file used for storage.
    public required init(fileName: String,
                         fileManager: FileManager = .default,
                         filePath: URL,
                         defaultValue: Value) {
        self.fileName = fileName
        self.filePath = filePath
        self.fileManager = fileManager
        self.defaultValue = defaultValue
    }

    private func get() -> Value {
        do {
            guard fileManager.fileExists(atPath: filePath.path) else {
                return defaultValue
            }

            let data = try Data(contentsOf: filePath)
            let result = try decoder.decode(Value.self, from: data)
            return result
        } catch {
            assertionFailure("\(error)")
            return defaultValue
        }
    }

    private func set(_ newValue: Value) {
        do {
            if fileManager.fileExists(atPath: filePath.path) {
                try fileManager.removeItem(at: filePath)
            }

            let data = try encoder.encode(newValue)
            try data.write(to: filePath, options: [.atomic])

            objectWillChange.send()
            subject.send(newValue)
        } catch {
            assertionFailure("\(error)")
        }
    }
}

/// Convenience initializers that use `nil` as the default value.
public extension FileStorage where Value: ExpressibleByNilLiteral {
    convenience init(fileName: String,
                     fileManager: FileManager = .default) {
        self.init(fileName: fileName, defaultValue: nil, fileManager: fileManager)
    }

    convenience init(fileName: String,
                     fileManager: FileManager = .default,
                     filePath: URL) {
        self.init(fileName: fileName,
                  fileManager: fileManager,
                  filePath: filePath,
                  defaultValue: nil)
    }
}

/// Convenience initializers that use an empty array as the default value.
public extension FileStorage where Value: ExpressibleByArrayLiteral {
    convenience init(fileName: String,
                     fileManager: FileManager = .default) {
        self.init(fileName: fileName, defaultValue: [], fileManager: fileManager)
    }

    convenience init(fileName: String,
                     fileManager: FileManager = .default,
                     filePath: URL) {
        self.init(fileName: fileName,
                  fileManager: fileManager,
                  filePath: filePath,
                  defaultValue: [])
    }
}

/// Convenience initializers that use an empty dictionary as the default value.
public extension FileStorage where Value: ExpressibleByDictionaryLiteral {
    convenience init(fileName: String,
                     fileManager: FileManager = .default) {
        self.init(fileName: fileName, defaultValue: [:], fileManager: fileManager)
    }

    convenience init(fileName: String,
                     fileManager: FileManager = .default,
                     filePath: URL) {
        self.init(fileName: fileName,
                  fileManager: fileManager,
                  filePath: filePath,
                  defaultValue: [:])
    }
}

/// Convenience initializers that use `false` as the default value.
public extension FileStorage where Value: ExpressibleByBooleanLiteral {
    convenience init(fileName: String,
                     fileManager: FileManager = .default) {
        self.init(fileName: fileName, defaultValue: false, fileManager: fileManager)
    }

    convenience init(fileName: String,
                     fileManager: FileManager = .default,
                     filePath: URL) {
        self.init(fileName: fileName,
                  fileManager: fileManager,
                  filePath: filePath,
                  defaultValue: false)
    }
}

#if swift(>=6.0)
extension FileStorage: @unchecked Sendable {}
#endif
