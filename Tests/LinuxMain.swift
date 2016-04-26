#if os(Linux)

import XCTest
@testable import RegexRouteMatcherTestSuite

XCTMain([
    testCase(RegexRouteMatcherTests.allTests)
])

#endif
