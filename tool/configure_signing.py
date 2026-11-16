"""Optional persistent release signing, configured using GitHub secrets."""
import base64
import os
from pathlib import Path

encoded = os.environ.get("KEYSTORE_BASE64", "")
if not encoded:
    print("Release secrets not set: using Flutter template debug signing.")
else:
    required = ("STORE_PASSWORD", "KEY_PASSWORD", "KEY_ALIAS")
    if not all(os.environ.get(key) for key in required):
        raise SystemExit("Incomplete Android signing secrets.")
    Path("android/app/release.jks").write_bytes(base64.b64decode(encoded, validate=True))
    gradle = Path("android/app/build.gradle.kts")
    text = gradle.read_text(encoding="utf-8")
    marker = "    buildTypes {"
    signing = '''
    signingConfigs {
        create("release") {
            storeFile = file("release.jks")
            storePassword = System.getenv("STORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }
'''
    if marker not in text or 'signingConfigs.getByName("debug")' not in text:
        raise SystemExit("Flutter signing template changed; review Gradle configuration.")
    text = text.replace(marker, signing + marker, 1).replace(
        'signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")'
    )
    gradle.write_text(text, encoding="utf-8")
