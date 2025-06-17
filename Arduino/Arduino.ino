#include <Wire.h>
#include <RTClib.h>
#include <LiquidCrystal_I2C.h>
#include "DHT.h"
#include <SoftwareSerial.h>

#define DHTPIN 2
#define DHTTYPE DHT11
#define RELAYPIN 13

// UART communication dengan ESP32
SoftwareSerial espSerial(3, 4);  // RX, TX ke ESP32

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
// int setHour = 8;
// int setMinute = 45;
// int setSecond = 0;
// Variabel sensor
float currentTemp = 0;
float currentHumidity = 0;
bool fanState = false;
unsigned long lastSensorRead = 0;
unsigned long lastDisplayUpdate = 0;

void setup() {
  Serial.begin(9600);
  espSerial.begin(9600);
  dht.begin();
  
  // Inisialisasi RTC
  if (!rtc.begin()) {
    Serial.println("RTC tidak ditemukan!");
    while (1);
  }
//   DateTime now = rtc.now();
// rtc.adjust(DateTime(now.year(), now.month(), now.day(), setHour, setMinute, setSecond));
  // rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));


  // Inisialisasi LCD

  lcd.begin();
  lcd.backlight();
  showStartupMessage();

  // Setup relay
  pinMode(RELAYPIN, OUTPUT);
  digitalWrite(RELAYPIN, HIGH);

  Serial.println("Arduino Master siap!");
  espSerial.println("ARDUINO_READY");
}

void loop() {
  // Baca sensor setiap 2 detik
  if (millis() - lastSensorRead > 2000) {
    readSensors();
    lastSensorRead = millis();
  }

  // Handle request dari ESP32
  handleESP32Request();

  // Kontrol kipas
  controlFan();

  // Update display setiap 1 detik
  if (millis() - lastDisplayUpdate > 1000) {
    updateDisplay();
    lastDisplayUpdate = millis();
  }

  delay(50);
}

void readSensors() {
  currentTemp = dht.readTemperature();
  currentHumidity = dht.readHumidity();

  if (isnan(currentTemp) || isnan(currentHumidity)) {
    Serial.println("Error membaca sensor DHT11!");
    currentTemp = -999;
    currentHumidity = -999;
  } else {
    Serial.print("Sensor - T:");
    Serial.print(currentTemp, 1);
    Serial.print("°C H:");
    Serial.print(currentHumidity, 1);
    Serial.println("%");
  }
}

void handleESP32Request() {
  if (espSerial.available()) {
    String request = espSerial.readStringUntil('\n');
    request.trim();

    Serial.println("Request dari ESP32: " + request);
    processRequest(request);
  }
}

