#include <WiFi.h>
#include <WebServer.h>
#include <WebSocketsServer.h>
#include <HardwareSerial.h>
#include <ArduinoJson.h>
#include <WiFi.h>
#include <Preferences.h>

// Preferences untuk menyimpan WiFi credentials
Preferences preferences;
String savedSSID = "";
String savedPassword = "";
bool wifiConfigured = false;  

// UART communication dengan Arduino
HardwareSerial ArduinoSerial(2);

// WebSocket server
WebSocketsServer webSocket = WebSocketsServer(81);

// Data sensor
struct SensorData {
  float temperature = 0;
  float humidity = 0;
  bool fanStatus = false;
  int currentHour = 0;
  int currentMinute = 0;
  bool dataValid = false;
} sensorData;

// Variabel kontrol
bool manualMode = false;
float tempThreshold = 30.0;
float humidThreshold = 60.0; // Sesuaikan dengan Arduino default
int scheduleValues[4] = {7, 14, 0, 0}; // startHour, endHour, startMin, endMin

// WiFi connection timeout
const unsigned long WIFI_TIMEOUT = 30000; // 30 detik
unsigned long wifiStartTime = 0;

// WebSocket clients
bool wsConnected = false;

// WiFi configuration variables

WebServer server(80);

void setup() {
  Serial.begin(115200);
  ArduinoSerial.begin(9600, SERIAL_8N1, 16, 17); // RX=16, TX=17
  
  Serial.println("ESP32 Fan Automation Starting...");
  
  // Initialize preferences
  preferences.begin("wifi-config", false);
  
  // Load saved WiFi credentials
  loadWiFiCredentials();
  
  // Connect WiFi
  connectWiFi();
  
  // Setup server endpoints
  setupServer();
  
  // Setup WebSocket
  webSocket.begin();
  webSocket.onEvent(webSocketEvent);
  
  server.begin();
  Serial.println("HTTP server dimulai di port 80");
  Serial.println("WebSocket server dimulai di port 81");
  
  // Kirim sinyal ready ke Arduino
  ArduinoSerial.println("ESP32_READY");
  
  // Print setup instructions
  printSetupInstructions();
}

void loadWiFiCredentials() {
  savedSSID = preferences.getString("ssid", "");
  savedPassword = preferences.getString("password", "");
  
  if (savedSSID.length() > 0) {
    Serial.println("WiFi credentials loaded from memory");
    Serial.print("SSID: ");
    Serial.println(savedSSID);
  } else {
    Serial.println("No WiFi credentials found in memory");
  }
}

void saveWiFiCredentials(String ssid, String password) {
  preferences.putString("ssid", ssid);
  preferences.putString("password", password);
  savedSSID = ssid;
  savedPassword = password;
  Serial.println("WiFi credentials saved to memory");
}

void connectWiFi() {
  Serial.println("Memulai koneksi WiFi...");
  
  // Coba connect ke WiFi yang sudah disimpan
  if (savedSSID.length() > 0 && savedPassword.length() > 0) {
    Serial.println("Mencoba connect ke WiFi yang tersimpan...");
    Serial.print("SSID: ");
    Serial.println(savedSSID);
    
    WiFi.begin(savedSSID.c_str(), savedPassword.c_str());
    
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
      delay(500);
      Serial.print(".");
      attempts++;
    }
    
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\nWiFi terhubung!");
      Serial.print("IP Address: ");
      Serial.println(WiFi.localIP());
      Serial.print("SSID: ");
      Serial.println(WiFi.SSID());
      Serial.print("Signal Strength (RSSI): ");
      Serial.print(WiFi.RSSI());
      Serial.println(" dBm");
      wifiConfigured = true;
      
      // Send IP address to Arduino for LCD display
      delay(1000); // Wait for Arduino to be ready
      String ipCommand = "SET_IP|" + WiFi.localIP().toString();
      ArduinoSerial.println(ipCommand);
      Serial.println("Sent IP to Arduino: " + ipCommand);
      
      // Send multiple times to ensure Arduino receives it
      for (int i = 0; i < 3; i++) {
        delay(500);
        ArduinoSerial.println(ipCommand);
        Serial.println("Resent IP to Arduino (attempt " + String(i+2) + "): " + ipCommand);
      }
      
      return;
    }
  }
  
  // Jika tidak ada WiFi tersimpan atau gagal connect, masuk mode AP
  Serial.println("\nTidak ada WiFi tersimpan atau gagal connect. Masuk mode AP...");
  startAPMode();
}

