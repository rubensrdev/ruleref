import Foundation
@testable import RuleRef

/// What text search finds for each eval question, scored by page. It measures; it never judges a score.
nonisolated struct BaselineReport: Codable, Sendable {
    nonisolated struct Score: Codable, Sendable, Equatable {
        let count: Int
        let total: Int
        /// `count / total`; 0 when `total` is 0.
        let rate: Double

        init(count: Int, total: Int) {
            self.count = count
            self.total = total
            rate = total == 0 ? 0 : Double(count) / Double(total)
        }
    }

    nonisolated struct Summary: Codable, Sendable, Equatable {
        let hitAt1: Score
        let hitAt3: Score
        let noMatchAccuracy: Score
        let passageCount: Int
        let fixtureSHA256: String
        let iOSVersion: String
    }

    nonisolated struct Row: Codable, Sendable, Equatable {
        let id: String
        let type: EvalSet.QuestionType
        let overlap: EvalSet.Overlap
        let expectedPage: Int?
        /// Pages of the first three matches in `SearchIndex` order, duplicates kept.
        let topPages: [Int]
        /// Only for questions with an expected page.
        let hitAt1: Bool?
        let hitAt3: Bool?
        /// Only for `absent` questions.
        let noMatchCorrect: Bool?

        init(question: EvalSet.Question, state: SearchState) {
            id = question.id
            type = question.type
            overlap = question.overlap
            expectedPage = question.expectedPage
            topPages = state.matches.prefix(3).map(\.pageNumber)
            if let page = question.expectedPage {
                hitAt1 = topPages.first == page
                hitAt3 = topPages.contains(page)
                noMatchCorrect = nil
            } else {
                hitAt1 = nil
                hitAt3 = nil
                noMatchCorrect = state == .noMatch
            }
        }
    }

    let summary: Summary
    let rows: [Row]

    init(rows: [Row], passageCount: Int, fixtureSHA256: String, iOSVersion: String) {
        let pageRows = rows.filter { $0.expectedPage != nil }
        let absentRows = rows.filter { $0.type == .absent }
        summary = Summary(
            hitAt1: Score(count: pageRows.filter { $0.hitAt1 == true }.count, total: pageRows.count),
            hitAt3: Score(count: pageRows.filter { $0.hitAt3 == true }.count, total: pageRows.count),
            noMatchAccuracy: Score(count: absentRows.filter { $0.noMatchCorrect == true }.count, total: absentRows.count),
            passageCount: passageCount,
            fixtureSHA256: fixtureSHA256,
            iOSVersion: iOSVersion
        )
        self.rows = rows
    }

    func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}
