//
//  SignRequestInterceptor.swift
//  iOS Example
//
//  Created by Gaoyang on 2021/11/25.
//  Copyright © 2021 Alamofire. All rights reserved.
//

import Foundation
import Alamofire

/// 负责向请求中添加自定义的签名请求头
class SignRequestInterceptor: RequestInterceptor {
    
    // MARK: - RequestAdapter
    
    func adapt(_ urlRequest: URLRequest, using state: RequestAdapterState, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        let request = sign(request: urlRequest)
        completion(.success(request))
    }
    
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        let request = sign(request: urlRequest)
        completion(.success(request))
    }
    
    // MARK: - RequestRetrier
    
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        completion(.retryWithDelay(3.0))
    }
    
    // MARK: -
    
    /// 模拟签名请求，使用url作为签名内容，便于观察
    private func sign(request: URLRequest) -> URLRequest {
        guard let urlString = request.url?.absoluteString else {
            return request
        }
        var retRequest = request
        retRequest.headers.add(name: "X-SIGN", value: urlString)
        return retRequest
    }
}

