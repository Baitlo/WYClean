import Foundation

struct CleaningOptions {
    var removeLineBreaks: Bool = true
}

public struct TextCleaningService {
    private let options: CleaningOptions

    init(options: CleaningOptions = CleaningOptions()) {
        self.options = options
    }

    public func clean(_ input: String) -> String {
        var result = input
        result = removeCitations(from: result)
        result = normalizeWidth(in: result)
        if options.removeLineBreaks {
            result = normalizeLineBreaks(in: result)
        }
        result = compressWhitespace(in: result)
        result = normalizeChinesePunctuation(in: result)
        result = removeSpacesBetweenNonEnglishCharacters(in: result)
        result = cleanupPunctuationSpacing(in: result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removeCitations(from text: String) -> String {
        let patterns = [
            #"\[\s*\d+\s*(?:[-–]\s*\d+\s*)?\]"#,
            #"\[\s*\d+(?:\s*,\s*\d+)+\s*\]"#,
            #"[（(]\s*\d+(?:\s*[-–]\s*\d+)?(?:\s*[,，]\s*\d+(?:\s*[-–]\s*\d+)?)*\s*[）)]"#
        ]

        return patterns.reduce(text) { partial, pattern in
            partial.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
    }

    private func normalizeLineBreaks(in text: String) -> String {
        text.replacingOccurrences(of: #"\r\n|\n|\r"#, with: " ", options: .regularExpression)
    }

    private func compressWhitespace(in text: String) -> String {
        var result = text.replacingOccurrences(of: "\t", with: " ")
        result = result.replacingOccurrences(of: "\u{3000}", with: " ")
        result = result.replacingOccurrences(of: #"[ ]{2,}"#, with: " ", options: .regularExpression)
        return result
    }

    private func normalizeWidth(in text: String) -> String {
        let normalizedScalars = text.unicodeScalars.map { scalar -> UnicodeScalar in
            switch scalar.value {
            case 0xFF10...0xFF19, 0xFF21...0xFF3A, 0xFF41...0xFF5A:
                return UnicodeScalar(scalar.value - 0xFEE0) ?? scalar
            default:
                return scalar
            }
        }
        return String(String.UnicodeScalarView(normalizedScalars))
    }

    private func normalizeChinesePunctuation(in text: String) -> String {
        let punctuationMap: [Character: Character] = [
            ",": "，", ".": "。", ";": "；", ":": "：", "?": "？", "!": "！"
        ]

        let chars = Array(text)
        var output = String()

        for index in chars.indices {
            let current = chars[index]
            guard let converted = punctuationMap[current] else {
                output.append(current)
                continue
            }

            let previous = nearestNonWhitespaceCharacter(in: chars, from: index, direction: -1)
            let next = nearestNonWhitespaceCharacter(in: chars, from: index, direction: 1)
            if containsCJK(previous) || containsCJK(next) {
                output.append(converted)
            } else {
                output.append(current)
            }
        }

        return output
    }

    private func removeSpacesBetweenNonEnglishCharacters(in text: String) -> String {
        text.replacingOccurrences(of: #"(?<=[^A-Za-z\s])\s+(?=[^A-Za-z\s])"#, with: "", options: .regularExpression)
    }

    private func cleanupPunctuationSpacing(in text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: #"\s*([，。；：？！、])\s*"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return result
    }

    private func nearestNonWhitespaceCharacter(in chars: [Character], from index: Int, direction: Int) -> Character? {
        var cursor = index + direction
        while chars.indices.contains(cursor) {
            if !chars[cursor].isWhitespace {
                return chars[cursor]
            }
            cursor += direction
        }
        return nil
    }

    private func containsCJK(_ character: Character?) -> Bool {
        guard let scalar = character?.unicodeScalars.first else { return false }
        return (0x4E00...0x9FFF).contains(scalar.value)
    }
}

private extension Character {
    var isWhitespace: Bool {
        unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }
}