void startAPMode() {
  Serial.println("Memulai mode Access Point...");
  
  // Setup Access Point
  WiFi.mode(WIFI_AP);
  WiFi.softAP("FanAutomation_AP", "12345678");
  
  Serial.print("AP IP Address: ");
  Serial.println(WiFi.softAPIP());
  Serial.println("SSID: FanAutomation_AP");
  Serial.println("Password: 12345678");
  Serial.println("Siap menerima konfigurasi WiFi dari Flutter");
  
  wifiConfigured = false;
}

void printSetupInstructions() {
  Serial.println("\n=== WIFI SETUP INSTRUCTIONS ===");
  Serial.println("1. Via Serial Monitor:");
  Serial.println("   - Kirim: SET_WIFI|SSID|PASSWORD");
  Serial.println("   - Contoh: SET_WIFI|MyWiFi|MyPassword123");
  Serial.println("");
  Serial.println("2. Via Flutter App:");
  Serial.println("   - Gunakan SmartConfig feature");
  Serial.println("   - Atau set IP manual jika sudah terhubung");
  Serial.println("");
  Serial.println("3. Reset WiFi:");
  Serial.println("   - Kirim: RESET_WIFI");
  Serial.println("================================\n");
}

void setupServer() {
  // CORS headers untuk semua endpoint
  server.enableCORS(true);
  
  // Endpoint REST
  server.on("/", HTTP_GET, handleRoot);
  server.on("/get_data", HTTP_GET, handleGetData);
  server.on("/set_fan", HTTP_POST, handleSetFan);
  server.on("/set_mode", HTTP_POST, handleSetMode);
  server.on("/set_schedule", HTTP_POST, handleSetSchedule);
  server.on("/set_threshold", HTTP_POST, handleSetThreshold);
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/reset_wifi", HTTP_POST, handleResetWiFi);
  server.on("/wifi_info", HTTP_GET, handleWiFiInfo);
  server.on("/setup_wifi", HTTP_POST, handleSetupWiFi);
  server.on("/ping", HTTP_GET, handlePing); // New endpoint for auto-detection
  
  // Handle 404
  server.onNotFound(handleNotFound);
}

void loop() {
  server.handleClient();
  webSocket.loop();
  handleArduinoResponse();
  requestDataFromArduino();
  
  // Check WiFi connection setiap 30 detik
  static unsigned long lastWiFiCheck = 0;
  if (millis() - lastWiFiCheck > 30000) {
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi disconnected! Reconnecting...");
      connectWiFi();
    }
    lastWiFiCheck = millis();
  }
  
  delay(100);
}

// WebSocket event handler
void webSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
  switch(type) {
    case WStype_DISCONNECTED:
      Serial.printf("[%u] Disconnected!\n", num);
      wsConnected = false;
      break;
    case WStype_CONNECTED:
      {
        IPAddress ip = webSocket.remoteIP(num);
        Serial.printf("[%u] Connected from %d.%d.%d.%d\n", num, ip[0], ip[1], ip[2], ip[3]);
        wsConnected = true;
        
        // Send initial data
        sendWebSocketData();
      }
      break;
    case WStype_TEXT:
      {
        String message = String((char*)payload);
        Serial.printf("WebSocket message: %s\n", message);
        
        // Handle commands from Flutter
        handleWebSocketCommand(message);
      }
      break;
  }
}

