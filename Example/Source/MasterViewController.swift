//
//  MasterViewController.swift
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

import Alamofire
import UIKit

/// 负责向请求中添加自定义的签名请求头
private
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
        completion(.retry)
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

class MasterViewController: UITableViewController {
    // MARK: - Properties

    @IBOutlet var titleImageView: UIImageView!

    var detailViewController: DetailViewController?

    private var reachability: NetworkReachabilityManager!
    
    private let session = Session(interceptor: SignRequestInterceptor())

    // MARK: - View Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()

        navigationItem.titleView = titleImageView
        clearsSelectionOnViewWillAppear = true

        reachability = NetworkReachabilityManager.default
        monitorReachability()
        
    }

    // MARK: - UIStoryboardSegue

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if
            let navigationController = segue.destination as? UINavigationController,
            let detailViewController = navigationController.topViewController as? DetailViewController {
            func requestForSegue(_ segue: UIStoryboardSegue) -> Request? {
                switch segue.identifier! {
                case "GET":
                    detailViewController.segueIdentifier = "GET"
                    return session.request("https://httpbin.org/get")
                case "POST":
                    detailViewController.segueIdentifier = "POST"
//                    return session.request("https://httpbin.org/post", method: .post)
                    return AF.request("https://httpbin.org/post", interceptor: SignRequestInterceptor())
                case "PUT":
                    detailViewController.segueIdentifier = "PUT"
                    return session.request("https://httpbin.org/put", method: .put)
                case "DELETE":
                    detailViewController.segueIdentifier = "DELETE"
                    return session.request("https://httpbin.org/delete", method: .delete)
                case "DOWNLOAD":
                    detailViewController.segueIdentifier = "DOWNLOAD"
                    let destination = DownloadRequest.suggestedDownloadDestination(for: .cachesDirectory,
                                                                                   in: .userDomainMask)
                    return session.download("https://httpbin.org/stream/1", to: destination)
                default:
                    return nil
                }
            }

            if let request = requestForSegue(segue) {
                detailViewController.request = request
            }
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 3 && indexPath.row == 0 {
            print("Reachability Status: \(reachability.status)")
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    // MARK: - Private - Reachability

    private func monitorReachability() {
        reachability.startListening { status in
            print("Reachability Status Changed: \(status)")
        }
    }
}
