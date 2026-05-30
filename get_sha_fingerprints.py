#!/usr/bin/env python3
"""
Generate SHA-1 and SHA-256 fingerprints for Android debug keystore
"""
import subprocess
import os
import sys

def get_sha_fingerprints():
    """Extract SHA fingerprints from debug keystore"""
    keystore_path = os.path.expanduser("~/.android/debug.keystore")
    
    if not os.path.exists(keystore_path):
        print(f"❌ Debug keystore not found at: {keystore_path}")
        print("\nTo generate it, run:")
        print("  flutter clean")
        print("  flutter run")
        return None
    
    try:
        # Try to find keytool
        keytool_paths = [
            os.path.expandvars("$JAVA_HOME/bin/keytool.exe"),
            os.path.expandvars("$JAVA_HOME/bin/keytool"),
            "keytool.exe",
            "keytool",
        ]
        
        keytool_path = None
        for path in keytool_paths:
            if os.path.exists(path):
                keytool_path = path
                break
        
        if not keytool_path:
            print("❌ keytool not found. Make sure Java is installed and JAVA_HOME is set.")
            print("\nSet JAVA_HOME manually:")
            print('  $env:JAVA_HOME = "C:\\Program Files\\Java\\jdk1.8.0_xxx"  # or your Java version')
            return None
        
        # Run keytool to get SHA fingerprints
        cmd = [
            keytool_path,
            "-list",
            "-v",
            "-keystore", keystore_path,
            "-alias", "androiddebugkey",
            "-storepass", "android",
            "-keypass", "android"
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"❌ Error running keytool: {result.stderr}")
            return None
        
        output = result.stdout
        lines = output.split('\n')
        
        sha1 = None
        sha256 = None
        
        for line in lines:
            if 'SHA1:' in line or 'SHA-1:' in line:
                sha1 = line.split(':')[-1].strip()
            elif 'SHA-256:' in line or 'SHA256:' in line:
                sha256 = line.split(':')[-1].strip()
        
        if not sha1 or not sha256:
            print("❌ Could not extract SHA fingerprints from keystore")
            print("\nKeytool output:")
            print(output)
            return None
        
        return {"SHA-1": sha1, "SHA-256": sha256}
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

def main():
    print("🔐 Android SHA Fingerprint Generator")
    print("=" * 50)
    
    fingerprints = get_sha_fingerprints()
    
    if fingerprints:
        print("\n✅ SHA Fingerprints for Firebase:")
        print("=" * 50)
        print(f"\n📍 SHA-1:\n   {fingerprints['SHA-1']}")
        print(f"\n🔒 SHA-256:\n   {fingerprints['SHA-256']}")
        print("\n" + "=" * 50)
        print("\n📋 To add to Firebase Console:")
        print("1. Go to Firebase Console > Project Settings")
        print("2. Select your Android app (com.vectorai.almadhina)")
        print("3. Scroll to 'SHA certificate fingerprints'")
        print("4. Add both SHA-1 and SHA-256 fingerprints")
        print("5. Click 'Save'")
        print("\n✨ After adding, phone authentication will work properly!\n")
    else:
        print("\n❌ Failed to extract SHA fingerprints")
        print("\nTroubleshooting:")
        print("1. Ensure Java/JDK is installed")
        print("2. Set JAVA_HOME environment variable")
        print("3. Ensure ~/.android/debug.keystore exists")
        sys.exit(1)

if __name__ == "__main__":
    main()
