import Foundation
import HubCore
import Testing

@testable import CompanionKit

// Temporary: dumps the distinct part sets for building the placement table. Not for merge.
@Suite struct PlacementProbeTests {
    @Test func dump() throws {
        guard let path = ProcessInfo.processInfo.environment["PLACEMENT_DUMP"] else { return }
        var seen: [String: String] = [:]
        for state in PlacementPoses.haku {
            let key =
                "H " + RunnerFigure.parts(for: state.mode, pose: state.pose).map(\.rawValue).joined(separator: ",")
            if seen[key] == nil { seen[key] = state.label }
        }
        for state in PlacementPoses.kuro {
            let key = "K " + KuroFigure.parts(for: state.look, pose: state.pose).map(\.rawValue).joined(separator: ",")
            if seen[key] == nil { seen[key] = state.label }
        }
        let lines = seen.map { "\($0.value)\t\($0.key)" }.sorted()
        try lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
        print("placement dump: \(lines.count) sets")
    }
}
