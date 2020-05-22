import XCTest

import LoggingHttpTests

var tests = [XCTestCaseEntry]()
tests += LoggingHttpTests.__allTests()

XCTMain(tests)
