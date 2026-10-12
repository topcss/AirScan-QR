//
//  WebReceiverView.swift
//  ios-cfc-client
//
//  SwiftUI 包装：把 WebReceiverViewController（WKWebView 接收端）嵌入界面。
//
//  布局职责划分（v1.3.0 起）：
//   · 相机取景 + 实时进度面板全部由 harness.html 负责（上下分区，互不遮挡），
//     因为网页内 HUD 是同一线程内的直接渲染，不受 postMessage / 轮询滞后影响；
//   · 原生侧只负责文件落地后的预览 / 保存 / 分享，避免两套 HUD 互相压叠。
//

import SwiftUI
import UIKit

struct WebReceiverView: View {
    // 完成文件
    @State private var receivedFile: (name: String, data: Data)?
    @State private var showPreview = false
    // 每次自增即通知网页复位进度面板，继续扫描下一个文件
    @State private var resetToken = 0

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea()

            WebReceiverRepresentable(
                resetToken: resetToken,
                onFile: { name, data in
                    receivedFile = (name, data)
                    showPreview = true
                }
            )

            // 完成文件弹窗
            if showPreview, let f = receivedFile {
                Color.black.opacity(0.4).ignoresSafeArea()
                FilePreviewView(fileName: f.name, fileData: f.data) {
                    showPreview = false
                    receivedFile = nil
                    resetToken += 1
                }
                .transition(.scale)
            }
        }
    }
}

// MARK: - UIViewControllerRepresentable
struct WebReceiverRepresentable: UIViewControllerRepresentable {
    var resetToken: Int = 0
    var onFile: (String, Data) -> Void
    var onStatus: ((String) -> Void)?

    final class Coordinator {
        var lastResetToken = 0
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> WebReceiverViewController {
        let vc = WebReceiverViewController()
        vc.onFile = { name, data in DispatchQueue.main.async { onFile(name, data) } }
        vc.onStatus = { s in DispatchQueue.main.async { onStatus?(s) } }
        context.coordinator.lastResetToken = resetToken
        return vc
    }

    func updateUIViewController(_ uiViewController: WebReceiverViewController, context: Context) {
        guard context.coordinator.lastResetToken != resetToken else { return }
        context.coordinator.lastResetToken = resetToken
        uiViewController.resetWebHUD()
    }
}
