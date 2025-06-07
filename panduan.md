# Setup Dashboard Blynk - Smart Fan Controller

## 📱 Langkah 1: Setup Akun dan Template

### A. Buat Akun Blynk
1. Download **Blynk IoT** app dari Play Store/App Store
2. Buat akun baru atau login
3. Buka [Blynk Console](https://blynk.cloud) di browser

### B. Buat Template Baru
1. Di Blynk Console, klik **"+ Create Template"**
2. Isi form:
   - **Name:** `Smart Fan Controller`
   - **Hardware:** `ESP32`
   - **Connection Type:** `WiFi`
3. Klik **"Done"**
4. **Catat Template ID** (contoh: TMPL12345678)

## 🔗 Langkah 2: Setup Datastreams

Buat 12 datastream berikut di tab **"Datastreams"**:

### Monitoring Datastreams
```
V0 - Temperature
├── Name: Temperature
├── PIN: V0
├── Data Type: Double
├── Units: °C
├── Min: -10, Max: 60
├── Default: 25
└── Decimals: 1

V1 - Humidity  
├── Name: Humidity
├── PIN: V1
├── Data Type: Double
├── Units: %
├── Min: 0, Max: 100
├── Default: 50
└── Decimals: 1

V2 - Fan Status
├── Name: Fan Status
├── PIN: V2
├── Data Type: String
└── Default: "OFF"

V11 - Current Time
├── Name: Current Time
├── PIN: V11
├── Data Type: String
└── Default: "00:00"
```

### Control Datastreams
```
V3 - Manual Mode
├── Name: Manual Mode
├── PIN: V3
├── Data Type: Integer
├── Min: 0, Max: 1
└── Default: 0

V4 - Manual Fan Control
├── Name: Manual Fan
├── PIN: V4
├── Data Type: Integer
├── Min: 0, Max: 1
└── Default: 0
```

### Settings Datastreams
```
V5 - Temperature Threshold
├── Name: Temp Threshold
├── PIN: V5
├── Data Type: Double
├── Units: °C
├── Min: 20, Max: 50
├── Default: 30
└── Decimals: 1

V6 - Humidity Threshold
├── Name: Humidity Threshold
├── PIN: V6
├── Data Type: Double
├── Units: %
├── Min: 30, Max: 90
├── Default: 60
└── Decimals: 1
```

### Schedule Datastreams
```
V7 - Start Hour
├── Name: Start Hour
├── PIN: V7
├── Data Type: Integer
├── Min: 0, Max: 23
└── Default: 7

V8 - End Hour
├── Name: End Hour
├── PIN: V8
├── Data Type: Integer
├── Min: 0, Max: 23
└── Default: 14

V9 - Start Minute
├── Name: Start Minute
├── PIN: V9
├── Data Type: Integer
├── Min: 0, Max: 59
└── Default: 0

V10 - End Minute
├── Name: End Minute
├── PIN: V10
├── Data Type: Integer
├── Min: 0, Max: 59
└── Default: 0
```

## 📱 Langkah 3: Buat Device

1. Di Blynk Console, buka tab **"Devices"**
2. Klik **"+ New Device"**
3. Pilih **"From Template"**
4. Pilih template "Smart Fan Controller"
5. Beri nama: `Fan Controller - Room 1`
6. Klik **"Create"**
7. **Catat Auth Token** (contoh: abcd1234efgh5678...)

## 📱 Langkah 4: Design Mobile Dashboard

### Tab 1: 📊 MONITOR
**Layout:** Portrait, 4 widgets per row

**Widget 1 - Temperature Gauge**
```
Widget: Gauge
Datastream: V0 (Temperature)
Position: Row 1, Col 1-2
Color: Orange
Title: "Temperature"
Show: Value + Units
```

**Widget 2 - Humidity Gauge**
```
Widget: Gauge  
Datastream: V1 (Humidity)
Position: Row 1, Col 3-4
Color: Blue
Title: "Humidity"
Show: Value + Units
```

**Widget 3 - Fan Status**
```
Widget: Value Display
Datastream: V2 (Fan Status)
Position: Row 2, Col 1-2
Color: Green (ON) / Red (OFF)
Title: "Fan Status"
Font Size: Large
```

**Widget 4 - Current Time**
```
Widget: Value Display
Datastream: V11 (Current Time)
Position: Row 2, Col 3-4
Color: Purple
Title: "Current Time"
Font Size: Large
```

**Widget 5 - Temperature Chart**
```
Widget: Chart
Datastream: V0 (Temperature)
Position: Row 3, Full Width
Time Range: 6 hours
Color: Orange
Title: "Temperature Trend"
```

**Widget 6 - Humidity Chart**
```
Widget: Chart
Datastream: V1 (Humidity)
Position: Row 4, Full Width
Time Range: 6 hours
Color: Blue  
Title: "Humidity Trend"
```

### Tab 2: 🎮 CONTROL
**Layout:** Portrait, Clean spacing

**Widget 1 - Mode Switch**
```
Widget: Switch
Datastream: V3 (Manual Mode)
Position: Row 1, Full Width
OFF Label: "AUTO MODE"
ON Label: "MANUAL MODE"
OFF Color: Green
ON Color: Orange
Size: Large
```

**Widget 2 - Manual Fan Control**
```
Widget: Button
Datastream: V4 (Manual Fan)
Position: Row 2, Full Width
OFF Label: "FAN OFF"
ON Label: "FAN ON"
OFF Color: Red
ON Color: Green
Mode: Push (momentary)
Size: Large
Note: "Only works in Manual Mode"
```

**Widget 3 - System Status**
```
Widget: Value Display
Datastream: V2 (Fan Status)
Position: Row 3, Col 1-2
Title: "System Status"
Font Size: Medium
```

**Widget 4 - Mode Indicator**
```
Widget: LED
Datastream: V3 (Manual Mode)
Position: Row 3, Col 3-4
Title: "Manual Mode"
OFF Color: Green (Auto)
ON Color: Orange (Manual)
```

### Tab 3: ⚙️ SETTINGS
**Layout:** Vertical, with labels

**Widget 1 - Temperature Threshold**
```
Widget: Slider
Datastream: V5 (Temp Threshold)
Position: Row 1, Full Width
Title: "Temperature Threshold"
Show Value: Yes
Color: Orange
Label: "Fan turns ON when temp >"
```

**Widget 2 - Humidity Threshold**
```
Widget: Slider
Datastream: V6 (Humidity Threshold)
Position: Row 2, Full Width
Title: "Humidity Threshold"
Show Value: Yes
Color: Blue
Label: "Fan turns ON when humidity >"
```

**Widget 3 - Current Thresholds Display**
```
Widget: Value Display
Datastream: V5 (Temp Threshold)
Position: Row 3, Col 1-2
Title: "Temp Setting"
Suffix: "°C"
```

**Widget 4 - Current Humidity Display**
```
Widget: Value Display
Datastream: V6 (Humidity Threshold)  
Position: Row 3, Col 3-4
Title: "Humidity Setting"
Suffix: "%"
```

### Tab 4: ⏰ SCHEDULE
**Layout:** Form-like, organized

**Widget 1 - Start Time Section**
```
Widget: Styled Button (Header)
Position: Row 1, Full Width
Text: "START TIME"
Color: Green
Non-functional (decoration only)
```

**Widget 2 - Start Hour**
```
Widget: Numeric Input
Datastream: V7 (Start Hour)
Position: Row 2, Col 1-2
Title: "Start Hour"
Suffix: "h"
```

**Widget 3 - Start Minute**
```
Widget: Numeric Input
Datastream: V9 (Start Minute)
Position: Row 2, Col 3-4
Title: "Start Min"
Suffix: "m"
```

**Widget 4 - End Time Section**
```
Widget: Styled Button (Header)
Position: Row 3, Full Width
Text: "END TIME"
Color: Red
Non-functional (decoration only)
```

**Widget 5 - End Hour**
```
Widget: Numeric Input
Datastream: V8 (End Hour)
Position: Row 4, Col 1-2
Title: "End Hour"
Suffix: "h"
```

**Widget 6 - End Minute**
```
Widget: Numeric Input
Datastream: V10 (End Minute)
Position: Row 4, Col 3-4
Title: "End Min"
Suffix: "m"
```

**Widget 7 - Schedule Summary**
```
Widget: Value Display
Datastream: Custom text
Position: Row 5, Full Width
Title: "Current Schedule"
Text: "Active: 07:00 - 14:00"
Update via code or manual
```

## 🔧 Langkah 5: Setup Device di Mobile App

1. Buka **Blynk IoT** app di smartphone
2. Klik **"Add Device"**
3. Pilih **"Find Devices Nearby"** atau **"Manual Setup"**
4. Masukkan **Auth Token** dari step 3
5. Device akan muncul di dashboard

## 📝 Langkah 6: Update ESP32 Code

Update kode ESP32 dengan kredensial Anda:

```cpp
#define BLYNK_TEMPLATE_ID "TMPL12345678"  // Dari step 1
#define BLYNK_AUTH_TOKEN "abcd1234..."    // Dari step 3

char ssid[] = "YourWiFiName";
char pass[] = "YourWiFiPassword";
```

## 🧪 Langkah 7: Testing Dashboard

### A. Test Monitoring
1. Upload kode ke ESP32
2. Buka Serial Monitor - cek koneksi WiFi
3. Buka Blynk app - cek data sensor masuk
4. Tunggu 5-10 detik untuk sinkronisasi

### B. Test Controls
1. **Switch Mode**: Ubah dari Auto ke Manual
2. **Manual Fan**: Tekan tombol di mode manual
3. **Settings**: Ubah threshold temperature/humidity
4. **Schedule**: Set jam operasi baru

### C. Troubleshooting
```
❌ Data tidak muncul:
   - Cek Serial Monitor ESP32
   - Pastikan WiFi terhubung
   - Cek Auth Token benar

❌ Control tidak berfungsi:
   - Cek komunikasi UART Arduino-ESP32
   - Pastikan pin RX/TX benar
   - Cek Serial Monitor Arduino

❌ App tidak connect:
   - Restart ESP32
   - Cek Template ID dan Auth Token
   - Pastikan device sudah dibuat di Console
```

## 🎨 Tips UI/UX

### Color Scheme
- **Temperature**: Orange/Red gradient
- **Humidity**: Blue gradient  
- **Fan ON**: Green
- **Fan OFF**: Red
- **Manual Mode**: Orange
- **Auto Mode**: Green

### Widget Sizing
- **Gauges**: Medium to Large
- **Buttons**: Large for easy tap
- **Sliders**: Full width with labels
- **Charts**: Full width, 6-hour window

### Notifications (Optional)
Tambahkan notifikasi untuk:
- Fan turned ON/OFF
- Temperature/Humidity alerts
- System mode changes
- WiFi connection issues

## 📊 Dashboard Preview

```
📱 TAB 1: MONITOR
┌─────────────────────────────┐
│  🌡️ Temp    💧 Humidity    │
│   28.5°C      65%           │
│                             │
│  🔥 Fan: ON   ⏰ 14:30     │
│                             │
│  📈 Temperature Chart       │
│  ▓▓░░▓▓▓░░░▓▓▓▓░░          │
│                             │
│  📈 Humidity Chart          │
│  ░░▓▓▓░░▓▓▓▓░░▓▓▓          │
└─────────────────────────────┘

📱 TAB 2: CONTROL  
┌─────────────────────────────┐
│  🔄 [AUTO MODE    ]         │
│     ────────────────        │
│                             │
│  🎮 [   FAN OFF   ]         │
│     ────────────────        │
│                             │
│  Status: AUTO  🟢 Auto     │
└─────────────────────────────┘
```

Dengan setup ini, Anda akan memiliki dashboard yang lengkap dan mudah digunakan untuk mengontrol sistem kipas otomatis!