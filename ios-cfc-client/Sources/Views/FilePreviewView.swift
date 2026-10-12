//
//  FilePreviewView.swift
//  ios-cfc-client
//
//  File Preview & Native iOS Share Sheet Controller
//

import SwiftUI
import UIKit

struct FilePreviewView: View {
    let fileName: String
    let fileData: Data
    let onDismiss: () -> Void

    @State private var isSharing = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("🎉 文件接收成功")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(fileName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("\(fileData.count / 1024) KB")
                    .font(.caption)
                    .fontDesign(.monospaced)
                    .foregroundColor(.gray)
            }

            VStack(spacing: 12) {
                Button(action: {
                    isSharing = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("保存到文件 / 分享")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(14)
                }

                Button(action: onDismiss) {
                    Text("完成并返回")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(32)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(24)
        .shadow(radius: 20)
        .sheet(isPresented: $isSharing) {
            if let url = createTemporaryFileURL() {
                ShareSheet(activityItems: [url])
            } else {
                Text("无法写入临时文件，分享失败")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    /// 文件名来自发送端的 zstd 头（cimbard_get_filename），属不可信输入：
    /// 只取最后一段并剔除分隔符，避免 "a/b.bin" 落到不存在的子目录里。
    private func createTemporaryFileURL() -> URL? {
        var safe = (fileName as NSString).lastPathComponent
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        if safe.isEmpty || safe == "." || safe == ".." { safe = "received.bin" }

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(safe)
        do {
            try fileData.write(to: fileURL)
        } catch {
            NSLog("[FilePreview] 写入临时文件失败 \(safe): \(error)")
            return nil
        }
        return fileURL
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
