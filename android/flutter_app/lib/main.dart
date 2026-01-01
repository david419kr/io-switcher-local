import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

const MethodChannel _widgetChannel = MethodChannel('com.example.switcher_local/widget');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _widgetChannel.setMethodCallHandler(_handleWidgetAction);
  runApp(const MyApp());
}

Future<dynamic> _handleWidgetAction(MethodCall call) async {
  if (call.method == 'widgetAction') {
    final String action = call.arguments as String;
    final parts = action.split('_');
    if (parts.length == 2) {
      final switchNum = int.tryParse(parts[0]);
      final actionType = parts[1];
      if (switchNum != null) {
        await _executeWidgetAction(switchNum, actionType);
      }
    }
  }
}

Future<void> _executeWidgetAction(int switchIndex, String action) async {
  final sp = await SharedPreferences.getInstance();
  final mac = sp.getString('mac') ?? '';
  final deviceType = sp.getInt('type') ?? 2;
  final invert = sp.getBool('invert') ?? false;
  
  if (mac.isEmpty) return;
  
  String finalAction = action;
  if (invert) {
    finalAction = (action == 'on') ? 'off' : 'on';
  }
  
  final flutterReactiveBle = FlutterReactiveBle();
  await _writeWithRetriesBackground(flutterReactiveBle, mac, switchIndex, finalAction, retries: 3);
}

Future<bool> _writeWithRetriesBackground(FlutterReactiveBle ble, String deviceId, int switchIndex, String action, {int retries = 3}) async {
  final serviceId = Uuid.parse(SERVICE_UUID);
  final charIdConst = Uuid.parse(CHAR_UUID);
  final data = Uint8List.fromList((switchIndex == 1)
      ? (action == 'on' ? ON_KEY1 : OFF_KEY1)
      : (action == 'on' ? ON_KEY2 : OFF_KEY2));

  for (int i = 0; i < retries; i++) {
    StreamSubscription<ConnectionStateUpdate>? connSub;
    try {
      final connStream = ble.connectToDevice(id: deviceId, connectionTimeout: const Duration(seconds: 5));
      final completer = Completer<ConnectionStateUpdate>();
      connSub = connStream.listen((update) {
        if (!completer.isCompleted) {
          if (update.connectionState == DeviceConnectionState.connected) {
            completer.complete(update);
          } else if (update.connectionState == DeviceConnectionState.disconnected) {
            completer.completeError(Exception('Device disconnected'));
          }
        }
      }, onError: (err) {
        if (!completer.isCompleted) completer.completeError(err);
      });
      
      try {
        await completer.future.timeout(const Duration(seconds: 6));
      } catch (e) {
        try { await connSub?.cancel(); } catch (_) {}
        rethrow;
      }
      
      await Future.delayed(const Duration(milliseconds: 200));
      
      final characteristic = QualifiedCharacteristic(
        serviceId: serviceId,
        characteristicId: charIdConst,
        deviceId: deviceId,
      );

      try {
        await ble.writeCharacteristicWithResponse(characteristic, value: data);
        await Future.delayed(const Duration(milliseconds: 300));
        await connSub?.cancel();
        return true;
      } catch (e) {
        try {
          await ble.writeCharacteristicWithoutResponse(characteristic, value: data);
          await Future.delayed(const Duration(milliseconds: 300));
          await connSub?.cancel();
          return true;
        } catch (e2) {
          throw Exception('Write failed');
        }
      }
    } catch (e) {
      try { await connSub?.cancel(); } catch (_) {}
      if (i < retries - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
        continue;
      }
    }
  }
  return false;
}

const String SERVICE_UUID = '0000150b-0000-1000-8000-00805f9b34fb';
const String CHAR_UUID = '000015ba-0000-1000-8000-00805f9b34fb';

