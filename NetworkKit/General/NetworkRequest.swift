//
//  NetworkRequest.swift
//  Blockchain
//
//  Created by Alex McGregor on 8/28/18.
//  Copyright © 2018 Blockchain Luxembourg S.A. All rights reserved.
//

import DIKit
import RxSwift

public typealias HTTPHeaders = [String: String]

public struct NetworkRequest {
    
    public enum NetworkError: Error {
        case generic
    }
    
    public enum NetworkMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }

    public enum ContentType: String {
        case json = "application/json"
        case formUrlEncoded = "application/x-www-form-urlencoded"
    }
    
    var URLRequest: URLRequest {
        
        if authenticated && headers?[HttpHeaderField.authorization] == nil {
            fatalError("Missing Autentication Header")
        }
        
        let request: NSMutableURLRequest = NSMutableURLRequest(
            url: endpoint,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30.0
        )
        
        request.httpMethod = method.rawValue
        
        if let headers = headers {
            headers.forEach {
                request.addValue($1, forHTTPHeaderField: $0)
            }
        }
        
        if request.value(forHTTPHeaderField: HttpHeaderField.accept) == nil {
            request.addValue(HttpHeaderValue.json, forHTTPHeaderField: HttpHeaderField.accept)
        }
        if request.value(forHTTPHeaderField: HttpHeaderField.contentType) == nil {
            request.addValue(contentType.rawValue, forHTTPHeaderField: HttpHeaderField.contentType)
        }
        
        addHttpBody(to: request)
        
        return request.copy() as! URLRequest
    }
    
    let method: NetworkMethod
    let endpoint: URL
    private(set) var headers: HTTPHeaders?
    let contentType: ContentType
    // TODO:
    // * Also inject error decoder
    let decoder: NetworkResponseDecoderAPI
    let responseHandler: NetworkResponseHandlerAPI

    // TODO: modify this to be an Encodable type so that JSON serialization is done in this class
    // vs. having to serialize outside of this class
    let body: Data?
    
    let recordErrors: Bool
    
    let authenticated: Bool

    public init(
        endpoint: URL,
        method: NetworkMethod,
        body: Data? = nil,
        headers: HTTPHeaders? = nil,
        authenticated: Bool = false,
        contentType: ContentType = .json,
        decoder: NetworkResponseDecoderAPI = resolve(),
        responseHandler: NetworkResponseHandlerAPI = resolve(),
        recordErrors: Bool = false
    ) {
        self.endpoint = endpoint
        self.method = method
        self.body = body
        self.headers = headers
        self.authenticated = authenticated
        self.contentType = contentType
        self.decoder = decoder
        self.responseHandler = responseHandler
        self.recordErrors = recordErrors
    }
    
    mutating func add(authenticationToken: String) {
        if headers == nil {
            headers = [:]
        }
        headers?[HttpHeaderField.authorization] = authenticationToken
    }
    
    private func addHttpBody(to request: NSMutableURLRequest) {
        guard let data = body else {
            return
        }

        switch contentType {
        case .json:
            request.httpBody = data
        case .formUrlEncoded:
            if let params = try? JSONDecoder().decode([String: String].self, from: data) {
                request.encode(params: params)
            } else {
                request.httpBody = data
            }
        }
    }
}

extension NSMutableURLRequest {

    public func encode(params: [String : String]) {
        let encodedParamsArray = params.map { keyPair -> String in
            let (key, value) = keyPair
            return "\(key)=\(self.percentEscapeString(value))"
        }
        self.httpBody = encodedParamsArray.joined(separator: "&").data(using: .utf8)
    }

    private func percentEscapeString(_ stringToEscape: String) -> String {
        let characterSet = NSMutableCharacterSet.alphanumeric()
        characterSet.addCharacters(in: "-._* ")
        return stringToEscape
            .addingPercentEncoding(withAllowedCharacters: characterSet as CharacterSet)?
            .replacingOccurrences(of: " ", with: "+", options: [], range: nil) ?? stringToEscape
    }
}
