import UIKit

extension FileManager {
    private var documentsDirectory: URL? {
        return try? url(for: .documentDirectory, in: .userDomainMask,
                        appropriateFor: nil, create: true)
    }

    func documentsDirectoryURL(for key: String) -> URL? {
        return FileManager.default.documentsDirectory?.appendingPathComponent(key)
    }
}

struct DiskPersistor {
    static func value<T: Codable>(for key: String) -> T? {
        guard let url = FileManager.default.documentsDirectoryURL(for: key),
            let rawData = DiskDataIO.read(from: url) else { return nil }

        return try? JSONDecoder().decode(T.self, from: rawData)
    }

    static func save<T: Codable>(value: T, for key: String, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            defer { completion?() }
            guard let url = FileManager.default.documentsDirectoryURL(for: key),
                let rawData = try? JSONEncoder().encode(value) else { return }
            DiskDataIO.write(rawData, to: url)
        }
    }
}

struct DiskDataIO {
    static func read(from url: URL) -> Data? {
        return try? Data(contentsOf: url)
    }

    static func write(_ data: Data, to url: URL) {
        try? data.write(to: url, options: .atomic)
    }
}

extension DiskPersistor {
    static func imageFromCache(for key: String) -> UIImage? {
        if let imageDataString: String = DiskPersistor.value(for: key) {
            if let imageData = Data(base64Encoded: imageDataString) {
                if let image = UIImage(data: imageData) {
                    return image
                }
            }
        }
        
        return nil
    }
}
