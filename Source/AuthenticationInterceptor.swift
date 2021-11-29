//
//  AuthenticationInterceptor.swift
//
//  Copyright (c) 2020 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
/// 授权凭证，可以使用它对URLRequest进行授权。
/// 例如：在OAuth2授权体系中，凭证包含accessToken，它可以对一个用户的所有请求进行授权。
/// 通常情况下，该accessToken有效时长为60分钟；在过期前后（一段时间内）可以使用refreshToken对accessToken进行刷新。
/// Types adopting the `AuthenticationCredential` protocol can be used to authenticate `URLRequest`s.
///
/// One common example of an `AuthenticationCredential` is an OAuth2 credential containing an access token used to
/// authenticate all requests on behalf of a user. The access token generally has an expiration window of 60 minutes
/// which will then require a refresh of the credential using the refresh token to generate a new access token.
public protocol AuthenticationCredential {
    /// 授权凭证是否需要刷新。
    /// 在凭证在即将过期或过期后，应该返回true。
    /// 例如，accessToken的有效期为60分钟，在凭证即将过期的5分钟应该返回true，保证accessToken得到刷新。
    /// Whether the credential requires a refresh. This property should always return `true` when the credential is
    /// expired. It is also wise to consider returning `true` when the credential will expire in several seconds or
    /// minutes depending on the expiration window of the credential.
    ///
    /// For example, if the credential is valid for 60 minutes, then it would be wise to return `true` when the
    /// credential is only valid for 5 minutes or less. That ensures the credential will not expire as it is passed
    /// around backend services.
    var requiresRefresh: Bool { get }
}

// MARK: -
/// 授权中心，可以使用凭证（AuthenticationCredential）对URLRequest授权；也可以管理token的刷新。
/// Types adopting the `Authenticator` protocol can be used to authenticate `URLRequest`s with an
/// `AuthenticationCredential` as well as refresh the `AuthenticationCredential` when required.
public protocol Authenticator: AnyObject {
    /// 该授权中心使用的凭证类型
    /// The type of credential associated with the `Authenticator` instance.
    associatedtype Credential: AuthenticationCredential
    
    /// 使用凭证对请求进行授权。
    /// 例如：在OAuth2体系中，应该设置请求头 [ "Authorization": "Bearer accessToken" ]
    /// Applies the `Credential` to the `URLRequest`.
    ///
    /// In the case of OAuth2, the access token of the `Credential` would be added to the `URLRequest` as a Bearer
    /// token to the `Authorization` header.
    ///
    /// - Parameters:
    ///   - credential: The `Credential`.
    ///   - urlRequest: The `URLRequest`.
    func apply(_ credential: Credential, to urlRequest: inout URLRequest)
    
    /// 刷新凭证，并通过completion回调结果。
    /// 在下面两种情况下，会执行刷新：
    /// 1. 适配过程中 - 对应 拦截器的 adapt(_:for:completion:) 方法
    /// 2. 重试过程中 - 对应拦截器的 retry(_:for:dueTo:completion:)方法
    ///
    /// 例如：在OAuth2体系中，应该在该方法中使用refreshToken去刷新accessToken，完成后在回调中返回新的凭证。
    /// 若刷新请求被拒绝（状态码401），refreshToken不应该再使用，此时应该要求用户重新授权。
    /// Refreshes the `Credential` and executes the `completion` closure with the `Result` once complete.
    ///
    /// Refresh can be called in one of two ways. It can be called before the `Request` is actually executed due to
    /// a `requiresRefresh` returning `true` during the adapt portion of the `Request` creation process. It can also
    /// be triggered by a failed `Request` where the authentication server denied access due to an expired or
    /// invalidated access token.
    ///
    /// In the case of OAuth2, this method would use the refresh token of the `Credential` to generate a new
    /// `Credential` using the authentication service. Once complete, the `completion` closure should be called with
    /// the new `Credential`, or the error that occurred.
    ///
    /// In general, if the refresh call fails with certain status codes from the authentication server (commonly a 401),
    /// the refresh token in the `Credential` can no longer be used to generate a valid `Credential`. In these cases,
    /// you will need to reauthenticate the user with their username / password.
    ///
    /// Please note, these are just general examples of common use cases. They are not meant to solve your specific
    /// authentication server challenges. Please work with your authentication server team to ensure your
    /// `Authenticator` logic matches their expectations.
    ///
    /// - Parameters:
    ///   - credential: The `Credential` to refresh.
    ///   - session:    The `Session` requiring the refresh.
    ///   - completion: The closure to be executed once the refresh is complete.
    func refresh(_ credential: Credential, for session: Session, completion: @escaping (Result<Credential, Error>) -> Void)

