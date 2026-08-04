import Testing
@testable import Catalyst

@Suite("Natural language calculator")
struct CalculatorTests {
    let calculator = Calculator()

    @Test func arithmeticWords() throws {
        #expect(try calculator.evaluate("12 plus 7 times 3") == 33)
    }

    @Test func percentage() throws {
        #expect(try calculator.evaluate("20 percent of 85") == 17)
    }

    @Test func squareRoot() throws {
        #expect(try calculator.evaluate("square root of 81") == 9)
    }

    @Test func groupingAndPower() throws {
        #expect(try calculator.evaluate("(2 + 3) ^ 2") == 25)
    }
}
