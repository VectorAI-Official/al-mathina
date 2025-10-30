# Language Persistence Flow Diagram

## App Initialization Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    App Start (main())                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
         ┌───────────────────────────────────┐
         │  WidgetsFlutterBinding.ensureInit │
         └───────────────────┬───────────────┘
                             │
                             ▼
         ┌───────────────────────────────────────┐
         │ Create new AppProvider instance       │
         │ _currentLanguage = 'en' (default)     │
         └───────────────────┬───────────────────┘
                             │
                             ▼
         ┌───────────────────────────────────────────────────┐
         │      appProvider.loadLanguage()                   │
         │  ┌─────────────────────────────────────────────┐ │
         │  │ Get SharedPreferences instance              │ │
         │  │ savedLanguage = prefs.getString('user...') │ │
         │  └──────────────────┬──────────────────────────┘ │
         │                     │                             │
         │        ┌────────────┴────────────┐                │
         │        │                         │                │
         │    ▼ (Found)                 ▼ (Not Found)        │
         │  ┌─────────┐              ┌──────────────────┐   │
         │  │Set lang │              │Use default 'en'  │   │
         │  │from pref│              │_currentLanguage  │   │
         │  └────┬────┘              └──────────┬───────┘   │
         │       │                              │            │
         │       └──────────┬───────────────────┘            │
         │                  │                                │
         │                  ▼                                │
         │         ┌────────────────────┐                   │
         │         │ notifyListeners()  │                   │
         │         └────────────────────┘                   │
         └───────────────────┬───────────────────────────────┘
                             │
                             ▼
         ┌───────────────────────────────────────┐
         │  Pass AppProvider to runApp()         │
         │  Create MyApp with provider           │
         └───────────────────┬───────────────────┘
                             │
                             ▼
         ┌───────────────────────────────────────┐
         │  App builds UI with saved language    │
         │  User sees content in correct language│
         └───────────────────────────────────────┘
```

## Language Change Flow

```
┌──────────────────────────────────┐
│ User selects language dropdown   │
└────────────────┬─────────────────┘
                 │
                 ▼
   ┌─────────────────────────────────┐
   │ onChanged: (value) {             │
   │   provider.setLanguage(value)    │
   │ }                               │
   └────────────────┬────────────────┘
                    │
                    ▼
   ┌──────────────────────────────────────────┐
   │ setLanguage(String lang)                 │
   │ ├─ Check translations.containsKey(lang) │
   │ ├─ _currentLanguage = lang               │
   │ ├─ _saveLanguage(lang) [async]           │
   │ │  │                                     │
   │ │  └─→ Save to SharedPreferences        │
   │ │     prefs.setString('userLanguage',   │
   │ │                      lang)             │
   │ │                                        │
   │ └─ notifyListeners()                    │
   └────────────────┬────────────────────────┘
                    │
                    ▼
   ┌──────────────────────────────────┐
   │ UI Rebuilds with new language    │
   │ All text updates instantly       │
   └──────────────────────────────────┘
```

## State Persistence

```
BEFORE: No language persistence
┌─────────────────────┐
│ Select Tamil        │
└──────────┬──────────┘
           │
           ▼
    ┌────────────────┐
    │ App in Tamil   │
    └────────┬───────┘
             │
             ▼
    ┌────────────────┐
    │ Close app      │
    └────────┬───────┘
             │
             ▼
    ┌────────────────────────┐
    │ Reopen app             │
    │ ❌ Defaults to English │
    └────────────────────────┘

AFTER: With language persistence
┌─────────────────────┐
│ Select Tamil        │
└──────────┬──────────┘
           │
           ▼
    ┌────────────────────────────────┐
    │ App in Tamil                   │
    │ Save 'ta' to SharedPreferences │
    └────────┬───────────────────────┘
             │
             ▼
    ┌────────────────┐
    │ Close app      │
    └────────┬───────┘
             │
             ▼
    ┌────────────────────────────┐
    │ Reopen app                 │
    │ Load saved language 'ta'   │
    │ ✅ App displays in Tamil   │
    └────────────────────────────┘
```

## Data Storage Structure

```
SharedPreferences Storage
┌────────────────────────────────────────┐
│ Key: 'userLanguage'                    │
│ Value: 'en' or 'ta'                    │
│ Type: String                           │
│ Persistent: Yes (survives app restart) │
│ Location: Device local storage         │
└────────────────────────────────────────┘

AppProvider Memory State
┌────────────────────────────────────────┐
│ _currentLanguage: String               │
│  ├─ Set on app startup from prefs      │
│  ├─ Updated when user changes language │
│  └─ Used to provide text() method      │
│                                        │
│ Listeners (UI Widgets)                 │
│  └─ Notified when _currentLanguage     │
│     changes to trigger rebuild         │
└────────────────────────────────────────┘
```

## Fallback Behavior

```
Language Loading Fallback Chain:

1. App Starts
   ↓
2. Try to load from SharedPreferences
   │
   ├─ Success & Valid? → Use saved language
   │
   ├─ Key not found? → Use default 'en'
   │
   ├─ Invalid language? → Use default 'en'
   │
   └─ Error occurred? → Use default 'en', log error
   
   ↓
3. UI Displays with language
```
