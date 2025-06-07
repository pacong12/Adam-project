#define BLYNK_TEMPLATE_ID "YourTemplateID"  // Ganti dengan Template ID Anda
#define BLYNK_TEMPLATE_NAME "Smart Fan Controller"
#define BLYNK_AUTH_TOKEN "YourAuthToken"  // Ganti dengan Auth Token Anda

#include <WiFi.h>
#include <BlynkSimpleEsp32.h>
#include <HardwareSerial.h>

// WiFi credentials
char ssid[] = "YourWiFiName";      // Ganti dengan nama WiFi Anda
char pass[] = "YourWiFiPassword";  // Ganti dengan password WiFi Anda

// UART communication dengan Arduino
HardwareSerial ArduinoSerial(2);

// Blynk Virtual Pins
#define V_TEMP           V0   // Display suhu
#define V_HUMIDITY       V1   // Display kelembaban
#define V_FAN_STATUS     V2   // Display status kipas
#define V_MANUAL_MODE    V3   // Switch mode manual/auto
#define V_MANUAL_FAN     V4   // Button kipas manual
#define V_TEMP_SLIDER    V5   // Slider threshold suhu
#define V_HUMID_SLIDER   V6   // Slider threshold kelembaban
#define V_START_HOUR     V7   // Input jam mulai
#define V_END_HOUR       V8   // Input jam selesai
#define V_START_MIN      V9   // Input menit mulai
#define V_END_MIN        V10  // Input menit selesai
#define V_CURRENT_TIME   V11  // Display waktu saat ini

// Variabel data sensor
struct SensorData {
  float temperature = 0;
  float humidity = 0;
  bool fanStatus = false;
  int currentHour = 0;
  int currentMinute = 0;
} sensorData;

BlynkTimer timer;

void setup() {
  Serial.begin(115200);
  ArduinoSerial.begin(9600, SERIAL_8N1, 16, 17); // RX=16, TX=17
  
  // Connect to Blynk
  Blynk.begin(BLYNK_AUTH_TOKEN, ssid, pass);
  
  Serial.println("ESP32 Gateway siap!");
  
  // Setup timer untuk membaca data dari Arduino
  timer.setInterval(2000L, readFromArduino);
  timer.setInterval(5000L, updateBlynkDisplays);
  
  // Kirim sinyal ready ke Arduino
  ArduinoSerial.println("ESP32_READY");
}

void loop() {
  Blynk.run();
  timer.run();
}

void readFromArduino() {
  if (ArduinoSerial.available()) {
    String data = ArduinoSerial.readStringUntil('\n');
    data.trim();
    
    Serial.println("Terima dari Arduino: " + data);
    
    if (data.startsWith("DATA|")) {
      parseArduinoData(data);
    }
  }
}

void parseArduinoData(String data) {
  // Format: DATA|temp|humidity|fanState|hour|minute
  int idx1 = data.indexOf('|', 5);
  int idx2 = data.indexOf('|', idx1 + 1);
  int idx3 = data.indexOf('|', idx2 + 1);
  int idx4 = data.indexOf('|', idx3 + 1);
  
  if (idx1 > 0 && idx2 > 0 && idx3 > 0 && idx4 > 0) {
    sensorData.temperature = data.substring(5, idx1).toFloat();
    sensorData.humidity = data.substring(idx1 + 1, idx2).toFloat();
    sensorData.fanStatus = (data.substring(idx2 + 1, idx3).toInt() == 1);
    sensorData.currentHour = data.substring(idx3 + 1, idx4).toInt();
    sensorData.currentMinute = data.substring(idx4 + 1).toInt();
  }
}

void updateBlynkDisplays() {
  // Update sensor readings
  if (sensorData.temperature != -999) {
    Blynk.virtualWrite(V_TEMP, sensorData.temperature);
  }
  if (sensorData.humidity != -999) {
    Blynk.virtualWrite(V_HUMIDITY, sensorData.humidity);
  }
  
  // Update fan status
  Blynk.virtualWrite(V_FAN_STATUS, sensorData.fanStatus ? "ON" : "OFF");
  
  // Update current time
  String timeStr = String(sensorData.currentHour) + ":" + 
                  (sensorData.currentMinute < 10 ? "0" : "") + 
                  String(sensorData.currentMinute);
  Blynk.virtualWrite(V_CURRENT_TIME, timeStr);
}

// Blynk Virtual Pin Handlers

// Mode Manual/Auto Switch
BLYNK_WRITE(V_MANUAL_MODE) {
  int value = param.asInt();
  String command = "MANUAL|" + String(value);
  ArduinoSerial.println(command);
  Serial.println("Kirim ke Arduino: " + command);
}

// Manual Fan Control Button
BLYNK_WRITE(V_MANUAL_FAN) {
  int value = param.asInt();
  String command = "FAN|" + String(value);
  ArduinoSerial.println(command);
  Serial.println("Kirim ke Arduino: " + command);
}

// Temperature Threshold Slider
BLYNK_WRITE(V_TEMP_SLIDER) {
  float value = param.asFloat();
  String command = "TEMP|" + String(value, 1);
  ArduinoSerial.println(command);
  Serial.println("Kirim ke Arduino: " + command);
}

// Humidity Threshold Slider
BLYNK_WRITE(V_HUMID_SLIDER) {
  float value = param.asFloat();
  String command = "HUMID|" + String(value, 1);
  ArduinoSerial.println(command);
  Serial.println("Kirim ke Arduino: " + command);
}

// Schedule Start Hour
BLYNK_WRITE(V_START_HOUR) {
  updateSchedule();
}

// Schedule End Hour  
BLYNK_WRITE(V_END_HOUR) {
  updateSchedule();
}

// Schedule Start Minute
BLYNK_WRITE(V_START_MIN) {
  updateSchedule();
}

// Schedule End Minute
BLYNK_WRITE(V_END_MIN) {
  updateSchedule();
}

void updateSchedule() {
  // Ambil semua nilai schedule dari Blynk
  int startHour = 7;   // Default values
  int endHour = 14;
  int startMin = 0;
  int endMin = 0;
  
  // Dalam implementasi nyata, Anda perlu menyimpan nilai ini
  // atau menggunakan Blynk.syncVirtual() untuk mendapatkan nilai terbaru
  
  String command = "SCHEDULE|" + String(startHour) + "|" + String(endHour) + 
                   "|" + String(startMin) + "|" + String(endMin);
  ArduinoSerial.println(command);
  Serial.println("Kirim ke Arduino: " + command);
}

// Blynk Connected Event
BLYNK_CONNECTED() {
  Serial.println("Terhubung ke Blynk!");
  // Sync semua virtual pins
  Blynk.syncAll();
}