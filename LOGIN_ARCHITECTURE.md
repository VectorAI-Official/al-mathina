# AL-Madhina Login Architecture

## Summary: Frontend-Driven Login with Backend Support

The login is **primarily handled on the Frontend (Flutter)** with the **Backend providing user profile management**.

---

## Architecture Breakdown

### 1. **Frontend Authentication (Flutter)**

#### Firebase Phone Authentication (Primary)
Located in: `flutter_preview/lib/screens/phone_auth_screen.dart`

**Flow:**
```
User enters phone number
       ↓
Firebase sends OTP via SMS
       ↓
User enters 6-digit OTP
       ↓
Firebase verifies OTP
       ↓
User is authenticated locally with Firebase
       ↓
App stores isOldUser flag in SharedPreferences
       ↓
Navigate to MainScreen (home page)
```

**Key Code:**
```dart
// File: flutter_preview/lib/main.dart (SplashScreen)
Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final isOldUser = prefs.getBool('isOldUser') ?? false;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => isOldUser 
                ? MainScreen(key: mainScreenKey) 
                : const PhoneAuthScreen(),
        ),
    );
}
```

**Service:** `flutter_preview/lib/services/phone_auth_service.dart`
- `verifyPhoneNumber()` - Send OTP
- `signInWithOTP()` - Verify OTP and create Firebase session
- `signOut()` - Logout user

**Technology:** Firebase Authentication
- ✅ Handles all authentication logic
- ✅ Manages session tokens
- ✅ Provides user identity verification
- ✅ No backend authentication endpoint needed

---

### 2. **Backend User Profile Management**

Located in: `Backend/routes/user_profile.py`

**Purpose:** 
- Store and retrieve user data (name, email, addresses)
- Manage orders
- Handle favorites

**Endpoints:**
```
GET    /api/flutter/user/profile/{phone}     - Get user profile
POST   /api/flutter/user/profile/{phone}     - Create/update user
GET    /api/flutter/user/orders/{phone}      - Get user orders
POST   /api/flutter/user/orders              - Create order
GET    /api/flutter/favorites/{user_id}      - Get favorites
POST   /api/flutter/favorites/{user_id}      - Add/remove favorites
```

**Key Detail:**
- Backend uses **phone number as user identifier** (not Firebase UID)
- **No backend authentication required** - Frontend validates via Firebase first
- Backend trusts phone number passed by frontend

**Example Code:**
```python
@router.get("/profile/{phone}")
async def get_user_profile(phone: str, request: Request):
    """Get user profile by phone number, create if doesn't exist"""
    db = get_mongo_db()
    users_collection = db['users']
    
    # Find or create user
    user = users_collection.find_one({"phone": phone})
    if not user:
        new_user = {
            "phone": phone,
            "name": None,
            "email": None,
            "addresses": [],
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow()
        }
        result = users_collection.insert_one(new_user)
```

---

## Complete User Journey

### First-Time User
```
1. App opens → SplashScreen (2 second delay)
2. Check SharedPreferences for "isOldUser" flag
3. If flag not found → Show PhoneAuthScreen
4. User enters phone: +919876543210
5. Firebase sends OTP via SMS
6. User enters OTP: 123456
7. Firebase verifies OTP ✅
8. App sets "isOldUser" = true in SharedPreferences
9. Navigate to MainScreen
10. When placing order, app calls Backend:
    - POST /api/flutter/user/orders with phone number
    - Backend auto-creates user profile if needed
11. User can manage profile via GET /api/flutter/user/profile/{phone}
```

### Returning User
```
1. App opens → SplashScreen (2 second delay)
2. Check SharedPreferences for "isOldUser" flag
3. If flag exists = true → Directly go to MainScreen
4. App is ready to use without login
```

### Logout
```
1. User taps logout in profile
2. Call PhoneAuthService.signOut()
3. Firebase session cleared
4. Remove "isOldUser" flag from SharedPreferences
5. Navigate to PhoneAuthScreen
```

---

## Admin Dashboard Login (Separate System)

**Important:** Admin login is **completely separate** from mobile app login.

Located in: `Backend/routes/admin.py` and `Backend/routes/admin_local.py`

**Admin Flow:**
```
Admin goes to: http://localhost:8000/admin/login
Admin enters: username + password
Backend validates credentials
Admin gets session cookie
Admin can access: http://localhost:8000/admin/
```

**This is NOT used by Flutter app** - it's a separate web dashboard for backend management.

---

## Security Considerations

### Current Implementation
| Component | Security |
|-----------|----------|
| **Mobile Authentication** | ✅ Firebase (industry standard) |
| **Session Management** | ✅ Firebase handles tokens |
| **User Identification** | ✅ Phone number (verified via SMS) |
| **Backend Trust** | ⚠️ Trusts phone from frontend |
| **API Security** | ⚠️ No authentication header validation |

### Recommendations for Production
1. **Add Backend Verification:**
   ```python
   # Instead of blindly trusting phone number:
   @router.get("/user/profile/{phone}")
   async def get_user_profile(phone: str, auth_header: str = Header(...)):
       # Validate Firebase token from auth_header
       decoded_token = verify_firebase_token(auth_header)
       if decoded_token['phone'] != phone:
           raise HTTPException(status_code=403, detail="Unauthorized")
   ```

2. **Send Firebase Token from Frontend:**
   ```dart
   // In api_service.dart
   final token = await FirebaseAuth.instance.currentUser?.getIdToken();
   final response = await http.get(
       Uri.parse('$API_BASE/user/profile/$phone'),
       headers: {
           'Authorization': 'Bearer $token',
           'Content-Type': 'application/json',
       },
   );
   ```

3. **Validate in Backend:**
   ```python
   from firebase_admin import auth as firebase_auth
   
   def verify_firebase_token(token: str):
       try:
           decoded_token = firebase_auth.verify_id_token(token)
           return decoded_token
       except firebase_auth.InvalidIdTokenError:
           raise HTTPException(status_code=401, detail="Invalid token")
   ```

---

## Login Status in Code

### How App Tracks Login State

**SharedPreferences** (Local device storage):
```dart
// Save on successful login
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('isOldUser', true);

// Check on app startup
final isOldUser = prefs.getBool('isOldUser') ?? false;

// Clear on logout
await prefs.remove('isOldUser');
```

**Firebase Authentication**:
```dart
// Check current user
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
    // User is logged in
    print(user.phoneNumber);
} else {
    // User is logged out
}
```

---

## Key Files to Remember

| File | Purpose |
|------|---------|
| `flutter_preview/lib/screens/phone_auth_screen.dart` | Frontend login UI |
| `flutter_preview/lib/services/phone_auth_service.dart` | Firebase OTP service |
| `flutter_preview/lib/main.dart` | SplashScreen navigation logic |
| `flutter_preview/lib/firebase_options.dart` | Firebase configuration |
| `Backend/routes/user_profile.py` | Backend user data management |
| `Backend/routes/admin.py` | Admin dashboard login (separate) |

---

## To Implement Backend Token Validation

If you want to add backend security validation (recommended):

1. **Modify `api_service.dart`** to send Firebase token in headers
2. **Modify `user_profile.py`** to validate Firebase token
3. **Add Firebase Admin SDK** to backend (`pip install firebase-admin`)
4. **Test with phone number validation** to ensure security

Would you like me to implement these security improvements?

---

**Last Updated:** November 7, 2025
**Status:** Frontend-driven with optional backend security enhancement available
