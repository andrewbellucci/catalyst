import AppKit
import CoreServices
import Foundation

struct DictionaryLookup {
    func define(_ term: String) -> String? {
        let value = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let range = CFRange(location: 0, length: value.utf16.count)
        return DCSCopyTextDefinition(nil, value as CFString, range)?.takeRetainedValue() as String?
    }

    func formattedDefinition(_ term: String) -> NSAttributedString? {
        guard let definition = define(term) else { return nil }
        let partsOfSpeech = "adjective|adverb|noun|verb|pronoun|preposition|conjunction|determiner|exclamation"
        guard let partRange = definition.range(
            of: "\\b(\(partsOfSpeech))\\b",
            options: .regularExpression
        ) else {
            return NSAttributedString(string: definition)
        }

        let heading = String(definition[..<partRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        var remainder = String(definition[partRange.lowerBound...])
        remainder = remainder.replacingOccurrences(of: " DERIVATIVES ", with: "\n\nDERIVATIVES\n")
        remainder = remainder.replacingOccurrences(of: " ORIGIN ", with: "\n\nORIGIN\n")
        remainder = remainder.replacingOccurrences(
            of: " (?=\\S+ \\|[^|]+\\| (?:adverb|noun|verb|adjective)(?: |$))",
            with: "\n",
            options: .regularExpression
        )

        let output = "\(heading)\n\(remainder)"
        let attributed = NSMutableAttributedString(string: output)
        let fullRange = NSRange(location: 0, length: attributed.length)
        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.lineSpacing = 5
        bodyParagraph.paragraphSpacing = 7
        attributed.addAttributes([
            .font: NSFont(name: "New York", size: 18) ?? .systemFont(ofSize: 18),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: bodyParagraph
        ], range: fullRange)

        let headingRange = (output as NSString).range(of: heading)
        let firstSpace = (heading as NSString).range(of: " ")
        let wordLength = firstSpace.location == NSNotFound ? headingRange.length : firstSpace.location
        attributed.addAttributes([
            .font: NSFont(name: "New York Bold", size: 27) ?? .boldSystemFont(ofSize: 27)
        ], range: NSRange(location: headingRange.location, length: wordLength))
        if wordLength < headingRange.length {
            attributed.addAttributes([
                .font: NSFont.systemFont(ofSize: 19, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ], range: NSRange(
                location: headingRange.location + wordLength,
                length: headingRange.length - wordLength
            ))
        }

        styleMatches("(?m)^(\(partsOfSpeech))\\b", in: output, attributed: attributed) {
            [.font: NSFont.systemFont(ofSize: 16, weight: .semibold),
             .foregroundColor: NSColor.secondaryLabelColor]
        }
        styleMatches("(?m)^(DERIVATIVES|ORIGIN)$", in: output, attributed: attributed) {
            [.font: NSFont.systemFont(ofSize: 14, weight: .bold),
             .foregroundColor: NSColor.secondaryLabelColor]
        }
        styleMatches("(?m)^(\\S+)(?= \\|[^|]+\\| (?:adverb|noun|verb|adjective))", in: output, attributed: attributed) {
            [.font: NSFont(name: "New York Bold", size: 18) ?? .boldSystemFont(ofSize: 18)]
        }
        styleMatches("(\\|[^|]+\\|)", in: output, attributed: attributed) {
            [.foregroundColor: NSColor.secondaryLabelColor]
        }
        styleMatches(": ([^.]+\\.)", in: output, attributed: attributed) {
            [.font: NSFont(name: "New York Italic", size: 18)
                ?? NSFontManager.shared.convert(.systemFont(ofSize: 18), toHaveTrait: .italicFontMask),
             .foregroundColor: NSColor.secondaryLabelColor]
        }
        return attributed
    }

    private func styleMatches(
        _ pattern: String,
        in value: String,
        attributed: NSMutableAttributedString,
        attributes: () -> [NSAttributedString.Key: Any]
    ) {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(location: 0, length: (value as NSString).length)
        for match in expression.matches(in: value, range: range) {
            attributed.addAttributes(attributes(), range: match.range(at: 1))
        }
    }
}
