import Foundation

class URLUtils {
    static func parseHeaders(headers: String?) -> [String:String]? {
        if let headers = headers {
            var parsedHeaders: [String:String] = [:]
            let headerPairs = headers.components(separatedBy: ",")
            for headerPair in headerPairs {
                let sanitizedHeaderPair = headerPair.trimmingCharacters(in: .whitespacesAndNewlines)
                let headerParts = sanitizedHeaderPair.components(separatedBy: "=")
                let headerKey = headerParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let headerValue = headerParts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                parsedHeaders[headerKey] = headerValue
            }
            return parsedHeaders
        }
        return nil
    }
}
