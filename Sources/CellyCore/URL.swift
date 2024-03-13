import Foundation

public extension URL {
    static func create(string: String) throws -> URL {
        guard let url = URL(string: string) else {
            throw CellyError(message: "Invalid url \(string)")
        }
        return url
    }

    static func create(
        path: String,
        isDirectory: Bool = false
    ) throws -> URL {
        URL(fileURLWithPath: path, isDirectory: isDirectory)
    }
}
