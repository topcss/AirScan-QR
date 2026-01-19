import http.server, ssl, json

state = {"received_indexes": [], "total": 0, "request_frame": -1}

class QRStreamHandler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = {}
        if content_length > 0:
            try: post_data = json.loads(self.rfile.read(content_length).decode('utf-8'))
            except: pass

        if self.path == '/update_progress':
            state["received_indexes"] = list(set(state["received_indexes"] + post_data.get("indexes", [])))
            state["total"] = post_data.get("total", 0)
        elif self.path == '/request_frame':
            state["request_frame"] = post_data.get("index", -1)
        elif self.path == '/reset':
            state.update({"received_indexes": [], "total": 0, "request_frame": -1})

        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps({"status": "ok"}).encode())

    def do_GET(self):
        if self.path == '/get_status':
            self.send_response(200)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(state).encode())
        else: return super().do_GET()

httpd = http.server.HTTPServer(('0.0.0.0', 4443), QRStreamHandler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(certfile="cert.pem", keyfile="key.pem")
httpd.socket = context.wrap_socket(httpd.socket, server_side=True)
print("🚀 Server: https://0.0.0.0:4443")
httpd.serve_forever()