import Foundation

// https://github.com/mxcl/swift-sh/blob/master/Sources/Utility/exec().swift

func exec(_ arg0: String, args: [String]) throws -> Never {
	let args = CStringArray([arg0] + args)
	
	guard execvp(arg0, args.cArray) != -1 else {
		print(string(forErrorWithCode: errno))
		throw POSIXError.execv(executable: arg0, errno: errno)
	}
	
	fatalError("Impossible if execv succeeded")
}

public enum POSIXError: LocalizedError {
	case execv(executable: String, errno: Int32)
	
	public var errorDescription: String? {
		switch self {
		case .execv(let executablePath, let errno):
			return "execv failed: \(string(forErrorWithCode: errno)): \(executablePath)"
		}
	}
}

private final class CStringArray {
	/// The null-terminated array of C string pointers.
	public let cArray: [UnsafeMutablePointer<Int8>?]
	
	/// Creates an instance from an array of strings.
	public init(_ array: [String]) {
		cArray = array.map({ $0.withCString({ strdup($0) }) }) + [nil]
	}
	
	deinit {
		for case let element? in cArray {
			free(element)
		}
	}
}

// https://github.com/mxcl/swift-sh/blob/master/Sources/Utility/etc.swift

private func string(forErrorWithCode code: Int32) -> String {
	var cap = 64
	while cap <= 16 * 1024 {
		var buf = [Int8](repeating: 0, count: cap)
		let err = strerror_r(code, &buf, buf.count)
		if err == EINVAL {
			return "unknown error \(code)"
		}
		if err == ERANGE {
			cap *= 2
			continue
		}
		if err != 0 {
			return "fatal: strerror_r: \(err)"
		}
		return "\(String(cString: buf)) (\(code))"
	}
	return "fatal: strerror_r: ERANGE"
}
