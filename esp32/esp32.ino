#define BLYNK_TEMPLATE_ID "TMPL6XU-aybNm"
#define BLYNK_TEMPLATE_NAME "Smart Fan Controller"
#define BLYNK_AUTH_TOKEN "rPScbpRyZGN8MwfTkygo4aqhED5lVbEE"

#include <WiFi.h>
#include <BlynkSimpleEsp32.h>
#include <HardwareSerial.h>

// WiFi credentials
char ssid[] = "MATURNUWUN.ID";      
char pass[] = "Samisami";  

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
  bool dataValid = false;
} sensorData;

// Variabel untuk request-response system
unsigned long lastDataRequest = 0;
unsigned long commandTimeout = 0;
bool waitingForResponse = false;
String pendingCommand = "";

BlynkTimer timer;

void setup() {
  Serial.begin(115200);
  ArduinoSerial.begin(9600, SERIAL_8N1, 16, 17); // RX=16, TX=17
  
  // Connect to Blynk
  Blynk.begin(BLYNK_AUTH_TOKEN, ssid, pass);
  
  Serial.println("ESP32 Gateway siap!");
  
  // Setup timer untuk request data dari Arduino
  timer.setInterval(3000L, requestDataFromArduino);
  timer.setInterval(5000L, updateBlynkDisplays);
  timer.setInterval(1000L, checkCommandTimeout);
  
  // Kirim sinyal ready ke Arduino
  ArduinoSerial.println("ESP32_READY");
}

void loop() {
  Blynk.run();
  timer.run();
  handleArduinoResponse();
}

// Request data dari Arduino
void requestDataFromArduino() {
  if (!waitingForResponse) {
    ArduinoSerial.println("GET_DATA");
    Serial.println("Request data dari Arduino");
    lastDataRequest = millis();
  }
}

// Handle response dari Arduino
void handleArduinoResponse() {
  if (ArduinoSerial.available()) {
    String response = ArduinoSerial.readStringUntil('\n');
    response.trim();
    
    Serial.println("Terima dari Arduino: " + response);
    
    if (response.startsWith("DATA|")) {
      parseArduinoData(response);
      waitingForResponse = false;
    } else if (response.startsWith("OK|")) {
      // Command acknowledgment
      Serial.println("Command berhasil: " + response);
      waitingForResponse = false;
    } else if (response.startsWith("ERROR|")) {
      // Command error
      Serial.println("Command error: " + response);
      waitingForResponse = false;
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
    sensorData.dataValid = true;
    
    Serial.print("Parsed - T:");
    Serial.print(sensorData.temperature, 1);
    Serial.print(" H:");
    Serial.print(sensorData.humidity, 1);
    Serial.print(" Fan:");
    Serial.print(sensorData.fanStatus ? "ON" : "OFF");
    Serial.print(" Time:");
    if (sensorData.currentHour < 10) Serial.print("0");
    Serial.print(sensorData.currentHour);
    Serial.print(":");
    if (sensorData.currentMinute < 10) Serial.print("0");
    Serial.println(sensorData.currentMinute);
  }
}

void updateBlynkDisplays() {
  if (!sensorData.dataValid) return;
  
  // Update sensor readings
  Blynk.virtualWrite(V_TEMP, sensorData.temperature);
  Blynk.virtualWrite(V_HUMIDITY, sensorData.humidity);
  
  // Update fan status
  Blynk.virtualWrite(V_FAN_STATUS, sensorData.fanStatus ? "ON" : "OFF");
  
  // Update current time
  String timeStr = String(sensorData.currentHour) + ":" + 
                  (sensorData.currentMinute < 10 ? "0" : "") + 
                  String(sensorData.currentMinute);
  Blynk.virtualWrite(V_CURRENT_TIME, timeStr);
}

// Send command to Arduino dengan timeout
void sendCommandToArduino(String command) {
  if (!waitingForResponse) {
    ArduinoSerial.println(command);
    Serial.println("Kirim ke Arduino: " + command);
    waitingForResponse = true;
    commandTimeout = millis() + 5000; // 5 second timeout
    pendingCommand = command;
  } else {
    Serial.println("Masih menunggu response, command ditunda: " + command);
  }
}

// Check command timeout
void checkCommandTimeout() {
  if (waitingForResponse && millis() > commandTimeout) {
    Serial.println("Command timeout: " + pendingCommand);
    waitingForResponse = false;
    pendingCommand = "";
  }
}

// Blynk Virtual Pin Handlers

// Mode Manual/Auto Switch
BLYNK_WRITE(V_MANUAL_MODE) {
  int value = param.asInt();
  String command = "SET_MANUAL|" + String(value);
  sendCommandToArduino(command);
}

// Manual Fan Control Button
BLYNK_WRITE(V_MANUAL_FAN) {
  int value = param.asInt();
  String command = "SET_FAN|" + String(value);
  sendCommandToArduino(command);
}

// Temperature Threshold Slider
BLYNK_WRITE(V_TEMP_SLIDER) {
  float value = param.asFloat();
  String command = "SET_TEMP|" + String(value, 1);
  sendCommandToArduino(command);
}

// Humidity Threshold Slider
BLYNK_WRITE(V_HUMID_SLIDER) {
  float value = param.asFloat();
  String command = "SET_HUMID|" + String(value, 1);
  sendCommandToArduino(command);
}

// Schedule handlers - store values untuk dikirim bersamaan
int scheduleValues[4] = {7, 14, 0, 0}; // startHour, endHour, startMin, endMin

BLYNK_WRITE(V_START_HOUR) {
  scheduleValues[0] = param.asInt();
  updateSchedule();
}

BLYNK_WRITE(V_END_HOUR) {
  scheduleValues[1] = param.asInt();
  updateSchedule();
}

BLYNK_WRITE(V_START_MIN) {
  scheduleValues[2] = param.asInt();
  updateSchedule();
}

BLYNK_WRITE(V_END_MIN) {
  scheduleValues[3] = param.asInt();
  updateSchedule();
}

void updateSchedule() {
  String command = "SET_SCHEDULE|" + String(scheduleValues[0]) + "|" + 
                   String(scheduleValues[1]) + "|" + String(scheduleValues[2]) + 
                   "|" + String(scheduleValues[3]);
  sendCommandToArduino(command);
}

// Get current settings from Arduino
void requestCurrentSettings() {
  sendCommandToArduino("GET_SETTINGS");
}

// Blynk Connected Event
BLYNK_CONNECTED() {
  Serial.println("Terhubung ke Blynk!");
  // Sync semua virtual pins
  Blynk.syncAll();
  // Request current settings dari Arduino
  timer.setTimeout(2000L, requestCurrentSettings);
}