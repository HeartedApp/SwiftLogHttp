import Logging
@testable import LoggingHttp
import XCTest

// We can only bootstrap the logging system once.
// This makes the setup more complicated since we want to test
// using a mock session and a real session.
let isLoggingConfigured: Bool = {
    LoggingSystem.bootstrap { label in
        guard let url = ProcessInfo.processInfo.environment["URL"].flatMap({ URL(string: $0) }) else {
            fatalError("URL must be set to a valid URL.")
        }
        var httpLogHandler = HttpLogHandler(label: label,
                                              url: url)
        
        return MultiplexLogHandler([
            httpLogHandler,
            StreamLogHandler.standardOutput(label: label)
        ])
    }
    return true
}()

final class HttpLogHandlerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        
        XCTAssert(isLoggingConfigured)
        
        HttpLogHandler.globalLogLevelThreshold = .error
        HttpLogHandler.messageSendHandler = nil
    }
    
    func testSending() {
        guard ProcessInfo.processInfo.environment["URL"] != nil else {
            print("Skipping sending real message since URL is not configured.")
            return
        }

        let logger = Logger(label: "com.example.app")
        
        let messageSentExpectation = expectation(description: "Expected message to send.")
        
        HttpLogHandler.messageSendHandler = { result in
            switch result {
            case .success:
                messageSentExpectation.fulfill()
            case let .failure(error):
                XCTFail("Failed to send Http message with error: \(error)")
            }
        }
        
        let metadata: Logger.Metadata = [
            "identifier": .stringConvertible(UUID()),
            "name": "test-name",
            "number": .stringConvertible(42),
            "embedded": [ "dictionary" : "value", "sub" : ["date" : .stringConvertible(Date())]]
        ]
        
        logger.error("This is an error with metadata", metadata: metadata)
        
        wait(for: [messageSentExpectation], timeout: 10)
    }
}
