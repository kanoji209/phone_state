import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'dart:async';
import 'package:flutter_network_connectivity/flutter_network_connectivity.dart';
import 'package:battery_plus/battery_plus.dart';

enum BatteryState {
  // The battery is completely full of energy.
  full,

  // The battery is currently storing energy.
  charging,

  // The battery is currently losing energy.
  discharging,

  // The state of the battery is unknown.
  unknown
}

void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Phone State')),
        body: const DataDisplayScreen(),
      ),
    );
  }
}

class DataDisplayScreen extends StatefulWidget {
  const DataDisplayScreen({super.key});

  @override
  _DataDisplayScreenState createState() => _DataDisplayScreenState();
}

class _DataDisplayScreenState extends State<DataDisplayScreen> {
  final FlutterNetworkConnectivity _flutterNetworkConnectivity =
      FlutterNetworkConnectivity(
    isContinousLookUp: true,
    lookUpDuration: const Duration(seconds: 5),
    lookUpUrl: 'example.com',
  );

  int _captureCount = 0;
  int _frequency = 1;
  String _location = 'Unknown';
  String _currentDateTime =
      DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());
  Location location = Location();
  var battery = Battery();
  int percentage = 0;
  late Timer timer;

  BatteryState batteryState = BatteryState.full;
  late StreamSubscription streamSubscription;

  bool? _isInternetAvailableStreamStatus;

  StreamSubscription<bool>? _networkConnectionStream;

  Timer? _timer;
  Timer? _timeUpdater; // Timer for time update every second

  void _startTimer() {
    _timer = Timer.periodic(Duration(minutes: _frequency), (timer) {
      setState(() {
        _captureCount++;
      });
    });

    _timeUpdater = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentDateTime =
            DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());
      });
    });
  }

  // Function to handle modifying frequency
  void _modifyFrequency() {
    // Set the frequency to 1 minute for auto refresh
    setState(() {
      _frequency = 1;
    });

    // Restart the timer with the updated frequency
    _timer?.cancel();
    _timeUpdater?.cancel();
    _startTimer();
  }

  // Function to fetch location
  Future<void> _fetchLocation() async {
    try {
      LocationData locationData = await location.getLocation();
      setState(() {
        _location =
            'Lat: ${locationData.latitude}, Long: ${locationData.longitude}';
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
      setState(() {
        _location = 'Unable to fetch location';
      });
    }
  }

  // Function to manually refresh data
  void _refreshData() {
    setState(() {
      _captureCount++;
      _currentDateTime =
          DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.now());
      _fetchLocation();
    });
  }

  @override
  void initState() {
    super.initState();
    // Fetch location initially
    _fetchLocation();
    // Call the _modifyFrequency function to set auto refresh to 1 minute
    _modifyFrequency();
    getBatteryState();
    getBatteryPerentage();
    Timer.periodic(const Duration(seconds: 5), (timer) {
      getBatteryPerentage();
      getBatteryState();
    });

    _flutterNetworkConnectivity.getInternetAvailabilityStream().listen((event) {
      _isInternetAvailableStreamStatus = event;
      setState(() {});
    });
  }

  void getBatteryPerentage() async {
    final level = await battery.batteryLevel;
    percentage = level;

    setState(() {});
  }

  void getBatteryState() {
    streamSubscription = battery.onBatteryStateChanged.listen((state) {
      batteryState = state as BatteryState;

      setState(() {});
    });
  }

  @override
  void dispose() {
    // Cancel the timers when the widget is disposed
    _timer?.cancel();
    _timeUpdater?.cancel();
    _networkConnectionStream?.cancel();
    _flutterNetworkConnectivity.unregisterAvailabilityListener();

    super.dispose();
  }

  void init() async {
    await _flutterNetworkConnectivity.registerAvailabilityListener();
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Timestamp: $_currentDateTime'),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Capture Count: $_captureCount'),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: _modifyFrequency,
            child: Text('Frequency (min): $_frequency'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            null == _isInternetAvailableStreamStatus
                ? 'Unknown State'
                : _isInternetAvailableStreamStatus!
                    ? "Connectivity: On"
                    : "Connectivity: Off",
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('Battery Charging: Discharging'),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Battery Percentage: $percentage %'),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Location: $_location'),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: () {
              _refreshData(); // Refresh data on button press
            },
            child: const Text('Manual Data Refresh'),
          ),
        ),
      ],
    );
  }
}
