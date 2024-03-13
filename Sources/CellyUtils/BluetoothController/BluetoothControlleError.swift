import Foundation

public enum BluetoothControllerError: LocalizedError {
    case expectedCommandLetter
    case badNumberFormat
    case invalidStatement
    case travelExceeded // soft limit
    case unknown(String?)

    public var errorDescription: String? {
        switch self {
        case .expectedCommandLetter:
            return "Expected Command Letter. G-code words consist of a letter and a value. Letter was not found."
        case .badNumberFormat:
            return "Bad Number Format. Missing the expected G-code word value or numeric value format is not valid"
        case .invalidStatement:
            return "Invalid Statement. Grbl ‘$’ system command was not recognized or supported."
        case .travelExceeded:
            return "Jog target exceeds machine travel. Jog command has been ignored."
        case let .unknown(code):
            return "Controller error: ".appending(code ?? "uknown")
        }
    }
}
