import CoreML
import Foundation

public extension MLModel {
    static func create(
        path: String,
        type: String? = "mlmodel",
        bundle: Bundle = .main,
        configuration: MLModelConfiguration = .init()
    ) throws -> MLModel {
        guard let path = bundle.path(forResource: path, ofType: type) else {
            throw CellyError(message: "Tfile could not be located: \(path)")
        }
        let modelDescriptionURL = URL(fileURLWithPath: path)
        let compiledModelURL = try MLModel.compileModel(at: modelDescriptionURL)
        return try MLModel(contentsOf: compiledModelURL, configuration: configuration)
    }
}
