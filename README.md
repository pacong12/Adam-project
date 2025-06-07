# Proyek Arduino dan ESP32

## Deskripsi
Proyek ini berisi implementasi kode untuk Arduino dan ESP32 yang dapat digunakan untuk berbagai aplikasi IoT (Internet of Things). Proyek ini fokus pada pengembangan Smart Fan Controller yang dapat dikontrol melalui aplikasi Blynk IoT.

## Fitur Utama
- Monitoring suhu dan kelembaban secara real-time
- Kontrol kipas otomatis berdasarkan suhu dan kelembaban
- Mode manual dan otomatis
- Penjadwalan operasi kipas
- Dashboard monitoring melalui aplikasi Blynk
- Grafik tren suhu dan kelembaban

## Struktur Proyek
- `Arduino.ino` - Kode utama untuk Arduino
- `esp32.ino` - Kode untuk ESP32
- `panduan.md` - Dokumentasi panduan penggunaan
- `datastream.md` - Dokumentasi tentang aliran data

## Persyaratan
- Arduino IDE
- ESP32 board support package
- Library yang diperlukan:
  - Blynk IoT
  - DHT sensor library
  - ESP32 board support package
  - WiFi library

## Cara Penggunaan
1. Buka file `.ino` yang sesuai dengan board yang Anda gunakan di Arduino IDE
2. Pastikan board support package sudah terinstal
3. Upload kode ke board Anda
4. Ikuti panduan di `panduan.md` untuk konfigurasi lebih lanjut

## Diagram Alur
```
[ESP32] <-> [Sensor DHT] <-> [Kipas]
   ↑
   ↓
[WiFi] <-> [Blynk Cloud] <-> [Aplikasi Blynk]
```

## Troubleshooting
1. Masalah Koneksi WiFi
   - Pastikan kredensial WiFi benar
   - Periksa kekuatan sinyal WiFi
   - Restart ESP32 jika diperlukan

2. Sensor Tidak Berfungsi
   - Periksa koneksi kabel sensor
   - Pastikan library DHT terinstal dengan benar
   - Verifikasi pin yang digunakan

3. Kipas Tidak Merespons
   - Periksa koneksi relay
   - Verifikasi pin output
   - Pastikan power supply mencukupi

## Dokumentasi
- Lihat `panduan.md` untuk panduan lengkap penggunaan
- Lihat `datastream.md` untuk informasi tentang aliran data

## Kontribusi
Silakan buat pull request untuk kontribusi. Untuk perubahan besar, harap buka issue terlebih dahulu untuk mendiskusikan perubahan yang diinginkan.

## Lisensi
[MIT](https://choosealicense.com/licenses/mit/) 