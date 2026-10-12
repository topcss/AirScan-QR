//
//  MainView.swift
//  ios-cfc-client
//
//  Main iOS SwiftUI Navigation View
//

import SwiftUI

struct MainView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WebReceiverView()
                .tabItem {
                    Label("扫码接收", systemImage: "qrcode.viewfinder")
                }
                .tag(0)

            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)

                    Text("AirScan / CFC 传输说明")
                        .font(.title2)
                        .fontWeight(.bold)

                    VStack(alignment: .leading, spacing: 12) {
                        Label("支持标准单码、喷泉码 4C 与 Cimbar 全协议自动识别", systemImage: "qrcode")
                        Label("Cimbar 走 WebAssembly + 3 Worker 并行解码与 Zstd 解压", systemImage: "cpu")
                        Label("标准单码 / 喷泉码走内置 jsQR，全帧 + 四象限同时扫描", systemImage: "square.grid.2x2")
                        Label("迟滞平滑消抖，扫码过程连续不跳变", systemImage: "timer")
                        Label("目标丢失自动暂停计时，识别后恢复起表", systemImage: "pause.circle")
                        Label("解码全程在本机完成，不联网、不上传任何数据", systemImage: "shield.checkerboard")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    VStack(spacing: 8) {
                        Text("🌐 发送端在线体验地址（需联网打开，接收端本身不联网）：")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Link(destination: URL(string: "https://zxq1002.github.io/AirScan-QR")!) {
                            HStack {
                                Image(systemName: "safari.fill")
                                Text("https://zxq1002.github.io/AirScan-QR")
                                    .fontWeight(.bold)
                            }
                            .font(.footnote)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.top, 4)

                    Text("⏱ iOS 端实测传输速度对比：\n• ⚡ Cimbar 高速色码：1MB 约 32 秒（15 FPS，推荐）\n• 🌊 喷泉码 4C：100KB 约 50 秒\n• 📷 标准单码：30KB 约 50 秒\n\n耗时还取决于帧率、光照、距离与机型。大文件建议优先使用 Cimbar 高速色码模式。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    Spacer(minLength: 30)
                }
                .padding(.top, 30)
            }
            .tabItem {
                Label("关于算法", systemImage: "info.circle")
            }
            .tag(1)
        }
        .accentColor(.blue)
    }
}
