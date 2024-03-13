import CellyCore
import Foundation

public class ABProgress: Progress {
    public var status: String? {
        set {
            self.atomicStatus.mutate {
                $0 = newValue
                self.statusChange?(newValue)
            }
        }
        get {
            self.atomicStatus.value
        }
    }

    private(set) var atomicStatus: Atomic<String?>
    public var statusChange: ((String?) -> Void)?

    public init(
        status: String? = nil,
        totalUnitCount unitCount: Int64,
        parent: Progress,
        pendingUnitCount portionOfParentTotalUnitCount: Int64
    ) {
        self.atomicStatus = Atomic(status)
        self.statusChange = nil
        super.init(parent: nil, userInfo: nil)
        self.totalUnitCount = unitCount
        parent.addChild(self, withPendingUnitCount: portionOfParentTotalUnitCount)
    }

    public init(
        status: String? = nil,
        totalUnitCount unitCount: Int64
    ) {
        self.atomicStatus = Atomic(status)
        self.statusChange = nil
        super.init(parent: nil, userInfo: nil)
        self.totalUnitCount = unitCount
    }
}
