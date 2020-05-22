import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol SlackSession {
    func send(_ message: LogEvent, to url: URL, completion: ((Result<Void, Error>) -> Void)?)
}

enum SlackSessionError: Error {
    case invalidResponseType
    case errorStatusCode(Int, String?)
}

extension URLSession: SlackSession {
    func send(_ logEvent: LogEvent,
              to url: URL,
              completion: ((Result<Void, Error>) -> Void)?) {
        let data: Data
        do {
            data = try JSONEncoder().encode(logEvent)
        } catch {
            completion?(.failure(error))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = dataTask(with: request) { data, response, error in
            guard let response = response as? HTTPURLResponse else {
                completion?(.failure(SlackSessionError.invalidResponseType))
                return
            }
            
            guard (200..<300).contains(response.statusCode) else {
                let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) }
                completion?(.failure(SlackSessionError.errorStatusCode(response.statusCode, errorMessage)))
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
