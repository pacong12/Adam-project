# 📖 MANUAL BOOK - FAN AUTOMATION SYSTEM
## ESP32 + Arduino + Flutter Mobile App

---

## 📋 DAFTAR ISI
1. [Overview Project](#overview-project)
2. [Komponen Hardware](#komponen-hardware)
3. [Instalasi & Setup](#instalasi--setup)
4. [Konfigurasi ESP32](#konfigurasi-esp32)
5. [Konfigurasi Arduino](#konfigurasi-arduino)
6. [Setup Flutter App](#setup-flutter-app)
7. [Cara Penggunaan](#cara-penggunaan)
8. [Troubleshooting](#troubleshooting)
9. [API Documentation](#api-documentation)
10. [Maintenance](#maintenance)

---

## 🎯 OVERVIEW PROJECT

### Deskripsi
Sistem Fan Automation adalah project IoT yang mengontrol kipas angin secara otomatis berdasarkan suhu dan kelembaban. Sistem terdiri dari:
- **ESP32**: Modul WiFi untuk komunikasi internet
- **Arduino Uno**: Mikrokontroler untuk membaca sensor dan mengontrol relay
- **Flutter App**: Aplikasi mobile untuk monitoring dan kontrol

### Fitur Utama
- ✅ **Real-time Monitoring**: Suhu, kelembaban, status kipas
- ✅ **Mode Otomatis**: Kipas ON/OFF berdasarkan threshold
- ✅ **Mode Manual**: Kontrol manual kipas
- ✅ **Scheduling**: Jadwal otomatis kipas
- ✅ **SmartConfig**: Setup WiFi mudah
- ✅ **Mobile App**: Kontrol via smartphone
- ✅ **Web Interface**: Monitoring via browser

---

## 🔧 KOMPONEN HARDWARE

### Komponen Utama
| Komponen | Jumlah | Fungsi |
|----------|--------|--------|
| ESP32 DevKit | 1 | Modul WiFi & HTTP Server |
| Arduino Uno | 1 | Mikrokontroler utama |
| DHT22 Sensor | 1 | Sensor suhu & kelembaban |
| Relay Module | 1 | Kontrol kipas angin |
| LCD 16x2 | 1 | Display informasi |
| RTC DS3231 | 1 | Real-time clock |
| Breadboard | 1 | Prototyping |
| Jumper Wires | - | Koneksi |

### Koneksi Hardware
```
ESP32 <---> Arduino (UART)
  |         |
  |         +-- DHT22 (Pin 2)
  |         +-- Relay (Pin 8)
  |         +-- LCD (Pin 12,11,5,4,3,9)
  |         +-- RTC (A4, A5)
  |
  +-- WiFi Router
```

---

## ⚙️ INSTALASI & SETUP

### Prerequisites
- Arduino IDE (versi 1.8.x atau 2.x)
- Flutter SDK (versi 3.x)
- Android Studio / VS Code
- Library Arduino yang diperlukan

### Library Arduino yang Diperlukan
1. **DHT Sensor Library** (by Adafruit)
2. **LiquidCrystal**
3. **RTClib** (by Adafruit)
4. **ESP32 Board Support**

### Cara Install Library
1. Buka Arduino IDE
2. Menu: `Tools` → `Manage Libraries`
3. Search dan install library di atas
4. Restart Arduino IDE

---

## 🔌 KONFIGURASI ESP32

### 1. Setup Board ESP32
1. Buka Arduino IDE
2. Menu: `File` → `Preferences`
3. Tambahkan URL: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
4. Menu: `Tools` → `Board` → `Boards Manager`
5. Search "ESP32" dan install
6. Pilih board: `ESP32 Dev Module`

### 2. Upload Kode ESP32
1. Buka file `esp32/esp32.ino`
2. **Ubah WiFi credentials**:
   ```cpp
   char ssid[32] = "NAMA_WIFI_ANDA";      
   char pass[64] = "PASSWORD_WIFI_ANDA";
   ```
3. Pilih port COM ESP32
4. Klik `Upload`
5. Tunggu upload selesai

### 3. Verifikasi ESP32
1. Buka Serial Monitor (115200 baud)
2. Pastikan output:
   ```
   ESP32 Fan Automation Starting...
   Menghubungkan ke WiFi: NAMA_WIFI_ANDA
   WiFi terhubung! IP: 192.168.1.xxx
   HTTP server dimulai di port 80
   ```

### 4. Test Web Interface
1. Buka browser
2. Akses: `http://[IP_ESP32]/`
3. Harus muncul halaman status ESP32

---

## 🔌 KONFIGURASI ARDUINO

### 1. Koneksi Hardware
```
DHT22:
- VCC → 5V
- GND → GND
- DATA → Pin 2

Relay:
- VCC → 5V
- GND → GND
- IN → Pin 8

LCD 16x2:
- VSS → GND
- VDD → 5V
- V0 → Potentiometer
- RS → Pin 12
- RW → GND
- E → Pin 11
- D4 → Pin 5
- D5 → Pin 4
- D6 → Pin 3
- D7 → Pin 9

RTC DS3231:
- VCC → 5V
- GND → GND
- SDA → A4
- SCL → A5

ESP32 ↔ Arduino:
- ESP32 TX (GPIO17) → Arduino RX (Pin 0)
- ESP32 RX (GPIO16) → Arduino TX (Pin 1)
- GND → GND
```

### 2. Upload Kode Arduino
1. Buka file `Arduino/Arduino.ino`
2. Pilih board: `Arduino Uno`
3. Pilih port COM Arduino
4. Klik `Upload`
5. Tunggu upload selesai

### 3. Verifikasi Arduino
1. Buka Serial Monitor (9600 baud)
2. Pastikan output:
   ```
   Arduino Fan Control Starting...
   DHT22 initialized
   LCD initialized
   RTC initialized
   Waiting for ESP32...
   ```

---

## 📱 SETUP FLUTTER APP

### 1. Install Flutter
1. Download Flutter SDK dari [flutter.dev](https://flutter.dev)
2. Extract ke folder (misal: `C:\flutter`)
3. Tambahkan `C:\flutter\bin` ke PATH
4. Restart terminal/command prompt

### 2. Setup Project
1. Buka terminal di folder project
2. Masuk ke folder Flutter:
   ```bash
   cd fanmobile
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```

### 3. Konfigurasi IP ESP32
1. Buka file `fanmobile/lib/main.dart`
2. Cari variabel `esp32Url`
3. Ubah IP sesuai ESP32:
   ```dart
   String esp32Url = "http://192.168.1.xxx"; // Ganti dengan IP ESP32
   ```

### 4. Build & Run
1. **Android**:
   ```bash
   flutter build apk
   flutter install
   ```
2. **Debug Mode**:
   ```bash
   flutter run
   ```

---

## 📱 CARA PENGGUNAAN

### 1. Setup Awal
1. **Power ON** ESP32 dan Arduino
2. **Pastikan** keduanya terhubung ke WiFi yang sama
3. **Buka Flutter app** di smartphone
4. **Set IP ESP32** jika belum:
   - Klik icon ⚙️ (settings)
   - Masukkan IP ESP32
   - Klik "Simpan"

### 2. SmartConfig WiFi (Opsional)
1. Klik icon 📶 (WiFi) di app
2. Masukkan SSID dan password WiFi
3. Klik "Mulai"
4. Tunggu proses konfigurasi selesai
5. Input IP ESP32 yang muncul

### 3. Kontrol Fan
#### Mode Manual
1. **Aktifkan Mode Manual**:
   - Toggle switch "Mode Manual" ke ON
2. **Kontrol Fan**:
   - Klik "Nyalakan" untuk ON
   - Klik "Matikan" untuk OFF

#### Mode Otomatis
1. **Aktifkan Mode Otomatis**:
   - Toggle switch "Mode Manual" ke OFF
2. **Set Threshold**:
   - Geser slider suhu (default: 30°C)
   - Geser slider kelembaban (default: 70%)
3. **Fan akan otomatis** ON/OFF berdasarkan threshold

### 4. Scheduling
1. **Set Jadwal**:
   - Masukkan jam mulai (0-23)
   - Masukkan jam selesai (0-23)
   - Masukkan menit mulai (0-59)
   - Masukkan menit selesai (0-59)
2. **Klik "Simpan"**
3. **Fan akan otomatis** ON/OFF sesuai jadwal

### 5. Monitoring
- **Real-time Data**: Update setiap 2 detik
- **Status Fan**: ON/OFF dengan alasan
- **Trend Data**: Indikator naik/turun
- **Last Update**: Waktu update terakhir

---

## 🔧 TROUBLESHOOTING

### ESP32 Issues

#### WiFi Tidak Connect
**Gejala**: ESP32 tidak bisa connect WiFi
**Solusi**:
1. Cek SSID dan password WiFi
2. Pastikan WiFi 2.4GHz (ESP32 tidak support 5GHz)
3. Restart ESP32
4. Cek jarak dengan router

#### HTTP Server Error
**Gejala**: Flutter app tidak bisa connect
**Solusi**:
1. Cek IP ESP32 di Serial Monitor
2. Test ping dari komputer: `ping [IP_ESP32]`
3. Buka browser: `http://[IP_ESP32]/`
4. Restart ESP32

#### UART Communication Error
**Gejala**: Data sensor tidak update
**Solusi**:
1. Cek koneksi TX/RX ESP32 ↔ Arduino
2. Pastikan baudrate sama (9600)
3. Restart kedua device
4. Cek Serial Monitor Arduino

### Arduino Issues

#### Sensor DHT22 Error
**Gejala**: Suhu/kelembaban tidak terbaca
**Solusi**:
1. Cek koneksi DHT22 (VCC, GND, DATA)
2. Ganti kabel jumper
3. Cek library DHT
4. Restart Arduino

#### Relay Tidak Berfungsi
**Gejala**: Kipas tidak ON/OFF
**Solusi**:
1. Cek koneksi relay (VCC, GND, IN)
2. Test relay dengan multimeter
3. Cek koneksi kipas ke relay
4. Ganti relay jika rusak

#### LCD Tidak Menampilkan
**Gejala**: LCD kosong atau error
**Solusi**:
1. Cek koneksi LCD (VCC, GND, RS, E, D4-D7)
2. Atur potentiometer untuk kontras
3. Restart Arduino
4. Ganti LCD jika rusak

### Flutter App Issues

#### Tidak Bisa Connect ESP32
**Gejala**: Error "Tidak bisa connect ke ESP32"
**Solusi**:
1. Cek IP ESP32 benar
2. Pastikan smartphone dan ESP32 satu WiFi
3. Test ping dari smartphone
4. Restart app

#### Data Tidak Update
**Gejala**: Data statis, tidak real-time
**Solusi**:
1. Pull-to-refresh
2. Klik icon refresh
3. Restart app
4. Cek koneksi internet

#### App Crash
**Gejala**: App force close
**Solusi**:
1. Clear app data
2. Uninstall dan install ulang
3. Update Flutter SDK
4. Cek log error

---

## 📚 API DOCUMENTATION

### Base URL
```
http://[ESP32_IP]:80
```

### Endpoints

#### 1. GET /get_data
**Deskripsi**: Ambil data sensor dan status
**Response**:
```json
{
  "temperature": 25.5,
  "humidity": 65.2,
  "fan": true,
  "manualMode": false,
  "tempThreshold": 30.0,
  "humidThreshold": 70.0,
  "schedule": [7, 14, 0, 0],
  "hour": 10,
  "minute": 30,
  "dataValid": true,
  "wifiRSSI": -45,
  "uptime": 3600
}
```

#### 2. POST /set_fan
**Deskripsi**: Kontrol fan ON/OFF
**Body**: `"true"` atau `"false"`
**Response**:
```json
{
  "status": "OK",
  "fan": true
}
```

#### 3. POST /set_mode
**Deskripsi**: Set mode manual/otomatis
**Body**: `"true"` (manual) atau `"false"` (otomatis)
**Response**:
```json
{
  "status": "OK",
  "manualMode": true
}
```

#### 4. POST /set_threshold
**Deskripsi**: Set threshold suhu dan kelembaban
**Body**: `"temp,humid"` (contoh: `"30.0,70.0"`)
**Response**:
```json
{
  "status": "OK"
}
```

#### 5. POST /set_schedule
**Deskripsi**: Set jadwal fan
**Body**: `"startHour,endHour,startMin,endMin"` (contoh: `"7,14,0,0"`)
**Response**:
```json
{
  "status": "OK"
}
```

#### 6. GET /status
**Deskripsi**: Status ESP32
**Response**:
```json
{
  "wifiConnected": true,
  "ip": "192.168.1.100",
  "rssi": -45,
  "uptime": 3600,
  "dataValid": true
}
```

#### 7. GET /
**Deskripsi**: Web interface status
**Response**: HTML page

---

## 🔧 MAINTENANCE

### Daily Maintenance
1. **Cek Sensor**: Pastikan DHT22 bersih
2. **Monitor Logs**: Cek Serial Monitor untuk error
3. **Test Fan**: Test ON/OFF manual
4. **Cek WiFi**: Pastikan koneksi stabil

### Weekly Maintenance
1. **Clean Hardware**: Bersihkan debu dari sensor dan board
2. **Update Time**: Sync RTC jika perlu
3. **Backup Settings**: Catat threshold dan schedule
4. **Test Full System**: Test semua fitur

### Monthly Maintenance
1. **Check Connections**: Cek semua koneksi kabel
2. **Update Firmware**: Update ESP32/Arduino jika ada
3. **Performance Check**: Cek response time dan stability
4. **Hardware Inspection**: Cek komponen untuk kerusakan

### Troubleshooting Log
| Date | Issue | Solution | Status |
|------|-------|----------|--------|
| - | - | - | - |

---

## 📞 SUPPORT

### Contact Information
- **Email**: [your-email@domain.com]
- **WhatsApp**: [+62xxx-xxxx-xxxx]
- **GitHub**: [github.com/your-username]

### Resources
- **ESP32 Documentation**: [docs.espressif.com](https://docs.espressif.com)
- **Arduino Reference**: [arduino.cc/reference](https://arduino.cc/reference)
- **Flutter Documentation**: [docs.flutter.dev](https://docs.flutter.dev)

### Version History
- **v1.0.0**: Initial release
- **v1.1.0**: Added SmartConfig feature
- **v1.2.0**: Improved error handling
- **v1.3.0**: Added web interface

---

## 📄 LICENSE

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**© 2024 Fan Automation System. All rights reserved.** 