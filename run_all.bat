@echo off
cd /d "C:\Users\Nishith\Downloads\LAW\legal-cms\backend"
start "Backend" cmd /k "venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8001"
timeout /t 8 /nobreak >nul
cd /d "C:\Users\Nishith\Downloads\LAW\legal-cms"
start "Proxy" cmd /k "backend\venv\Scripts\python.exe -u serve.py"
echo.
echo ============================================
echo  Backend:  http://localhost:8001
echo  App:      http://localhost:8080
echo.
ipconfig | findstr /i "IPv4"
echo.
echo  Open http://YOUR-IP:8080 on your phone
echo ============================================
echo.
pause
