import Foundation
import Testing
@testable import RuleRef

struct NewGameFailureTests {

    // MARK: Scenario 1

    @Test func sheetFailureMappingIsUnchanged() {
        #expect(NewGameFailure(error: GameNameError.blank) == .blank)
        #expect(NewGameFailure(error: GameNameError.duplicate) == .duplicate)
        #expect(NewGameFailure(error: CocoaError(.fileWriteUnknown)) == .saveFailed)
    }
}
