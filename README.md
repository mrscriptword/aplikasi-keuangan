# Catatan Keuangan

Aplikasi Android Flutter offline berdasarkan `Desain Aplikasi Keuangan.html`.
Data awal kosong; transaksi disimpan dalam SQLite di perangkat.

## Fitur

- Beranda: ringkasan bulan berjalan dan transaksi per hari.
- Catatan: pilihan bulan, filter pemasukan/pengeluaran, riwayat per tanggal.
- Tambah, edit (ketuk transaksi), dan hapus catatan.
- Rekap: grafik tujuh hari dan pengeluaran per kategori.
- Profil: informasi penyimpanan lokal. Halaman ini tambahan karena desain
  sumber hanya menyediakan empat layar.
- Rupiah, bahasa Indonesia, font Inter dibundel sehingga tidak perlu internet.

## Build APK melalui GitHub Actions

1. Buat repository GitHub dan unggah isi folder ini, termasuk folder tersembunyi
   `.github` beserta workflow-nya. Jika memakai Git, jalankan dari folder proyek:

   ```powershell
   git init
   git add .
   git commit -m "Build aplikasi keuangan Flutter offline"
   git branch -M main
   git remote add origin https://github.com/USERNAME/NAMA-REPOSITORY.git
   git push -u origin main
   ```

2. Buka tab **Actions → Build Android APK**.
3. Build otomatis berjalan pada push `main`/`master`, atau pilih **Run workflow**.
4. Setelah berhasil, unduh **catatan-keuangan-apk** pada bagian **Artifacts**.
5. Ekstrak ZIP dan instal `app-release.apk` di HP Android.

Workflow memasang Flutter 3.35.7, membuat Android runner resmi, menjalankan
analisis dan tes, lalu membangun APK. Folder `android/` sengaja dihasilkan
dari template SDK yang sama agar Gradle wrapper cocok dengan versi Flutter.

APK release memakai signing debug bawaan template Flutter untuk instalasi
pribadi/uji coba, belum signing produksi Play Store. Kunci debug pada runner
GitHub dapat berbeda antarbuilt; untuk pembaruan APK tanpa uninstall dan
tanpa kehilangan data, gunakan keystore release tetap sebelum distribusi
jangka panjang. Jangan uninstall aplikasi berisi data penting untuk mengganti APK.

### Signing tetap untuk pembaruan APK

Workflow mendukung keystore sendiri. Buat satu kali dengan Java `keytool`:

```powershell
keytool -genkeypair -v -keystore catatan-release.jks -alias catatan -keyalg RSA -keysize 2048 -validity 10000
[Convert]::ToBase64String([IO.File]::ReadAllBytes("catatan-release.jks")) | Set-Clipboard
```

Simpan keystore dan password untuk build berikutnya. Di GitHub → Settings →
Secrets and variables → Actions, tambahkan:

- `ANDROID_KEYSTORE_BASE64`: isi clipboard dari perintah di atas.
- `ANDROID_STORE_PASSWORD`: password keystore.
- `ANDROID_KEY_PASSWORD`: password key.
- `ANDROID_KEY_ALIAS`: `catatan`.

Workflow otomatis memakai signing release ketika secret tersebut tersedia.
Gunakan signing tetap sejak APK pertama yang akan menyimpan data Anda.

## Pengembangan lokal (setelah Flutter terpasang)

```powershell
flutter create --platforms=android --org=id.rendy --project-name=catatan_keuangan --no-pub .runner
Copy-Item .runner/android android -Recurse
python tool/configure_android.py
flutter pub get
flutter analyze
flutter test
flutter run
```

Folder `.runner` hanya template sementara dan dapat dihapus setelah runner disalin.

## Struktur

- `lib/main.dart`: tema, navigasi, layar dan formulir.
- `lib/data.dart`: model, agregasi rupiah integer, dan database SQLite.
- `test/ledger_test.dart`: CRUD SQLite, validasi dan perhitungan lintas tahun.
- `.github/workflows/android.yml`: analisis, tes, build dan artifact APK.

Tidak ada login, server, iklan, atau sinkronisasi. Menghapus data aplikasi atau
uninstall dapat menghilangkan semua transaksi. Backup cloud Android dinonaktifkan.

## Status verifikasi

SDK Flutter belum tersedia di lingkungan pembuatan source ini. Analisis Dart,
tes Flutter, pemeriksaan visual pada emulator, dan build APK harus diverifikasi
melalui workflow atau lingkungan Flutter.
