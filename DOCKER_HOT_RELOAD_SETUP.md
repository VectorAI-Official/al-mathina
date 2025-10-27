# 🔥 Hot-Reload Setup - Automatic Code Reload on Save

## What's Enabled ✅

Docker now automatically **reloads the backend when you save code changes**. No need to manually restart the container!

### How It Works

```
You save a Python file in Backend/
        ↓
Docker volume sync detects the change
        ↓
Uvicorn reloader watches the directory
        ↓
Backend automatically restarts
        ↓
http://localhost:8000 reflects your changes immediately
```

### Log Evidence
```
INFO:     Will watch for changes in these directories: ['/app']
INFO:     Started reloader process [8] using WatchFiles
```

These lines in the Docker logs confirm hot-reload is active.

---

## How to Use

### 1. Edit Backend Code
Open any Python file in `Backend/` directory and make changes:

```python
# Example: routes/admin_production.py
# Make any change and save (Ctrl+S)
logger.info("My new debug message")
```

### 2. Save the File
- **VS Code:** Ctrl+S (auto-save can be enabled)
- **Any Editor:** Just save normally

### 3. Docker Auto-Reloads
Watch the Docker logs and you'll see:
```
INFO:     Shutting down
INFO:     Waiting for application shutdown complete.
INFO:     Shutdown complete.
INFO:     Startup complete.
```

The backend restarts in ~2-3 seconds.

### 4. Test Your Changes
Refresh the browser or test the API - your changes are live!

```powershell
# Quick test
curl http://localhost:8000/health
```

---

## Watch the Logs (Optional)

To see real-time reload activity:

```powershell
cd Backend
docker-compose logs -f backend
```

You'll see output like:
```
backend-1  | INFO:     Detected file change in '/app/routes/admin_production.py'
backend-1  | INFO:     Shutting down
backend-1  | INFO:     Startup complete.
```

---

## What Triggers a Reload

✅ **Reloads on change:**
- Python files (`.py`)
- Configuration files (`.py` imports)
- Templates (if you use them)
- Any file in `/app` directory

❌ **Does NOT reload on:**
- `.env` file changes (restart container for env var changes)
- `requirements.txt` changes (rebuild container: `docker-compose up -d --build`)
- Dockerfile changes (rebuild container)

---

## Typical Development Workflow

### 1. Start Backend
```powershell
cd Backend
docker-compose up -d
```

### 2. Edit Code
Open VS Code and edit `Backend/` files as normal.

### 3. Save Changes
Press `Ctrl+S` to save. Docker automatically reloads!

### 4. Refresh Browser
Browser picks up your changes immediately:
```
http://localhost:8000/admin/dashboard
```

### 5. Check Logs If Needed
```powershell
docker-compose logs -f backend
```

---

## Example: Quick Test

### Before (Old Way)
```
1. Edit code
2. Save file
3. Restart container: docker-compose restart
4. Wait 5 seconds
5. Test changes
```

### After (New Way with Hot-Reload)
```
1. Edit code
2. Save file
3. Backend auto-reloads (~2 seconds)
4. Test changes immediately
```

---

## Configuration Details

### Files Modified

**docker-compose.yml:**
```yaml
environment:
  - RELOAD=true              # Enable hot-reload
volumes:
  - .:/app                   # Mount local code to container
  - /app/__pycache__         # Exclude cache
  - /app/.pytest_cache       # Exclude test cache
```

**Dockerfile:**
```dockerfile
# Conditional reload based on RELOAD env var
CMD sh -c 'if [ "$RELOAD" = "true" ]; then python -m uvicorn main_production:app --host 0.0.0.0 --port 8080 --reload; else python -m uvicorn main_production:app --host 0.0.0.0 --port 8080; fi'
```

### How It's Controlled

- **Local Development (Docker):** `RELOAD=true` → Hot-reload ENABLED
- **Production (Fly.io):** `RELOAD=false` → Hot-reload DISABLED (safer for production)

---

## Troubleshooting

