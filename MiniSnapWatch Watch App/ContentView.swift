//
//  ContentView.swift
//  MiniSnapWatch Watch App
//
//  Created by 江逸帆 on 6/8/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        WatchPreviewView(receiver: WatchPreviewReceiver())
    }
}

#Preview {
    ContentView()
}
