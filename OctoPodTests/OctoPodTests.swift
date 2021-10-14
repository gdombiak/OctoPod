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
    
    func testHTTClientURLs() throws {
        let httpClient = HTTPClient(serverURL: "http://octopi.local", apiKey: "asd", username: nil, password: nil)
        
        XCTAssertNotNil(httpClient.buildURL("/plugin/asd"))
        XCTAssertNotNil(httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/E_PLA affe-c.png?20210812223724"))
        XCTAssertNotNil(httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/E_PLA hundepaar.png?20210812220714"))
        XCTAssertNotNil(httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube (1).gcode?20210812220714"))
        XCTAssertNotNil(httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube >(1).gcode?20210812220714"))
        XCTAssertNotNil(httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube #(1).gcode?20210812220714"))
        XCTAssertNotNil(httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube $(1).gcode?20210812220714"))
        XCTAssertNotNil(httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube ?(1).gcode?20210812220714"))
        
        var url = httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube >(1).gcode?20210812220714")
        XCTAssertEqual(url?.path, "/plugin/prusaslicerthumbnails/thumbnail/CE5_cube >(1).gcode")
        XCTAssertEqual(url?.query, "20210812220714")

        // Filenames with ? are trouble. It will generate some URL but will not work
        url = httpClient.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube ?(1).gcode?20210812220714")
        XCTAssertEqual(url?.path, "/plugin/prusaslicerthumbnails/thumbnail/CE5_cube ")
        XCTAssertEqual(url?.query, "(1).gcode?20210812220714")
    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        measure {
//            // Put the code you want to measure the time of here.
//        }
//    }

}
