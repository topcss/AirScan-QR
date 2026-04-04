#!/bin/bash
# 生成自签名 SSL 证书脚本
# 用于 https_server.py

echo "=========================================="
echo "🔐 生成自签名 SSL 证书"
echo "=========================================="
echo ""

# 检查 openssl 是否安装
if ! command -v openssl &> /dev/null; then
    echo "❌ 错误: 未找到 openssl 命令"
    echo "请先安装 openssl:"
    echo "  macOS: brew install openssl"
    echo "  Ubuntu/Debian: sudo apt-get install openssl"
    exit 1
fi

echo "✅ 检测到 openssl"
echo ""

# 生成证书
echo "📝 正在生成证书..."
openssl req -x509 -newkey rsa:2048 \
    -keyout key.pem \
    -out cert.pem \
    -days 365 \
    -nodes \
    -subj "/C=CN/ST=Beijing/L=Beijing/O=AirScan-QR/CN=localhost" \
    2>&1

# 检查是否成功
if [ -f "cert.pem" ] && [ -f "key.pem" ]; then
    echo ""
    echo "=========================================="
    echo "✅ 证书生成成功！"
    echo "=========================================="
    echo ""
    echo "📄 生成的文件:"
    ls -lh cert.pem key.pem
    echo ""
    echo "📅 有效期: 365 天"
    echo "🌐 域名: localhost"
    echo ""
    echo "💡 现在可以运行:"
    echo "   python3 https_server.py"
    echo ""
    echo "⚠️  浏览器会显示安全警告（因为是自签名证书）"
    echo "   点击「高级」→「继续访问」即可"
    echo ""
else
    echo ""
    echo "❌ 证书生成失败"
    exit 1
fi
