Set-Location -LiteralPath 'C:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview'; flutter run -d chrome --verbose

Set-Location "c:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview" ; flutter run -d chrome --web-port 9090

cd "c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend" ; & ".\venv\Scripts\Activate.ps1" ; python -m uvicorn main_local:app --reload --host 127.0.0.1 --port 8000