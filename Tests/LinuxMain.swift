import XCTest

import ABACAuthorizationTests

var tests = [XCTestCaseEntry]()
tests += ABACMiddlewareTests.allTests()
tests += InMemoryAuthorizationPolicyTests.allTests()
XCTMain(tests)
