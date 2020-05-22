import Foundation
import Logging

struct Location: Encodable, Equatable {
    let file: String
    let function: String
    let line: UInt
}

struct LogEvent: Encodable, Equatable {
    let label: String
    let level: String
    let location: Location
    let message: String
    let metadata: Logger.Metadata?
    
    enum CodingKeys: String, CodingKey {
        case label
        case level
        case location
        case message
        case metadata
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encode(level, forKey: .level)
        try container.encode(location, forKey: .location)
        try container.encode(message, forKey: .message)
        if metadata != nil {
            let unpackedMetadata = unpackMetadata(.dictionary(metadata!))
            let encoder = JSONEncoder()
            let jsonMetadata = try! encoder.encode(unpackedMetadata)
            //let jsonMetadata = try JSONSerialization.data(withJSONObject: unpackedMetadata, options: [])
            try container.encode(String(data: jsonMetadata, encoding: .utf8), forKey: .metadata)
        }
        
    }
    
    private func mergedMetadata(_ metadata: Logger.Metadata?) -> Logger.Metadata? {
        if let metadata = metadata {
            return self.metadata?.merging(metadata, uniquingKeysWith: { _, new in new })
        } else {
            return self.metadata
        }
    }
    
    private func unpackMetadata(_ value: Logger.MetadataValue?) -> Any {
        switch value {
            case .dictionary(let dict):
                return dict.mapValues { unpackMetadata($0) }
            case .array(let list):
                return list.map { unpackMetadata($0) }
            case .string(let str):
                return str
            case .stringConvertible(let repr):
                return repr.description
            case .none:
                return Optional<Any>.none
            }
    }
}
