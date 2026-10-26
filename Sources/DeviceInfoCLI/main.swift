#if os(macOS)
import AppleDeviceInfo
import Darwin
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--help"] || arguments == ["-h"] {
    print("Usage: device-info [--pretty]\nPrint current Mac model and computer name as JSON.")
} else if arguments.isEmpty || arguments == ["--pretty"] {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = arguments.isEmpty ? [.sortedKeys] : [.sortedKeys, .prettyPrinted]
        var output = try encoder.encode(AppleDevice.current())
        output.append(0x0A)
        try FileHandle.standardOutput.write(contentsOf: output)
    } catch {
        FileHandle.standardError.write(Data("device-info: could not write JSON: \(error)\n".utf8))
        exit(1)
    }
} else {
    FileHandle.standardError.write(Data("device-info: unsupported arguments; use --help\n".utf8))
    exit(64)
}
#endif