### Hot-Reload Not Working?

1. **Check if container is running:**
   ```powershell
   docker-compose ps
   ```

2. **Verify hot-reload is enabled:**
   ```powershell
   docker-compose logs backend | Select-String "watch for changes"
   ```

3. **Check if file is actually being mounted:**
   ```powershell
   docker exec backend-backend-1 ls -la /app | head -20
   ```

4. **Restart container:**
   ```powershell
   docker-compose down && docker-compose up -d
   ```

### Large Files Taking Long to Reload?

If reloading takes too long (>5 seconds), it might be:
- Large file being watched
- Lots of imports
- Heavy initialization in `main_production.py`

**Solution:** Check logs to see what's slow:
```powershell
docker-compose logs -f backend | Select-String "Detected file change"
```

### Syntax Errors Crash the Reloader?

If you have a Python syntax error, the reloader will stop.

```
ERROR:    Uvicorn running on http://0.0.0.0:8080 (Press CTRL+C to quit)
ERROR:    ERROR:    Exception in ASGI app initialization: invalid syntax
```

**Solution:** Fix the syntax error and save again. Reloader will recover.

---

## Monitoring Hot-Reloads

### Real-time Reload Log
```powershell
# Show only reload events
docker-compose logs backend -f | Select-String -Pattern "Detected file change|Shutting down|Startup complete"
```

### Example Output
```
backend-1  | INFO:     Detected file change in '/app/routes/admin_production.py'
backend-1  | INFO:     Shutting down
backend-1  | INFO:     Waiting for application shutdown complete.
backend-1  | INFO:     Shutdown complete.
backend-1  | INFO:     Startup complete.
```

Each reload takes 2-3 seconds typically.

---

## Environment-Specific Behavior

### Local Docker (Current Setup)
```
RELOAD=true
Behavior: Auto-reload on save ✅
Startup time: ~3 seconds with reloader
```

### Production Fly.io (Future Deployment)
```
RELOAD=false
Behavior: No auto-reload (safer)
Startup time: ~2 seconds
```

To change for production, just update the `RELOAD` environment variable in Fly.io.

---

## Best Practices

✅ **Do:**
- Make small, focused changes
- Test after each change
- Use hot-reload for rapid development
- Check logs if something seems off

❌ **Don't:**
- Assume hot-reload works for all file types (it doesn't for `.env` or dependencies)
- Leave the container running without monitoring for long
- Make breaking changes without testing

---

## Quick Commands Reference

```powershell
# Start with hot-reload
docker-compose up -d

# Watch logs for reload events
docker-compose logs -f backend

# Manually restart if needed
docker-compose restart backend

# Full rebuild (for dependency changes)
docker-compose down && docker-compose up -d --build

# Check if hot-reload is enabled
docker-compose logs backend | Select-String "watch for changes"

# Disable hot-reload (edit docker-compose.yml and set RELOAD=false)
# Then: docker-compose down && docker-compose up -d
```

---

## Development Tips

### Tip 1: Auto-save in VS Code
Enable auto-save to get instant hot-reload:
1. File → Preferences → Settings
2. Search: "auto save"
3. Set to: "afterDelay" (1000ms delay)

### Tip 2: Multiple Terminals
Keep one terminal showing logs:
```powershell
# Terminal 1: Watch logs
docker-compose logs -f backend

# Terminal 2: Edit code
code Backend/
```

### Tip 3: Test APIs While Editing
Use VS Code REST Client or Postman:
```
GET http://localhost:8000/health
GET http://localhost:8000/admin/api/categories/metadata
POST http://localhost:8000/admin/api/products
```

Modify code and test again - see changes immediately!

---

## Status: ✅ HOT-RELOAD ENABLED

Your backend now has:
- ✅ Automatic file watching
- ✅ Quick restart on save (2-3 seconds)
- ✅ Volume mounting for code sync
- ✅ Production-safe configuration (can disable for Fly.io)
- ✅ Logs showing reload status

**Start editing and saving - your changes appear instantly!** 🚀
