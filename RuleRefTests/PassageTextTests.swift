import Testing
@testable import RuleRef

struct PassageTextTests {

    nonisolated private static let lineBreakHyphenBeforeLowercaseCases: [(String, String)] = [
        ("cons-\ntruir", "construir"),
        ("con\u{2010}\nstruir", "construir"),
    ]

    nonisolated private static let lineBreakHyphenBeforeAnythingElseCases: [(String, String)] = [
        ("Norte-\nSur", "Norte-Sur"),
        ("nivel-\n2", "nivel-2"),
    ]

    nonisolated private static let softHyphenCases: [(String, String)] = [
        ("cons\u{00AD}\ntruir", "construir"),
        ("a\u{00AD}b", "ab"),
        ("\u{00AD}", ""),
    ]

    nonisolated private static let notAWordHyphenCases: [(String, String)] = [
        ("x -\ny", "x - y"),
        ("fin \u{2014}\nsigue", "fin \u{2014} sigue"),
        ("fin\u{2014}\nsigue", "fin\u{2014} sigue"),
    ]

    nonisolated private static let whitespaceCases: [(String, String)] = [
        ("  uno \n\t dos\u{00A0}tres  ", "uno dos tres"),
    ]

    nonisolated private static let acceptedWrongJoinCases: [(String, String)] = [
        ("franco-\nalemán", "francoalemán"),
    ]

    /// Every input of scenarios 2-6 and 8.
    nonisolated private static let idempotenceInputs: [String] = {
        let tables: [[(String, String)]] = [
            lineBreakHyphenBeforeLowercaseCases, lineBreakHyphenBeforeAnythingElseCases, softHyphenCases,
            notAWordHyphenCases, whitespaceCases, acceptedWrongJoinCases,
        ]
        return tables.flatMap { $0.map(\.0) }
    }()

    // MARK: Scenario 2

    @Test(arguments: lineBreakHyphenBeforeLowercaseCases)
    func lineBreakHyphenBeforeALowercaseLetter(input: String, expected: String) {
        #expect(PassageText.normalized(input) == expected)
    }

    // MARK: Scenario 3

    @Test(arguments: lineBreakHyphenBeforeAnythingElseCases)
    func lineBreakHyphenBeforeAnythingElse(input: String, expected: String) {
        #expect(PassageText.normalized(input) == expected)
    }

    // MARK: Scenario 4

    @Test(arguments: softHyphenCases)
    func softHyphen(input: String, expected: String) {
        #expect(PassageText.normalized(input) == expected)
    }

    // MARK: Scenario 5

    @Test(arguments: notAWordHyphenCases)
    func notAWordHyphen(input: String, expected: String) {
        #expect(PassageText.normalized(input) == expected)
    }

    // MARK: Scenario 6

    @Test(arguments: whitespaceCases)
    func whitespace(input: String, expected: String) {
        #expect(PassageText.normalized(input) == expected)
    }

    // MARK: Scenario 7

    @Test(arguments: idempotenceInputs)
    func idempotence(input: String) {
        let once = PassageText.normalized(input)
        #expect(PassageText.normalized(once) == once)
    }

    // MARK: Scenario 8

    @Test(arguments: acceptedWrongJoinCases)
    func acceptedWrongJoinOfAGenuineCompound(input: String, expected: String) {
        #expect(PassageText.normalized(input) == expected)
    }
}
