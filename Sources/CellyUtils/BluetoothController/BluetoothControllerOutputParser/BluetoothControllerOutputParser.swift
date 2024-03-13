import CellyCore
import Combine
import Foundation

public protocol BluetoothControllerOutputParser {
    var outputSubject: CurrentValueSubject<BluetoothControllerStatus, Never> { get }
    func parse(data: Data, characteristicUUID: String) throws
}

public final class BluetoothControllerOutputParserImpl: BluetoothControllerOutputParser {
    private let logger: BluetoothControllerLogger?
    private var buffer: [String]
    public var outputSubject: CurrentValueSubject<BluetoothControllerStatus, Never>

    public init(logger: BluetoothControllerLogger?) {
        self.logger = logger
        self.buffer = [String]()
        self.outputSubject = CurrentValueSubject<BluetoothControllerStatus, Never>(.none)
    }

    public func parse(data: Data, characteristicUUID: String) throws {
        // Start: Convert data2string (ascii)
        guard
            let ASCIIstring = NSString(
                data: data,
                encoding: String.Encoding.ascii.rawValue
            )
        else {
            throw CellyError(message: "Failed to decodate data: \(data.count)", status: -1)
        }
        #if BUFFER_OUTPUT_LOGGING
            let str = ASCIIstring.replacingOccurrences(
                of: BluetoothControllerOutputSymbols.lineBreak,
                with: "\\n"
            ).replacingOccurrences(
                of: BluetoothControllerOutputSymbols.return,
                with: "\\r"
            )
            Log.log(.debug, "raw-ASCIIstring: \"%@\"", str)
        #endif
        // Start: Substitue line breaks
        var parseableString = ASCIIstring.replacingOccurrences(
            of: BluetoothControllerOutputSymbols.lineBreak,
            with: BluetoothControllerOutputSymbols.lineBreakSubstitutionSymbol
        ) as String
        parseableString = parseableString.replacingOccurrences(
            of: BluetoothControllerOutputSymbols.return,
            with: BluetoothControllerOutputSymbols.lineBreakSubstitutionSymbol
        ) as String
        // End
        // End
        try self.parse(parseableString: parseableString, characteristicUUID: characteristicUUID)
    }

    func parse(parseableString: String, characteristicUUID: String, purge: Bool = false) throws {
        let outputComponents = parseableString
            .components(separatedBy: BluetoothControllerOutputSymbols.lineBreakSubstitutionSymbol)
        // Ignoring empty input
        guard !outputComponents.isEmpty else {
            return
        }
        // Start: Collection batches in buffer
        if outputComponents.count > 1 {
            try self.parse(
                parseableString: outputComponents[0],
                characteristicUUID: characteristicUUID,
                purge: true
            )
            let leftParseableString = outputComponents.dropFirst().joined()
            if !leftParseableString.isEmpty {
                try self.parse(
                    parseableString: leftParseableString,
                    characteristicUUID: characteristicUUID
                )
            }
            return
        }
        // End

        self.buffer.append(outputComponents[0])
        if purge {
            let buffer = self.buffer
            self.buffer.removeAll()
            let rawString = buffer.joined()
            guard !rawString.isEmpty else { return }
            let info = BluetoothControllerOutputInfo(
                rawString: rawString,
                characteristicUUID: characteristicUUID
            )
            let parts = rawString.split(separator: BluetoothControllerOutputSymbols.separator)
                .map { String($0) }
            do {
                if rawString.contains(BluetoothControllerOutputSymbols.error) {
                    let errorParts = rawString
                        .split(separator: BluetoothControllerOutputSymbols.errorCodeSeparator)
                        .map { String($0) }
                    self.outputSubject
                        .send(.outputError(
                            info,
                            self.outputError(from: errorParts[safe: 1])
                        ))
                }
                else if rawString.contains(BluetoothControllerOutputSymbols.intro) {
                    self.outputSubject.send(.msg(info, rawString))
                }
                else if rawString.contains(BluetoothControllerOutputSymbols.homeMsg) {
                    self.outputSubject.send(.msg(info, rawString))
                }
                else if rawString.contains(BluetoothControllerOutputSymbols.msg) {
                    let messageString = self.messageString(from: rawString)
                    self.outputSubject
                        .send(.msg(info, "Controller message: ".appending(messageString)))
                }
                else if parts.count > 1 {
                    try self.outputSubject.send(self.status(from: parts, with: info))
                }
                else if rawString.contains(BluetoothControllerOutputSymbols.ok) {
                    self.outputSubject.send(.ok(info))
                }
                else if rawString.contains(BluetoothControllerOutputSymbols.ALARM) {
                    self.outputSubject.send(.ALARM(info))
                }
                else {
                    throw CellyError(
                        message: "Unable to parse: \(rawString) combined from buffer \(buffer)"
                    )
                }
            }
            catch {
                self.outputSubject.send(.outputError(info, error))
            }
        }
    }