    /// 判断URLRequest失败是否因为授权问题。
    /// 若授权服务器不支持对已经生效的凭证进行撤销（也就是说凭证永久有效）应该返回false。否则应该根据具体情况判断。
    /// 例如：在OAuth2体系中， 可以使用状态码401代表授权失败，此时应该返回true。
    /// 注意：上面只是一般情况，你应该根据你所处的系统具体判断。
    /// Determines whether the `URLRequest` failed due to an authentication error based on the `HTTPURLResponse`.
    ///
    /// If the authentication server **CANNOT** invalidate credentials after they are issued, then simply return `false`
    /// for this method. If the authentication server **CAN** invalidate credentials due to security breaches, then you
    /// will need to work with your authentication server team to understand how to identify when this occurs.
    ///
    /// In the case of OAuth2, where an authentication server can invalidate credentials, you will need to inspect the
    /// `HTTPURLResponse` or possibly the `Error` for when this occurs. This is commonly handled by the authentication
    /// server returning a 401 status code and some additional header to indicate an OAuth2 failure occurred.
    ///
    /// It is very important to understand how your authentication server works to be able to implement this correctly.
    /// For example, if your authentication server returns a 401 when an OAuth2 error occurs, and your downstream
    /// service also returns a 401 when you are not authorized to perform that operation, how do you know which layer
    /// of the backend returned you a 401? You do not want to trigger a refresh unless you know your authentication
    /// server is actually the layer rejecting the request. Again, work with your authentication server team to understand
    /// how to identify an OAuth2 401 error vs. a downstream 401 error to avoid endless refresh loops.
    ///
    /// - Parameters:
    ///   - urlRequest: The `URLRequest`.
    ///   - response:   The `HTTPURLResponse`.
    ///   - error:      The `Error`.
    ///
    /// - Returns: `true` if the `URLRequest` failed due to an authentication error, `false` otherwise.
    func didRequest(_ urlRequest: URLRequest, with response: HTTPURLResponse, failDueToAuthenticationError error: Error) -> Bool
    
    /// 判断URLRequest是否使用凭证进行了授权。
    /// 若授权服务器不支持对已经生效的凭证进行撤销（也就是说凭证永久有效）应该返回true。否则应该根据具体情况判断。
    /// 例如：在OAuth2体系中，  可以对比`URLRequest中header的授权字段Authorization的值` 和 `Credential中的token`;
    /// 若他们相等，返回true，否则返回false
    ///
    /// Determines whether the `URLRequest` is authenticated with the `Credential`.
    ///
    /// If the authentication server **CANNOT** invalidate credentials after they are issued, then simply return `true`
    /// for this method. If the authentication server **CAN** invalidate credentials due to security breaches, then
    /// read on.
    ///
    /// When an authentication server can invalidate credentials, it means that you may have a non-expired credential
    /// that appears to be valid, but will be rejected by the authentication server when used. Generally when this
    /// happens, a number of requests are all sent when the application is foregrounded, and all of them will be
    /// rejected by the authentication server in the order they are received. The first failed request will trigger a
    /// refresh internally, which will update the credential, and then retry all the queued requests with the new
    /// credential. However, it is possible that some of the original requests will not return from the authentication
    /// server until the refresh has completed. This is where this method comes in.
    ///
    /// When the authentication server rejects a credential, we need to check to make sure we haven't refreshed the
    /// credential while the request was in flight. If it has already refreshed, then we don't need to trigger an
    /// additional refresh. If it hasn't refreshed, then we need to refresh.
    ///
    /// Now that it is understood how the result of this method is used in the refresh lifecyle, let's walk through how
    /// to implement it. You should return `true` in this method if the `URLRequest` is authenticated in a way that
    /// matches the values in the `Credential`. In the case of OAuth2, this would mean that the Bearer token in the
    /// `Authorization` header of the `URLRequest` matches the access token in the `Credential`. If it matches, then we
    /// know the `Credential` was used to authenticate the `URLRequest` and should return `true`. If the Bearer token
    /// did not match the access token, then you should return `false`.
    ///
    /// - Parameters:
    ///   - urlRequest: The `URLRequest`.
    ///   - credential: The `Credential`.
    ///
    /// - Returns: `true` if the `URLRequest` is authenticated with the `Credential`, `false` otherwise.
    func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: Credential) -> Bool
}

