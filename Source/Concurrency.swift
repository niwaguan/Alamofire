//
//  Concurrency.swift
//
//  Copyright (c) 2021 Alamofire Software Foundation (http://alamofire.org/)
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

#if compiler(>=5.5.2) && canImport(_Concurrency)

import Foundation

/// Value used to `await` a `DataResponse` and associated values.
///
/// `DataTask` additionally exposes the read-only properties available from the underlying `DataRequest`.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
@dynamicMemberLookup
public struct DataTask<Value> {
    /// `DataResponse` produced by the `DataRequest` and its response handler.
    public var response: DataResponse<Value, AFError> {
        get async {
            if shouldAutomaticallyCancel {
                return await withTaskCancellationHandler {
                    self.cancel()
                } operation: {
                    await task.value
                }
            } else {
                return await task.value
            }
        }
    }

    /// `Result` of any response serialization performed for the `response`.
    public var result: Result<Value, AFError> {
        get async { await response.result }
    }

    /// `Value` returned by the `response`.
    public var value: Value {
        get async throws {
            try await result.get()
        }
    }

    private let request: DataRequest
    private let task: Task<DataResponse<Value, AFError>, Never>
    private let shouldAutomaticallyCancel: Bool

    fileprivate init(request: DataRequest, task: Task<DataResponse<Value, AFError>, Never>, shouldAutomaticallyCancel: Bool) {
        self.request = request
        self.task = task
        self.shouldAutomaticallyCancel = shouldAutomaticallyCancel
    }

    /// Cancel the underlying `DataRequest` and `Task`.
    public func cancel() {
        task.cancel()
    }

    /// Resume the underlying `DataRequest`.
    public func resume() {
        request.resume()
    }

    /// Suspend the underlying `DataRequest`.
    public func suspend() {
        request.suspend()
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<DataRequest, T>) -> T {
        request[keyPath: keyPath]
    }
}

extension DispatchQueue {
    fileprivate static let singleCompletionQueue = DispatchQueue(label: "org.alamofire.concurrencySingleCompletionQueue",
                                                                 attributes: .concurrent)

