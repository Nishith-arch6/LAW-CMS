Write-Host "=== Starting Legal CMS ===" -ForegroundColor Green
$root = "C:\Users\Nishith\Downloads\LAW\legal-cms"
$flutter = "C:\Users\Nishith\Downloads\LAW\flutter\bin\flutter.bat"

# 1. Start Backend
Write-Host "[1/3] Starting backend on port 8001..." -ForegroundColor Yellow
$ps = @{
    FilePath = "uvicorn"
    ArgumentList = "app.main:app --port 8001"
    WorkingDirectory = "$root\backend"
    WindowStyle = "Hidden"
}
$null = Start-Process @ps

Start-Sleep 4

# 2. Verify backend
try {
    $h = Invoke-RestMethod -Uri "http://localhost:8001/health" -ErrorAction Stop
    Write-Host "  Backend OK: $($h.status)" -ForegroundColor Green
} catch {
    Write-Host "  Backend failed to start!" -ForegroundColor Red
    exit 1
}

# 3. Build frontend if needed
if (-not (Test-Path "$root\frontend\build\web\index.html")) {
    Write-Host "[2/3] Building frontend..." -ForegroundColor Yellow
    & $flutter build web
}

# 4. Start proxy on port 8080
Write-Host "[3/3] Starting proxy on port 8080..." -ForegroundColor Yellow
$proxyCode = @"
import http.server, urllib.request, os, sys
BACKEND = "http://localhost:8001"
FRONTEND = r"$root\frontend\build\web"
class H(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/api/") or self.path == "/health":
            try:
                r = urllib.request.urlopen(BACKEND + self.path)
                self.send_response(r.status)
                for k,v in r.headers.items():
                    if k.lower() not in ("transfer-encoding","content-encoding","content-length"):
                        self.send_header(k,v)
                self.end_headers()
                self.wfile.write(r.read())
            except urllib.error.HTTPError as e:
                self.send_response(e.code); self.end_headers(); self.wfile.write(e.read())
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
            h = {k:v for k,v in self.headers.items() if k.lower() not in ("host","content-length")}
            r = urllib.request.Request(BACKEND+self.path,data=b,headers=h,method="POST")
            try:
                resp = urllib.request.urlopen(r)
                self.send_response(resp.status)
                for k,v in resp.headers.items():
                    if k.lower() not in ("transfer-encoding","content-encoding","content-length"):
                        self.send_header(k,v)
                self.end_headers()
                self.wfile.write(resp.read())
            except urllib.error.HTTPError as e:
                self.send_response(e.code); self.end_headers(); self.wfile.write(e.read())
    def do_PUT(self): self.do_POST()
    def do_DELETE(self):
        if self.path.startswith("/api/"):
            h = {k:v for k,v in self.headers.items() if k.lower() not in ("host","content-length")}
            r = urllib.request.Request(BACKEND+self.path,headers=h,method="DELETE")
            try:
                resp = urllib.request.urlopen(r)
                self.send_response(resp.status)
                for k,v in resp.headers.items():
                    if k.lower() not in ("transfer-encoding","content-encoding","content-length"):
                        self.send_header(k,v)
                self.end_headers()
                self.wfile.write(resp.read())
            except urllib.error.HTTPError as e:
                self.send_response(e.code); self.end_headers(); self.wfile.write(e.read())
http.server.HTTPServer(("0.0.0.0",8080),H).serve_forever()
"@

$null = Start-Process -FilePath "python" -ArgumentList "-c", $proxyCode -WindowStyle Hidden
Start-Sleep 2

# 5. Verify proxy
try {
    $h = Invoke-RestMethod -Uri "http://localhost:8080/health" -ErrorAction Stop
    Write-Host "  Proxy OK: $($h.status)" -ForegroundColor Green
} catch {
    Write-Host "  Proxy failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n==============================" -ForegroundColor Green
Write-Host "  ALL SERVICES RUNNING" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green
Write-Host "  Open: http://localhost:8080" -ForegroundColor Cyan
Write-Host "  API:  http://localhost:8001/docs" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Green
Write-Host "`nClose this window to stop all services." -ForegroundColor Yellow

# Keep window open
Read-Host "`nPress Enter to exit and stop all services"