void handleWebSocketCommand(String message) {
  // Parse JSON command
  DynamicJsonDocument doc(256);
  DeserializationError error = deserializeJson(doc, message);
  
  if (error) {
    Serial.println("JSON parsing failed: " + String(error.c_str()));
    return;
  }
  
  if (!doc.containsKey("command")) {
    Serial.println("No command field in JSON");
    return;
  }
  
  String command = doc["command"];
  
  if (command == "set_fan") {
    if (!doc.containsKey("value")) {
      Serial.println("No value field for set_fan");
      return;
    }
    bool fan = doc["value"];
    String cmd = "SET_FAN|" + String(fan ? 1 : 0);
    ArduinoSerial.println(cmd);
    Serial.println("Set Fan: " + String(fan ? "ON" : "OFF"));
  }
  else if (command == "set_mode") {
    if (!doc.containsKey("value")) {
      Serial.println("No value field for set_mode");
      return;
    }
    bool mode = doc["value"];
    manualMode = mode;
    String cmd = "SET_MANUAL|" + String(mode ? 1 : 0);
    ArduinoSerial.println(cmd);
    Serial.println("Set Mode: " + String(mode ? "Manual" : "Auto"));
  }
  else if (command == "set_threshold") {
    if (!doc.containsKey("temp") || !doc.containsKey("humid")) {
      Serial.println("Missing temp or humid field for set_threshold");
      return;
    }
    float temp = doc["temp"];
    float humid = doc["humid"];
    
    // Validate ranges
    if (temp < 0 || temp > 100 || humid < 0 || humid > 100) {
      Serial.println("Invalid threshold values (0-100)");
      return;
    }
    
    tempThreshold = temp;
    humidThreshold = humid;
    
    String cmd = "SET_TEMP|" + String(tempThreshold, 1);
    ArduinoSerial.println(cmd);
    cmd = "SET_HUMID|" + String(humidThreshold, 1);
    ArduinoSerial.println(cmd);
    
    Serial.printf("Set Thresholds: Temp=%.1f°C, Humid=%.1f%%\n", tempThreshold, humidThreshold);
  }
  else if (command == "set_schedule") {
    if (!doc.containsKey("schedule")) {
      Serial.println("No schedule field for set_schedule");
      return;
    }
    JsonArray schedule = doc["schedule"];
    if (schedule.size() != 4) {
      Serial.println("Schedule array must have 4 elements");
      return;
    }
    
    // Validate schedule values
    for (int i = 0; i < 4; i++) {
      int val = schedule[i];
      if (i == 0 || i == 1) { // hours
        if (val < 0 || val > 23) {
          Serial.println("Invalid hour value (0-23)");
          return;
        }
      } else { // minutes
        if (val < 0 || val > 59) {
          Serial.println("Invalid minute value (0-59)");
          return;
        }
      }
      scheduleValues[i] = val;
    }
    
    String cmd = "SET_SCHEDULE|" + String(scheduleValues[0]) + "|" + String(scheduleValues[1]) + "|" + String(scheduleValues[2]) + "|" + String(scheduleValues[3]);
    ArduinoSerial.println(cmd);
    
    Serial.printf("Set Schedule: %02d:%02d - %02d:%02d\n", scheduleValues[0], scheduleValues[2], scheduleValues[1], scheduleValues[3]);
  }
  else {
    Serial.println("Unknown command: " + command);
    return;
  }
  
  // Send updated data back
  sendWebSocketData();
}

void sendWebSocketData() {
  if (!wsConnected) return;
  
  // Create JSON data
  DynamicJsonDocument doc(512);
  
  doc["type"] = "data";
  doc["temperature"] = round(sensorData.temperature * 10) / 10.0;
  doc["humidity"] = round(sensorData.humidity * 10) / 10.0;
  doc["fan"] = sensorData.fanStatus;
  doc["manualMode"] = manualMode;
  doc["tempThreshold"] = round(tempThreshold * 10) / 10.0;
  doc["humidThreshold"] = round(humidThreshold * 10) / 10.0;
  
  JsonArray schedule = doc.createNestedArray("schedule");
  for (int i = 0; i < 4; i++) {
    schedule.add(scheduleValues[i]);
  }
  
  doc["hour"] = sensorData.currentHour;
  doc["minute"] = sensorData.currentMinute;
  doc["dataValid"] = sensorData.dataValid;
  doc["wifiRSSI"] = WiFi.RSSI();
  doc["uptime"] = millis() / 1000;
  doc["ip"] = WiFi.localIP().toString();
  
  String json;
  serializeJson(doc, json);
  
  // Send to all connected clients
  webSocket.broadcastTXT(json);
  
  Serial.println("WebSocket data sent: " + json);
}

