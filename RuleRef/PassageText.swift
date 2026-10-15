/// Turns a segment's raw text (lines joined by "\n") into the prose stored as a passage's text.
/// Passes run in order: line-break hyphens, soft hyphens, whitespace; each reads the previous one's output.
nonisolated enum PassageText {
    static func normalized(_ text: String) -> String {
        collapsingWhitespace(removingSoftHyphens(joiningLineBreakHyphens(text)))
    }

    /// U+2011, U+2013, U+2014 and U+2212 are deliberately not hyphens.
    private static func isHyphen(_ character: Character) -> Bool {
        character == "\u{002D}" || character == "\u{2010}"
    }

    /// Rule a: a letter, a hyphen and "\n" lose the hyphen and the "\n" before a lowercase letter,
    /// and only the "\n" before anything else.
    private static func joiningLineBreakHyphens(_ text: String) -> String {
        let characters = Array(text)
        var result: [Character] = []
        result.reserveCapacity(characters.count)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if isHyphen(character), index > 0, characters[index - 1].isLetter,
               index + 1 < characters.count, characters[index + 1] == "\n" {
                let continuesLowercase = index + 2 < characters.count && characters[index + 2].isLowercase
                if !continuesLowercase {
                    result.append(character)
                }
                index += 2
                continue
            }
            result.append(character)
            index += 1
        }
        return String(result)
    }

    /// Rule b, on scalars because the clustering of U+00AD into Characters is not relied on.
    private static func removingSoftHyphens(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var result = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            if scalars[index] == "\u{00AD}" {
                let followedByLineBreak = index + 1 < scalars.count && scalars[index + 1] == "\u{000A}"
                index += followedByLineBreak ? 2 : 1
                continue
            }
            result.append(scalars[index])
            index += 1
        }
        return String(result)
    }

    /// Rule c: each run of whitespace becomes one space, with none at either end.
    private static func collapsingWhitespace(_ text: String) -> String {
        var result = ""
        var pendingSpace = false
        for character in text {
            if character.isWhitespace {
                pendingSpace = true
                continue
            }
            if pendingSpace, !result.isEmpty {
                result.append(" ")
            }
            pendingSpace = false
            result.append(character)
        }
        return result
    }
}
