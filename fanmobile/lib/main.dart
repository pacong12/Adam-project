import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fan Automation',
      debugShowCheckedModeBanner: false, // Remove debug banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Fan Automation'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Data variables (real data from ESP32)
  double temperature = 0;
  double humidity = 0;
  bool fanOn = false;
  bool manualMode = false;
  double tempThreshold = 30.0;
  double humidThreshold = 70.0;
  int startHour = 7, endHour = 14, startMin = 0, endMin = 0;
  int hour = 0, minute = 0;
  bool loading = false;
  bool userLoading = false;
  String lastUpdate = "00:00";
  String errorMessage = "";
  
  // WebSocket variables
  WebSocketChannel? channel;
  bool wsConnected = false;
  // Ubah inisialisasi esp32Url menjadi string kosong (tidak hardcode IP dummy)
  String esp32Url = "";
  Timer? _timer;

  // SmartConfig variables
  bool isConfiguring = false;
  String configStatus = "";
  String wifiSSID = "";
  String wifiPassword = "";

  @override
  void initState() {
    super.initState();
    _loadIp();
  }

  @override
  void dispose() {
    _timer?.cancel();
    channel?.sink.close();
    super.dispose();
  }

  // WebSocket connection
  void _connectWebSocket() {
    try {
      // Validate URL format
      if (!esp32Url.startsWith('http://')) {
        throw Exception('Invalid URL format. Expected http:// but got: ${esp32Url.substring(0, min(10, esp32Url.length))}...');
      }
      
      String wsUrl = esp32Url.replaceFirst('http://', 'ws://') + ':81';
      
      // Validate WebSocket URL
      Uri uri = Uri.parse(wsUrl);
      if (uri.host.isEmpty) {
        throw Exception('Invalid host in URL: $wsUrl');
      }
      
      // Close existing connection if any
      channel?.sink.close();
      
      channel = WebSocketChannel.connect(uri);
      
      channel!.stream.listen(
        (data) {
          _handleWebSocketData(data);
        },
        onError: (error) {
          print('WebSocket error: $error');
    setState(() {
            wsConnected = false;
            errorMessage = "WebSocket connection error: ${error.toString().contains('SocketException') ? 'Cannot connect to ESP32' : error}";
          });
          // Fallback to HTTP polling
          _startPolling();
        },
        onDone: () {
          print('WebSocket connection closed');
          setState(() {
            wsConnected = false;
            if (errorMessage.isEmpty) {
              errorMessage = "WebSocket connection closed";
            }
          });
          // Fallback to HTTP polling
          _startPolling();
        },
      );
      
      setState(() {
        wsConnected = true;
        errorMessage = "";
      });
      
      print('WebSocket connected to $wsUrl');
    } catch (e) {
      print('WebSocket connection failed: $e');
      setState(() {
        wsConnected = false;
        errorMessage = "WebSocket connection failed: ${e.toString().contains('SocketException') ? 'Cannot connect to ESP32' : e}";
      });
      // Fallback to HTTP polling
      _startPolling();
    }
  }

  void _handleWebSocketData(dynamic data) {
    try {
      // Validate input data
      if (data == null) {
        throw Exception('Received null data from WebSocket');
      }
      
      String dataString = data.toString();
      if (dataString.isEmpty) {
        throw Exception('Received empty data from WebSocket');
      }
      
      Map<String, dynamic> jsonData = json.decode(dataString);
      
      // Validate required fields
      if (jsonData['type'] != 'data') {
        throw Exception('Invalid data type: ${jsonData['type']}');
      }
      
      // Validate and set data with bounds checking
      setState(() {
        // Temperature validation (0-100°C)
        double temp = (jsonData['temperature'] ?? 0).toDouble();
        temperature = temp.clamp(0.0, 100.0);
        
        // Humidity validation (0-100%)
        double humid = (jsonData['humidity'] ?? 0).toDouble();
        humidity = humid.clamp(0.0, 100.0);
        
        // Boolean values
        fanOn = jsonData['fan'] == true;
        manualMode = jsonData['manualMode'] == true;
        
        // Threshold validation (0-100)
        double tempThresh = (jsonData['tempThreshold'] ?? 30).toDouble();
        tempThreshold = tempThresh.clamp(0.0, 100.0);
        
        double humidThresh = (jsonData['humidThreshold'] ?? 70).toDouble();
        humidThreshold = humidThresh.clamp(0.0, 100.0);
        
        // Schedule validation
        List schedule = jsonData['schedule'] ?? [7, 14, 0, 0];
        if (schedule.length >= 4) {
          startHour = (schedule[0] ?? 7).clamp(0, 23);
          endHour = (schedule[1] ?? 14).clamp(0, 23);
          startMin = (schedule[2] ?? 0).clamp(0, 59);
          endMin = (schedule[3] ?? 0).clamp(0, 59);
        }
        
        // Time validation
        hour = (jsonData['hour'] ?? 0).clamp(0, 23);
        minute = (jsonData['minute'] ?? 0).clamp(0, 59);
        
        lastUpdate = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
        loading = false;
        userLoading = false;
        errorMessage = ""; // Clear error on successful data
      });
      
    } catch (e) {
      print('Error parsing WebSocket data: $e');
      setState(() {
        errorMessage = "Data parsing error: ${e.toString().contains('FormatException') ? 'Invalid data format' : e}";
      });
    }
  }

  // Fallback to HTTP polling
  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!loading) fetchData();
    });
  }

  // Send command via WebSocket
  void _sendWebSocketCommand(String command, Map<String, dynamic> data) {
    try {
      // Jangan pernah kirim setup_wifi via WebSocket
      if (command == 'setup_wifi') {
        // Fallback langsung ke HTTP
        _sendHttpCommand(command, data);
        return;
      }
      // Validate command
      if (command.isEmpty) {
        throw Exception('Command cannot be empty');
      }
      
      // Validate data
      if (data == null) {
        throw Exception('Data cannot be null');
      }
      
      if (wsConnected && channel != null) {
        try {
          Map<String, dynamic> message = {
            'command': command,
            ...data,
          };
          
          String jsonMessage = json.encode(message);
          channel!.sink.add(jsonMessage);
          
          print('WebSocket command sent: $command');
        } catch (e) {
          print('Error sending WebSocket command: $e');
          setState(() {
            errorMessage = "Failed to send command via WebSocket: ${e.toString().contains('StateError') ? 'Connection lost' : e}";
          });
          // Fallback to HTTP
          _sendHttpCommand(command, data);
        }
      } else {
        print('WebSocket not connected, falling back to HTTP');
        // Fallback to HTTP
        _sendHttpCommand(command, data);
      }
    } catch (e) {
      print('Error in _sendWebSocketCommand: $e');
      setState(() {
        errorMessage = "Command error: $e";
      });
    }
  }

  void _sendHttpCommand(String command, Map<String, dynamic> data) async {
    try {
      if (esp32Url.isEmpty) throw Exception('ESP32 URL is empty');
      http.Response response;

      switch (command) {
        case 'set_fan':
          response = await http.post(
            Uri.parse('$esp32Url/set_fan'),
            body: data['value'].toString(),
            headers: {'Content-Type': 'text/plain'},
          );
          break;
        case 'set_mode':
          response = await http.post(
            Uri.parse('$esp32Url/set_mode'),
            body: data['value'].toString(),
            headers: {'Content-Type': 'text/plain'},
          );
          break;
        case 'set_threshold':
          response = await http.post(
            Uri.parse('$esp32Url/set_threshold'),
            body: '${data['temp']},${data['humid']}',
            headers: {'Content-Type': 'text/plain'},
          );
          break;
        case 'set_schedule':
          List<int> s = List<int>.from(data['schedule']);
          response = await http.post(
            Uri.parse('$esp32Url/set_schedule'),
            body: '${s[0]},${s[1]},${s[2]},${s[3]}',
            headers: {'Content-Type': 'text/plain'},
          );
          break;
        case 'setup_wifi':
          // Hanya boleh via HTTP, bukan WebSocket
          if (!data.containsKey('ssid') || !data.containsKey('password')) {
            throw Exception('Missing ssid or password for setup_wifi');
          }
          response = await http.post(
            Uri.parse('$esp32Url/setup_wifi'),
            body: '${data['ssid']},${data['password']}',
            headers: {'Content-Type': 'text/plain'},
          );
          break;
        default:
          throw Exception('Unknown command: $command');
      }

      if (response.statusCode != 200) {
        throw Exception('HTTP  ${response.statusCode}: ${response.body}');
      }
      print('HTTP command executed: $command');
    } catch (e) {
      print('Error in _sendHttpCommand: $e');
      setState(() {
        errorMessage = "HTTP command error: $e";
      });
    }
  }

  Future<void> _loadIp() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('esp32_ip') ?? '';
    if (ip.isNotEmpty) {
      setState(() {
        esp32Url = 'http://$ip';
      });
      _connectWebSocket();
    } else {
      // Tampilkan dialog input IP manual jika belum ada
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSetIpDialog();
      });
    }
  }

  Future<void> _saveIp() async {
    try {
      // Extract IP from URL
      String ip = esp32Url.replaceAll('http://', '');
      
      // Validate IP address
      if (!_isValidIpAddress(ip)) {
        throw Exception('Invalid IP address format: $ip');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('esp32_ip', ip);
      
      print('Saved IP: $ip');
    } catch (e) {
      print('Error saving IP: $e');
      setState(() {
        errorMessage = "Failed to save IP address: $e";
      });
    }
  }

  // IP validation function
  bool _isValidIpAddress(String ip) {
    try {
      // Check if IP is empty
      if (ip.isEmpty) {
        return false;
      }
      
      // Check if IP contains only valid characters
      if (!RegExp(r'^[0-9.]+$').hasMatch(ip)) {
        return false;
      }
      
      final parts = ip.split('.');
      if (parts.length != 4) return false;
      
      for (String part in parts) {
        // Check if part is empty
        if (part.isEmpty) return false;
        
        try {
          int num = int.parse(part);
          if (num < 0 || num > 255) return false;
        } catch (e) {
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error validating IP address: $e');
      return false;
    }
  }

  Future<void> _showSetIpDialog() async {
    final controller = TextEditingController(text: esp32Url.replaceAll('http://', ''));
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set IP ESP32'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                hintText: '192.168.1.100',
                helperText: 'Format: xxx.xxx.xxx.xxx',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pastikan ESP32 dan HP dalam jaringan WiFi yang sama',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final ip = controller.text.trim();
              if (ip.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('IP Address tidak boleh kosong!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (!_isValidIpAddress(ip)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Format IP Address tidak valid!'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, ip);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        esp32Url = 'http://$result';
        errorMessage = ""; // Clear previous errors
      });
      _saveIp();
      // Reconnect WebSocket with new IP
      channel?.sink.close();
      _connectWebSocket();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('IP berhasil diubah ke $result'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // SmartConfig function - menggunakan WiFiManager
  Future<void> _startSmartConfig() async {
    setState(() {
      isConfiguring = true;
      configStatus = "Memulai SmartConfig...";
    });
    
    try {
      // Langsung buka dialog untuk set IP
      // WiFiManager akan handle konfigurasi WiFi
      setState(() {
        configStatus = "SmartConfig siap! Silakan set IP ESP32";
        isConfiguring = false;
      });
      
      // Tampilkan dialog untuk set IP
      _showSetIpDialog();
      
    } catch (e) {
      setState(() {
        configStatus = "Error: $e";
        isConfiguring = false;
      });
    }
  }
  
  void _showSmartConfigDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Setup WiFi ESP32'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pilih metode setup WiFi untuk ESP32',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: const Text(
                  '📱 ESP32 akan membuat hotspot "FanAutomation_AP" dengan password "12345678".\n\n'
                  'Pilih metode setup:',
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showDirectWiFiSetupDialog();
              },
              child: const Text('Setup Langsung'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showSetIpDialog();
              },
              child: const Text('Set IP Manual'),
            ),
          ],
        );
      },
    );
  }

  void _showDirectWiFiSetupDialog() {
    final TextEditingController ssidController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Setup WiFi Langsung'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan WiFi credentials untuk ESP32',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ssidController,
                decoration: const InputDecoration(
                  labelText: 'WiFi SSID',
                  border: OutlineInputBorder(),
                  hintText: 'Masukkan nama WiFi',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'WiFi Password',
                  border: OutlineInputBorder(),
                  hintText: 'Masukkan password WiFi',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Text(
                  '⚠️ Pastikan HP terhubung ke hotspot "FanAutomation_AP" terlebih dahulu!',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (ssidController.text.isEmpty || passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SSID dan Password tidak boleh kosong!')),
                  );
                  return;
                }
                
                Navigator.of(context).pop();
                
                try {
                  // Kirim credentials tanpa loading dialog
                  await http.post(
                    Uri.parse('http://192.168.4.1/setup_wifi'),
                    body: '${ssidController.text},${passwordController.text}',
                    headers: {'Content-Type': 'text/plain'},
                  ).timeout(const Duration(seconds: 30));
                  // Tampilkan instruksi ke user
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          const Text('Setup Berhasil'),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Credentials berhasil dikirim ke ESP32!',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'ESP32 sedang mencoba connect ke WiFi rumah. Langkah selanjutnya:',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('1. Hubungkan HP ke WiFi rumah'),
                                Text('2. Aplikasi akan otomatis detect ESP32'),
                                Text('3. Jika tidak terdeteksi, tekan "Auto Detect"'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Tutup'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _startAutoDetection();
                          },
                          child: const Text('Auto Detect'),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  
                  // Tampilkan error dialog dengan opsi retry
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text('Setup Gagal'),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gagal mengirim credentials ke ESP32:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            e.toString().contains('SocketException') 
                              ? 'Tidak bisa connect ke ESP32. Pastikan HP terhubung ke hotspot "FanAutomation_AP"'
                              : e.toString().contains('TimeoutException')
                                ? 'Request timeout. ESP32 mungkin sudah connect ke WiFi rumah'
                                : 'Error: $e',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Jika ESP32 sudah connect ke WiFi:'),
                                Text('1. Hubungkan HP ke WiFi rumah'),
                                Text('2. Tekan "Auto Detect" untuk detect ESP32'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Tutup'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _startAutoDetection();
                          },
                          child: const Text('Auto Detect'),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Text('Setup WiFi'),
            ),
          ],
        );
      },
    );
  }

  // HTTP fallback methods
  Future<void> fetchData({bool showLoading = false}) async {
    try {
      // Validate URL
      if (esp32Url.isEmpty) {
        throw Exception('ESP32 URL is empty');
      }
      
      if (showLoading) setState(() => userLoading = true);
      setState(() {
        loading = true;
        errorMessage = "";
      });
      
      final response = await http.get(Uri.parse('$esp32Url/get_data'))
          .timeout(const Duration(seconds: 10)); // Increased timeout
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          
          // Validate response data
          if (data == null) {
            throw Exception('Received null data from ESP32');
          }
          
          setState(() {
            // Temperature validation (0-100°C)
            double temp = (data['temperature'] ?? 0).toDouble();
            temperature = temp.clamp(0.0, 100.0);
            
            // Humidity validation (0-100%)
            double humid = (data['humidity'] ?? 0).toDouble();
            humidity = humid.clamp(0.0, 100.0);
            
            // Boolean values
            fanOn = data['fan'] == true;
            manualMode = data['manualMode'] == true;
            
            // Threshold validation (0-100)
            double tempThresh = (data['tempThreshold'] ?? 30).toDouble();
            tempThreshold = tempThresh.clamp(0.0, 100.0);
            
            double humidThresh = (data['humidThreshold'] ?? 70).toDouble();
            humidThreshold = humidThresh.clamp(0.0, 100.0);
            
            // Schedule validation
            List schedule = data['schedule'] ?? [7, 14, 0, 0];
            if (schedule.length >= 4) {
              startHour = (schedule[0] ?? 7).clamp(0, 23);
              endHour = (schedule[1] ?? 14).clamp(0, 23);
              startMin = (schedule[2] ?? 0).clamp(0, 59);
              endMin = (schedule[3] ?? 0).clamp(0, 59);
            }
            
            // Time validation
            hour = (data['hour'] ?? 0).clamp(0, 23);
            minute = (data['minute'] ?? 0).clamp(0, 59);
            
            lastUpdate = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
            loading = false;
            if (showLoading) userLoading = false;
            errorMessage = ""; // Clear error on successful data
          });
          
        } catch (e) {
          throw Exception('Invalid data format: ${e.toString().contains('FormatException') ? 'JSON parsing failed' : e}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.statusCode == 404 ? 'Endpoint not found' : response.statusCode == 500 ? 'Server error' : 'Request failed'}');
      }
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        errorMessage = e.toString().contains('SocketException') 
            ? "Cannot connect to ESP32 at $esp32Url" 
            : e.toString().contains('TimeoutException') 
                ? "Request timeout - ESP32 not responding" 
                : "Data fetch error: $e";
        loading = false;
        if (showLoading) userLoading = false;
      });
    }
  }

  Future<void> setFan(bool on) async {
    try {
      _sendWebSocketCommand('set_fan', {'value': on});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim perintah fan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> setMode(bool mode) async {
    try {
      _sendWebSocketCommand('set_mode', {'value': mode});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim perintah mode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> setThreshold(double temp, double humid) async {
    try {
      _sendWebSocketCommand('set_threshold', {'temp': temp, 'humid': humid});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim threshold: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> setSchedule(List<int> schedule) async {
    try {
      _sendWebSocketCommand('set_schedule', {'schedule': schedule});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim jadwal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Reset WiFi configuration
  Future<void> resetWiFi() async {
    try {
      // Validate URL
      if (esp32Url.isEmpty) {
        throw Exception('ESP32 URL is empty');
      }
      
      final response = await http.post(Uri.parse('$esp32Url/reset_wifi'))
          .timeout(const Duration(seconds: 15)); // Increased timeout
      
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WiFi berhasil direset. ESP32 akan restart.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Clear saved IP
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('esp32_ip');
          print('Cleared saved IP address');
        } catch (e) {
          print('Error clearing saved IP: $e');
        }
        
        // Show IP setup dialog after delay
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            _showSetIpDialog();
          }
        });
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.statusCode == 404 ? 'Reset endpoint not found' : response.statusCode == 500 ? 'Server error' : 'Reset failed'}');
      }
    } catch (e) {
      print('Error resetting WiFi: $e');
      String errorMsg = e.toString().contains('SocketException') 
          ? "Cannot connect to ESP32 to reset WiFi" 
          : e.toString().contains('TimeoutException') 
              ? "Reset timeout - ESP32 not responding" 
              : "Reset error: $e";
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Get WiFi information
  Future<void> getWiFiInfo() async {
    try {
      // Validate URL
      if (esp32Url.isEmpty) {
        throw Exception('ESP32 URL is empty');
      }
      
      final response = await http.get(Uri.parse('$esp32Url/wifi_info'))
          .timeout(const Duration(seconds: 10)); // Increased timeout
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          
          // Validate response data
          if (data == null) {
            throw Exception('Received null data from ESP32');
          }
          
          // Validate required fields
          String ssid = data['ssid'] ?? 'Unknown';
          String ip = data['ip'] ?? 'Unknown';
          int rssi = data['rssi'] ?? 0;
          String status = data['status'] ?? 'Unknown';
          
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('WiFi Information'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SSID: $ssid'),
                    Text('IP: $ip'),
                    Text('RSSI: $rssi dBm'),
                    Text('Status: $status'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } catch (e) {
          throw Exception('Invalid WiFi info format: ${e.toString().contains('FormatException') ? 'JSON parsing failed' : e}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.statusCode == 404 ? 'WiFi info endpoint not found' : response.statusCode == 500 ? 'Server error' : 'Request failed'}');
      }
    } catch (e) {
      print('Error getting WiFi info: $e');
      String errorMsg = e.toString().contains('SocketException') 
          ? "Cannot connect to ESP32 to get WiFi info" 
          : e.toString().contains('TimeoutException') 
              ? "WiFi info timeout - ESP32 not responding" 
              : "WiFi info error: $e";
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Auto-detect ESP32 on WiFi network
  Future<void> _startAutoDetection() async {
    setState(() {
      userLoading = true;
      errorMessage = "";
    });
    
    // Show detection dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              const SizedBox(width: 12),
              const Text('Detecting ESP32...'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Mencari ESP32 di jaringan WiFi...',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pastikan HP terhubung ke WiFi rumah yang sama dengan ESP32',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: const Text(
                  '💡 Scanning IP ranges: 192.168.x.x, 10.x.x.x, 172.x.x.x',
                  style: TextStyle(fontSize: 11, color: Colors.blue),
                ),
              ),
            ],
          ),
        );
      },
    );
    
    try {
      // Generate comprehensive IP ranges for ESP32 detection
      List<String> commonRanges = [];
      
      // 192.168.x.x ranges (most common for home networks)
      for (int i = 0; i <= 50; i++) {
        commonRanges.add('192.168.$i');
      }
      
      // 10.x.x.x ranges (common for larger networks)
      commonRanges.addAll(['10.0.0', '10.0.1', '10.1.0', '10.1.1', '10.10.0', '10.10.1']);
      
      // 172.x.x.x ranges (less common but possible)
      commonRanges.addAll(['172.16.0', '172.16.1', '172.20.0', '172.20.1', '172.30.0', '172.30.1']);
      
      String? foundIp;
      int totalScanned = 0;
      int totalToScan = commonRanges.length * 254;
      
      for (String range in commonRanges) {
        for (int i = 1; i <= 254; i++) {
          String testIp = '$range.$i';
          totalScanned++;
          
          // Update progress every 50 scans
          if (totalScanned % 50 == 0) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Row(
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      const SizedBox(width: 12),
                      const Text('Scanning...'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Scanned: $totalScanned / $totalToScan IPs',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current: $testIp',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              },
            );
          }
          
          try {
            // Try ping endpoint first (faster and lighter)
            final pingResponse = await http.get(
              Uri.parse('http://$testIp/ping'),
              headers: {'Connection': 'close'},
            ).timeout(const Duration(milliseconds: 300));
            
            if (pingResponse.statusCode == 200) {
              try {
                final pingData = json.decode(pingResponse.body);
                if (pingData.containsKey('device') && pingData['device'] == 'ESP32_FanAutomation') {
                  foundIp = testIp;
                  break;
                }
              } catch (e) {
                // Try get_data as fallback
                final dataResponse = await http.get(
                  Uri.parse('http://$testIp/get_data'),
                  headers: {'Connection': 'close'},
                ).timeout(const Duration(milliseconds: 300));
                
                if (dataResponse.statusCode == 200) {
                  try {
                    final data = json.decode(dataResponse.body);
                    if (data.containsKey('temperature') && data.containsKey('humidity')) {
                      foundIp = testIp;
                      break;
                    }
                  } catch (e) {
                    // Not our ESP32, continue searching
                    continue;
                  }
                }
              }
            }
          } catch (e) {
            // Timeout or connection failed, continue
            continue;
          }
        }
        
        if (foundIp != null) break;
      }
      
      // Close detection dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (foundIp != null) {
        // ESP32 found!
        setState(() {
          esp32Url = 'http://$foundIp';
          userLoading = false;
          errorMessage = "";
        });
        
        // Save IP
        await _saveIp();
        
        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                const Text('ESP32 Ditemukan!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESP32 berhasil terdeteksi di jaringan WiFi!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('IP Address: $foundIp'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Text(
                    'Aplikasi akan otomatis connect ke ESP32',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _connectWebSocket();
                  fetchData(showLoading: true);
                },
                child: const Text('Connect'),
              ),
            ],
          ),
        );
      } else {
        // ESP32 not found
        setState(() {
          userLoading = false;
        });
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('ESP32 Tidak Ditemukan'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ESP32 tidak ditemukan di jaringan WiFi',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total IP yang di-scan: $totalScanned',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kemungkinan penyebab:'),
                      Text('• ESP32 belum connect ke WiFi rumah'),
                      Text('• HP tidak terhubung ke WiFi yang sama'),
                      Text('• ESP32 menggunakan IP range yang tidak umum'),
                      Text('• Firewall/router blocking connection'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Solusi:'),
                      Text('• Cek IP ESP32 di Serial Monitor'),
                      Text('• Gunakan "Set IP Manual"'),
                      Text('• Pastikan ESP32 dan HP di WiFi yang sama'),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showSetIpDialog();
                },
                child: const Text('Set IP Manual'),
              ),
            ],
          ),
        );
      }
      
    } catch (e) {
      // Close detection dialog
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      setState(() {
        userLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saat detect ESP32: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Check if ESP32 is already connected to WiFi
  Future<void> checkWiFiStatus() async {
    try {
      final response = await http.get(Uri.parse('$esp32Url/wifi_info'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final connected = (data['status'] ?? '') == 'Connected';
        final ssid = data['ssid'] ?? '';
        final ip = data['ip'] ?? '';
        if (connected && ssid.isNotEmpty) {
         // Show WiFi status dialog with IP information
         showDialog(
           context: context,
           builder: (BuildContext context) {
             return AlertDialog(
               title: Row(
                 children: [
                   Icon(Icons.wifi, color: Colors.green),
                   const SizedBox(width: 8),
                   const Text('WiFi Status'),
                 ],
               ),
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: Colors.green.shade50,
                       borderRadius: BorderRadius.circular(8),
                       border: Border.all(color: Colors.green),
                     ),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           'ESP32 sudah terhubung ke WiFi!',
                           style: TextStyle(
                             fontWeight: FontWeight.bold,
                             color: Colors.green.shade800,
                           ),
                         ),
                         const SizedBox(height: 8),
                         Text('SSID: $ssid'),
                         Text('IP Address: $ip'),
                         Text('Signal Strength: ${data['rssi'] ?? 0} dBm'),
                       ],
                     ),
                   ),
                 ],
               ),
               actions: [
                 TextButton(
                   onPressed: () => Navigator.of(context).pop(),
                   child: const Text('OK'),
                 ),
               ],
             );
           },
         );
         
         // Auto-save IP if different
         if (ip.isNotEmpty && esp32Url != 'http://$ip') {
           final prefs = await SharedPreferences.getInstance();
           await prefs.setString('esp32_ip', ip);
           setState(() {
             esp32Url = 'http://$ip';
           });
           fetchData(showLoading: true);
         }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ESP32 belum terhubung ke WiFi'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak bisa check status WiFi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper functions
  String getTempStatus() {
    if (temperature < tempThreshold - 2) return "Dingin";
    if (temperature > tempThreshold + 2) return "Panas";
    return "Normal";
  }

  String getHumidStatus() {
    if (humidity < humidThreshold - 5) return "Kering";
    if (humidity > humidThreshold + 5) return "Lembab";
    return "Normal";
  }

  IconData getTrendIcon() {
    return Icons.trending_up;
  }

  Color getStatusColor() {
    if (fanOn) return Colors.green;
    return Colors.red;
  }

  String getFanReason() {
    if (manualMode) return "Mode Manual";
    if (getScheduleStatus() == "Tidak Aktif") return "Jadwal Tidak Aktif";
    if (temperature > tempThreshold) return "Suhu Tinggi";
    if (humidity > humidThreshold) return "Kelembaban Tinggi";
    return "Kondisi Normal";
  }

  String getScheduleStatus() {
    int currentTime = hour * 60 + minute;
    int startTime = startHour * 60 + startMin;
    int endTime = endHour * 60 + endMin;
    
    if (currentTime >= startTime && currentTime <= endTime) {
      return "Aktif";
    }
    return "Tidak Aktif";
  }

  String getNextFanEvent() {
    int currentTime = hour * 60 + minute;
    int startTime = startHour * 60 + startMin;
    int endTime = endHour * 60 + endMin;
    
    if (currentTime < startTime) {
      int diff = startTime - currentTime;
      return "Mode Otomatis ON dalam ${diff ~/ 60}j ${diff % 60}m";
    } else if (currentTime > endTime) {
      int diff = (24 * 60 - currentTime) + startTime;
      return "Mode Otomatis ON besok dalam ${diff ~/ 60}j ${diff % 60}m";
    } else {
      int diff = endTime - currentTime;
      return "Mode Otomatis OFF dalam ${diff ~/ 60}j ${diff % 60}m";
    }
  }

  String getScheduleStr() {
    return "${startHour.toString().padLeft(2, '0')}:${startMin.toString().padLeft(2, '0')} - ${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}";
  }

  // Setup jadwal function
  Future<void> _showScheduleDialog() async {
    TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: startHour, minute: startMin),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: Colors.blue,
              hourMinuteColor: Colors.blue.shade50,
              dialHandColor: Colors.blue,
              dialBackgroundColor: Colors.blue.shade50,
            ),
          ),
          child: child!,
        );
      },
    );

    if (startTime != null) {
      TimeOfDay? endTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: endHour, minute: endMin),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              timePickerTheme: TimePickerThemeData(
                backgroundColor: Colors.white,
                hourMinuteTextColor: Colors.orange,
                hourMinuteColor: Colors.orange.shade50,
                dialHandColor: Colors.orange,
                dialBackgroundColor: Colors.orange.shade50,
              ),
            ),
            child: child!,
          );
        },
      );

      if (endTime != null) {
        // Validate time range
        int startMinutes = startTime.hour * 60 + startTime.minute;
        int endMinutes = endTime.hour * 60 + endTime.minute;
        
        if (startMinutes >= endMinutes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Waktu mulai harus sebelum waktu selesai!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }

        // Update schedule
        List<int> newSchedule = [
          startTime.hour,
          endTime.hour,
          startTime.minute,
          endTime.minute,
        ];

        await setSchedule(newSchedule);
      }
    }
  }

  // Quick schedule presets
  Future<void> _showQuickScheduleDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jadwal Cepat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.wb_sunny, color: Colors.orange),
              title: const Text('Pagi (07:00 - 12:00)'),
              subtitle: const Text('Mode otomatis pagi'),
              onTap: () => Navigator.pop(context, 'morning'),
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined, color: Colors.yellow),
              title: const Text('Siang (12:00 - 18:00)'),
              subtitle: const Text('Mode otomatis siang'),
              onTap: () => Navigator.pop(context, 'afternoon'),
            ),
            ListTile(
              leading: const Icon(Icons.nightlight, color: Colors.indigo),
              title: const Text('Malam (18:00 - 22:00)'),
              subtitle: const Text('Mode otomatis malam'),
              onTap: () => Navigator.pop(context, 'evening'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule, color: Colors.green),
              title: const Text('Custom'),
              subtitle: const Text('Atur sendiri'),
              onTap: () => Navigator.pop(context, 'custom'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ],
      ),
    );

    if (result != null) {
      List<int> schedule;
      switch (result) {
        case 'morning':
          schedule = [7, 12, 0, 0];
          break;
        case 'afternoon':
          schedule = [12, 18, 0, 0];
          break;
        case 'evening':
          schedule = [18, 22, 0, 0];
          break;
        case 'custom':
          _showScheduleDialog();
          return;
        default:
          return;
      }
      await setSchedule(schedule);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 32,
              width: 32,
            ),
            const SizedBox(width: 12),
            const Text('Fan Automation'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(wsConnected ? Icons.wifi : Icons.wifi_off),
            onPressed: _showSmartConfigDialog,
            tooltip: 'Setup WiFi',
          ),
                      PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'wifi_info':
                  getWiFiInfo();
                  break;
                case 'check_wifi':
                  checkWiFiStatus();
                  break;
                case 'auto_detect':
                  _startAutoDetection();
                  break;
                case 'reset_wifi':
                  resetWiFi();
                  break;
                case 'set_ip':
                  _showSetIpDialog();
                  break;
                case 'refresh':
                  fetchData(showLoading: true);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'wifi_info', child: Row(children: [Icon(Icons.info_outline, size: 20), SizedBox(width: 8), Text('WiFi Info')])),
              PopupMenuItem(value: 'check_wifi', child: Row(children: [Icon(Icons.wifi_find, size: 20), SizedBox(width: 8), Text('Check WiFi Status')])),
              PopupMenuItem(value: 'auto_detect', child: Row(children: [Icon(Icons.search, size: 20), SizedBox(width: 8), Text('Auto Detect ESP32')])),
              PopupMenuItem(value: 'reset_wifi', child: Row(children: [Icon(Icons.refresh, size: 20), SizedBox(width: 8), Text('Reset WiFi')])),
              PopupMenuItem(value: 'set_ip', child: Row(children: [Icon(Icons.settings_ethernet, size: 20), SizedBox(width: 8), Text('Set IP Manual')])),
              PopupMenuItem(value: 'refresh', child: Row(children: [Icon(Icons.sync, size: 20), SizedBox(width: 8), Text('Refresh')]))
            ],
            tooltip: 'Menu',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => fetchData(showLoading: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Connection Status
            if (errorMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Connection Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          wsConnected ? Icons.wifi : Icons.wifi_off,
                          color: wsConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
            Text(
                          'Connection Status',
                          style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status: ${wsConnected ? "Connected" : "Disconnected"}',
                                style: TextStyle(
                                  color: wsConnected ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ESP32 IP: ${esp32Url.replaceAll('http://', '')}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                'Protocol: ${wsConnected ? "WebSocket" : "HTTP"}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (wsConnected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.air,
                          size: 32,
                          color: getStatusColor(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status Fan',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                fanOn ? 'ON' : 'OFF',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: getStatusColor(),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Mode: ${manualMode ? "Manual" : "Otomatis"}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                'Alasan: ${getFanReason()}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                'Update: $lastUpdate',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Sensor Data Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data Sensor',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Icon(Icons.thermostat, size: 32, color: Colors.orange),
                              const SizedBox(height: 8),
                              Text(
                                '${temperature.toStringAsFixed(1)}°C',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              Text(
                                'Suhu',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                getTempStatus(),
                                style: TextStyle(
                                  color: temperature > tempThreshold ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Icon(Icons.water_drop, size: 32, color: Colors.blue),
                              const SizedBox(height: 8),
                              Text(
                                '${humidity.toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              Text(
                                'Kelembaban',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                getHumidStatus(),
                                style: TextStyle(
                                  color: humidity > humidThreshold ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            if (userLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            
            // Control Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kontrol',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Mode Manual'),
                      value: manualMode,
                      onChanged: (value) => setMode(value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: loading || !manualMode || fanOn ? null : () => setFan(true),
                            icon: const Icon(Icons.power_settings_new),
                            label: const Text('Nyalakan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: loading || !manualMode || !fanOn ? null : () => setFan(false),
                            icon: const Icon(Icons.power_off),
                            label: const Text('Matikan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!manualMode)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Tombol ON/OFF hanya aktif di mode manual',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Threshold Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Threshold',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Text('Suhu: ${tempThreshold.toStringAsFixed(1)}°C'),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        showValueIndicator: ShowValueIndicator.onlyForContinuous,
                      ),
                      child: Slider(
                        value: tempThreshold,
                        min: 20,
                        max: 40,
                        divisions: 20,
                        label: '${tempThreshold.toStringAsFixed(1)}°C',
                        onChanged: (value) {
                          setState(() {
                            tempThreshold = value;
                          });
                        },
                        onChangeEnd: (value) {
                          setThreshold(value, humidThreshold);
                        },
                      ),
                    ),
                    Text('Kelembaban: ${humidThreshold.toStringAsFixed(1)}%'),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        showValueIndicator: ShowValueIndicator.onlyForContinuous,
                      ),
                      child: Slider(
                        value: humidThreshold,
                        min: 30,
                        max: 90,
                        divisions: 60,
                        label: '${humidThreshold.toStringAsFixed(1)}%',
                        onChanged: (value) {
                          setState(() {
                            humidThreshold = value;
                          });
                        },
                        onChangeEnd: (value) {
                          setThreshold(tempThreshold, value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Schedule Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Jadwal',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.schedule, color: Colors.blue),
                              onPressed: _showQuickScheduleDialog,
                              tooltip: 'Jadwal Cepat',
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange),
                              onPressed: _showScheduleDialog,
                              tooltip: 'Edit Jadwal',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: getScheduleStatus() == "Aktif" 
                          ? Colors.green.shade50 
                          : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: getScheduleStatus() == "Aktif" 
                            ? Colors.green 
                            : Colors.grey,
                        ),
                      ),
        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: getScheduleStatus() == "Aktif" 
                                  ? Colors.green 
                                  : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                getScheduleStr(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: getScheduleStatus() == "Aktif" 
                                    ? Colors.green.shade700 
                                    : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8, 
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: getScheduleStatus() == "Aktif" 
                                    ? Colors.green 
                                    : Colors.grey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  getScheduleStatus(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  getNextFanEvent(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '💡 Tips: Mode otomatis aktif dalam jadwal. Fan ON jika suhu/kelembaban melebihi threshold',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Connection Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      wsConnected ? Icons.wifi : Icons.wifi_off,
                      color: wsConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
            Text(
                      wsConnected ? 'WebSocket Connected' : 'HTTP Polling',
                      style: TextStyle(
                        color: wsConnected ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
