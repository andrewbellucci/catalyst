import Foundation

enum CalculatorError: Error {
    case invalidExpression
    case divisionByZero
}

struct Calculator {
    func evaluate(_ input: String) throws -> Double {
        var normalized = input.lowercased()
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "multiplied by", with: "*")
            .replacingOccurrences(of: "divided by", with: "/")
            .replacingOccurrences(of: "to the power of", with: "^")
            .replacingOccurrences(of: "plus", with: "+")
            .replacingOccurrences(of: "minus", with: "-")
            .replacingOccurrences(of: "times", with: "*")
            .replacingOccurrences(of: "over", with: "/")

        normalized = normalized.replacingOccurrences(
            of: #"(\d+(?:\.\d+)?)\s*percent\s+of\s+(\d+(?:\.\d+)?)"#,
            with: "($1/100)*$2",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"square root of\s+(\d+(?:\.\d+)?)"#,
            with: "sqrt($1)",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(of: "what is", with: "")
        normalized = normalized.replacingOccurrences(of: "calculate", with: "")
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "?=")))

        var parser = Parser(normalized)
        let result = try parser.parse()
        guard result.isFinite else { throw CalculatorError.invalidExpression }
        return result
    }

    func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

private struct Parser {
    private let characters: [Character]
    private var position = 0

    init(_ input: String) {
        characters = Array(input.filter { !$0.isWhitespace })
    }

    mutating func parse() throws -> Double {
        guard !characters.isEmpty else { throw CalculatorError.invalidExpression }
        let result = try expression()
        guard position == characters.count else { throw CalculatorError.invalidExpression }
        return result
    }

    private mutating func expression() throws -> Double {
        var value = try term()
        while let operation = peek(), operation == "+" || operation == "-" {
            position += 1
            let rhs = try term()
            value = operation == "+" ? value + rhs : value - rhs
        }
        return value
    }

    private mutating func term() throws -> Double {
        var value = try power()
        while let operation = peek(), operation == "*" || operation == "/" {
            position += 1
            let rhs = try power()
            if operation == "/" {
                guard rhs != 0 else { throw CalculatorError.divisionByZero }
                value /= rhs
            } else {
                value *= rhs
            }
        }
        return value
    }

    private mutating func power() throws -> Double {
        var value = try unary()
        if peek() == "^" {
            position += 1
            value = Foundation.pow(value, try power())
        }
        return value
    }

    private mutating func unary() throws -> Double {
        if peek() == "-" {
            position += 1
            return -(try unary())
        }
        if matches("sqrt(") {
            let value = try expression()
            try consume(")")
            return Foundation.sqrt(value)
        }
        return try primary()
    }

    private mutating func primary() throws -> Double {
        if peek() == "(" {
            position += 1
            let value = try expression()
            try consume(")")
            return value
        }

        let start = position
        while let character = peek(), character.isNumber || character == "." {
            position += 1
        }
        guard start != position, let value = Double(String(characters[start..<position])) else {
            throw CalculatorError.invalidExpression
        }
        return value
    }

    private func peek() -> Character? {
        position < characters.count ? characters[position] : nil
    }

    private mutating func matches(_ token: String) -> Bool {
        let tokenCharacters = Array(token)
        guard position + tokenCharacters.count <= characters.count else { return false }
        if Array(characters[position..<(position + tokenCharacters.count)]) == tokenCharacters {
            position += tokenCharacters.count
            return true
        }
        return false
    }

    private mutating func consume(_ expected: Character) throws {
        guard peek() == expected else { throw CalculatorError.invalidExpression }
        position += 1
    }
}
