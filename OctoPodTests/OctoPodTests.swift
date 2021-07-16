import XCTest
@testable import OctoPod

class OctoPodTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// Test that URL validation works fine
    func testValidURLs() throws {
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://octopi.local"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "https://octopi.local"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://www.hola.com"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://www.hola.com:89"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://www.hola.com/"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://www.hola.com:89/"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://www.hola.com/chau"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://www.hola.com:89/chau"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1:89"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1/"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1:89/"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1/chau"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1:89/chau"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1/chau/"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://192.168.1.1:89/chau/"))

        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://2001:db8:3c4d:0015:0000:0000:1a2f:1a2b"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://2001:db8:3c4d:0015:0000:0000:1a2f:1a2b/"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://2001:db8:3c4d:0015:0000:0000:1a2f:1a2b:89"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://2001:db8:3c4d:0015:0000:0000:1a2f:1a2b:89/"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://2001:db8:3c4d:0015:0000:0000:1a2f:1a2b:89/chau"))
        XCTAssertTrue(PrinterUtils.isValidURL(inputURL: "http://2001:db8:3c4d:0015:0000:0000:1a2f:1a2b:89/chau/"))

        XCTAssertFalse(PrinterUtils.isValidURL(inputURL: "qweqwe"))
        XCTAssertFalse(PrinterUtils.isValidURL(inputURL: "www.google.com"))
        XCTAssertFalse(PrinterUtils.isValidURL(inputURL: "http://http://www.google.com"))
        XCTAssertFalse(PrinterUtils.isValidURL(inputURL: "http://www.goo gle.com"))
    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        measure {
//            // Put the code you want to measure the time of here.
//        }
//    }

}
