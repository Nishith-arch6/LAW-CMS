Write-Host "=== Starting Legal CMS ===" -ForegroundColor Green

# 1. Start Backend on port 8001
Push-Location backend
$venv = if (Test-Path "venv\Scripts\Activate.ps1") { "venv\Scripts\Activate.ps1" } else { ".venv\Scripts\Activate.ps1" }
. $venv
$jobBackend = Start-Job -Name "backend" -ScriptBlock {
    cd "$using:PWD"
    . "$using:venv"
    uvicorn app.main:app --port 8001
}
Pop-Location

Start-Sleep 3

# 2. Build frontend if needed
if (-not (Test-Path "frontend\build\web\index.html")) {
    Write-Host "Building frontend..." -ForegroundColor Yellow
    $flutter = if (Test-Path "flutter\bin\flutter.bat") { "flutter\bin\flutter.bat" } else { "flutter\bin\flutter.bat" }
    & "C:\Users\Nishith\Downloads\LAW\flutter\bin\flutter.bat" build web
}

# 3. Start proxy on port 8080 (frontend + API proxy to 8001)
$jobProxy = Start-Job -Name "proxy" -ScriptBlock {
    $script = @"
import http.server, urllib.request, os, sys
BACKEND = "http://localhost:8001"
FRONTEND = r"C:\Users\Nishith\Downloads\LAW\legal-cms\frontend\build\web"
class H(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/api/") or self.path == "/health":
            u = BACKEND + self.path
            try:
                r = urllib.request.urlopen(u)
                self.send_response(r.status)
                for k,v in r.headers.items():
                    if k.lower() not in ("transfer-encoding","content-encoding","content-length"):
                        self.send_header(k,v)
                self.end_headers()
                self.wfile.write(r.read())
            except urllib.error.HTTPError as e:
                self.send_response(e.code)
                self.end_headers()
                self.wfile.write(e.read())
        else:
            p = self.path if self.path != "/" else "/index.html"
            f = os.path.join(FRONTEND, p.lstrip("/"))
            if os.path.isfile(f):
                self.send_response(200)
                self.send_header("Content-Type", {"html":"text/html","js":"application/javascript","css":"text/css"}.get(f.split(".")[-1],"text/html"))
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
                resp = urllib.request.urlopen(r)
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
    def do_PUT(self): self.do_POST()
    def do_DELETE(self):
        if self.path.startswith("/api/"):
            u = BACKEND + self.path
            h = {k:v for k,v in self.headers.items() if k.lower() not in ("host","content-length")}
            r = urllib.request.Request(u,headers=h,method="DELETE")
            try:
                resp = urllib.request.urlopen(r)
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
http.server.HTTPServer(("0.0.0.0",8080),H).serve_forever()
"@
    python -c $script
}

Start-Sleep 2

Write-Host "`n=== READY ===" -ForegroundColor Green
Write-Host "  Frontend + API: http://localhost:8080" -ForegroundColor Cyan
Write-Host "  Backend docs:   http://localhost:8001/docs" -ForegroundColor Cyan
Write-Host "  API health:     http://localhost:8080/health" -ForegroundColor Cyan
Write-Host "`nPress Ctrl+C to stop all services" -ForegroundColor Yellow

# Wait for Ctrl+C
while ($true) {
    Start-Sleep 1
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'C' -and $key.Modifiers -band [ConsoleModifiers]::Control) {
            Write-Host "`nStopping services..." -ForegroundColor Yellow
            Get-Job | Stop-Job
            Get-Job | Remove-Job
            break
        }
    }
}