// MARK: -

/// Represents various authentication failures that occur when using the `AuthenticationInterceptor`. All errors are
/// still vended from Alamofire as `AFError` types. The `AuthenticationError` instances will be embedded within
/// `AFError` `.requestAdaptationFailed` or `.requestRetryFailed` cases.
public enum AuthenticationError: Error {
    /// The credential was missing so the request could not be authenticated.
    case missingCredential
    /// The credential was refreshed too many times within the `RefreshWindow`.
    case excessiveRefresh
}

// MARK: -

/// The `AuthenticationInterceptor` class manages the queuing and threading complexity of authenticating requests.
/// It relies on an `Authenticator` type to handle the actual `URLRequest` authentication and `Credential` refresh.
public class AuthenticationInterceptor<AuthenticatorType>: RequestInterceptor where AuthenticatorType: Authenticator {
    // MARK: Typealiases

    /// Type of credential used to authenticate requests.
    public typealias Credential = AuthenticatorType.Credential

    // MARK: Helper Types

    /// Type that defines a time window used to identify excessive refresh calls. When enabled, prior to executing a
    /// refresh, the `AuthenticationInterceptor` compares the timestamp history of previous refresh calls against the
    /// `RefreshWindow`. If more refreshes have occurred within the refresh window than allowed, the refresh is
    /// cancelled and an `AuthorizationError.excessiveRefresh` error is thrown.
    public struct RefreshWindow {
        /// `TimeInterval` defining the duration of the time window before the current time in which the number of
        /// refresh attempts is compared against `maximumAttempts`. For example, if `interval` is 30 seconds, then the
        /// `RefreshWindow` represents the past 30 seconds. If more attempts occurred in the past 30 seconds than
        /// `maximumAttempts`, an `.excessiveRefresh` error will be thrown.
        public let interval: TimeInterval

        /// Total refresh attempts allowed within `interval` before throwing an `.excessiveRefresh` error.
        public let maximumAttempts: Int

        /// Creates a `RefreshWindow` instance from the specified `interval` and `maximumAttempts`.
        ///
        /// - Parameters:
        ///   - interval:        `TimeInterval` defining the duration of the time window before the current time.
        ///   - maximumAttempts: The maximum attempts allowed within the `TimeInterval`.
        public init(interval: TimeInterval = 30.0, maximumAttempts: Int = 5) {
            self.interval = interval
            self.maximumAttempts = maximumAttempts
        }
    }

    private struct AdaptOperation {
        let urlRequest: URLRequest
        let session: Session
        let completion: (Result<URLRequest, Error>) -> Void
    }

    private enum AdaptResult {
        case adapt(Credential)
        case doNotAdapt(AuthenticationError)
        case adaptDeferred
    }

    private struct MutableState {
        var credential: Credential?

        var isRefreshing = false
        var refreshTimestamps: [TimeInterval] = []
        var refreshWindow: RefreshWindow?

        var adaptOperations: [AdaptOperation] = []
        var requestsToRetry: [(RetryResult) -> Void] = []
    }

    // MARK: Properties

