#include <Wire.h>
#include <RTClib.h>
#include <LiquidCrystal_I2C.h>
#include "DHT.h"
#include <SoftwareSerial.h>

#define DHTPIN 2     
#define DHTTYPE DHT11 
#define RELAYPIN 8

// UART communication dengan ESP32
SoftwareSerial espSerial(3, 4); // RX, TX ke ESP32

DHT dht(DHTPIN, DHTTYPE);
LiquidCrystal_I2C lcd(0x27, 16, 2);
RTC_DS3231 rtc;

// Variabel kontrol dari Blynk
struct BlynkSettings {
  bool manualMode = false;
  bool manualFanState = false;
  float tempThreshold = 30.0;
  float humidityThreshold = 60.0;
  int startHour = 7;
  int endHour = 14;
  int startMinute = 0;
  int endMinute = 0;
} settings;

// Variabel sensor
float currentTemp = 0;
float currentHumidity = 0;
bool fanState = false;
unsigned long lastSensorRead = 0;
unsigned long lastDataSend = 0;

void setup() {
  Serial.begin(9600);
  espSerial.begin(9600);
  dht.begin();

  // Inisialisasi RTC
  if (!rtc.begin()) {
    Serial.println("RTC tidak ditemukan!");
    while (1);
  }
  
  // Inisialisasi LCD
  lcd.init();
  lcd.backlight();
  showStartupMessage();
  
  // Setup relay
  pinMode(RELAYPIN, OUTPUT);
  digitalWrite(RELAYPIN, LOW);
  
  Serial.println("Arduino Master siap!");
  espSerial.println("ARDUINO_READY");
}

void loop() {
  // Baca sensor setiap 2 detik
  if (millis() - lastSensorRead > 2000) {
    readSensors();
    lastSensorRead = millis();
  }
  
  // Kirim data ke ESP32 setiap 5 detik
  if (millis() - lastDataSend > 5000) {
    sendDataToESP32();
    lastDataSend = millis();
  }
  
  // Terima perintah dari ESP32
  receiveFromESP32();
  
  // Kontrol kipas
  controlFan();
  
  // Update display
  updateDisplay();
  
  delay(100);
}

void readSensors() {
  currentTemp = dht.readTemperature();
  currentHumidity = dht.readHumidity();
  
  if (isnan(currentTemp) || isnan(currentHumidity)) {
    Serial.println("Error membaca sensor DHT22!");
    currentTemp = -999;
    currentHumidity = -999;
  }
}

void sendDataToESP32() {
  DateTime now = rtc.now();
  
  // Format: DATA|temp|humidity|fanState|hour|minute
  String data = "DATA|";
  data += String(currentTemp, 1) + "|";
  data += String(currentHumidity, 1) + "|";
  data += String(fanState ? 1 : 0) + "|";
  data += String(now.hour()) + "|";
  data += String(now.minute());
  
  espSerial.println(data);
  Serial.println("Kirim ke ESP32: " + data);
}

void receiveFromESP32() {
  if (espSerial.available()) {
    String command = espSerial.readStringUntil('\n');
    command.trim();
    
    Serial.println("Terima dari ESP32: " + command);
    parseCommand(command);
  }
}

void parseCommand(String command) {
  // Format perintah dari ESP32:
  // MANUAL|1 atau MANUAL|0 (mode manual on/off)
  // FAN|1 atau FAN|0 (kipas manual on/off)
  // TEMP|30.5 (set threshold suhu)
  // HUMID|65.0 (set threshold kelembaban)
  // SCHEDULE|7|14|0|0 (start_hour|end_hour|start_min|end_min)
  
  int separatorIndex = command.indexOf('|');
  if (separatorIndex == -1) return;
  
  String cmd = command.substring(0, separatorIndex);
  String value = command.substring(separatorIndex + 1);
  
  if (cmd == "MANUAL") {
    settings.manualMode = (value.toInt() == 1);
    lcd.setCursor(0, 0);
    lcd.print(settings.manualMode ? "Mode: MANUAL   " : "Mode: AUTO     ");
    delay(1000);
  }
  else if (cmd == "FAN") {
    settings.manualFanState = (value.toInt() == 1);
  }
  else if (cmd == "TEMP") {
    settings.tempThreshold = value.toFloat();
  }
  else if (cmd == "HUMID") {
    settings.humidityThreshold = value.toFloat();
  }
  else if (cmd == "SCHEDULE") {
    // Parse SCHEDULE|7|14|0|0
    int idx1 = value.indexOf('|');
    int idx2 = value.indexOf('|', idx1 + 1);
    int idx3 = value.indexOf('|', idx2 + 1);
    
    if (idx1 > 0 && idx2 > 0 && idx3 > 0) {
      settings.startHour = value.substring(0, idx1).toInt();
      settings.endHour = value.substring(idx1 + 1, idx2).toInt();
      settings.startMinute = value.substring(idx2 + 1, idx3).toInt();
      settings.endMinute = value.substring(idx3 + 1).toInt();
    }
  }
}

void controlFan() {
  bool shouldTurnOn = false;
  
  if (settings.manualMode) {
    // Mode manual
    shouldTurnOn = settings.manualFanState;
  } else {
    // Mode otomatis
    DateTime now = rtc.now();
    int currentMinutes = now.hour() * 60 + now.minute();
    int startMinutes = settings.startHour * 60 + settings.startMinute;
    int endMinutes = settings.endHour * 60 + settings.endMinute;
    
    bool timeOK = (currentMinutes >= startMinutes && currentMinutes < endMinutes);
    bool tempOK = (currentTemp > settings.tempThreshold);
    bool humidOK = (currentHumidity > settings.humidityThreshold);
    
    shouldTurnOn = timeOK && tempOK && humidOK;
  }
  
  fanState = shouldTurnOn;
  digitalWrite(RELAYPIN, fanState ? HIGH : LOW);
}

void updateDisplay() {
  static unsigned long lastUpdate = 0;
  if (millis() - lastUpdate < 1000) return;
  lastUpdate = millis();
  
  DateTime now = rtc.now();
  
  // Baris 1: Suhu dan status
  lcd.setCursor(0, 0);
  if (currentTemp == -999) {
    lcd.print("T:ERR ");
  } else {
    lcd.print("T:");
    lcd.print(currentTemp, 1);
    lcd.print((char)223);
    lcd.print("C ");
  }
  
  lcd.setCursor(9, 0);
  lcd.print(fanState ? "ON " : "OFF");
  
  lcd.setCursor(13, 0);
  lcd.print(settings.manualMode ? "M" : "A");
  
  // Baris 2: Kelembaban dan waktu
  lcd.setCursor(0, 1);
  if (currentHumidity == -999) {
    lcd.print("H:ERR ");
  } else {
    lcd.print("H:");
    lcd.print(currentHumidity, 1);
    lcd.print("% ");
  }
  
  lcd.setCursor(10, 1);
  if (now.hour() < 10) lcd.print("0");
  lcd.print(now.hour());
  lcd.print(":");
  if (now.minute() < 10) lcd.print("0");
  lcd.print(now.minute());
}

void showStartupMessage() {
  lcd.setCursor(0, 0);
  lcd.print("Smart Fan Ctrl");
  lcd.setCursor(0, 1);
  lcd.print("Starting...");
  delay(2000);
  lcd.clear();
}