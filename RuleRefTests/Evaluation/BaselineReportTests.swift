import CoreGraphics
import Foundation
import Testing
@testable import RuleRef

struct BaselineReportTests {

    // MARK: Hand-built inputs

    private static let rulebookID = RulebookID(bytes: Data("eval rulebook".utf8))

    /// One match per page, in the given order, as `SearchIndex` would rank them.
    private static func matches(onPages pages: [Int]) -> SearchState {
        .matches(pages.enumerated().map { ordinal, page in
            Match(
                passage: ExtractedPassage(
                    text: "passage \(ordinal)",
                    ordinal: ordinal,
                    locator: .pdf(rulebookID: rulebookID, pageIndex: page - 1, bounds: CGRect(x: 72, y: 600, width: 400, height: 24))
                ),
                occurrences: pages.count - ordinal
            )
        })
    }

    private static func question(id: String = "q01", type: EvalSet.QuestionType, expectedPage: Int?) -> EvalSet.Question {
        EvalSet.Question(
            id: id, question: "¿Pregunta?", query: "consulta", type: type, overlap: .low,
            expectedPage: expectedPage, fragment: nil, note: nil
        )
    }

    // MARK: Scenario 3

    @Test(arguments: [EvalSet.QuestionType.normal, .table, .falsePremise])
    func aPageQuestionWithMatches(type: EvalSet.QuestionType) {
        let row = BaselineReport.Row(question: Self.question(type: type, expectedPage: 5), state: Self.matches(onPages: [3, 5, 5, 7]))
        #expect(row.topPages == [3, 5, 5])
        #expect(row.hitAt1 == false)
        #expect(row.hitAt3 == true)
        #expect(row.noMatchCorrect == nil)
        #expect(row.expectedPage == 5)
    }

    @Test(arguments: [EvalSet.QuestionType.normal, .table, .falsePremise])
    func aPageQuestionWithNoMatchIsAMiss(type: EvalSet.QuestionType) {
        let row = BaselineReport.Row(question: Self.question(type: type, expectedPage: 5), state: .noMatch)
        #expect(row.topPages == [])
        #expect(row.hitAt1 == false)
        #expect(row.hitAt3 == false)
        #expect(row.noMatchCorrect == nil)
    }

    @Test func aPageQuestionHitAtOne() {
        let row = BaselineReport.Row(question: Self.question(type: .normal, expectedPage: 3), state: Self.matches(onPages: [3, 5]))
        #expect(row.topPages == [3, 5])
        #expect(row.hitAt1 == true)
        #expect(row.hitAt3 == true)
    }

    @Test func aPageQuestionFoundOnlyAfterTheThirdMatchIsAMiss() {
        let row = BaselineReport.Row(question: Self.question(type: .table, expectedPage: 9), state: Self.matches(onPages: [1, 2, 4, 9]))
        #expect(row.topPages == [1, 2, 4])
        #expect(row.hitAt1 == false)
        #expect(row.hitAt3 == false)
    }

    // MARK: Scenario 4

    @Test func anAbsentQuestionWithNoMatchIsCorrect() {
        let row = BaselineReport.Row(question: Self.question(type: .absent, expectedPage: nil), state: .noMatch)
        #expect(row.noMatchCorrect == true)
        #expect(row.topPages == [])
        #expect(row.hitAt1 == nil)
        #expect(row.hitAt3 == nil)
    }

    @Test func anAbsentQuestionWithMatchesIsWrong() {
        let row = BaselineReport.Row(question: Self.question(type: .absent, expectedPage: nil), state: Self.matches(onPages: [8, 2, 2, 6, 1]))
        #expect(row.noMatchCorrect == false)
        #expect(row.topPages == [8, 2, 2])
        #expect(row.hitAt1 == nil)
        #expect(row.hitAt3 == nil)
    }

    // MARK: Summary

    @Test func theSummaryCountsItsRows() {
        let rows = [
            BaselineReport.Row(question: Self.question(id: "q01", type: .normal, expectedPage: 3), state: Self.matches(onPages: [3])),
            BaselineReport.Row(question: Self.question(id: "q02", type: .table, expectedPage: 5), state: Self.matches(onPages: [3, 5])),
            BaselineReport.Row(question: Self.question(id: "q03", type: .falsePremise, expectedPage: 7), state: .noMatch),
            BaselineReport.Row(question: Self.question(id: "q04", type: .absent, expectedPage: nil), state: .noMatch),
            BaselineReport.Row(question: Self.question(id: "q05", type: .absent, expectedPage: nil), state: Self.matches(onPages: [1])),
        ]
        let report = BaselineReport(rows: rows, passageCount: 221, fixtureSHA256: "abc", iOSVersion: "27.0.0")
        #expect(report.summary.hitAt1 == BaselineReport.Score(count: 1, total: 3))
        #expect(report.summary.hitAt3 == BaselineReport.Score(count: 2, total: 3))
        #expect(report.summary.noMatchAccuracy == BaselineReport.Score(count: 1, total: 2))
        #expect(report.summary.noMatchAccuracy.rate == 0.5)
        #expect(report.summary.passageCount == 221)
        #expect(report.summary.fixtureSHA256 == "abc")
        #expect(report.summary.iOSVersion == "27.0.0")
        #expect(report.rows.map(\.id) == ["q01", "q02", "q03", "q04", "q05"])
    }

    @Test func aScoreWithNoRowsHasRateZero() {
        #expect(BaselineReport.Score(count: 0, total: 0).rate == 0)
    }

    // MARK: Scenario 2

    @Test func noMatchForEveryQuestionStillBuildsAReport() throws {
        let rows = [
            BaselineReport.Row(question: Self.question(id: "q01", type: .normal, expectedPage: 3), state: .noMatch),
            BaselineReport.Row(question: Self.question(id: "q02", type: .absent, expectedPage: nil), state: .noMatch),
        ]
        let report = BaselineReport(rows: rows, passageCount: 0, fixtureSHA256: "abc", iOSVersion: "27.0.0")
        #expect(report.summary.hitAt1.count == 0)
        #expect(report.summary.hitAt3.count == 0)
        #expect(try JSONDecoder().decode(BaselineReport.self, from: report.json()).summary == report.summary)
    }

    // MARK: Encoding

    @Test func nilFieldsAreOmittedAndKeysAreSorted() throws {
        let rows = [
            BaselineReport.Row(question: Self.question(id: "q01", type: .absent, expectedPage: nil), state: .noMatch),
        ]
        let json = try #require(String(data: BaselineReport(rows: rows, passageCount: 1, fixtureSHA256: "abc", iOSVersion: "27.0.0").json(), encoding: .utf8))
        #expect(!json.contains("null"))
        #expect(!json.contains("expectedPage"))
        #expect(json.contains("\"noMatchCorrect\" : true"))
        let rowsRange = try #require(json.range(of: "\"rows\""))
        let summaryRange = try #require(json.range(of: "\"summary\""))
        #expect(rowsRange.lowerBound < summaryRange.lowerBound)
    }
}
