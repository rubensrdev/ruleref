import Testing
@testable import RuleRef

struct GameNameTests {

    @Test(arguments: ["", "   ", "\n\t "])
    func blankNameThrowsBlank(raw: String) {
        #expect(throws: GameNameError.blank) {
            try GameName(raw)
        }
    }

    @Test func valueIsTrimmed() throws {
        let name = try GameName("  Taifa  ")
        #expect(name.value == "Taifa")
    }

    @Test func surroundingSpacesAndCaseGiveTheSameKey() throws {
        #expect(try GameName("Taifa").key == GameName(" taifa ").key)
    }

    @Test func diacriticsGiveTheSameKey() throws {
        #expect(try GameName("Catán").key == GameName("catan").key)
    }

    @Test func differentNamesGiveDifferentKeys() throws {
        #expect(try GameName("Taifa").key != GameName("Catan").key)
    }

}
