#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AirScan-QR · 本地服务器（单文件，图形界面）

双击运行即可（.pyw 不会弹黑框）。

- 端口随便改，点「启动」后网页就能打开
- HTTPS 用的是脚本里内置的自签证书，**不需要本机装 openssl**
  （浏览器会提示"不安全"，点"继续前往"就行）
- 手机当接收端（用摄像头）必须选 HTTPS；手机只当发送端用 HTTP 也可以
"""

import http.server
import os
import queue
import socket
import ssl
import sys
import tempfile
import threading
import time
import webbrowser
import tkinter as tk
from tkinter import ttk, messagebox

APP = "AirScan-QR"
ROOT = os.path.dirname(os.path.abspath(__file__))
DEFAULT_PORT = 8080

# 内置自签证书（有效期到 2036 年；仅用于本机/局域网自测）
CERT_PEM = """\
-----BEGIN CERTIFICATE-----
MIIDLTCCAhWgAwIBAgIUc3JwAVeKH/trhBFtuTMkiGWQebcwDQYJKoZIhvcNAQEL
BQAwFTETMBEGA1UEAwwKQWlyU2Nhbi1RUjAeFw0yNjExMTEwODMwNDJaFw0zNjEx
MDgwODMwNDJaMBUxEzARBgNVBAMMCkFpclNjYW4tUVIwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQC7s/++rYd9hRNCh2gOu+igW0Olf/oSpsZzi4VIsRtO
YvcsQ2PSxO+Kmlcr/t0+MWUK1RhGJ5m3EbiaiNLg733i5EGZPGz0XtCv/OP8xY7X
opRB56jlYY/XLKEG7n4FbX/DkfgK+xxGjFi5xJaP1GyC8gSyw8W9iS9/Gv7ecNuO
FBvrJkCeEryz142bH00PJYnuL9xGEB5+Avb543gyVUcOFEluYkTZSEnP0Uk8zxaU
I2/j1hz+2cjMX7jnHrCmpKtZI9cpuUSd3GscRN6V19+2mnVOaw20FVnMXEA+kGDU
K4eHuccw3psZOh8FXkWn8hPwhMmo3t1MJZoqA920Ygt3AgMBAAGjdTBzMB0GA1Ud
DgQWBBQFsBe+ZsAHy1eG8X7vAuCqvZsx2DAfBgNVHSMEGDAWgBQFsBe+ZsAHy1eG
8X7vAuCqvZsx2DAPBgNVHRMBAf8EBTADAQH/MCAGA1UdEQQZMBeCCWxvY2FsaG9z
dIcEfwAAAYcEAAAAADANBgkqhkiG9w0BAQsFAAOCAQEAoTNEZGHkUjvaqw4Bzm2A
RHYeeFJw7yDIhFDLxrqwIxSpIIXkLFiKlhrGVUZSiFDrOmm6S7QjcLnbdFqMMMGh
aJemmT8I0R1kryVJBEoHvLux3E85yZl5XrAkjppBSwHZO/oTVxCY0Cc4466664UQ
gy9/cLJ76l3yHAW1YdoJPTKPM1HzmhgrWD7Z5NyScp/4QM7DnBFpUF1Jn1RwGWMN
YoHLFapORdbLCIf9r4hlPKPgjlZTezNYW9kdnrMk33hLjDz9YyI5LuQBNhts5FRh
mE5FvrAnwKBlnH2K28/kOUgQ+VQ3u0/BIUvXhU8zD/OCgjLXE2Za93ufVHrBlL/T
/Q==
-----END CERTIFICATE-----
"""

KEY_PEM = """\
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7s/++rYd9hRNC
h2gOu+igW0Olf/oSpsZzi4VIsRtOYvcsQ2PSxO+Kmlcr/t0+MWUK1RhGJ5m3Ebia
iNLg733i5EGZPGz0XtCv/OP8xY7XopRB56jlYY/XLKEG7n4FbX/DkfgK+xxGjFi5
xJaP1GyC8gSyw8W9iS9/Gv7ecNuOFBvrJkCeEryz142bH00PJYnuL9xGEB5+Avb5
43gyVUcOFEluYkTZSEnP0Uk8zxaUI2/j1hz+2cjMX7jnHrCmpKtZI9cpuUSd3Gsc
RN6V19+2mnVOaw20FVnMXEA+kGDUK4eHuccw3psZOh8FXkWn8hPwhMmo3t1MJZoq
A920Ygt3AgMBAAECggEAC7FOTJ/9sTWBeiL6OfS9rIOS5rPerZvC//6gemNB+rOS
hyjZho8rBtzPclepi47DJxYYMYKVAkDx2XqNfGKe2mvypCuN8/kWEeh0gVIDMG6Z
wrM+I6/cqIBItahUpFzqWRH2PCThYYmrm0LiSCpo6g1Oep5UapappUbWup+YJbUC
pSMDXTRqHepFZeqMabNlUCWzMD9AAHsgXD78QEZdSyvHzFgZgs5N8MgyBhcMmeNG
wdz07Cdfb8UTtEajH05wO7g5zgFRgoVUl4DJwYGZM20ZlPAAOsRxxr0m4KyveIw6
3VCpkygYv43dvKePj5US9odICBJUaUv8QBDNPf6IpQKBgQDkHolPNReJ0cVk6yq8
2dW1Zyrdqm4mh61N6UMXZS77vWUzj3qD/7HPo2sipJXm6nMh+yOGX+2EzxuLgW34
n5eltWQKIbep3JdEp/6d1dIipLZoL1tHsRteyx/Q4pXGtsH9DDbqz3ve2RPRXiWE
Nxcc5RVMgvsoaxBSol0UqwR1CwKBgQDSpOjpftEqRYfe/sftR9qJVuQtjBXVvcPg
mYZa4/+5rTv9QCNthMnhmkiw2E4WPT7Dye0zgYa84PwY/tR30ccaAmhS1TTFsBEw
z61LjGyIfSG5B4KUNKkeE+VT/6u1OI05/uFFzTr8O7i8jHVpLBbIysUEWlIqWi0a
4Sl6YkQuxQKBgQC0ru8pOq8zLWEBJzeJr6yS621Ld8OZZxvAu0K11CIbqQ7wgPOU
e8GV6iVgoiZNaWPaBXZE59RUvkpd/B1jsNzHlt3vHHfB5gQ2kC2fTI4NfJMyAFh3
d3NraM4BgIcLhxQt3y/cWo0NnLkSu1RR3eTDsTtmh9RxViPun8XEKhT0swKBgGWL
PAB7swdmt2YnemeHcPEuIxdV5ZzBOzEFsYAVU0zGFxoxliKQleWcw5gE3jfYVG57
5E4lDbf12XGPPwt35DxEltf/kc4O32qhYs/9pMBzWhNhbHBXpoMqYi4JHVRiK6qe
lShaFCpN+/Ng3qTRrTYkka9UfzGNgRrpGl62ClplAoGAbs1YTd4Y8POjvq/u5Z87
XtIurLJmfX0HZep2Zu5pC5dj1koYNGBjss0SIEWxTbtXTE8FZcrUy3nwc6IeQaOc
PTo6HQIvCitihAE7bMx2olxU7pmNt5WSUbd4LlLgyq2pfK4OXWOPH9vT4slN4om1
Y1iWWf1+g+hEG8HKwv5L/4U=
-----END PRIVATE KEY-----
"""

LOG = lambda msg: None  # 由界面替换


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".js": "text/javascript",
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_request(self, code="-", size="-"):
        LOG("%s  %s" % (self.path, code))

    def log_error(self, fmt, *args):
        LOG("错误: " + (fmt % args))


class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True
    # Windows 上 SO_REUSEADDR 会让两个实例绑同一端口，必须关掉
    allow_reuse_address = False
    allow_reuse_port = False

    def handle_error(self, request, client_address):
        # 停止服务时正在处理的连接会抛异常，别打整页 traceback
        LOG("连接结束：" + str(client_address[0]))


def lan_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"
    finally:
        s.close()


class App:
    def __init__(self, root):
        self.root = root
        self.httpd = None
        self.thread = None
        self.q = queue.Queue()
        self.cert_dir = None
        self._build()
        self.root.after(120, self._pump)
        self.root.protocol("WM_DELETE_WINDOW", self.on_close)

    # ---------------- 界面 ----------------
    def _build(self):
        self.root.title(APP)
        self.root.geometry("720x520")
        self.root.minsize(620, 420)

        try:
            self.root.tk.call("tk", "scaling", 1.25)
        except Exception:
            pass

        frm = ttk.Frame(self.root, padding=14)
        frm.pack(fill="both", expand=True)

        row = ttk.Frame(frm)
        row.pack(fill="x")

        ttk.Label(row, text="端口").pack(side="left")
        self.port = ttk.Entry(row, width=8)
        self.port.insert(0, str(DEFAULT_PORT))
        self.port.pack(side="left", padx=(6, 16))

        ttk.Label(row, text="协议").pack(side="left")
        self.scheme = tk.StringVar(value="HTTPS")
        ttk.Combobox(row, textvariable=self.scheme, values=("HTTPS", "HTTP"),
                     state="readonly", width=8).pack(side="left", padx=(6, 16))

        self.btn_start = ttk.Button(row, text="启动", command=self.start)
        self.btn_start.pack(side="left")
        self.btn_stop = ttk.Button(row, text="停止", command=self.stop, state="disabled")
        self.btn_stop.pack(side="left", padx=8)

        ttk.Button(row, text="打开浏览器", command=self.open_browser).pack(side="left", padx=(16, 0))

        self.addr = ttk.Label(frm, text="未启动", foreground="#666")
        self.addr.pack(fill="x", pady=(12, 2))

        self.tip = ttk.Label(
            frm,
            text="提示：HTTPS 用内置自签证书，浏览器提示不安全时点「继续前往」；"
                 "手机要用摄像头必须 HTTPS，只当发送端用 HTTP 也行。",
            foreground="#888", wraplength=660, justify="left",
        )
        self.tip.pack(fill="x", pady=(0, 10))

        box = ttk.Frame(frm)
        box.pack(fill="both", expand=True)
        self.log = tk.Text(box, height=14, wrap="none", state="disabled",
                           background="#fbfcff", relief="solid", borderwidth=1)
        sb = ttk.Scrollbar(box, command=self.log.yview)
        self.log.configure(yscrollcommand=sb.set)
        self.log.pack(side="left", fill="both", expand=True)
        sb.pack(side="right", fill="y")

        bottom = ttk.Frame(frm)
        bottom.pack(fill="x", pady=(10, 0))
        ttk.Button(bottom, text="清空日志", command=self.clear_log).pack(side="left")
        ttk.Button(bottom, text="退出", command=self.on_close).pack(side="right")

    # ---------------- 日志 ----------------
    def _log(self, msg):
        self.q.put("[%s] %s" % (time.strftime("%H:%M:%S"), msg))

    def _pump(self):
        try:
            while True:
                line = self.q.get_nowait()
                self.log.configure(state="normal")
                self.log.insert("end", line + "\n")
                self.log.see("end")
                self.log.configure(state="disabled")
        except queue.Empty:
            pass
        self.root.after(120, self._pump)

    def clear_log(self):
        self.log.configure(state="normal")
        self.log.delete("1.0", "end")
        self.log.configure(state="disabled")

    # ---------------- 服务 ----------------
    def _port(self):
        try:
            p = int(self.port.get().strip())
            if not (1 <= p <= 65535):
                raise ValueError
            return p
        except Exception:
            messagebox.showerror(APP, "端口要是 1-65535 之间的数字")
            return None

    def _ssl_ctx(self):
        try:
            if not self.cert_dir:
                self.cert_dir = tempfile.mkdtemp(prefix="airscan-cert-")
                with open(os.path.join(self.cert_dir, "c.pem"), "w", encoding="utf-8") as f:
                    f.write(CERT_PEM)
                with open(os.path.join(self.cert_dir, "k.pem"), "w", encoding="utf-8") as f:
                    f.write(KEY_PEM)
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ctx.load_cert_chain(os.path.join(self.cert_dir, "c.pem"), os.path.join(self.cert_dir, "k.pem"))
            return ctx
        except Exception as e:
            messagebox.showerror(APP, "准备证书失败：%s" % e)
            return None

    def start(self):
        if self.httpd:
            return
        port = self._port()
        if port is None:
            return

        try:
            httpd = Server(("0.0.0.0", port), Handler)
        except OSError as e:
            messagebox.showerror(APP, "端口 %d 用不了：%s" % (port, e))
            self._log("启动失败：%s" % e)
            return

        httpd.daemon_threads = True
        scheme = "http"
        if self.scheme.get() == "HTTPS":
            ctx = self._ssl_ctx()
            if ctx is None:
                httpd.server_close()
                return
            httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
            scheme = "https"

        self.httpd = httpd
        self.thread = threading.Thread(target=httpd.serve_forever, daemon=True)
        self.thread.start()

        ip = lan_ip()
        self.local_url = "%s://127.0.0.1:%d/" % (scheme, port)
        self.lan_url = "%s://%s:%d/" % (scheme, ip, port)
        self.addr.configure(
            text="本机：%s      手机：%s" % (self.local_url, self.lan_url),
            foreground="#1b2330",
        )
        self.btn_start.configure(state="disabled")
        self.btn_stop.configure(state="normal")
        self._log("启动 %s（%s，%s）" % (self.local_url, scheme.upper(), time.strftime("%H:%M:%S")))
        if scheme == "https":
            self._log("手机访问会提示证书不安全，点「继续前往」即可")

    def stop(self):
        if not self.httpd:
            return
        self._log("停止服务")
        try:
            self.httpd.shutdown()
        except Exception:
            pass
        try:
            self.httpd.server_close()
        except Exception:
            pass
        self.httpd = None
        self.thread = None
        self.addr.configure(text="未启动", foreground="#666")
        self.btn_start.configure(state="normal")
        self.btn_stop.configure(state="disabled")

    def open_browser(self):
        url = getattr(self, "local_url", None)
        if not url:
            messagebox.showinfo(APP, "先点「启动」")
            return
        webbrowser.open(url)

    def on_close(self):
        self.stop()
        self.root.destroy()


def main():
    root = tk.Tk()
    app = App(root)
    global LOG
    LOG = app._log
    LOG("就绪，点「启动」开始（默认 HTTPS 8080）")
    root.mainloop()


if __name__ == "__main__":
    main()
