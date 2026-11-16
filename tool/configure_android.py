"""Apply application metadata after Flutter generates the Android runner."""
from pathlib import Path

manifest = Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text(encoding="utf-8")
text = text.replace('android:label="catatan_keuangan"',
                    'android:label="Catatan Keuangan" android:allowBackup="false"')
manifest.write_text(text, encoding="utf-8")
