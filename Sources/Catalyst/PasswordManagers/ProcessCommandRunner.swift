import Foundation

enum ProcessCommandRunner {
    static func run(executable: URL, arguments: [String]) throws -> Data {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()

        // Drain stdout before waiting so large password-manager catalogs cannot fill the pipe
        // and deadlock the child process.
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let detail = String(data: errorOutput, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw PasswordManagerError.commandFailed(
                detail?.isEmpty == false ? detail! : "Password manager command failed."
            )
        }
        return output
    }
}
