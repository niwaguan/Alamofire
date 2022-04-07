//
//  DumpTrustMonitor.swift
//  iOS Example
//
//  Created by Gaoyang on 2022/4/1.
//  Copyright © 2022 Alamofire. All rights reserved.
//

import Foundation
import Alamofire

class DumpTrustMoniter: EventMonitor {
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) {
        _dumpTrustInfo(challenge.protectionSpace.serverTrust)
    }
    
    func _dumpTrustInfo(_ trust: SecTrust?) {
        guard let trust = trust else {
            print("nothing to dump")
            return
        }
        print("start dump")
        let cerCount = SecTrustGetCertificateCount(trust)
        for i in 0..<cerCount {
            guard
                let cer = SecTrustGetCertificateAtIndex(trust, i),
                let summary = SecCertificateCopySubjectSummary(cer) else {
                continue
            }
            print(summary)
        }
        print("----end---")
    }
}
