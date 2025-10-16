# MongoDB Installation Guide for Windows

## Quick Install Options

### Option 1: MongoDB Community Edition (Recommended - Standalone)

1. **Download MongoDB Installer**
   - Visit: https://www.mongodb.com/try/download/community
   - Select: Windows x64
   - Version: Latest (8.0+)
   - Package: MSI

2. **Run Installer**
   - Double-click the downloaded `.msi` file
   - Choose "Complete" installation
   - ✅ Check "Install MongoDB as a Service"
   - ✅ Check "Run service as Network Service user"
   - Install MongoDB Compass (optional GUI)

3. **Verify Installation**
   ```powershell
   # Open NEW PowerShell window
   mongod --version
   ```

4. **MongoDB is Auto-Started**
   - Service runs automatically on `localhost:27017`
   - No manual start needed!

### Option 2: MongoDB in Docker (If you have Docker Desktop)

1. **Start Docker Desktop** application

2. **Run MongoDB Container**
   ```powershell
   docker run -d --name almathina-mongodb -p 27017:27017 mongo:latest
   ```

3. **Verify Running**
   ```powershell
   docker ps
   ```

### Option 3: MongoDB Atlas Free Tier (Cloud - If local fails)

1. Visit: https://www.mongodb.com/cloud/atlas/register
2. Create free account
3. Create free cluster
4. Get connection string
5. Update `Backend/.env`:
   ```
   MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/almadhinadb
   ```

## After MongoDB is Installed

### Terminal 1: Start Backend with Real Database

```powershell
cd c:\Users\faisa\AndroidStudioProjects\AlMathina\Backend
.\venv\Scripts\python.exe .\main_local.py
```

Expected Output:
```
🚀 AL-Madhina Backend Starting (Local MongoDB)
============================================================
📊 Testing Database Connection...
✓ MongoDB connection successful
✓ MongoDB collections initialized
============================================================
✅ Backend Ready - Listening on http://127.0.0.1:8000
🎨 Admin Dashboard: http://127.0.0.1:8000/admin/login
   👤 Username: admin
   🔑 Password: admin123
============================================================
```

### Access Admin Dashboard

Open: http://127.0.0.1:8000/admin/login

---

## Troubleshooting

### "MongoDB connection failed"
- Check MongoDB service is running:
  ```powershell
  # If installed as Windows Service
  Get-Service MongoDB
  
  # If using Docker
  docker ps | Select-String "mongo"
  ```

### "mongod not recognized"
- Restart PowerShell after installation
- Or manually add to PATH: `C:\Program Files\MongoDB\Server\8.0\bin`

### Still having issues?
Let me know and I can:
1. Help troubleshoot the specific error
2. Set up MongoDB Atlas (cloud) instead
3. Use an alternative embedded database for development
