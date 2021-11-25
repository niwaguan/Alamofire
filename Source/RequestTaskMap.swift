//
//  RequestTaskMap.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
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
/// 记录`URLSessionTask`和 `Request`之间的一对一映射
/// A type that maintains a two way, one to one map of `URLSessionTask`s to `Request`s.
struct RequestTaskMap {
    private typealias Events = (completed: Bool, metricsGathered: Bool)

    private var tasksToRequests: [URLSessionTask: Request]
    private var requestsToTasks: [Request: URLSessionTask]
    private var taskEvents: [URLSessionTask: Events]

    var requests: [Request] {
        Array(tasksToRequests.values)
    }

    init(tasksToRequests: [URLSessionTask: Request] = [:],
         requestsToTasks: [Request: URLSessionTask] = [:],
         taskEvents: [URLSessionTask: (completed: Bool, metricsGathered: Bool)] = [:]) {
        self.tasksToRequests = tasksToRequests
        self.requestsToTasks = requestsToTasks
        self.taskEvents = taskEvents
    }

    subscript(_ request: Request) -> URLSessionTask? {
        get { requestsToTasks[request] }
        set {
            guard let newValue = newValue else {
                guard let task = requestsToTasks[request] else {
                    fatalError("RequestTaskMap consistency error: no task corresponding to request found.")
                }

                requestsToTasks.removeValue(forKey: request)
                tasksToRequests.removeValue(forKey: task)
                taskEvents.removeValue(forKey: task)

                return
            }

            requestsToTasks[request] = newValue
            tasksToRequests[newValue] = request
            taskEvents[newValue] = (completed: false, metricsGathered: false)
        }
    }

    subscript(_ task: URLSessionTask) -> Request? {
        get { tasksToRequests[task] }
        set {
            guard let newValue = newValue else {
                guard let request = tasksToRequests[task] else {
                    fatalError("RequestTaskMap consistency error: no request corresponding to task found.")
                }

                tasksToRequests.removeValue(forKey: task)
                requestsToTasks.removeValue(forKey: request)
                taskEvents.removeValue(forKey: task)

                return
            }

            tasksToRequests[task] = newValue
            requestsToTasks[newValue] = task
            taskEvents[task] = (completed: false, metricsGathered: false)
        }
    }

    var count: Int {
        precondition(tasksToRequests.count == requestsToTasks.count,
                     "RequestTaskMap.count invalid, requests.count: \(tasksToRequests.count) != tasks.count: \(requestsToTasks.count)")

        return tasksToRequests.count
    }

    var eventCount: Int {
        precondition(taskEvents.count == count, "RequestTaskMap.eventCount invalid, count: \(count) != taskEvents.count: \(taskEvents.count)")

        return taskEvents.count
    }

    var isEmpty: Bool {
        precondition(tasksToRequests.isEmpty == requestsToTasks.isEmpty,
                     "RequestTaskMap.isEmpty invalid, requests.isEmpty: \(tasksToRequests.isEmpty) != tasks.isEmpty: \(requestsToTasks.isEmpty)")

        return tasksToRequests.isEmpty
    }

    var isEventsEmpty: Bool {
        precondition(taskEvents.isEmpty == isEmpty, "RequestTaskMap.isEventsEmpty invalid, isEmpty: \(isEmpty) != taskEvents.isEmpty: \(taskEvents.isEmpty)")

        return taskEvents.isEmpty
    }
    
    /// 在收集到统计信息后调用
    mutating func disassociateIfNecessaryAfterGatheringMetricsForTask(_ task: URLSessionTask) -> Bool {
        guard let events = taskEvents[task] else {
            fatalError("RequestTaskMap consistency error: no events corresponding to task found.")
        }

        switch (events.completed, events.metricsGathered) {
        // 统计信息已经完成，不应该再次进入该方法
        case (_, true): fatalError("RequestTaskMap consistency error: duplicate metricsGatheredForTask call.")
        // task未完成，统计信息未收集。此时标记task的统计信息以收集
        case (false, false): taskEvents[task] = (completed: false, metricsGathered: true); return false
        // task已经完成，统计信息未收集。此时可以直接移除task记录
        case (true, false): self[task] = nil; return true
        }
    }
    
    /// 在task完成后调用，标记状态
    mutating func disassociateIfNecessaryAfterCompletingTask(_ task: URLSessionTask) -> Bool {
        guard let events = taskEvents[task] else {
            fatalError("RequestTaskMap consistency error: no events corresponding to task found.")
        }

        switch (events.completed, events.metricsGathered) {
        // 已经完成的task，不应该再次进入该方法
        case (true, _): fatalError("RequestTaskMap consistency error: duplicate completionReceivedForTask call.")
        #if os(Linux) // Linux doesn't gather metrics, so unconditionally remove the reference and return true.
        default: self[task] = nil; return true
        #else
        // task没有完成，统计信息未收集。此时标task务完成
        case (false, false):
            if #available(macOS 10.12, iOS 10, watchOS 7, tvOS 10, *) {
                taskEvents[task] = (completed: true, metricsGathered: false); return false
            } else {
                // watchOS < 7 doesn't gather metrics, so unconditionally remove the reference and return true.
                self[task] = nil; return true
            }
        // task没有完成，统计信息已经收集。此时直接移除该task记录
        case (false, true):
            self[task] = nil; return true
        #endif
        }
    }
}