// Request data dari Arduino
void requestDataFromArduino() {
  static unsigned long lastRequest = 0;
  if (millis() - lastRequest > 3000) {
    ArduinoSerial.println("GET_DATA");
    lastRequest = millis();
  }
}

// Handle response dari Arduino
void handleArduinoResponse() {
  if (ArduinoSerial.available()) {
    String response = ArduinoSerial.readStringUntil('\n');
    response.trim();
    
    if (response.startsWith("DATA|")) {
      parseArduinoData(response);
      // Send data via WebSocket immediately
      sendWebSocketData();
    } else if (response.startsWith("ERROR|")) {
      Serial.println("Arduino Error: " + response.substring(6));
    }
  }
}

void parseArduinoData(String data) {
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
    
    Serial.printf("Data: Temp=%.1f°C, Humid=%.1f%%, Fan=%s, Time=%02d:%02d\n",
                  sensorData.temperature, sensorData.humidity,
                  sensorData.fanStatus ? "ON" : "OFF",
                  sensorData.currentHour, sensorData.currentMinute);
  }
}

// REST Handlers (untuk backward compatibility)
void handleRoot() {
  String html = "<html><body>";
  html += "<h1>ESP32 Fan Automation</h1>";
  html += "<p>Status: <strong>" + String(WiFi.status() == WL_CONNECTED ? "Connected" : "Disconnected") + "</strong></p>";
  html += "<p>IP: <strong>" + WiFi.localIP().toString() + "</strong></p>";
  html += "<p>RSSI: <strong>" + String(WiFi.RSSI()) + " dBm</strong></p>";
  html += "<p>Uptime: <strong>" + String(millis() / 1000) + "s</strong></p>";
  html += "<p>WebSocket: <strong>" + String(wsConnected ? "Connected" : "Disconnected") + "</strong></p>";
  html += "</body></html>";
  
  server.send(200, "text/html", html);
}

void handleGetData() {
  // Buat JSON response yang lebih efisien
  String json = "{";
  json += "\"temperature\":" + String(sensorData.temperature, 1) + ",";
  json += "\"humidity\":" + String(sensorData.humidity, 1) + ",";
  json += "\"fan\":" + String(sensorData.fanStatus ? "true" : "false") + ",";
  json += "\"manualMode\":" + String(manualMode ? "true" : "false") + ",";
  json += "\"tempThreshold\":" + String(tempThreshold, 1) + ",";
  json += "\"humidThreshold\":" + String(humidThreshold, 1) + ",";
  json += "\"schedule\":[" + String(scheduleValues[0]) + "," + String(scheduleValues[1]) + "," + String(scheduleValues[2]) + "," + String(scheduleValues[3]) + "],";
  json += "\"hour\":" + String(sensorData.currentHour) + ",";
  json += "\"minute\":" + String(sensorData.currentMinute) + ",";
  json += "\"dataValid\":" + String(sensorData.dataValid ? "true" : "false") + ",";
  json += "\"wifiRSSI\":" + String(WiFi.RSSI()) + ",";
  json += "\"uptime\":" + String(millis() / 1000);
  json += "}";
  
  server.send(200, "application/json", json);
}

void handleSetFan() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\":\"No data provided\"}");
    return;
  }
  
  String body = server.arg("plain");
  body.trim();
  
  bool fan = (body == "true");
  String command = "SET_FAN|" + String(fan ? 1 : 0);
  ArduinoSerial.println(command);
  
  Serial.println("Set Fan: " + String(fan ? "ON" : "OFF"));
  
  server.send(200, "application/json", "{\"status\":\"OK\",\"fan\":" + String(fan ? "true" : "false") + "}");
}

void handleSetMode() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\":\"No data provided\"}");
    return;
  }
  
  String body = server.arg("plain");
  body.trim();
  
  bool mode = (body == "true");
  manualMode = mode;
  String command = "SET_MANUAL|" + String(mode ? 1 : 0);
    ArduinoSerial.println(command);
  
  Serial.println("Set Mode: " + String(mode ? "Manual" : "Auto"));
  
  server.send(200, "application/json", "{\"status\":\"OK\",\"manualMode\":" + String(mode ? "true" : "false") + "}");
}