    private func outputError(from code: String?) -> BluetoothControllerError {
        switch code {
        case "1":
            return .expectedCommandLetter
        case "2":
            return .badNumberFormat
        case "3":
            return .invalidStatement
        case "15":
            return .travelExceeded
        default:
            return .unknown(code)
        }
    }

    private func status(
        from rawStringParts: [String],
        with info: BluetoothControllerOutputInfo
    ) throws -> BluetoothControllerStatus {
        guard rawStringParts.count > 1
        else { throw CellyError(message: "Invalid parts count in status") }
        let statusString = self.statusString(from: rawStringParts[0])
        let position = try self.position(from: rawStringParts[1])
        switch statusString {
        case BluetoothControllerOutputSymbols.idle:
            return .idle(info, position)
        case BluetoothControllerOutputSymbols.jog:
            return .jog(info, position)
        case BluetoothControllerOutputSymbols.alarm:
            return .alarm(info, position)
        case BluetoothControllerOutputSymbols.home:
            return .home(info, position)
        default:
            throw CellyError(message: "Invalid status: \"\(statusString)\"")
        }
    }

    private func statusString(from rawString: String) -> String {
        var rawString = rawString
        if
            let startRange = rawString
                .range(of: BluetoothControllerOutputSymbols.start)
        {
            rawString.removeSubrange(rawString.startIndex..<startRange.upperBound)
        }
        return rawString
    }

    private func messageString(from rawString: String) -> String {
        var rawString = rawString
        if
            let startRange = rawString
                .range(of: BluetoothControllerOutputSymbols.msg)
        {
            rawString.removeSubrange(rawString.startIndex..<startRange.upperBound)
        }
        return rawString
    }

    private func position(from rawString: String) throws -> BluetoothControllerPosition {
        let positionKeyValueList = rawString
            .split(separator: BluetoothControllerOutputSymbols.positionValueSeparator)
            .map { String($0) }
        guard positionKeyValueList.count == 2 else {
            throw CellyError(
                message: "Invalid position format: \(positionKeyValueList)",
                status: -1
            )
        }
        let coordinates = positionKeyValueList[1]
            .split(separator: BluetoothControllerOutputSymbols.positionCoordinatesSeparator)
            .compactMap { Float($0) }
        guard coordinates.count == 3 else {
            throw CellyError(message: "Invalid coordinates format: \(coordinates)", status: -1)
        }
        return BluetoothControllerPosition(x: coordinates[0], y: coordinates[1], z: coordinates[2])
    }
}

private enum BluetoothControllerOutputSymbols {
    static let lineBreak = "\n"
    static let `return` = "\r"
    static let lineBreakSubstitutionSymbol = "<br>"
    static let separator = Character("|")
    static let start = "<"
    // Position
    static let positionValueSeparator = Character(":")
    static let positionCoordinatesSeparator = Character(",")
    // Error
    static let errorCodeSeparator = Character(":")
    // Message
    static let messageSeparator = Character(":")
    // Status
    static let idle = "Idle"
    static let jog = "Jog"
    static let alarm = "Alarm"
    static let ALARM = "ALARM"
    static let homeMsg = "'$H\'|\'$X\' to unlock"
    static let home = "Home"
    static let ok = "ok"
    static let error = "error"
    static let unlocked = "unlocked"
    static let msg = "MSG"
    static let intro = "Grbl"
}