    /// The `Credential` used to authenticate requests.
    public var credential: Credential? {
        get { $mutableState.credential }
        set { $mutableState.credential = newValue }
    }

    let authenticator: AuthenticatorType
    let queue = DispatchQueue(label: "org.alamofire.authentication.inspector")

    @Protected
    private var mutableState: MutableState

    // MARK: Initialization

    /// Creates an `AuthenticationInterceptor` instance from the specified parameters.
    ///
    /// A `nil` `RefreshWindow` will result in the `AuthenticationInterceptor` not checking for excessive refresh calls.
    /// It is recommended to always use a `RefreshWindow` to avoid endless refresh cycles.
    ///
    /// - Parameters:
    ///   - authenticator: The `Authenticator` type.
    ///   - credential:    The `Credential` if it exists. `nil` by default.
    ///   - refreshWindow: The `RefreshWindow` used to identify excessive refresh calls. `RefreshWindow()` by default.
    public init(authenticator: AuthenticatorType,
                credential: Credential? = nil,
                refreshWindow: RefreshWindow? = RefreshWindow()) {
        self.authenticator = authenticator
        mutableState = MutableState(credential: credential, refreshWindow: refreshWindow)
    }

    // MARK: Adapt

    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        let adaptResult: AdaptResult = $mutableState.write { mutableState in
            // 适配一个URLRequest时，正在刷新凭证，将此次适配记录下来，延迟执行
            // Queue the adapt operation if a refresh is already in place.
            guard !mutableState.isRefreshing else {
                let operation = AdaptOperation(urlRequest: urlRequest, session: session, completion: completion)
                mutableState.adaptOperations.append(operation)
                return .adaptDeferred
            }
            // 没有授权凭证时，报错
            // Throw missing credential error is the credential is missing.
            guard let credential = mutableState.credential else {
                let error = AuthenticationError.missingCredential
                return .doNotAdapt(error)
            }
            // 若凭证需要刷新，将此次适配记录下来，延迟执行。并触发刷新操作
            // Queue the adapt operation and trigger refresh operation if credential requires refresh.
            guard !credential.requiresRefresh else {
                let operation = AdaptOperation(urlRequest: urlRequest, session: session, completion: completion)
                mutableState.adaptOperations.append(operation)
                refresh(credential, for: session, insideLock: &mutableState)
                return .adaptDeferred
            }
            // 上面的情况都没有触发，则需要进行适配
            return .adapt(credential)
        }