void handleSetSchedule() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\":\"No data provided\"}");
    return;
  }
  
  String body = server.arg("plain");
  body.trim();
  
  // Parse comma-separated values
  int vals[4] = {0,0,0,0};
  int idx = 0;
  int last = 0;
  
  for (int i = 0; i < body.length() && idx < 4; i++) {
    if (body[i] == ',') {
      vals[idx] = body.substring(last, i).toInt();
      // Validate range
      if (idx == 0 || idx == 1) { // hours
        if (vals[idx] < 0 || vals[idx] > 23) {
          server.send(400, "application/json", "{\"error\":\"Invalid hour value\"}");
          return;
        }
      } else { // minutes
        if (vals[idx] < 0 || vals[idx] > 59) {
          server.send(400, "application/json", "{\"error\":\"Invalid minute value\"}");
          return;
        }
      }
      idx++;
      last = i + 1;
    }
  }
  
  if (idx < 4) {
    vals[idx] = body.substring(last).toInt();
  }
  
  // Update schedule
  for (int i = 0; i < 4; i++) {
    scheduleValues[i] = vals[i];
  }
  
  String command = "SET_SCHEDULE|" + String(vals[0]) + "|" + String(vals[1]) + "|" + String(vals[2]) + "|" + String(vals[3]);
  ArduinoSerial.println(command);
  
  Serial.printf("Set Schedule: %02d:%02d - %02d:%02d\n", vals[0], vals[2], vals[1], vals[3]);
  
  server.send(200, "application/json", "{\"status\":\"OK\"}");
}

void handleSetThreshold() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\":\"No data provided\"}");
    return;
  }
  
  String body = server.arg("plain");
  body.trim();
  
  int idx = body.indexOf(",");
  if (idx <= 0) {
    server.send(400, "application/json", "{\"error\":\"Invalid format. Use: temp,humid\"}");
    return;
  }
  
  float temp = body.substring(0, idx).toFloat();
  float humid = body.substring(idx + 1).toFloat();
  
  // Validate ranges
  if (temp < 0 || temp > 100 || humid < 0 || humid > 100) {
    server.send(400, "application/json", "{\"error\":\"Invalid threshold values (0-100)\"}");
    return;
  }
  
  tempThreshold = temp;
  humidThreshold = humid;
  
  String command = "SET_TEMP|" + String(tempThreshold, 1);
  ArduinoSerial.println(command);
  command = "SET_HUMID|" + String(humidThreshold, 1);
  ArduinoSerial.println(command);
  
  Serial.printf("Set Thresholds: Temp=%.1f°C, Humid=%.1f%%\n", tempThreshold, humidThreshold);
  
  server.send(200, "application/json", "{\"status\":\"OK\"}");
}

void handleStatus() {
  String json = "{";
  json += "\"wifiConnected\":" + String(WiFi.status() == WL_CONNECTED ? "true" : "false") + ",";
  json += "\"ip\":\"" + WiFi.localIP().toString() + "\",";
  json += "\"rssi\":" + String(WiFi.RSSI()) + ",";
  json += "\"uptime\":" + String(millis() / 1000) + ",";
  json += "\"dataValid\":" + String(sensorData.dataValid ? "true" : "false") + ",";
  json += "\"wsConnected\":" + String(wsConnected ? "true" : "false");
  json += "}";
  
  server.send(200, "application/json", json);
}

void handleResetWiFi() {
  Serial.println("Reset WiFi configuration");
  server.send(200, "application/json", "{\"status\":\"OK\",\"message\":\"WiFi reset. ESP32 akan restart dalam 3 detik.\"}");
  
  delay(1000);
  preferences.remove("ssid");
  preferences.remove("password");
  savedSSID = "";
  savedPassword = "";
  wifiConfigured = false;
  
  if (WiFi.status() == WL_CONNECTED) {
    WiFi.disconnect();
    delay(1000);
  }
  
  Serial.println("ESP32 akan restart dalam 3 detik...");
  delay(3000);
  ESP.restart();
}

