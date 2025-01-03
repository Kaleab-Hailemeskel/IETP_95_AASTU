import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(debugShowCheckedModeBanner: false, home: MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Bluetooth Connection Variables
  BluetoothConnection? _connection;
  bool _isConnected = false;
  bool isLoading = false;
  final String _esp32ModuleName = "ESP32_LED_Control";

  late StreamSubscription<BluetoothState> _bluetoothStateSubscription;

  @override
  void initState() {
    super.initState();
    _bluetoothStateSubscription = FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bluetooth: $state'),
          duration: const Duration(seconds: 3),
        ),
      );

      if (state == BluetoothState.STATE_OFF) {
        setState(() {
          _isConnected = false;
          _connection = null;
        });
      }
      if (state == BluetoothState.STATE_ON) {
        _connectToDevice();
      }
    });

    requestPermission();
  }

  @override
  void dispose() {
    _bluetoothStateSubscription.cancel();
    _disconnectFromDevice();
    super.dispose();
  }

  List<BluetoothDevice> devices = [];

  Future<void> _connectToDevice() async {
    setState(() {
      isLoading = true;
    });

    try {
      // get all devices in the area
      final List<BluetoothDevice> devices =
          await FlutterBluetoothSerial.instance.getBondedDevices();

      // get the device that has the same name with _esp32ModuleName
      final BluetoothDevice device =
          devices.firstWhere((d) => d.name == _esp32ModuleName);

      // initailaize connection
      final BluetoothConnection connection =
          await BluetoothConnection.toAddress(device.address);

      if (connection.isConnected) {
        setState(
          () {
            _connection = connection;
            _isConnected = true;
            isLoading = false;
          },
        );

        // Listen for disconnection events
        connection.input!.listen(null).onDone(() {
          setState(() {
            _isConnected = false;
            _connection = null;
          });
        });
      }
    } catch (e) {
      // Connection initialization got an error
      setState(() {
        isLoading = false;
        _isConnected = false;
      });
    }
  }

  Future<void> _disconnectFromDevice() async {
    // disconnect the Device manually
    await _connection?.finish();
    setState(
      () {
        _connection = null;
        _isConnected = false;
      },
    );
  }

  final int _minimumSpeedValue = 150;
  Future<void> _sendData(int value) async {
    // start the command by initial command either forward or reverse, it chooses based on the integer direction
    String command = movementDirecitonInteger == 1 ? 'FORWARD' : 'REVERSE';

    // sending data to ESP 32 only when there is a connection
    if (_connection != null) {
      // if the value is either 1 or 2, meainig if the train just start moving assign speed of _minimumSpeedValue
      if (value == 1 || value == 2) {
        command += '$_minimumSpeedValue';
      } // if the value is 3, which is STOP the stop command will be assigned
      else if (value == 3) {
        command = 'STOP';
      } // else the value will be a speed indicator. it will be concatinated after the directoin command
      else {
        command += '$value';
      }
      Uint8List bytes = Uint8List.fromList(utf8.encode('$command\n'));
      _connection!.output.add(bytes);
      await _connection!.output.allSent;
      
    }
  }

  Future<void> requestPermission() async {
    // request permission neede for the device connectiviey
    final blueStatus = await Permission.bluetooth.request();
    final blueScanStatus = await Permission.bluetoothScan.request();
    final blueConntatus = await Permission.bluetoothConnect.request();
    final locationInUseStatus = await Permission.locationWhenInUse.request();
    final locationAlwaysStatus = await Permission.locationAlways.request();

    // check if all permission request are permited,
    if (blueStatus.isGranted &&
            blueScanStatus.isGranted &&
            blueConntatus.isGranted &&
            locationInUseStatus.isGranted ||
        locationAlwaysStatus.isGranted) {
      _connectToDevice();
    }
  }

  // Train Body State Controlling Variables

  bool going = false, intermediate = false;
  Map<String, int> movementDireciton = {'Forward': 1, 'Backward': 2};
  int movementDirecitonInteger = 1;
  String movementDirectionString = 'Forward';
  double _speedValue = 0;
  int _selectedIndexStack = 0;

  // method that will be used to change the index value of bottomNavigationBar
  void _onNavigationTap(int index) {
    setState(
      () {
        _selectedIndexStack = index;
      },
    );
  } // Neccessary

  // this mehtod controlls the movement of the train
  void _powerButton() async {
    // each time the power Button is clicked an itermediate state will be set
    setState(() {
      intermediate = true;
    });

    // check if the train was going and if so until the train stops decrease the
    // speed of the train gradually, not suddenly. with delay of 100 ms

    if (going) {
      while (_speedValue > 0) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() {
          _speedValue -= 10;
          _sendData(_speedValue.toInt());
        });
      }
    }
    // if not set direcion of the train
    else {
      _sendData(movementDirecitonInteger);
    }
    // after slowly setting the movement of the train set intermediate and going values
    await Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        intermediate = false;
        going = !going;
      });
    });
  }

  // speed color for the Slider bar
  Color _getColor(double value) {
    if (value < 25) {
      return Colors.red;
    } else if (value < 50) {
      return Colors.yellow;
    } else if (value < 75) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  // UI building for this weidget will be here
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Suspended Monorail Controller',
          style: TextStyle(color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Colors.grey, Colors.black],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      // Access two screen pages using indexed stack
      body: IndexedStack(
        index: _selectedIndexStack,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  height: 300,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: _getColor(_speedValue),
                              thumbColor: _getColor(_speedValue),
                              overlayColor:
                                  _getColor(_speedValue).withOpacity(0.2),
                            ),
                            child: Slider(
                              value: _speedValue,
                              min: 0,
                              max: 100,
                              divisions: 10,
                              onChanged: (!going || intermediate)
                                  ? null
                                  : (newValue) {
                                      setState(() {
                                        _speedValue = newValue;
                                        _sendData(newValue.toInt());
                                      });
                                    },
                            ),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: intermediate
                                ? Colors.yellow
                                : going
                                    ? Colors.red
                                    : Colors.green,
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(30),
                            fixedSize: const Size(200, 200)),
                        onPressed: intermediate
                            ? () {}
                            : () {
                                _powerButton();
                              },
                        child: intermediate
                            ? Text(
                                going ? 'Stopping...' : 'Going...',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 16),
                              )
                            : Text(
                                going ? 'Stop' : 'Go',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      'Speed: $_speedValue',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      autofocus: false,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      dropdownColor: Colors.white,
                      underline: Container(
                        height: 2,
                        color: Colors.blue,
                      ),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.blue,
                      ),
                      value: movementDirectionString,
                      items: ['Forward', 'Backward'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: going || intermediate
                          ? null
                          : (String? newValue) {
                              setState(() {
                                movementDirectionString = newValue!;
                                movementDirecitonInteger =
                                    movementDireciton[movementDirectionString]!;
                              });
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _isConnected
                        ? ListView.builder(
                            itemCount: devices.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                leading: const Icon(Icons.bluetooth),
                                title: Text(devices[index].name!),
                                onTap: null,
                              );
                            },
                          )
                        : const Text(
                            'No Near By Devices',
                            style: TextStyle(color: Colors.red, fontSize: 25),
                          ),
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        fixedSize: const Size(300, 120)),
                    onPressed: _connectToDevice,
                    child: Text(
                      _isConnected ? 'Reconnect' : 'Connect',
                      style: const TextStyle(
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
      // this navigator used to swap the screen between Driver and Staus
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.control_camera),
            label: 'Driver',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outlined),
            label: 'Status',
          ),
        ],
        currentIndex: _selectedIndexStack,
        selectedItemColor: Colors.blue,
        onTap: _onNavigationTap,
      ),
    );
  }
}