    fileprivate static var streamCompletionQueue: DispatchQueue {
        DispatchQueue(label: "org.alamofire.concurrencyStreamCompletionQueue")
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DataRequest {
    /// Creates a `DataTask` to `await` serialization of a `Decodable` value.
    ///
    /// - Parameters:
    ///   - type:                `Decodable` type to decode from response data.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the serializer.
    ///                          `PassthroughPreprocessor()` by default.
    ///   - decoder:             `DataDecoder` to use to decode the response. `JSONDecoder()` by default.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns: The `DataTask`.
    public func serializingDecodable<Value: Decodable>(_ type: Value.Type = Value.self,
                                                       automaticallyCancelling shouldAutomaticallyCancel: Bool = false,
                                                       dataPreprocessor: DataPreprocessor = DecodableResponseSerializer<Value>.defaultDataPreprocessor,
                                                       decoder: DataDecoder = JSONDecoder(),
                                                       emptyResponseCodes: Set<Int> = DecodableResponseSerializer<Value>.defaultEmptyResponseCodes,
                                                       emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer<Value>.defaultEmptyRequestMethods) -> DataTask<Value> {
        serializingResponse(using: DecodableResponseSerializer<Value>(dataPreprocessor: dataPreprocessor,
                                                                      decoder: decoder,
                                                                      emptyResponseCodes: emptyResponseCodes,
                                                                      emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
    }

    /// Creates a `DataTask` to `await` serialization of a `String` value.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the serializer.
    ///                          `PassthroughPreprocessor()` by default.
    ///   - encoding:            `String.Encoding` to use during serialization. Defaults to `nil`, in which case the
    ///                          encoding will be determined from the server response, falling back to the default HTTP
    ///                          character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns: The `DataTask`.
    public func serializingString(automaticallyCancelling shouldAutomaticallyCancel: Bool = false,
                                  dataPreprocessor: DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                                  encoding: String.Encoding? = nil,
                                  emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                                  emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods) -> DataTask<String> {
        serializingResponse(using: StringResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                            encoding: encoding,
                                                            emptyResponseCodes: emptyResponseCodes,
                                                            emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
    }

    /// Creates a `DataTask` to `await` a `Data` value.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before completion.
    ///   - emptyResponseCodes:  HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns: The `DataTask`.
    public func serializingData(automaticallyCancelling shouldAutomaticallyCancel: Bool = false,
                                dataPreprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                                emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                                emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods) -> DataTask<Data> {
        serializingResponse(using: DataResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                          emptyResponseCodes: emptyResponseCodes,
                                                          emptyRequestMethods: emptyRequestMethods),
                            automaticallyCancelling: shouldAutomaticallyCancel)
    }

    /// Creates a `DataTask` to `await` serialization using the provided `DataResponseSerializerProtocol` instance.
    ///
    /// - Parameters:
    ///    - serializer: Response serializer responsible for serializing the request, response, and data.
    ///
    /// - Returns: The `DataTask`.
    public func serializingResponse<Serializer: DataResponseSerializerProtocol>(using serializer: Serializer,
                                                                                automaticallyCancelling shouldAutomaticallyCancel: Bool = false)
        -> DataTask<Serializer.SerializedObject> {
        dataTask(automaticallyCancelling: shouldAutomaticallyCancel) {
            self.response(queue: .singleCompletionQueue,
                          responseSerializer: serializer,
                          completionHandler: $0)
        }
    }

    private func dataTask<Value>(automaticallyCancelling shouldAutomaticallyCancel: Bool,
                                 forResponse onResponse: @escaping (@escaping (DataResponse<Value, AFError>) -> Void) -> Void) -> DataTask<Value> {
        let task = Task {
            await withTaskCancellationHandler {
                self.cancel()
            } operation: {
                await withCheckedContinuation { continuation in
                    onResponse {
                        continuation.resume(returning: $0)
                    }
                }
            }
        }

        return DataTask<Value>(request: self, task: task, shouldAutomaticallyCancel: shouldAutomaticallyCancel)
    }
}

/// Value used to `await` a `DownloadResponse` and associated values.
///
/// `DownloadTask` additionally exposes the read-only properties available from the underlying `DownloadRequest`.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
@dynamicMemberLookup
public struct DownloadTask<Value> {
    /// `DataResponse` produced by the `DataRequest` and its response handler.
    public var response: DownloadResponse<Value, AFError> {
        get async { await task.value }
    }

    /// `Result` of any response serialization performed for the `response`.
    public var result: Result<Value, AFError> {
        get async { await response.result }
    }

    /// `Value` returned by the `response`.
    public var value: Value {
        get async throws {
            try await result.get()
        }
    }

    private let task: Task<AFDownloadResponse<Value>, Never>
    private let request: DownloadRequest

    fileprivate init(request: DownloadRequest, task: Task<AFDownloadResponse<Value>, Never>) {
        self.request = request
        self.task = task
    }

    /// Cancel the underlying `DownloadRequest` and `Task`.
    public func cancel() {
        task.cancel()
    }

    /// Resume the underlying `DownloadRequest`.
    public func resume() {
        request.resume()
    }

    /// Suspend the underlying `DownloadRequest`.
    public func suspend() {
        request.suspend()
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<DownloadRequest, T>) -> T {
        request[keyPath: keyPath]
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DownloadRequest {
    /// Creates a `DownloadTask` to `await` a `Data` value.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before completion.
    ///   - emptyResponseCodes:  HTTP response codes for which empty responses are allowed. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns: The `DownloadTask`.
    public func data(dataPreprocessor: DataPreprocessor = DataResponseSerializer.defaultDataPreprocessor,
                     emptyResponseCodes: Set<Int> = DataResponseSerializer.defaultEmptyResponseCodes,
                     emptyRequestMethods: Set<HTTPMethod> = DataResponseSerializer.defaultEmptyRequestMethods) -> DownloadTask<Data> {
        serialize(using: DataResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                emptyResponseCodes: emptyResponseCodes,
                                                emptyRequestMethods: emptyRequestMethods))
    }

    /// Creates a `DownloadTask` to `await` serialization of a `Decodable` value.
    ///
    /// - Note: This serializer reads the entire response into memory before parsing.
    ///
    /// - Parameters:
    ///   - type:                `Decodable` type to decode from response data.
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the serializer.
    ///                          `PassthroughPreprocessor()` by default.
    ///   - decoder:             `DataDecoder` to use to decode the response. `JSONDecoder()` by default.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns: The `DownloadTask`.
    public func decode<Value: Decodable>(_ type: Value.Type = Value.self,
                                         dataPreprocessor: DataPreprocessor = DecodableResponseSerializer<Value>.defaultDataPreprocessor,
                                         decoder: DataDecoder = JSONDecoder(),
                                         emptyResponseCodes: Set<Int> = DecodableResponseSerializer<Value>.defaultEmptyResponseCodes,
                                         emptyRequestMethods: Set<HTTPMethod> = DecodableResponseSerializer<Value>.defaultEmptyRequestMethods) -> DownloadTask<Value> {
        serialize(using: DecodableResponseSerializer<Value>(dataPreprocessor: dataPreprocessor,
                                                            decoder: decoder,
                                                            emptyResponseCodes: emptyResponseCodes,
                                                            emptyRequestMethods: emptyRequestMethods))
    }

    /// Creates a `DownloadTask` to `await` serialization of a `String` value.
    ///
    /// - Parameters:
    ///   - dataPreprocessor:    `DataPreprocessor` which processes the received `Data` before calling the serializer.
    ///                          `PassthroughPreprocessor()` by default.
    ///   - encoding:            `String.Encoding` to use during serialization. Defaults to `nil`, in which case the
    ///                          encoding will be determined from the server response, falling back to the default HTTP
    ///                          character set, `ISO-8859-1`.
    ///   - emptyResponseCodes:  HTTP status codes for which empty responses are always valid. `[204, 205]` by default.
    ///   - emptyRequestMethods: `HTTPMethod`s for which empty responses are always valid. `[.head]` by default.
    ///
    /// - Returns: The `DownloadTask`.
    public func string(dataPreprocessor: DataPreprocessor = StringResponseSerializer.defaultDataPreprocessor,
                       encoding: String.Encoding? = nil,
                       emptyResponseCodes: Set<Int> = StringResponseSerializer.defaultEmptyResponseCodes,
                       emptyRequestMethods: Set<HTTPMethod> = StringResponseSerializer.defaultEmptyRequestMethods) -> DownloadTask<String> {
        serialize(using: StringResponseSerializer(dataPreprocessor: dataPreprocessor,
                                                  encoding: encoding,
                                                  emptyResponseCodes: emptyResponseCodes,
                                                  emptyRequestMethods: emptyRequestMethods))
    }

    /// Creates a `DownloadTask` to `await` the return of the downloaded file's `URL`.
    ///
    /// - Returns: The `DownloadTask`.
    public func downloadedFileURL() -> DownloadTask<URL> {
        serialize(using: URLResponseSerializer())
    }

    /// Creates a `DownloadTask` to `await` serialization using the provided `DownloadResponseSerializerProtocol`
    /// instance.
    ///
    /// - Parameters:
    ///    - serializer: Download serializer responsible for serializing the request, response, and data.
    ///
    /// - Returns: The `DownloadTask`.
    public func serialize<Serializer: DownloadResponseSerializerProtocol>(using serializer: Serializer) -> DownloadTask<Serializer.SerializedObject> {
        downloadTask {
            self.response(queue: .singleCompletionQueue,
                          responseSerializer: serializer,
                          completionHandler: $0)
        }
    }

    private func downloadTask<Value>(forResponse onResponse: @escaping (@escaping (DownloadResponse<Value, AFError>) -> Void) -> Void) -> DownloadTask<Value> {
        let task = Task {
            await withTaskCancellationHandler {
                self.cancel()
            } operation: {
                await withCheckedContinuation { continuation in
                    onResponse {
                        continuation.resume(returning: $0)
                    }
                }
            }
        }

        return DownloadTask<Value>(request: self, task: task)
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
@dynamicMemberLookup
public struct DataStreamTask {
    public typealias Stream<Success, Failure: Error> = AsyncStream<DataStreamRequest.Stream<Success, Failure>>
    private let request: DataStreamRequest

    fileprivate init(request: DataStreamRequest) {
        self.request = request
    }

    public func streamData(bufferingPolicy: Stream<Data, Never>.Continuation.BufferingPolicy = .unbounded) -> Stream<Data, Never> {
        createStream(bufferingPolicy: bufferingPolicy) { onStream in
            self.request.responseStream(on: .streamCompletionQueue, stream: onStream)
        }
    }

    public func streamStrings(bufferingPolicy: Stream<String, Never>.Continuation.BufferingPolicy = .unbounded) -> Stream<String, Never> {
        createStream(bufferingPolicy: bufferingPolicy) { onStream in
            self.request.responseStreamString(on: .streamCompletionQueue, stream: onStream)
        }
    }

    public func stream<Serializer: DataStreamSerializer>(serializedUsing serializer: Serializer,
                                                         bufferingPolicy: Stream<Serializer.SerializedObject, AFError>.Continuation.BufferingPolicy = .unbounded)
        -> Stream<Serializer.SerializedObject, AFError> {
        createStream(bufferingPolicy: bufferingPolicy) { onStream in
            self.request.responseStream(using: serializer, on: .streamCompletionQueue, stream: onStream)
        }
    }

    private func createStream<Success, Failure: Error>(bufferingPolicy: Stream<Success, Failure>.Continuation.BufferingPolicy = .unbounded,
                                                       forResponse onResponse: @escaping (@escaping (DataStreamRequest.Stream<Success, Failure>) -> Void) -> Void)
        -> Stream<Success, Failure> {
        Stream(bufferingPolicy: bufferingPolicy) { continuation in
            continuation.onTermination = { @Sendable termination in
                if case .cancelled = termination {
                    request.cancel()
                }
            }

            onResponse { stream in
                continuation.yield(stream)
                if case .complete = stream.event {
                    continuation.finish()
                }
            }
        }
    }

    /// Cancel the underlying `DataStreamRequest`.
    public func cancel() {
        request.cancel()
    }

    /// Resume the underlying `DataStreamRequest`.
    public func resume() {
        request.resume()
    }

    /// Suspend the underlying `DataStreamRequest`.
    public func suspend() {
        request.suspend()
    }

    public subscript<T>(dynamicMember keyPath: KeyPath<DataStreamRequest, T>) -> T {
        request[keyPath: keyPath]
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DataStreamRequest {
    public func task() -> DataStreamTask {
        DataStreamTask(request: self)
    }
}

#endif
