// Prints the window number of the first normal window owned by the process id given as the argument.
import CoreGraphics

let pid = Int(CommandLine.arguments[1]) ?? -1
let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows {
    guard window[kCGWindowOwnerPID as String] as? Int == pid, window[kCGWindowLayer as String] as? Int == 0 else {
        continue
    }
    print(window[kCGWindowNumber as String] as? Int ?? 0)
    break
}
