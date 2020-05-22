import Foundation
import Logging

struct LogEvent: Encodable, Equatable {
    let level: String
    let message: String
    let metadata: [String: String]
}
