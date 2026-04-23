//
//  ContentView.swift
//  iFans
//
//  Created by 伟（Wade） 王 on 2026/4/17.
//

import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if showsMenuBarPanelForUITesting {
                MenuBarPanelView()
            } else {
                DashboardView(model: model)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.clear, for: .window)
        .background {
            TransparentWindowConfigurator()
        }
    }

    private var showsMenuBarPanelForUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-test-menu-panel")
    }
}

#Preview {
    ContentView()
        .environment(AppModel(provider: PreviewHardwareProvider()))
}

private struct TransparentWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configure(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }

            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.styleMask.insert(.fullSizeContentView)
            window.toolbar?.showsBaselineSeparator = false
        }
    }
}


