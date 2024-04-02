import Foundation

public final class FileStorage<Value>: Storage
where Value: ExpressibleByNilLiteral & Codable {
    private lazy var subject: ValueSubject<Value> = .init(get())
    public private(set) lazy var eventier: ValuePublisher<Value> = subject.eraseToAnyPublisher()

    private let fileName: String
    private let filePath: URL
    private let fileManager: FileManager

    private lazy var decoder: JSONDecoder = .init()
    private lazy var encoder: JSONEncoder = .init()

    public var value: Value {
        get {
            return get()
        }
        set {
            set(newValue)
        }
    }

    public init(fileName: String,
                fileManager: FileManager = .default) {
        self.fileName = fileName
        self.fileManager = fileManager

        var folderUrl = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
            .first.unsafelyUnwrapped
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

        self.filePath = folderUrl.appendingPathComponent(fileName).appendingPathExtension("stg")
    }

    private func get() -> Value {
        do {
            guard fileManager.fileExists(atPath: filePath.path) else {
                return nil
            }

            let data = try Data(contentsOf: filePath)
            let result = try decoder.decode(Value.self, from: data)
            return result
        } catch {
            assertionFailure("\(error)")
            return nil
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
