import Foundation

public struct TextCleaningService {
    public init() {}

    public func clean(_ input: String) -> String {
        var result = input
        result = removeCitations(from: result)
        result = normalizeLineBreaks(in: result)
        result = compressWhitespace(in: result)
        result = normalizeWidth(in: result)
        result = normalizeChinesePunctuation(in: result)
        result = fixCJKSpacing(in: result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func removeCitations(from text: String) -> String {
        var result = text
        let patterns = [
            #"\[\s*\d+\s*(?:-\s*\d+\s*)?\]"#,
            #"\(\s*\d+\s*(?:-\s*\d+\s*)?(?:,\s*\d+\s*(?:-\s*\d+\s*)?)*\)"#
        ]

        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        return result
    }

    private func normalizeLineBreaks(in text: String) -> String {
        text.replacingOccurrences(of: #"\r\n|\n|\r"#, with: " ", options: .regularExpression)
    }

    private func compressWhitespace(in text: String) -> String {
        var result = text.replacingOccurrences(of: "\t", with: " ")
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
            ",": "，", ".": "。", ";": "；", ":": "：", "?": "？", "!": "！",
            "(": "（", ")": "）", "[": "【", "]": "】"
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

    private func fixCJKSpacing(in text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: #"\s*([，。；：？！、）】》」』])\s*"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\s*([（【《「『])\s*"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"(?<=[\p{Han}])\s+(?=[\p{Han}])"#, with: "", options: .regularExpression)
        result = removeUppercaseAcronymSpacingBeforeCJK(in: result)
        return result
    }

    private func removeUppercaseAcronymSpacingBeforeCJK(in text: String) -> String {
        let chars = Array(text)
        var output = String()
        var index = 0

        while index < chars.count {
            let current = chars[index]
            if current.isWhitespace,
               let previous = output.last,
               isUppercaseASCIIOrDigit(previous),
               index + 1 < chars.count,
               containsCJK(chars[index + 1]) {
                index += 1
                continue
            }

            output.append(current)
            index += 1
        }

        return output
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

    private func isUppercaseASCIIOrDigit(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        return (0x30...0x39).contains(scalar.value) || (0x41...0x5A).contains(scalar.value)
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
