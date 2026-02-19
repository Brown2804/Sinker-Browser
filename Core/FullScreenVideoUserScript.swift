//
//  FullScreenVideoUserScript.swift
//  DuckDuckGo
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import WebKit
import UserScript
import os.log

public extension Notification.Name {
    static let sinkerVideoDetected = Notification.Name("sinkerVideoDetected")
}

public final class FullScreenVideoUserScript: NSObject, UserScript {

    private enum Keys {
        static let handlerName = "videoPlayHandler"
        static let action = "action"
        static let videoDetected = "videoDetected"
        static let src = "src"
        static let resolvedSrc = "resolvedSrc"
        static let title = "title"
        static let referrer = "referrer"
        static let originalBlobSrc = "originalBlobSrc"
    }

    private let logger = Logger(subsystem: "com.duckduckgo.ios", category: "SinkerVideo")

    public var source: String {
        Self.loadJS("fullscreenvideo", from: Bundle.core)
    }

    public var injectionTime: WKUserScriptInjectionTime = .atDocumentEnd
    public var forMainFrameOnly: Bool = false
    public var messageNames: [String] = [Keys.handlerName]
    public var requiresRunInPageContentWorld: Bool { true }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Keys.handlerName,
              let body = message.body as? [String: Any],
              let action = body[Keys.action] as? String,
              action == Keys.videoDetected,
              let incomingSrc = body[Keys.src] as? String,
              let incomingURL = URL(string: incomingSrc),
              let incomingScheme = incomingURL.scheme?.lowercased(),
              ["http", "https", "blob"].contains(incomingScheme)
        else {
            return
        }

        var finalSrc = incomingSrc
        var originalBlobSrc: String?

        if incomingScheme == "blob",
           let resolvedSrc = body[Keys.resolvedSrc] as? String,
           let resolvedURL = URL(string: resolvedSrc),
           let resolvedScheme = resolvedURL.scheme?.lowercased(),
           ["http", "https"].contains(resolvedScheme) {
            finalSrc = resolvedSrc
            originalBlobSrc = incomingSrc
        }

        let title = body[Keys.title] as? String ?? "Unknown Video"
        let referrer = body[Keys.referrer] as? String ?? ""

        logger.debug("Detected video source: \(finalSrc, privacy: .public)")

        var userInfo: [String: String] = [
            Keys.src: finalSrc,
            Keys.title: title,
            Keys.referrer: referrer
        ]
        if let originalBlobSrc {
            userInfo[Keys.originalBlobSrc] = originalBlobSrc
        }

        NotificationCenter.default.post(
            name: .sinkerVideoDetected,
            object: nil,
            userInfo: userInfo
        )
    }
}
