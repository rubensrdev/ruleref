import Foundation
import Testing

struct EvalSetTests {

    // MARK: Small eval sets

    /// One question as JSON; `expectedPage` and `type` are raw JSON fragments so malformed values can be written.
    private static func question(
        id: String = "q01",
        query: String = "dado acertado",
        type: String = "\"normal\"",
        overlap: String = "\"low\"",
        expectedPage: String = "2"
    ) -> String {
        """
        {"id": "\(id)", "question": "¿Pregunta?", "query": "\(query)", "type": \(type), "overlap": \(overlap), \
        "expectedPage": \(expectedPage), "fragment": null, "note": null}
        """
    }

    private static func evalSet(_ questions: [String]) -> Data {
        Data("""
        {"fixture": "taifa-3.0.pdf", "fixtureSHA256": "00", "scoring": "page", "questions": [\(questions.joined(separator: ","))]}
        """.utf8)
    }

    private static func decode(_ questions: [String]) throws -> EvalSet {
        try JSONDecoder().decode(EvalSet.self, from: evalSet(questions))
    }

    @Test func aWellFormedSetDecodesAndValidates() throws {
        let set = try Self.decode([
            Self.question(id: "q01"),
            Self.question(id: "q02", type: "\"table\"", overlap: "\"high\"", expectedPage: "16"),
            Self.question(id: "q03", type: "\"falsePremise\"", expectedPage: "1"),
            Self.question(id: "q04", type: "\"absent\"", expectedPage: "null"),
        ])
        try set.validate(pageCount: 16)
        #expect(set.questions.map(\.type) == [.normal, .table, .falsePremise, .absent])
        #expect(set.questions.map(\.expectedPage) == [2, 16, 1, nil])
    }

    // MARK: Scenario 5

    @Test func aRepeatedIDFails() throws {
        let set = try Self.decode([Self.question(id: "q01"), Self.question(id: "q01")])
        #expect(throws: EvalSet.ValidationError.repeatedID(id: "q01")) {
            try set.validate(pageCount: 16)
        }
    }

    @Test func anUnknownTypeFailsDecoding() {
        #expect(throws: DecodingError.self) {
            try Self.decode([Self.question(type: "\"trick\"")])
        }
    }

    @Test func anUnknownOverlapFailsDecoding() {
        #expect(throws: DecodingError.self) {
            try Self.decode([Self.question(overlap: "\"medium\"")])
        }
    }

    @Test(arguments: ["\"normal\"", "\"table\"", "\"falsePremise\""])
    func aNullExpectedPageOnAPageQuestionFails(type: String) throws {
        let set = try Self.decode([Self.question(type: type, expectedPage: "null")])
        #expect(throws: EvalSet.ValidationError.missingExpectedPage(id: "q01")) {
            try set.validate(pageCount: 16)
        }
    }

    @Test func anExpectedPageOnAnAbsentQuestionFails() throws {
        let set = try Self.decode([Self.question(type: "\"absent\"", expectedPage: "3")])
        #expect(throws: EvalSet.ValidationError.expectedPageOnAbsent(id: "q01")) {
            try set.validate(pageCount: 16)
        }
    }

    @Test(arguments: [0, 17, -1])
    func anExpectedPageOutsideThePDFFails(page: Int) throws {
        let set = try Self.decode([Self.question(expectedPage: "\(page)")])
        #expect(throws: EvalSet.ValidationError.expectedPageOutOfRange(id: "q01", page: page, pageCount: 16)) {
            try set.validate(pageCount: 16)
        }
    }

    @Test(arguments: ["", "   ", "\\t\\n "])
    func aBlankQueryFails(query: String) throws {
        let set = try Self.decode([Self.question(query: query)])
        #expect(throws: EvalSet.ValidationError.blankQuery(id: "q01")) {
            try set.validate(pageCount: 16)
        }
    }

    // MARK: The real eval set

    @Test func theTaifaEvalSetValidatesClean() throws {
        let url = try TestFixture.url(forResource: "taifa-3.0-eval", withExtension: "json")
        let set = try JSONDecoder().decode(EvalSet.self, from: Data(contentsOf: url))
        try set.validate(pageCount: 16)
        #expect(set.questions.count == 25)
        #expect(set.questions.filter { $0.expectedPage != nil }.count == 21)
        #expect(set.questions.filter { $0.type == .absent }.count == 4)
    }

    // MARK: Scenario 6: a missing resource

    @Test func aMissingFixtureThrowsNamingTheFile() {
        #expect(throws: TestFixture.MissingResource(fileName: "no-such-fixture.json")) {
            try TestFixture.url(forResource: "no-such-fixture", withExtension: "json")
        }
        let message = String(describing: TestFixture.MissingResource(fileName: "no-such-fixture.json"))
        #expect(message.contains("no-such-fixture.json"))
    }
}
