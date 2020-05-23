import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

/// `HttpLogHandler` is an implementation of `LogHandler` for sending
/// `Logger` output directly to web server.
public struct HttpLogHandler: LogHandler {
    /// The global log level threshold that determines when to send log output via http.
    /// Defaults to `.info`.
    ///
    /// The `logLevel` of an individual `HttpLogHandler` is ignored when this global
    /// log level is set to a higher level.
    public static var globalLogLevelThreshold: Logger.Level = .info
    
    /// Internal for testing only.
    internal static var messageSendHandler: ((Result<Void, Error>) -> Void)?
    
    /// Internal for testing only.
    internal var httpSession: HttpSession = URLSession.shared
    
    /// The log label for the log handler.
    public var label: String
    
    /// The HTTP(S) URL.
    public var url: URL

    // Headers to pass along with the payload
    public var headers: [String: String]

    public var logLevel: Logger.Level = .info
    
    public var metadata = Logger.Metadata()
    
    /// Creates a `HttpLogHandler` for sending `Logger` output via http.
    /// - Parameters:
    ///   - label: The log label for the log handler.
    ///   - url: The HTTP(S) URL.
    public init(label: String,
                url: URL,
                headers: [String:String]) {
        self.label = label
        self.url = url
        self.headers = headers
    }
    
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            metadata[metadataKey]
        }
        set {
            metadata[metadataKey] = newValue
        }
    }
    
    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {
        // JSONSerialization and its internal JSONWriter calls seem to leak significant memory, especially when
        // called recursively or in loops. Wrapping the calls in an autoreleasepool fixes the problems entirely on Darwin.
        // see: https://bugs.swift.org/browse/SR-5501
        autoreleasepool {
            let entryMetadata: Logger.Metadata
            if let parameterMetadata = metadata {
                entryMetadata = self.metadata.merging(parameterMetadata) { $1 }
            } else {
                entryMetadata = self.metadata
            }
            
            var json = Self.unpackMetadata(.dictionary(entryMetadata)) as! [String: Any]
            assert(json["message"] == nil, "'message' is a metadata field reserved by Stackdriver, your custom 'message' metadata value will be overriden in production")
            assert(json["severity"] == nil, "'severity' is a metadata field reserved by Stackdriver, your custom 'severity' metadata value will be overriden in production")
            assert(json["sourceLocation"] == nil, "'sourceLocation' is a metadata field reserved by Stackdriver, your custom 'sourceLocation' metadata value will be overriden in production")
            assert(json["timestamp"] == nil, "'timestamp' is a metadata field reserved by Stackdriver, your custom 'timestamp' metadata value will be overriden in production")
            
            json["label"] = label
            json["message"] = message.description
            json["level"] = level.rawValue
            json["sourceLocation"] = ["file": Self.conciseSourcePath(file), "line": line, "function": function]
            json["timestamp"] = Self.iso8601DateFormatter.string(from: Date())
            
            do {
                try self.send(JSONSerialization.data(withJSONObject: json, options: []))
            } catch {
                print("Failed to serialize your log entry metadata to JSON with error: '\(error.localizedDescription)'")
            }
        }
    }
    
    /// ISO 8601 `DateFormatter` which is the accepted format for timestamps in Stackdriver
    private static let iso8601DateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()
    
    private static func unpackMetadata(_ value: Logger.MetadataValue) -> Any {
        /// Based on the core-foundation implementation of `JSONSerialization.isValidObject`, but optimized to reduce the amount of comparisons done per validation.
        /// https://github.com/apple/swift-corelibs-foundation/blob/9e505a94e1749d329563dac6f65a32f38126f9c5/Foundation/JSONSerialization.swift#L52
        func isValidJSONValue(_ value: CustomStringConvertible) -> Bool {
            if value is Int || value is Bool || value is NSNull ||
                (value as? Double)?.isFinite ?? false ||
                (value as? Float)?.isFinite ?? false ||
                (value as? Decimal)?.isFinite ?? false ||
                value is UInt ||
                value is Int8 || value is Int16 || value is Int32 || value is Int64 ||
                value is UInt8 || value is UInt16 || value is UInt32 || value is UInt64 ||
                value is String {
                return true
            }
            
            // Using the official `isValidJSONObject` call for NSNumber since `JSONSerialization.isValidJSONObject` uses internal/private functions to validate them...
            if let number = value as? NSNumber {
                return JSONSerialization.isValidJSONObject([number])
            }
            
            return false
        }
        
        switch value {
        case .string(let value):
            return value
        case .stringConvertible(let value):
            if isValidJSONValue(value) {
                return value
            } else if let date = value as? Date {
                return iso8601DateFormatter.string(from: date)
            } else if let data = value as? Data {
                return data.base64EncodedString()
            } else {
                return value.description
            }
        case .array(let value):
            return value.map { Self.unpackMetadata($0) }
        case .dictionary(let value):
            return value.mapValues { Self.unpackMetadata($0) }
        }
    }
    
    private static func conciseSourcePath(_ path: String) -> String {
        return path.split(separator: "/")
            .split(separator: "Sources")
            .last?
            .joined(separator: "/") ?? path
    }
    
    private func send(_ message: Data) {
        httpSession.send(message, to: url, headers: headers) { result in
            switch result {
            case .success:
                break
            case let .failure(error):
                print("Failed to send payload with error: \(error)")
            }
            
            HttpLogHandler.messageSendHandler?(result)
        }
    }
    
    private func withAutoReleasePool<T>(_ execute: () throws -> T) rethrows -> T {
        #if os(Linux)
        return try execute()
        #else
        return try autoreleasepool {
            try execute()
        }
        #endif
    }
}