        switch adaptResult {
        case let .adapt(credential):
            // 使用授权中心进行授权，之后回调
            var authenticatedRequest = urlRequest
            authenticator.apply(credential, to: &authenticatedRequest)
            completion(.success(authenticatedRequest))

        case let .doNotAdapt(adaptError):
            // 出错了就直接回调错误
            completion(.failure(adaptError))

        case .adaptDeferred:
            // 凭证需要刷新或正在刷新， 适配需要延迟到刷新完成后执行
            // No-op: adapt operation captured during refresh.
            break
        }
    }

    // MARK: Retry

    public func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        // 没有原始请求或没有收到服务器的响应，无需重试
        // Do not attempt retry if there was not an original request and response from the server.
        guard let urlRequest = request.request, let response = request.response else {
            completion(.doNotRetry)
            return
        }
        // 不是因为授权原因失败的，无需重试
        // Do not attempt retry unless the `Authenticator` verifies failure was due to authentication error (i.e. 401 status code).
        guard authenticator.didRequest(urlRequest, with: response, failDueToAuthenticationError: error) else {
            completion(.doNotRetry)
            return
        }
        // 需要授权，却没有凭证的，回调错误
        // Do not attempt retry if there is no credential.
        guard let credential = credential else {
            let error = AuthenticationError.missingCredential
            completion(.doNotRetryWithError(error))
            return
        }
        // 需要授权，但未使用当前凭证，需要重试
        // Retry the request if the `Authenticator` verifies it was authenticated with a previous credential.
        guard authenticator.isRequest(urlRequest, authenticatedWith: credential) else {
            completion(.retry)
            return
        }
        // 需要授权，存在凭证，也授权过了，还进入了重试那就说明凭证过期了，刷新凭证
        $mutableState.write { mutableState in
            mutableState.requestsToRetry.append(completion)

            guard !mutableState.isRefreshing else { return }

            refresh(credential, for: session, insideLock: &mutableState)
        }
    }

    // MARK: Refresh

    private func refresh(_ credential: Credential, for session: Session, insideLock mutableState: inout MutableState) {
        // 若过度刷新，直接报错
        guard !isRefreshExcessive(insideLock: &mutableState) else {
            let error = AuthenticationError.excessiveRefresh
            handleRefreshFailure(error, insideLock: &mutableState)
            return
        }
        // 记录刷新时间，设置刷新标志
        mutableState.refreshTimestamps.append(ProcessInfo.processInfo.systemUptime)
        mutableState.isRefreshing = true

        // Dispatch to queue to hop out of the lock in case authenticator.refresh is implemented synchronously.
        queue.async {
            // 使用授权中心进行刷新
            self.authenticator.refresh(credential, for: session) { result in
                self.$mutableState.write { mutableState in
                    switch result {
                    case let .success(credential):
                        self.handleRefreshSuccess(credential, insideLock: &mutableState)
                    case let .failure(error):
                        self.handleRefreshFailure(error, insideLock: &mutableState)
                    }
                }
            }
        }
    }
    
    /// 判断是否过度刷新
    private func isRefreshExcessive(insideLock mutableState: inout MutableState) -> Bool {
        // refreshWindow是判断过度刷新的参考，没有refreshWindow时说明不限制刷新
        guard let refreshWindow = mutableState.refreshWindow else { return false }
        // 计算可刷新的时间点
        let refreshWindowMin = ProcessInfo.processInfo.systemUptime - refreshWindow.interval
        // 统计在可刷新时间点之后的刷新次数
        let refreshAttemptsWithinWindow = mutableState.refreshTimestamps.reduce(into: 0) { attempts, refreshTimestamp in
            guard refreshWindowMin <= refreshTimestamp else { return }
            attempts += 1
        }
        // 若刷新次数 大于等于 配置的最大允许刷新次数，认为过度刷新
        let isRefreshExcessive = refreshAttemptsWithinWindow >= refreshWindow.maximumAttempts

        return isRefreshExcessive
    }
    // 处理刷新成功
    private func handleRefreshSuccess(_ credential: Credential, insideLock mutableState: inout MutableState) {
        // 记录新的凭证
        mutableState.credential = credential

        // 将后续操作取出，移除原始记录
        let adaptOperations = mutableState.adaptOperations
        let requestsToRetry = mutableState.requestsToRetry
        mutableState.adaptOperations.removeAll()
        mutableState.requestsToRetry.removeAll()
        // 重置刷新标志
        mutableState.isRefreshing = false
        // 异步执行后续步骤，以便快速跳出lock
        // Dispatch to queue to hop out of the mutable state lock
        queue.async {
            // 需要适配的继续适配
            adaptOperations.forEach { self.adapt($0.urlRequest, for: $0.session, completion: $0.completion) }
            // 需要重试的继续重试
            requestsToRetry.forEach { $0(.retry) }
        }
    }
    // 处理刷新失败
    private func handleRefreshFailure(_ error: Error, insideLock mutableState: inout MutableState) {
        // 将后续操作取出，移除原始记录
        let adaptOperations = mutableState.adaptOperations
        let requestsToRetry = mutableState.requestsToRetry
        mutableState.adaptOperations.removeAll()
        mutableState.requestsToRetry.removeAll()
        // 重置刷新标志
        mutableState.isRefreshing = false

        // Dispatch to queue to hop out of the mutable state lock
        queue.async {
            // 需要适配的直接回调失败
            adaptOperations.forEach { $0.completion(.failure(error)) }
            // 需要重试的，不再重试
            requestsToRetry.forEach { $0(.doNotRetryWithError(error)) }
        }
    }
}
