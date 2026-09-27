# Antigravity ACP Account Manager — Panduan Penggunaan (`agy-account.sh`)

Skrip ini digunakan untuk mengelola autentikasi Google OAuth pada **Antigravity External Agent (ACP)** di Zed Editor. Memungkinkan penyimpanan multi-akun, beralih profil (*seamless switch*) tanpa harus login ulang di browser setiap saat, dan mempermudah onboarding akun baru.

---

## 📂 Lokasi Script & Data
- **Executable**: `utils/agy-account.sh`
- **Active Token**: `~/.gemini/antigravity-acp/acp_token.json`
- **Saved Profiles**: `~/.gemini/antigravity-acp/profiles/<nama_profil>.json`

---

## ⚡ Cheatsheet Perintah

### 1. Persiapan Awal
Pastikan skrip memiliki izin eksekusi:
```bash
chmod +x ./utils/agy-account.sh
```

### 2. Cek Akun Aktif & Daftar Profil
```bash
# Melihat email akun Google yang sedang aktif di Zed saat ini
./utils/agy-account.sh status

# Melihat seluruh profil akun Google yang tersimpan
./utils/agy-account.sh list
```

### 3. Menyimpan Akun Aktif ke Profil
Simpan token yang sedang aktif ke dalam slot profil agar bisa dipakai lagi nanti:
```bash
./utils/agy-account.sh save <nama_profil>
```
*Contoh:*
```bash
./utils/agy-account.sh save pribadi
./utils/agy-account.sh save kantor
```
*(Jika `<nama_profil>` dikosongkan, skrip otomatis menggunakan username email sebagai nama profil).*

### 4. Pindah Akun Secara Instan (*Seamless Switch*)
Ganti akun aktif ke profil tersimpan tanpa login ulang:
```bash
./utils/agy-account.sh switch <nama_profil>
```
*Contoh:*
```bash
./utils/agy-account.sh switch pribadi
```
*Skrip otomatis menukar file token dan mematikan background daemon `agy_acp_server.par` agar Zed langsung mengaktifkan akun baru pada request berikutnya.*

### 5. Login Akun Google Baru
Jika ingin menambahkan akun Google baru yang belum pernah login:
```bash
./utils/agy-account.sh new
```
**Langkah selanjutnya:**
1. Token lama akan otomatis di-backup.
2. Buka **Zed Editor** dan kirim pesan di panel Assistant.
3. Antigravity ACP akan memunculkan URL/halaman browser untuk Google OAuth login.
4. Pilih akun Google baru Anda di browser dan setujui izin akses.
5. Setelah berhasil, simpan profilnya:
   ```bash
   ./utils/agy-account.sh save <nama_profil_baru>
   ```

### 6. Menghapus Profil Tersimpan
```bash
./utils/agy-account.sh delete <nama_profil>
```

---

## 🛡️ Catatan Keamanan
- File profil token disimpan di luar repositori Git (`~/.gemini/antigravity-acp/profiles/`), sehingga aman dan tidak akan ter-commit ke GitHub.
- Jika koneksi agent di Zed terasa lambat merespons setelah berpindah akun, reload jendela editor via `Ctrl+Shift+P` -> `window: reload`.
