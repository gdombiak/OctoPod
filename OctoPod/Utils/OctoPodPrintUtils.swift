import Foundation

class OctoPodPrintUtils {
    
    static func getSponsors(timeoutInterval: TimeInterval?, callback: @escaping (Array<Sponsor>?, Error?, HTTPURLResponse) -> Void) {
        let url = URL(string: "http://octopodprint.com/v1/octopod/sponsors")!
        let urlRequest = URLRequest(url: url, timeoutInterval: timeoutInterval ?? 5.0)
        URLSession.shared.dataTask(with: urlRequest) { (data: Data?, response: URLResponse?, error: Error?) in
            if let response = response as? HTTPURLResponse, let data = data {
                if response.statusCode == 200 {
                    do {
                        let sponsors = try JSONDecoder().decode(Array<Sponsor>.self, from: data)
                        callback(sponsors, error, response)
                    } catch let error {
                        callback(nil, error, response)
                    }
                } else {
                    callback(nil, error, response)
                }
            }
        }.resume()

    }
}
