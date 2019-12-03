//
//  Pinger.swift
//  EduRoomSDK
//
//  Created by Nicky Weber on 11.06.19.
//

import Foundation

typealias PingCompletionHandler = (NSError?) -> Void

private typealias Validationandler = (Data?, HTTPURLResponse, Error?) throws -> Void

private struct PingError: Decodable {
    let errorCode: String?
    let errorMessage: String?
    let errorMessageLocalized: String?
}

private struct PingResult: Decodable {
    let request: Bool
}

private struct PingBody: Decodable {
    let error: PingError?
    let result: PingResult?
    let http_status: Int?
}

@available(iOS 9.0, *)
class Pinger {

    private let pingURLSession: URLSession
    private let settings: Settings

    init(settings: Settings) {
        self.settings = settings
        
        let configuration = URLSessionConfiguration.ephemeral
        pingURLSession = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }
    
    deinit {
        self.pingURLSession.invalidateAndCancel()
    }
    
    func ping(completionHandler: @escaping PingCompletionHandler) {
        request(url: settings.pingURL,
                validationHandler: defaultValidator(),
                completionHandler: completionHandler)
    }
   
    func pingSessionClosing(completionHandler: @escaping () -> Void ) {
        request(url: settings.pingURL) { (error) in
            completionHandler()
        }
    }
    
    func stopAllRequests() {
        pingURLSession.getAllTasks { (tasks) in
            for task in tasks {
                task.cancel()
            }
        }
    }
    
    private func defaultValidator() -> Validationandler {
        return { [weak self] data, httpResponse, error in
            try self?.validateJsonResultIsOk(data: data, response: httpResponse)
            try self?.validateHttpStatusCodeIsOk(data: data, response: httpResponse)
        }
    }

    private func request(url: URL, completionHandler: @escaping PingCompletionHandler) {
        request(url: url, validationHandler: { (_, _, _) in }, completionHandler: completionHandler)
    }

    private func isCancelledError(_ error: Error?) -> Bool {
        if let requestError = error as NSError?, requestError.code != NSURLErrorCancelled {
            return true
        }
        return false
    }
    
    private func request(url: URL,
                         validationHandler: @escaping (Data?, HTTPURLResponse, Error?) throws -> Void,
                         completionHandler: @escaping PingCompletionHandler)
    {
        let task = self.pingURLSession.dataTask(with: url) { data, response, error in
            do {
                guard let httpResponse = response as? HTTPURLResponse else {
                    if let error = error as NSError? {
                        throw error
                    } else {
                        throw EduRoomError.pingProtocolError.asNSError("Received non http(s) response")
                    }
                }
                
                try validationHandler(data, httpResponse, error)
                completionHandler(nil)
            } catch let error as NSError {
                if self.isCancelledError(error) {
                    completionHandler(nil)
                    return
                }
                completionHandler(error)
            }
        }
        task.resume()
    }
    
    private func validateJsonResultIsOk(data: Data?, response: HTTPURLResponse) throws {
        let decoder = JSONDecoder()
        guard let someData = data,
            let pingBody = try? decoder.decode(PingBody.self, from: someData) else
        {
            throw EduRoomError.pingAPIMissingJsonBodyError.asNSError("Received response without json body")
        }
        
        guard let result = pingBody.result, result.request else
        {
            throw EduRoomError.pingStudentSessionEndedError.asNSError("The student's session expired.")
        }
    }
    
    private func validateHttpStatusCodeIsOk(data: Data?, response: HTTPURLResponse) throws {
        let expectedCode = 200
        guard response.statusCode == expectedCode else
        {
            var body = ""
            if let data = data, let _body = String(data: data, encoding: .utf8) {
                body = _body
            }
            let errorMessage = "API responded with status code \(response.statusCode) but \(expectedCode) expected. \n"
                + "Headers: \(response.allHeaderFields) \n"
                + "Body: \(body)"
            throw EduRoomError.pingAPIError.asNSError(errorMessage)
        }
    }
    
    private func validateResponseIsHttp(response: URLResponse) throws {
        guard response is HTTPURLResponse else {
            throw EduRoomError.pingProtocolError.asNSError("Received non http(s) response")
        }
    }
}