void processRequest(String request) {
  if (request == "GET_DATA") {
    sendDataToESP32();
  } else if (request == "GET_SETTINGS") {
    sendSettingsToESP32();
  } else if (request.startsWith("SET_")) {
    handleSetCommand(request);
  } else {
    // Unknown command
    sendErrorResponse("UNKNOWN_COMMAND");
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
  Serial.println("Send data: " + data);
}

void sendSettingsToESP32() {
  // Format: SETTINGS|manual|tempThresh|humidThresh|startH|endH|startM|endM
  String settings_data = "SETTINGS|";
  settings_data += String(settings.manualMode ? 1 : 0) + "|";
  settings_data += String(settings.tempThreshold, 1) + "|";
  settings_data += String(settings.humidityThreshold, 1) + "|";
  settings_data += String(settings.startHour) + "|";
  settings_data += String(settings.endHour) + "|";
  settings_data += String(settings.startMinute) + "|";
  settings_data += String(settings.endMinute);

  espSerial.println(settings_data);
  Serial.println("Send settings: " + settings_data);
}

void handleSetCommand(String command) {
  int separatorIndex = command.indexOf('|');
  if (separatorIndex == -1) {
    sendErrorResponse("INVALID_FORMAT");
    return;
  }

  String cmd = command.substring(0, separatorIndex);
  String value = command.substring(separatorIndex + 1);
  bool success = false;

  if (cmd == "SET_MANUAL") {
    settings.manualMode = (value.toInt() == 1);
    success = true;
    Serial.println("Mode set to: " + String(settings.manualMode ? "MANUAL" : "AUTO"));
    
    // Update LCD immediately
    lcd.setCursor(0, 0);
    lcd.print(settings.manualMode ? "Mode: MANUAL   " : "Mode: AUTO     ");
    delay(1000);
    
  } else if (cmd == "SET_FAN") {
    settings.manualFanState = (value.toInt() == 1);
    success = true;
    Serial.println("Manual fan set to: " + String(settings.manualFanState ? "ON" : "OFF"));
    
  } else if (cmd == "SET_TEMP") {
    float temp = value.toFloat();
    if (temp >= 0 && temp <= 50) {
      settings.tempThreshold = temp;
      success = true;
      Serial.println("Temp threshold set to: " + String(settings.tempThreshold, 1));
    }
    
  } else if (cmd == "SET_HUMID") {
    float humid = value.toFloat();
    if (humid >= 0 && humid <= 100) {
      settings.humidityThreshold = humid;
      success = true;
      Serial.println("Humidity threshold set to: " + String(settings.humidityThreshold, 1));
    }
    
  } else if (cmd == "SET_SCHEDULE") {
    success = parseSchedule(value);
  }

  if (success) {
    sendOKResponse(cmd);
  } else {
    sendErrorResponse("INVALID_VALUE");
  }
}

bool parseSchedule(String scheduleData) {
  // Format: startHour|endHour|startMin|endMin
  int idx1 = scheduleData.indexOf('|');
  int idx2 = scheduleData.indexOf('|', idx1 + 1);
  int idx3 = scheduleData.indexOf('|', idx2 + 1);

  if (idx1 > 0 && idx2 > 0 && idx3 > 0) {
    int startH = scheduleData.substring(0, idx1).toInt();
    int endH = scheduleData.substring(idx1 + 1, idx2).toInt();
    int startM = scheduleData.substring(idx2 + 1, idx3).toInt();
    int endM = scheduleData.substring(idx3 + 1).toInt();

    // Validasi
    if (startH >= 0 && startH <= 23 && endH >= 0 && endH <= 23 &&
        startM >= 0 && startM <= 59 && endM >= 0 && endM <= 59) {
      settings.startHour = startH;
      settings.endHour = endH;
      settings.startMinute = startM;
      settings.endMinute = endM;
      
      Serial.print("Schedule set: ");
      Serial.print(startH);
      Serial.print(":");
      if (startM < 10) Serial.print("0");
      Serial.print(startM);
      Serial.print(" - ");
      Serial.print(endH);
      Serial.print(":");
      if (endM < 10) Serial.print("0");
      Serial.println(endM);
      return true;
    }
  }
  return false;
}

void sendOKResponse(String command) {
  String response = "OK|" + command;
  espSerial.println(response);
  Serial.println("Send OK: " + response);
}

void sendErrorResponse(String error) {
  String response = "ERROR|" + error;
  espSerial.println(response);
  Serial.println("Send ERROR: " + response);
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
    bool tempOK = (currentTemp != -999 && currentTemp > settings.tempThreshold);
    bool humidOK = (currentHumidity != -999 && currentHumidity > settings.humidityThreshold);

    shouldTurnOn = timeOK && tempOK && humidOK;
    
    // Debug info (print every 30 seconds)
    static unsigned long lastDebug = 0;
    if (millis() - lastDebug > 30000) {
      lastDebug = millis();
      Serial.print("Auto check - Time:");
      Serial.print(timeOK ? "OK" : "NO");
      Serial.print(" Temp:");
      Serial.print(tempOK ? "OK" : "NO");
      Serial.print(" Humid:");
      Serial.print(humidOK ? "OK" : "NO");
      Serial.print(" -> Fan:");
      Serial.println(shouldTurnOn ? "ON" : "OFF");
    }
  }

  // Update fan state
  if (fanState != shouldTurnOn) {
    fanState = shouldTurnOn;
    digitalWrite(RELAYPIN, fanState ? LOW : HIGH);
    Serial.println("Fan state changed to: " + String(fanState ? "ON" : "OFF"));
  }
}

void updateDisplay() {
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