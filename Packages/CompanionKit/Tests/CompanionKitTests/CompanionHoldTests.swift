import Testing

@testable import CompanionKit

@MainActor
@Suite struct CompanionHoldTests {
    @Test func withoutAHandlerKuroStillReacts() {
        var reacted = false
        CompanionHold.release(nil) { reacted = true }
        #expect(reacted)
    }

    @Test func aHandlerReplacesTheReaction() {
        final class Count: @unchecked Sendable { var value = 0 }
        let held = Count()
        var reacted = false
        CompanionHold.release(CompanionHold { held.value += 1 }) { reacted = true }
        #expect(held.value == 1)
        #expect(!reacted)
    }
}
