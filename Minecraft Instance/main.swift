import Foundation
import Cocoa

let fileManager = FileManager.default
let cache = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
let libraryPath = cache.appendingPathComponent("\(Bundle.main.bundleIdentifier!)/libraries")
try? fileManager.createDirectory(at: libraryPath.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)

var givenArgs = CommandLine.arguments

let defaults = UserDefaults.standard

let args: [String]
// see if we're being launched by the launcher
if givenArgs.contains("--accessToken") {
	// copy the libraries so we can reuse them on next launch
	if let index = givenArgs.firstIndex(where: { $0.hasPrefix("-Djava.library.path=") }) {
		let path = URL(fileURLWithPath: givenArgs[index].components(separatedBy: "=").last!)
		try? fileManager.removeItem(at: libraryPath)
		try fileManager.copyItem(at: path, to: libraryPath)
		givenArgs[index] = "-Djava.library.path=\(libraryPath.path)"
	}
	args = Array(givenArgs.dropFirst())
	print("saving to defaults!")
	defaults.set(args, forKey: "latestArgs")
} else {
	print("loading from defaults!")
	guard let storedArgs = defaults.array(forKey: "latestArgs") as? [String]
		else { fatalError("no args passed; no stored args available") }
	dump(storedArgs)
	args = storedArgs
}

let environmentVars = Array((0...)
	.lazy
	.map { environ.advanced(by: $0).pointee }
	.prefix(while: { $0 != nil })
	.map { String(cString: $0!) }
)

let string = """
arguments:
\(args.map { "• \($0)" }.joined(separator: "\n"))

path: \(Bundle.main.executablePath!)
url: \(Bundle.main.executableURL!)

environment:
\(environmentVars.map { "• \($0)" }.joined(separator: "\n"))
"""
print(string)

let javaArgs = try args.filter { arg in
	switch arg {
	case "--debug-minecraft-instance":
		let desktop = try fileManager.url(for: .desktopDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
		try string.data(using: .utf8)!.write(to: desktop.appendingPathComponent("output.txt"))
		return false // don't pass on to java
	default:
		return true
	}
}

setenv("CFProcessPath", Bundle.main.executablePath!, 1)

try exec("java", args: javaArgs)
