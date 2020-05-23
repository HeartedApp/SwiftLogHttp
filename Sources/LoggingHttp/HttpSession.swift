import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol HttpSession {
    func send(_ message: Data, to url: URL, completion: ((Result<Void, Error>) -> Void)?)
    func send(_ message: Data, to url: URL, headers: [String: String], completion: ((Result<Void, Error>) -> Void)?)
}

enum HttpSessionError: Error {
    case invalidResponseType
    case errorStatusCode(Int, String?)
}

extension URLSession: HttpSession {
    func send(_ message: Data, to url: URL, completion: ((Result<Void, Error>) -> Void)?) {
        send(message, to: url, headers: [String:String].init(), completion: completion)
    }
    
    func send(_ message: Data,
              to url: URL,
              headers: [String: String],
              completion: ((Result<Void, Error>) -> Void)?) {
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        request.httpMethod = "POST"
        request.httpBody = message
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = dataTask(with: request) { data, response, error in
            guard let response = response as? HTTPURLResponse else {
                completion?(.failure(HttpSessionError.invalidResponseType))
                return
            }
            
            guard (200..<300).contains(response.statusCode) else {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) }
                completion?(.failure(HttpSessionError.errorStatusCode(response.statusCode, errorMessage)))
                return
            }
            
            if let error = error {
                completion?(.failure(error))
            } else {
                completion?(.success(()))
            }
        }
        
        task.resume()
    }
}
