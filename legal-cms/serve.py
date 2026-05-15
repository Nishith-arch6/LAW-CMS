import http.server, urllib.request, os, sys, socketserver

BACKEND = "http://localhost:8001"
FRONTEND = r"C:\Users\Nishith\Downloads\LAW\legal-cms\frontend\build\web"

class H(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/api/") or self.path == "/health":
            u = BACKEND + self.path
            try:
                r = urllib.request.urlopen(u, timeout=10)
                self.send_response(r.status)
                for k,v in r.headers.items():
                    if k.lower() not in ("transfer-encoding","content-encoding","content-length"):
                        self.send_header(k,v)
                self.end_headers()
                self.wfile.write(r.read())
            except Exception as e:
                self.send_response(502)
                self.send_header("Content-Type","application/json")
                self.end_headers()
                self.wfile.write(f'{{"error":"{e}"}}'.encode())
        else:
            p = self.path if self.path != "/" else "/index.html"
            f = os.path.join(FRONTEND, p.lstrip("/"))
            if os.path.isfile(f):
                self.send_response(200)
                ext = f.split(".")[-1]
                self.send_header("Content-Type", {"html":"text/html","js":"application/javascript","css":"text/css","png":"image/png","ico":"image/x-icon","json":"application/json"}.get(ext,"text/html"))
                self.end_headers()
                with open(f,"rb") as fp: self.wfile.write(fp.read())
            else:
                self.send_response(200)
                self.send_header("Content-Type","text/html")
                self.end_headers()
                with open(os.path.join(FRONTEND,"index.html"),"rb") as fp: self.wfile.write(fp.read())

    def do_POST(self):
        if self.path.startswith("/api/"):
            l = int(self.headers.get("Content-Length",0))
            b = self.rfile.read(l) if l else b""
            u = BACKEND + self.path
            h = {k:v for k,v in self.headers.items() if k.lower() not in ("host","content-length")}
            try:
                r = urllib.request.Request(u,data=b,headers=h,method="POST")
                resp = urllib.request.urlopen(r, timeout=10)
                self.send_response(resp.status)
                for k,v in resp.headers.items():
                    if k.lower() not in ("transfer-encoding","content-encoding","content-length"):
                        self.send_header(k,v)
                self.end_headers()
                self.wfile.write(resp.read())
            except urllib.error.HTTPError as e:
                self.send_response(e.code)
                self.end_headers()
                self.wfile.write(e.read())
            except Exception as e:
                self.send_response(502)
                self.send_header("Content-Type","application/json")
                self.end_headers()
                self.wfile.write(f'{{"error":"{e}"}}'.encode())

    def do_PUT(self): self.do_POST()
    def do_DELETE(self):
        if self.path.startswith("/api/"):
            u = BACKEND + self.path
            h = {k:v for k,v in self.headers.items() if k.lower() not in ("host","content-length")}
            try:
                r = urllib.request.Request(u,headers=h,method="DELETE")
                resp = urllib.request.urlopen(r, timeout=10)
                self.send_response(resp.status)
                for k,v in resp.headers.items():
                    if k.lower() not in ("transfer-encoding","content-encoding","content-length"):
                        self.send_header(k,v)
                self.end_headers()
                self.wfile.write(resp.read())
            except urllib.error.HTTPError as e:
                self.send_response(e.code)
                self.end_headers()
                self.wfile.write(e.read())
            except Exception as e:
                self.send_response(502)
                self.send_header("Content-Type","application/json")
                self.end_headers()
                self.wfile.write(f'{{"error":"{e}"}}'.encode())

class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True

ThreadedHTTPServer(("0.0.0.0",8080),H).serve_forever()
