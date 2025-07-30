# Fan Automation Mobile App

A Flutter mobile application for controlling ESP32-based fan automation system with real-time sensor monitoring and smart scheduling.

## Features

### 🔥 Real-time Monitoring
- **Temperature & Humidity**: Live sensor data display
- **Fan Status**: Real-time fan ON/OFF status
- **Connection Status**: WebSocket/HTTP connection monitoring
- **Auto-Update**: Real-time data updates via WebSocket

### 🎛️ Smart Control
- **Manual Mode**: Direct fan control (ON/OFF)
- **Automatic Mode**: Smart control based on thresholds
- **Threshold Settings**: Customizable temperature and humidity limits
- **Schedule Control**: Time-based automation

### 📡 WiFi Management
- **Auto-Detection**: Automatically find ESP32 on WiFi network
- **Direct Setup**: Easy WiFi credentials configuration
- **Connection Status**: Monitor WiFi connection quality
- **IP Management**: Manual IP configuration fallback

### ⏰ Smart Scheduling
- **Time-based Control**: Set fan operation hours
- **Quick Presets**: Morning, afternoon, evening schedules
- **Custom Schedules**: Flexible time range configuration
- **Status Monitoring**: Real-time schedule status

## Setup Process

### 1. Initial WiFi Setup
1. ESP32 creates hotspot "FanAutomation_AP" (password: 12345678)
2. Connect phone to ESP32 hotspot
3. Use "Setup Langsung" to configure WiFi credentials
4. ESP32 automatically connects to home WiFi

### 2. Auto-Detection
1. Connect phone to home WiFi
2. Use "Auto Detect ESP32" to find device automatically
3. App scans common IP ranges (192.168.1.x, 192.168.0.x, etc.)
4. Automatic connection once ESP32 is found

### 3. Manual Fallback
- If auto-detection fails, use "Set IP Manual"
- Enter ESP32 IP address manually
- App validates IP format and connectivity

## Technical Features

### Connection Protocols
- **WebSocket**: Real-time bidirectional communication
- **HTTP Fallback**: Polling when WebSocket unavailable
- **Auto-Reconnect**: Automatic connection recovery

### Data Validation
- **Sensor Bounds**: Temperature (0-100°C), Humidity (0-100%)
- **Threshold Limits**: Configurable ranges with validation
- **Schedule Validation**: Time range validation
- **Error Handling**: Comprehensive error messages

### Security
- **Input Validation**: All user inputs validated
- **Error Recovery**: Graceful error handling
- **Connection Security**: Secure WiFi communication

## Menu Options

### App Bar Menu (⋮)
- **WiFi Info**: Detailed WiFi connection information
- **Check WiFi Status**: Verify ESP32 WiFi connection
- **Auto Detect ESP32**: Scan network for ESP32 device
- **Reset WiFi**: Reset ESP32 WiFi configuration
- **Set IP Manual**: Manual IP address configuration
- **Refresh**: Refresh data from ESP32

## Requirements

### Hardware
- ESP32 development board
- DHT22/DHT11 temperature & humidity sensor
- Relay module for fan control
- Power supply

### Software
- Flutter SDK
- Android Studio / VS Code
- ESP32 Arduino IDE

### Network
- WiFi router
- Same network for ESP32 and mobile device

## Installation

1. Clone the repository
2. Install Flutter dependencies: `flutter pub get`
3. Connect ESP32 and upload Arduino code
4. Build and install mobile app
5. Follow setup process above

## Troubleshooting

### Connection Issues
- Ensure ESP32 and phone are on same WiFi network
- Check ESP32 power and connections
- Verify WiFi credentials are correct
- Use "Auto Detect" or manual IP setup

### Sensor Issues
- Check sensor wiring and power
- Verify sensor type (DHT22/DHT11)
- Check ESP32 serial monitor for errors

### App Issues
- Restart app if connection fails
- Check app permissions
- Clear app data if needed

## Documentation

- [WiFi Setup Process](WIFI_SETUP_PROCESS.md)
- [Auto-Detect Guide](AUTO_DETECT_GUIDE.md)
- [Schedule Guide](SCHEDULE_GUIDE.md)
- [Troubleshooting](WIFIMANAGER_TROUBLESHOOTING.md)

## Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

## License

This project is licensed under the MIT License.
