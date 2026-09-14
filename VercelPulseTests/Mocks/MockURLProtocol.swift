import Foundation

public final class MockURLProtocol: URLProtocol {
    public struct MockResponse {
        public let statusCode: Int
        public let headers: [String: String]?
        public let data: Data?
        public let error: Error?
        public let delay: TimeInterval
        
        public init(
            statusCode: Int = 200,
            headers: [String: String]? = ["Content-Type": "application/json"],
            data: Data? = nil,
            error: Error? = nil,
            delay: TimeInterval = 0
        ) {
            self.statusCode = statusCode
            self.headers = headers
            self.data = data
            self.error = error
            self.delay = delay
        }
    }
    
    public struct RecordedRequest {
        public let url: URL?
        public let httpMethod: String?
        public let allHTTPHeaderFields: [String: String]?
        public let httpBody: Data?
    }
    
    private static let lock = NSLock()
    public static var requestHandler: ((URLRequest) throws -> MockResponse)?
    public static var stubbedResponses: [String: MockResponse] = [:]
    public static var recordedRequests: [RecordedRequest] = []
    
    public static func reset() {
        lock.lock()
        defer { lock.unlock() }
        requestHandler = nil
        stubbedResponses.removeAll()
        recordedRequests.removeAll()
    }
    
    public static func stub(endpoint: String, response: MockResponse) {
        lock.lock()
        defer { lock.unlock() }
        stubbedResponses[endpoint] = response
    }
    
    public static func stub(endpoint: String, jsonString: String, statusCode: Int = 200, headers: [String: String]? = nil) {
        var respHeaders = ["Content-Type": "application/json"]
        if let headers = headers {
            for (k, v) in headers {
                respHeaders[k] = v
            }
        }
        let response = MockResponse(
            statusCode: statusCode,
            headers: respHeaders,
            data: jsonString.data(using: .utf8)
        )
        stub(endpoint: endpoint, response: response)
    }
    
    public static func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config)
    }
    
    public override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    public override func startLoading() {
        MockURLProtocol.lock.lock()
        let recorded = RecordedRequest(
            url: request.url,
            httpMethod: request.httpMethod,
            allHTTPHeaderFields: request.allHTTPHeaderFields,
            httpBody: request.httpBody ?? extractBody(from: request)
        )
        MockURLProtocol.recordedRequests.append(recorded)
        let handler = MockURLProtocol.requestHandler
        let stubs = MockURLProtocol.stubbedResponses
        MockURLProtocol.lock.unlock()
        
        do {
            let mockResponse: MockResponse
            if let handler = handler {
                mockResponse = try handler(request)
            } else {
                let urlString = request.url?.absoluteString ?? ""
                let path = request.url?.path ?? ""
                
                var bestMatch: (pattern: String, resp: MockResponse)?
                for (pattern, resp) in stubs {
                    if urlString.contains(pattern) || path.contains(pattern) {
                        if bestMatch == nil || pattern.count > bestMatch!.pattern.count {
                            bestMatch = (pattern, resp)
                        }
                    }
                }
                
                if let m = bestMatch?.resp {
                    mockResponse = m
                } else {
                    mockResponse = MockResponse(
                        statusCode: 404,
                        data: "{\"error\": \"Not Found in MockURLProtocol\"}".data(using: .utf8)
                    )
                }
            }
            
            if mockResponse.delay > 0 {
                Thread.sleep(forTimeInterval: mockResponse.delay)
            }
            
            if let error = mockResponse.error {
                client?.urlProtocol(self, didFailWithError: error)
                return
            }
            
            let httpResponse = HTTPURLResponse(
                url: request.url ?? URL(string: "https://api.vercel.com")!,
                statusCode: mockResponse.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: mockResponse.headers
            )!
            
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            
            if let data = mockResponse.data {
                client?.urlProtocol(self, didLoad: data)
            }
            
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    public override func stopLoading() {}
    
    private func extractBody(from request: URLRequest) -> Data? {
        if let bodyStream = request.httpBodyStream {
            bodyStream.open()
            defer { bodyStream.close() }
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            var data = Data()
            while bodyStream.hasBytesAvailable {
                let read = bodyStream.read(buffer, maxLength: bufferSize)
                if read > 0 {
                    data.append(buffer, count: read)
                } else {
                    break
                }
            }
            return data.isEmpty ? nil : data
        }
        return nil
    }
}