void handleSetupWiFi() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\":\"No data provided\"}");
    return;
  }
  
  String body = server.arg("plain");
  body.trim();
  
  int idx = body.indexOf(",");
  if (idx <= 0) {
    server.send(400, "application/json", "{\"error\":\"Invalid format. Use: ssid,password\"}");
    return;
  }
  
  String ssid = body.substring(0, idx);
  String password = body.substring(idx + 1);
  
  if (ssid.length() == 0 || password.length() == 0) {
    server.send(400, "application/json", "{\"error\":\"SSID and password cannot be empty\"}");
    return;
  }
  
  Serial.println("Setting up WiFi credentials...");
  Serial.print("SSID: ");
  Serial.println(ssid);
  
  // Save credentials
  saveWiFiCredentials(ssid, password);
  
  // Disconnect current WiFi if connected
  if (WiFi.status() == WL_CONNECTED) {
    WiFi.disconnect();
    delay(1000);
  }
  
  // Switch dari AP mode ke Station mode
  if (!wifiConfigured) {
    WiFi.mode(WIFI_STA);
    delay(1000);
  }
  
  // Connect to new WiFi
  WiFi.begin(ssid.c_str(), password.c_str());
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(300);
    Serial.print(".");
    attempts++;
  }
  
      if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\nWiFi connected successfully!");
      Serial.print("IP Address: ");
      Serial.println(WiFi.localIP());
      Serial.print("SSID: ");
      Serial.println(WiFi.SSID());
      Serial.print("RSSI: ");
      Serial.println(WiFi.RSSI());
      
      wifiConfigured = true;
      
      // Send IP address to Arduino for LCD display
      delay(1000); // Wait for Arduino to be ready
      String ipCommand = "SET_IP|" + WiFi.localIP().toString();
      ArduinoSerial.println(ipCommand);
      Serial.println("Sent IP to Arduino: " + ipCommand);
      
      // Send multiple times to ensure Arduino receives it
      for (int i = 0; i < 3; i++) {
        delay(500);
        ArduinoSerial.println(ipCommand);
        Serial.println("Resent IP to Arduino (attempt " + String(i+2) + "): " + ipCommand);
      }
    
    String response = "{";
    response += "\"status\":\"OK\",";
    response += "\"message\":\"WiFi connected successfully\",";
    response += "\"ip\":\"" + WiFi.localIP().toString() + "\",";
    response += "\"ssid\":\"" + WiFi.SSID() + "\",";
    response += "\"rssi\":" + String(WiFi.RSSI());
    response += "}";
    
    // Kirim response sebelum switch mode
    server.send(200, "application/json", response);
    
    // Delay sebentar untuk memastikan response terkirim
    delay(1000);
    
    // Switch ke Station mode dan matikan AP
    WiFi.mode(WIFI_STA);
    
    // Restart server di IP baru
    server.stop();
    delay(1000);
    server.begin();
    
    Serial.println("Switched to Station mode. Server restarted on new IP.");
    
  } else {
    Serial.println("\nWiFi connection failed!");
    // Kembali ke AP mode jika gagal
    startAPMode();
    
    server.send(500, "application/json", "{\"error\":\"WiFi connection failed. Please check credentials.\"}");
  }
}

void handleWiFiInfo() {
  String json = "{";
  json += "\"ssid\":\"" + WiFi.SSID() + "\",";
  json += "\"ip\":\"" + WiFi.localIP().toString() + "\",";
  json += "\"rssi\":" + String(WiFi.RSSI()) + ",";
  json += "\"status\":\"" + String(WiFi.status() == WL_CONNECTED ? "Connected" : "Disconnected") + "\"";
  json += "}";
  
  server.send(200, "application/json", json);
}

void handlePing() {
  // Lightweight endpoint for auto-detection
  String json = "{";
  json += "\"status\":\"OK\",";
  json += "\"device\":\"ESP32_FanAutomation\",";
  json += "\"ip\":\"" + WiFi.localIP().toString() + "\",";
  json += "\"uptime\":" + String(millis() / 1000);
  json += "}";
  
  server.send(200, "application/json", json);
}

void handleNotFound() {
  String message = "File Not Found\n\n";
  message += "URI: ";
  message += server.uri();
  message += "\nMethod: ";
  message += (server.method() == HTTP_GET) ? "GET" : "POST";
  message += "\nArguments: ";
  message += server.args();
  message += "\n";
  
  for (uint8_t i = 0; i < server.args(); i++) {
    message += " " + server.argName(i) + ": " + server.arg(i) + "\n";
  }
  
  server.send(404, "text/plain", message);
}