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

    public var logLevel: Logger.Level = .info
    
    public var metadata = Logger.Metadata()
    
    /// Creates a `HttpLogHandler` for sending `Logger` output via http.
    /// - Parameters:
    ///   - label: The log label for the log handler.
    ///   - url: The HTTP(S) URL.
    public init(label: String,
                url: URL) {
        self.label = label
        self.url = url
    }
    
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            metadata[metadataKey]
        }
        set {
            metadata[metadataKey] = newValue
        }
    }
    
    // swiftlint:disable:next function_parameter_count
    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata?,
                    file: String, function: String, line: UInt) {
        guard level >= HttpLogHandler.globalLogLevelThreshold else { return }
        
        let metadata = mergedMetadata(metadata).compactMapValues { value in unpackMetadata(value) }
        
        send(LogEvent(label: label, level: level.rawValue, message: message.description, metadata: metadata))
    }
    
    private func mergedMetadata(_ metadata: Logger.Metadata?) -> Logger.Metadata {
        if let metadata = metadata {
            return self.metadata.merging(metadata, uniquingKeysWith: { _, new in new })
        } else {
            return self.metadata
        }
    }
    
    private func unpackMetadata(_ value: Logger.MetadataValue) -> String? {
        switch value {
            case .dictionary(let dict):
                return dict.mapValues { $0.description }.description
            case .array(let list):
                return list.map { $0.description }.description
            case .string(let str):
                return str
            case .stringConvertible(let repr):
                return repr.description
        }
    }
    
    private func send(_ logEvent: LogEvent) {
        httpSession.send(logEvent, to: url) { result in
            switch result {
            case .success:
                break
            case let .failure(error):
                print("Failed to send payload with error: \(error)")
            }
            
            HttpLogHandler.messageSendHandler?(result)
        }
    }
}
