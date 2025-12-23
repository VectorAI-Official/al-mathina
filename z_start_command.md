Set-Location -LiteralPath 'C:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview'; flutter run -d chrome --verbose

Set-Location -LiteralPath 'C:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview'; flutter run -d emulator-5554

# LOCAL DEVELOPMENT (Local MongoDB)
cd "D:\AlMathina\Backend" ; & ".\venv\Scripts\Activate.ps1" ; python -m uvicorn main_local:app --reload --host 127.0.0.1 --port 8000

# PRODUCTION MODE (MongoDB Atlas + Cloudinary)
cd "c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend" ; & ".\venv\Scripts\Activate.ps1" ; $env:ENVIRONMENT='production' ; python -m uvicorn main_production:app --reload --host 0.0.0.0 --port 8000

cd Backend; python -m uvicorn main_local:app --reload --host 0.0.0.0 --port 8000




# FOR PHYSICAL ANDROID DEVICE
# Terminal 1: Start Backend (production with MongoDB Atlas)
cd "c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend" ; & ".\venv\Scripts\Activate.ps1" ; $env:ENVIRONMENT='production' ; python -m uvicorn main_production:app --reload --host 0.0.0.0 --port 8000


# Terminal 1: Start docker Backend 
cd backend; docker-compose restart

# Terminal 2: Run Flutter on physical device (RZ8NA1WCLWL)
Set-Location -LiteralPath 'C:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview'; flutter run -d RZ8NA1WCLWL    

# Terminal 3: Build APK
Set-Location -LiteralPath 'C:\Users\faisa\AndroidStudioProjects\AlMathina\flutter_preview'; flutter clean && flutter pub get; flutter build apk --release 2>&1 | tee apk_build.log    



# Terminal 1: Start docker Backend
cd backend; docker-compose restart

# Terminal 2: Run Flutter on physical device (103223138K111296)
flutter run -d 103223138K111296

# Terminal 3: Build APK
flutter clean ; flutter pub get; flutter build apk --release 2>&1 | tee apk_build.log    



