//
//  MiniSnapWatchApp.swift
//  MiniSnapWatch Watch App
//
//  Created by 江逸帆 on 6/8/26.
//

import SwiftUI

@main
struct MiniSnapWatch_Watch_AppApp: App {
    @StateObject private var previewReceiver = WatchPreviewReceiver()

    var body: some Scene {
        WindowGroup {
            WatchPreviewView(receiver: previewReceiver)
        }
    }
}