// command bytes (match pyswitcherio)
final List<int> ON_KEY1 = [0x00];
final List<int> OFF_KEY1 = [0x01];
final List<int> ON_KEY2 = [0x05];
final List<int> OFF_KEY2 = [0x03];

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'I/O 스위처 로컬',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final flutterReactiveBle = FlutterReactiveBle();
  final _macController = TextEditingController();
  int deviceType = 2; // 1 or 2
  bool invert = false;
  String status = '';
  StreamSubscription<DiscoveredDevice>? _scanSub;
  List<DiscoveredDevice> _scanResults = [];
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _macController.text = sp.getString('mac') ?? '';
      deviceType = sp.getInt('type') ?? 2;
      invert = sp.getBool('invert') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('mac', _macController.text.trim());
    await sp.setInt('type', deviceType);
    await sp.setBool('invert', invert);
    setState(() => status = '설정 저장됨');
  }

  Future<void> _requestPermissions() async {
    // For Android 12+, request BLUETOOTH_SCAN and BLUETOOTH_CONNECT
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    // proceed regardless; individual devices might still fail due to denied perms
  }

  Future<void> _findDevices() async {
    await _requestPermissions();
    setState(() {
      _scanResults = [];
      _scanning = true;
    });
    _scanSub = flutterReactiveBle.scanForDevices(withServices: []).listen((device) {
      if ((device.name ?? '').contains('SWITCHER_M')) {
        setState(() {
          if (!_scanResults.any((d) => d.id == device.id)) {
            _scanResults.add(device);
          }
        });
      }
    }, onError: (e) {
      setState(() {
        _scanning = false;
        status = '스캔 에러: $e';
      });
    });
    // stop scan after timeout
    Future.delayed(const Duration(seconds: 5), () async {
      await _scanSub?.cancel();
      _scanSub = null;
      setState(() => _scanning = false);
      _showScanDialog();
    });
  }

  void _showScanDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('SWITCHER_M devices'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: _scanResults.isEmpty
              ? const Text('No SWITCHER_M devices found')
              : ListView.builder(
                  itemCount: _scanResults.length,
                  itemBuilder: (c, i) {
                    final d = _scanResults[i];
                    return ListTile(
                      title: Text(d.name ?? '<unknown>'),
                      subtitle: Text(d.id),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: d.id));
                            Navigator.of(context).pop();
                            setState(() => status = 'MAC 복사됨: ${d.id}');
                          },
                        ),
                        TextButton(
                          child: const Text('Use'),
                          onPressed: () async {
                            _macController.text = d.id;
                            await _saveSettings();
                            Navigator.of(context).pop();
                          },
                        ),
                      ]),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))
        ],
      ),
    );
  }

  Future<void> _onAction(int switchIndex, String action) async {
    final mac = _macController.text.trim();
    if (mac.isEmpty) {
      _showAlert('MAC 주소를 입력하고 저장하세요.');
      return;
    }
    // apply invert
    if (invert) {
      action = (action == 'on') ? 'off' : 'on';
    }
    setState(() => status = '작업 중...');
    _setButtonsEnabled(false);
    final success = await _writeWithRetries(mac, switchIndex, action, retries: 5);
    if (success) {
      setState(() => status = '작업 성공 (로그 기준)');
      // per requirement: no explicit success dialog
    } else {
      setState(() => status = '실패');
      _showAlert('스위쳐 통신 실패..');
    }
    _setButtonsEnabled(true);
  }

  void _setButtonsEnabled(bool enabled) {
    // rebuild will reflect button enabled state via a member
    setState(() => _buttonsEnabled = enabled);
  }

  bool _buttonsEnabled = true;

  Future<bool> _writeWithRetries(String deviceId, int switchIndex, String action, {int retries = 5}) async {
    final serviceId = Uuid.parse(SERVICE_UUID);
    final charIdConst = Uuid.parse(CHAR_UUID);
    final data = Uint8List.fromList((switchIndex == 1)
        ? (action == 'on' ? ON_KEY1 : OFF_KEY1)
        : (action == 'on' ? ON_KEY2 : OFF_KEY2));

    for (int i = 0; i < retries; i++) {
      StreamSubscription<ConnectionStateUpdate>? connSub;
      try {
        setState(() => status = '연결 시도 중... (시도 ${i + 1}/$retries)');
        final connStream = flutterReactiveBle.connectToDevice(id: deviceId, connectionTimeout: const Duration(seconds: 6));
        // Subscribe once and wait for connected state using a Completer to avoid double-listen errors
        final completer = Completer<ConnectionStateUpdate>();
        connSub = connStream.listen((update) {
          if (!completer.isCompleted) {
            if (update.connectionState == DeviceConnectionState.connected) {
              completer.complete(update);
            } else if (update.connectionState == DeviceConnectionState.disconnected) {
              completer.completeError(Exception('Device disconnected before connection'));
            }
          }
        }, onError: (err) {
          if (!completer.isCompleted) completer.completeError(err);
        });
        // Wait for connected state with timeout
        try {
          await completer.future.timeout(const Duration(seconds: 8));
        } catch (e) {
          // ensure subscription cancelled on timeout/error
          try {
            await connSub?.cancel();
          } catch (_) {}
          rethrow;
        }
        // Optional short delay to let device initialize
        await Future.delayed(const Duration(milliseconds: 300));

        setState(() => status = '연결됨 - 서비스 탐색 중...');
        // Discover services and pick characteristic
        List<DiscoveredService> services = await flutterReactiveBle.discoverServices(deviceId);
        String? targetCharId;
        for (final s in services) {
          if (s.serviceId == serviceId) {
            // prefer explicit CHAR_UUID if present
            if (s.characteristics.isNotEmpty) {
              final exact = s.characteristics.firstWhere((c) => c.characteristicId == charIdConst, orElse: () => s.characteristics.last);
              targetCharId = exact.characteristicId.toString();
              break;
            }
          }
        }
        // fallback to constant char id
        if (targetCharId == null) {
          targetCharId = CHAR_UUID;
        }

        final characteristic = QualifiedCharacteristic(
          serviceId: serviceId,
          characteristicId: Uuid.parse(targetCharId),
          deviceId: deviceId,
        );

        setState(() => status = '쓰기중...');
        // Try write with response first
        try {
          await flutterReactiveBle.writeCharacteristicWithResponse(characteristic, value: data);
          // success
          await Future.delayed(const Duration(milliseconds: 500));
          await connSub?.cancel();
          return true;
        } catch (e) {
          // try without response
          try {
            await flutterReactiveBle.writeCharacteristicWithoutResponse(characteristic, value: data);
            await Future.delayed(const Duration(milliseconds: 500));
            await connSub?.cancel();
            return true;
          } catch (e2) {
            // both failed - throw to outer retry logic
            throw Exception('Write failed (withResponse: $e, withoutResponse: $e2)');
          }
        }
      } catch (e) {
        setState(() => status = '스위쳐 연결 실패. 다시 시도 남은 횟수 ${retries - i - 1} - 에러: $e');
        try {
          await connSub?.cancel();
        } catch (_) {}
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }
    }
    // final failure
    setState(() => status = '스위쳐 통신 실패..');
    return false;
  }

  void _showAlert(String msg) {
    showDialog<void>(context: context, builder: (c) => AlertDialog(title: const Text('실패'), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK'))]));
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _macController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('I/O 스위처 로컬'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // MAC 주소 설정 카드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('기기 설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _macController,
                  decoration: const InputDecoration(
                    labelText: 'MAC 주소',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.bluetooth),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text('저장'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _scanning ? null : _findDevices,
                      icon: _scanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search),
                      label: const Text('찾기'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // 옵션 설정 카드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('옵션', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Row(children: [
                    const Icon(Icons.electrical_services, size: 20),
                    const SizedBox(width: 8),
                    const Text('스위치 개수'),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: deviceType,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1구')),
                        DropdownMenuItem(value: 2, child: Text('2구')),
                      ],
                      onChanged: (v) async {
                        if (v != null) setState(() => deviceType = v);
                        await _saveSettings();
                      },
                    ),
                  ]),
                  Row(children: [
                    const Text('ON/OFF 반전'),
                    Switch(
                      value: invert,
                      onChanged: (v) async {
                        setState(() => invert = v);
                        await _saveSettings();
                      },
                    ),
                  ]),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // 제어 버튼 카드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('스위치 제어', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                // 스위치1 버튼
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _buttonsEnabled ? () => _onAction(1, 'on') : null,
                      icon: const Icon(Icons.power_settings_new),
                      label: const Text('스위치1 ON'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 50),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _buttonsEnabled ? () => _onAction(1, 'off') : null,
                      icon: const Icon(Icons.power_off),
                      label: const Text('스위치1 OFF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 50),
                      ),
                    ),
                  ),
                ]),
                // 스위치2 버튼 (2구일 때만)
                if (deviceType == 2) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _buttonsEnabled ? () => _onAction(2, 'on') : null,
                        icon: const Icon(Icons.power_settings_new),
                        label: const Text('스위치2 ON'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 50),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _buttonsEnabled ? () => _onAction(2, 'off') : null,
                        icon: const Icon(Icons.power_off),
                        label: const Text('스위치2 OFF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 50),
                        ),
                      ),
                    ),
                  ]),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // 상태 표시 카드
          Card(
            color: status.contains('실패') || status.contains('에러') ? Colors.red[50] : status.contains('성공') ? Colors.green[50] : Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(children: [
                Icon(
                  status.contains('실패') || status.contains('에러') ? Icons.error_outline : status.contains('성공') ? Icons.check_circle_outline : Icons.info_outline,
                  color: status.contains('실패') || status.contains('에러') ? Colors.red : status.contains('성공') ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status.isEmpty ? '대기 중...' : status,
                    style: TextStyle(
                      fontSize: 14,
                      color: status.contains('실패') || status.contains('에러') ? Colors.red[900] : status.contains('성공') ? Colors.green[900] : Colors.blue[900],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
