import Foundation

public class StatisticLogger {
    public enum LogKind: String, Comparable {
        case slideScan
        case translation
        case counter
        case camera
        case memory
        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public typealias ValueType = Int

    private var logs: [LogKind: [ValueType]]
    private var ready: Bool

    public init() {
        self.logs = [
            .slideScan: [ValueType](),
            .translation: [ValueType](),
            .counter: [ValueType](),
            .memory: [ValueType](),
            .camera: [ValueType](),
        ]
        self.ready = true
    }

    public func stop() {
        self.ready = false
    }

    public func log(_ value: ValueType, kind: LogKind) {
        guard self.ready else {
            return
        }
        self.logs[kind]?.append(value)
    }

    // MARK: Private

    private func mean(_ kind: LogKind) -> ValueType {
        self.logs[kind]?.median ?? 0
    }

    private func avg(_ kind: LogKind) -> ValueType {
        self.logs[kind]?.average ?? 0
    }

    private func min(_ kind: LogKind) -> ValueType {
        self.logs[kind]?.min(by: { $0 < $1 }) ?? 0
    }

    private func max(_ kind: LogKind) -> ValueType {
        self.logs[kind]?.max(by: { $0 < $1 }) ?? 0
    }

    private func stdDev(_ kind: LogKind) -> ValueType {
        self.logs[kind]?.std ?? 0
    }
}

public struct PerfomanceRecord: Encodable {
    let min: Int
    let max: Int
    let avg: Int
    let mean: Int
    let stdDev: Int
}

public struct PerfomanceReport: Encodable {
    let slideScan: PerfomanceRecord
    let translation: PerfomanceRecord
    let counter: PerfomanceRecord
    let camera: PerfomanceRecord
    let memory: PerfomanceRecord
}

public protocol PefomanceReporter {
    func pefomanceReport() -> PerfomanceReport
}

extension StatisticLogger: PefomanceReporter {
    public func pefomanceReport() -> PerfomanceReport {
        .init(
            slideScan: self.perfomanceRecord(logKind: .slideScan),
            translation: self.perfomanceRecord(logKind: .translation),
            counter: self.perfomanceRecord(logKind: .counter),
            camera: self.perfomanceRecord(logKind: .camera),
            memory: self.perfomanceRecord(logKind: .memory)
        )
    }

    private func perfomanceRecord(logKind: LogKind) -> PerfomanceRecord {
        .init(
            min: self.min(logKind),
            max: self.max(logKind),
            avg: self.avg(logKind),
            mean: self.mean(logKind),
            stdDev: self.stdDev(logKind)
        )
    }
}
