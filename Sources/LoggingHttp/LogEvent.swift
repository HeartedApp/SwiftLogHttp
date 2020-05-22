import Foundation
import Logging

struct LogEvent: Encodable, Equatable {
    let label: String
    let level: String
    let message: String
    let metadata: [String: String]
}
