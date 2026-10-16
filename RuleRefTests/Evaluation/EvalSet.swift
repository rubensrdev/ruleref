/// The eval set file (`Fixtures/taifa-3.0-eval.json`), decoded with the file's field names.
nonisolated struct EvalSet: Codable, Sendable {
    let fixture: String
    let fixtureSHA256: String
    let scoring: String
    let questions: [Question]

    nonisolated enum QuestionType: String, Codable, Sendable {
        case normal, table, falsePremise, absent
    }

    nonisolated enum Overlap: String, Codable, Sendable {
        case low, high
    }

    nonisolated struct Question: Codable, Sendable {
        let id: String
        /// The user's wording; decoded, never searched.
        let question: String
        /// Searched exactly as written.
        let query: String
        let type: QuestionType
        let overlap: Overlap
        /// 1-based page; `nil` only for `absent`.
        let expectedPage: Int?
        let fragment: String?
        let note: String?
    }

    nonisolated enum ValidationError: Error, Equatable, CustomStringConvertible {
        case repeatedID(id: String)
        case missingExpectedPage(id: String)
        case expectedPageOnAbsent(id: String)
        case expectedPageOutOfRange(id: String, page: Int, pageCount: Int)
        case blankQuery(id: String)

        var description: String {
            switch self {
            case let .repeatedID(id):
                "\(id): the id is repeated"
            case let .missingExpectedPage(id):
                "\(id): expectedPage is null for a type other than absent"
            case let .expectedPageOnAbsent(id):
                "\(id): expectedPage is not null for an absent question"
            case let .expectedPageOutOfRange(id, page, pageCount):
                "\(id): expectedPage \(page) is outside 1...\(pageCount)"
            case let .blankQuery(id):
                "\(id): the query has no non-whitespace character"
            }
        }
    }

    /// Throws on the first question that breaks a rule, in file order.
    func validate(pageCount: Int) throws {
        var seen: Set<String> = []
        for question in questions {
            guard seen.insert(question.id).inserted else {
                throw ValidationError.repeatedID(id: question.id)
            }
            switch (question.type, question.expectedPage) {
            case (.absent, nil):
                break
            case (.absent, .some):
                throw ValidationError.expectedPageOnAbsent(id: question.id)
            case (_, nil):
                throw ValidationError.missingExpectedPage(id: question.id)
            case let (_, .some(page)):
                guard page >= 1, page <= pageCount else {
                    throw ValidationError.expectedPageOutOfRange(id: question.id, page: page, pageCount: pageCount)
                }
            }
            guard question.query.contains(where: { !$0.isWhitespace }) else {
                throw ValidationError.blankQuery(id: question.id)
            }
        }
    }
}
