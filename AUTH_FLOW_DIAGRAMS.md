# AL-Madhina Authentication Flow Diagram

## Frontend Authentication (Primary)

```
┌─────────────────────────────────────────────────────────────────┐
│                       FLUTTER APP                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  SplashScreen (2s delay)                                         │
│         ↓                                                         │
│  Check SharedPreferences['isOldUser']?                          │
│         ↓                                                         │
│    ┌─────────────────┬──────────────────┐                       │
│    │ TRUE (exists)   │ FALSE (not exists)│                       │
│    ↓                 ↓                    │                       │
│  MainScreen    PhoneAuthScreen           │                       │
│  (Logged In)        │                    │                       │
│                     ↓                    │                       │
│              Enter Phone Number         │                       │
│              (with validation)          │                       │
│                     ↓                    │                       │
│        ┌────────────────────────┐       │                       │
│        │ Firebase SDK           │       │                       │
│        │ verifyPhoneNumber()    │       │                       │
│        └────────────────────────┘       │                       │
│                     ↓                    │                       │
│          Firebase sends OTP via SMS     │                       │
│                     ↓                    │                       │
│            User enters OTP (6 digits)   │                       │
│                     ↓                    │                       │
│        ┌────────────────────────┐       │                       │
│        │ Firebase SDK           │       │                       │
│        │ signInWithOTP()        │       │                       │
│        └────────────────────────┘       │                       │
│                     ↓                    │                       │
│       ✅ OTP Verified Successfully      │                       │
│                     ↓                    │                       │
│    Save SharedPreferences['isOldUser']=true                     │
│                     ↓                    │                       │
│              Navigate to MainScreen    │                       │
│              (Home Page)                │                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
        │
        │ User places order / accesses profile
        ↓
┌─────────────────────────────────────────────────────────────────┐
│                        BACKEND API                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  POST /api/flutter/user/orders                                  │
│  GET  /api/flutter/user/profile/{phone}                         │
│  POST /api/flutter/user/profile/{phone}                         │
│                                                                  │
│  ⚠️  Backend trusts phone number from frontend                 │
│  ⚠️  No authentication header validation (optional improvement) │
│                                                                  │
│  MongoDB Collections:                                            │
│  - users (phone as identifier)                                  │
│  - orders (phone as identifier)                                 │
│  - user_favorites (user_id from frontend)                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Authentication Responsibility

```
┌──────────────────────────────────┬──────────────────────────────┐
│        FRONTEND (Flutter)         │    BACKEND (FastAPI)        │
├──────────────────────────────────┼──────────────────────────────┤
│ ✅ Handles login/logout          │ ✅ Stores user profile       │
│ ✅ Manages phone verification    │ ✅ Stores orders             │
│ ✅ Sends OTP                     │ ✅ Stores favorites          │
│ ✅ Verifies OTP                  │ ✅ Business logic            │
│ ✅ Manages Firebase session      │                              │
│ ✅ Stores local preferences      │ ⚠️  Does NOT verify token   │
│                                  │ ⚠️  Trusts phone number      │
└──────────────────────────────────┴──────────────────────────────┘
```

## User State Transitions

```
                              ┌─────────────────┐
                              │   App Startup   │
                              └────────┬────────┘
                                       │
                  ┌────────────────────┴────────────────────┐
                  │                                         │
        ┌─────────▼──────────┐              ┌──────────────▼────────┐
        │ isOldUser = true   │              │  isOldUser = false    │
        │ (stored locally)   │              │  (not in storage)     │
        └────────┬───────────┘              └──────────┬───────────┘
                 │                                    │
        ┌────────▼──────────┐              ┌──────────▼───────────┐
        │   MainScreen      │              │ PhoneAuthScreen     │
        │  (Logged In)      │              │ (Authentication UI) │
        │ ✅ Can browse     │              │ Enter phone & OTP   │
        │ ✅ Can order      │              │ Verify with Firebase│
        │ ✅ Can view       │              │                     │
        │    profile        │              │ ┌─────────────────┐ │
        └────────┬──────────┘              │ │ Firebase SDK    │ │
                 │                         │ │ Verification    │ │
                 │                         │ └────────┬────────┘ │
                 │                         └──────────┬──────────┘
                 │                                    │
          ┌──────▼──────┐                     ┌───────▼──────┐
          │   Logout    │                     │ ✅ Verified  │
          │             │                     │              │
          │ 1. Sign out │                     │ Save flag    │
          │ 2. Clear    │                     │ isOldUser=T  │
          │    flag     │                     │              │
          │ 3. Clear   │                     │ Go to Main   │
          │    prefs    │                     │ Screen       │
          └──────┬──────┘                     └──────────────┘
                 │
       ┌─────────▼─────────┐
       │ PhoneAuthScreen   │
       │ (Back to Login)   │
       └───────────────────┘
```

## Firebase vs Backend Separation

```
┌────────────────────────────────────┐
│   FIREBASE (Authentication)        │  ← Handles all auth
├────────────────────────────────────┤
│ • Phone verification               │
│ • OTP validation                   │
│ • Session tokens                   │
│ • User identity                    │
│ • Sign out                         │
│                                    │
│ Location: Cloud (Google)           │
│ Responsibility: Identity           │
└────────────────────────────────────┘
         │
         │ After authentication ✅
         │
         ↓
┌────────────────────────────────────┐
│   BACKEND (Data Management)        │  ← Stores/manages data
├────────────────────────────────────┤
│ • User profiles (name, email)      │
│ • Delivery addresses               │
│ • Order history                    │
│ • Favorites                        │
│ • Product catalog                  │
│                                    │
│ Location: Render (onrender.com)    │
│ Responsibility: Business Data      │
└────────────────────────────────────┘
```

## Current vs Recommended Security

### Current Implementation
```
Flutter App
    │
    ├─→ Firebase: "Verify this OTP for +919876543210"
    │        ↓
    │   ✅ OTP verified
    │        ↓
    │   Firebase returns session token
    │
    └─→ Backend: "Get profile for +919876543210"
             ↓
        ⚠️  Backend: "OK, here's the profile"
             (No verification of who is asking!)
```

### Recommended Implementation (Future)
```
Flutter App
    │
    ├─→ Firebase: "Verify this OTP for +919876543210"
    │        ↓
    │   ✅ OTP verified
    │        ↓
    │   Firebase returns ID token
    │
    └─→ Backend: "Get profile (with ID token)"
             ↓
        ✅ Backend verifies ID token
             ↓
        ✅ Backend confirms: "+919876543210"
             ↓
        ✅ Backend: "OK, here's YOUR profile"
             (Verified and secure!)
```

---

**In Summary:**
- **Frontend (Flutter)**: Authentication via Firebase ✅
- **Backend (FastAPI)**: User data management (currently without token verification) ⚠️
- **Ready for**: Backend token validation upgrade when needed

