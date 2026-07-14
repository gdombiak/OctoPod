import XCTest
@testable import OctoPod

final class OctoPodURLTests: XCTestCase {
    func testValidURLs() {
        [
            "http://octopi.local", "https://octopi.local",
            "http://www.hola.com", "http://www.hola.com:89", "http://www.hola.com/", "http://www.hola.com:89/", "http://www.hola.com/chau", "http://www.hola.com:89/chau",
            "http://192.168.1.1", "http://192.168.1.1:89", "http://192.168.1.1/", "http://192.168.1.1:89/", "http://192.168.1.1/chau", "http://192.168.1.1:89/chau", "http://192.168.1.1/chau/", "http://192.168.1.1:89/chau/",
            "http://[2001:db8:3c4d:0015:0000:0000:1a2f:1a2b]:89/chau/"
        ].forEach {
            XCTAssertTrue(PrinterUtils.isValidURL(inputURL: $0))
        }
        ["qweqwe", "www.google.com", "http://http://www.google.com", "http://www.goo gle.com"].forEach {
            XCTAssertFalse(PrinterUtils.isValidURL(inputURL: $0))
        }
    }

    func testHTTPClientURLs() {
        let client = HTTPClient(serverURL: "http://octopi.local", apiKey: "asd", username: nil, password: nil, headers: nil)
        XCTAssertNotNil(client.buildURL("/plugin/asd"))
        XCTAssertNotNil(client.buildURL("/plugin/prusaslicerthumbnails/thumbnail/E_PLA affe-c.png?20210812223724"))
        XCTAssertNotNil(client.buildURL("/plugin/prusaslicerthumbnails/thumbnail/E_PLA hundepaar.png?20210812220714"))
        XCTAssertNotNil(client.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube (1).gcode?20210812220714"))
        let url = client.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube >(1).gcode?20210812220714")
        XCTAssertNotNil(client.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube #(1).gcode?20210812220714"))
        XCTAssertNotNil(client.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube $(1).gcode?20210812220714"))
        XCTAssertNotNil(client.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube ?(1).gcode?20210812220714"))
        XCTAssertEqual(url?.absoluteString, "http://octopi.local/plugin/prusaslicerthumbnails/thumbnail/CE5_cube%20%3E(1).gcode?20210812220714")
        XCTAssertEqual(url?.path, "/plugin/prusaslicerthumbnails/thumbnail/CE5_cube >(1).gcode")
        XCTAssertEqual(url?.query, "20210812220714")

        let questionMarkURL = client.buildURL("/plugin/prusaslicerthumbnails/thumbnail/CE5_cube ?(1).gcode?20210812220714")
        XCTAssertEqual(questionMarkURL?.absoluteString, "http://octopi.local/plugin/prusaslicerthumbnails/thumbnail/CE5_cube%20?(1).gcode?20210812220714")
        XCTAssertEqual(questionMarkURL?.path, "/plugin/prusaslicerthumbnails/thumbnail/CE5_cube ")
        XCTAssertEqual(questionMarkURL?.query, "(1).gcode?20210812220714")

        let absoluteURL = client.buildURL("http://octopi.local/plugin/prusaslicerthumbnails/thumbnail/CE5_cube >(1).gcode?20210812220714")
        XCTAssertEqual(absoluteURL?.absoluteString, "http://octopi.local/plugin/prusaslicerthumbnails/thumbnail/CE5_cube%20%3E(1).gcode?20210812220714")
        XCTAssertEqual(absoluteURL?.path, "/plugin/prusaslicerthumbnails/thumbnail/CE5_cube >(1).gcode")
        XCTAssertEqual(absoluteURL?.query, "20210812220714")
    }
}
