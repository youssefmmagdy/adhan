import 'dart:async';
import 'dart:convert';

import 'package:adhan/loc.dart';
import 'package:adhan/date_picker.dart';
import 'package:adhan/main_drawer.dart';
import 'package:adhan/place.dart';
import 'package:adhan/prayer_times_card.dart';
import 'package:adhan/screens/compass.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
Future<void> requestAndroidPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();
  final String timeZoneName = tz.local.name;
  tz.setLocalLocation(tz.getLocation(timeZoneName));

  const InitializationSettings initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'));

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: onTap,
    onDidReceiveBackgroundNotificationResponse: onTap,
  );

  requestAndroidPermission();

  runApp(const MyApp());
}

final StreamController<NotificationResponse> streamController =
    StreamController();
onTap(NotificationResponse notificationResponse) {
  // log(notificationResponse.id!.toString());
  // log(notificationResponse.payload!.toString());
  streamController.add(notificationResponse);
  // Navigator.push(context, route);
}

void showSchduledNotification(int id, String time) async {
  const AndroidNotificationDetails android = AndroidNotificationDetails(
    'schduled notification',
    'id 3',
    importance: Importance.max,
    priority: Priority.high,
    sound: RawResourceAndroidNotificationSound("azan"),
  );
  NotificationDetails details = const NotificationDetails(
    android: android,
  );
  tz.initializeTimeZones();

  final String currentTimeZone = await FlutterTimezone.getLocalTimezone();

  tz.setLocalLocation(tz.getLocation(currentTimeZone));

  final List<String> timeParts = time.split(':');
  final int hour = int.parse(timeParts[0]);
  final int minute = int.parse(timeParts[1]);

  // Get the current date and create a TZDateTime object
  final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
  tz.TZDateTime scheduledTime =
      tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

  // If the scheduled time is in the past, adjust to the next day
  if (scheduledTime.isBefore(now)) {
    scheduledTime = scheduledTime.add(const Duration(days: 1));
  }
  print("Scheduled is: $scheduledTime");
  await flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    'Schduled Notification',
    'body',
    scheduledTime,
    details,
    payload: 'zonedSchedule',
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _fajr;
  String? _zuhr;
  String? _asr;
  String? _maghrib;
  String? _ishaa;
  String? _shurouq;
  String? _address;
  String? _today;
  String? _hijriDate;
  String? _todayDate;
  DateTime _selectedDate = DateTime.now();

  var _navIndex = 0;
  var _currentScreen = "Prayer Times";
  PlaceLocation? _pickedLocation;
  var _isGettingLocation = false;

  @override
  void initState() {
    super.initState();

    _getCurrentLocation();
  }

  void setDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  String format(String address) {
    var res = "";
    for (var i = address.length - 1; i >= 0; i--) {
      if (address[i] == ',' && !RegExp(r'\d').hasMatch(address[i])) {
        res = address[i] + res;
        i--;
        while (i >= 0 && address[i] != ",") {
          if (!RegExp(r'\d').hasMatch(address[i])) {
            res = address[i] + res;
          }
          i--;
        }
        break;
      } else if (!RegExp(r'\d').hasMatch(address[i])) {
        res = address[i] + res;
      }
    }

    return res;
  }

  void _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    NumberGenerator numberGenerator = NumberGenerator();
    List<double?>? location = await numberGenerator.generateNumbers();
    if (location == null) {
      return;
    }
    final lat = location[0], lng = location[1];

    if (lat == null || lng == null) {
      return;
    }

    final url1 = Uri.parse(
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=AIzaSyDZiJXE4QVbPwqLJG3DuqEafGuEsbzcGco");
    final response1 = await http.get(url1);
    final responseData1 = json.decode(response1.body);
    setState(() {
      _address = responseData1['results'][0]['formatted_address'];
      _address = format(_address!);
    });

    final selectedDate = _selectedDate.add(const Duration(days: 0));

    String day = _selectedDate.day.toString(),
        month = _selectedDate.month.toString(),
        year = _selectedDate.year.toString();
    if (day.length == 1) day = "0$day";
    if (month.length == 1) month = "0$month";

    final url = Uri.parse(
        "https://api.aladhan.com/v1/timings/$day-$month-$year?latitude=$lat&longitude=$lng&method=5");
    final response = await http.get(url);
    final responseData = json.decode(response.body);

    final fajr = responseData['data']["timings"]['Fajr'];
    final zuhr = responseData['data']["timings"]['Dhuhr'];
    final asr = responseData['data']["timings"]['Asr'];
    final maghrib = responseData['data']["timings"]['Maghrib'];
    final ishaa = responseData['data']["timings"]['Isha'];
    final shurouq = responseData['data']["timings"]['Sunrise'];
    final hijriDate = responseData['data']["date"]["hijri"]["day"] +
        " " +
        responseData['data']["date"]["hijri"]["month"]["en"] +
        " " +
        responseData['data']["date"]["hijri"]["year"];
    final todayDate = responseData['data']["date"]["readable"];
    final today = responseData['data']["date"]["gregorian"]["weekday"]["en"];
    final pickedLocation = PlaceLocation(
      latitude: lat,
      longitude: lng,
    );

    setState(() {
      _selectedDate = selectedDate;
      _fajr = fajr;
      _zuhr = zuhr;
      _asr = asr;
      _maghrib = maghrib;
      _ishaa = ishaa;
      _shurouq = shurouq;
      _hijriDate = hijriDate;
      _todayDate = todayDate;
      _today = today;
      _pickedLocation = pickedLocation;
      _isGettingLocation = false;
    });
    _fajr = "23:49";
    _zuhr = "23:50";
    // _asr = "16:24";
    // _maghrib = "16:25";
    // _ishaa = "16:26";

    showSchduledNotification(1, _fajr!);

    showSchduledNotification(2, _zuhr!);
    showSchduledNotification(3, _asr!);
    showSchduledNotification(4, _maghrib!);
    showSchduledNotification(5, _ishaa!);
  }

  static AudioPlayer audioPlayer = AudioPlayer();
  static void playAudio() async {
    audioPlayer.stop();
    String audioPath = '../assets/azan.mp3';
    await audioPlayer.play(AssetSource(audioPath));
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  int hourOf(String time) {
    var res = "";
    for (var i = 0; i < time.length; i++) {
      if (time[i] == ':') {
        break;
      } else {
        res += time[i];
      }
    }

    return int.parse(res);
  }

  int minuteOf(String time) {
    var res = "";
    for (var i = time.length - 1; i >= 0; i--) {
      if (time[i] == ':') {
        break;
      } else {
        res = time[i] + res;
      }
    }

    return int.parse(res);
  }

  void setScreen(int x) {
    setState(() {
      _navIndex = x;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content = const Text("");

    if (_isGettingLocation) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_pickedLocation != null) {
      DateTime now = DateTime.now();

      if (_navIndex == 0) {
        _currentScreen = "Prayer Times";
        content = Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // ElevatedButton(
            //   onPressed: () {
            //     _getCurrentLocation();
            //   },
            //   child: const Text("Update Prayer Timings"),
            // ),

            Container(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.location_on_sharp),
                        Text(
                          _address!,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ]),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Card(
                        elevation: 5,
                        color: Colors.white.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Text(_today!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  )),
                              Text(
                                _hijriDate!,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _todayDate!,
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DatePicker(
                        setDate: setDate,
                        getLocation: _getCurrentLocation,
                        selectedDate: _selectedDate,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            PrayerTimesCard(
              prayerTimes: {
                'Fajr': _fajr!,
                "Shurouq": _shurouq!,
                'Dhuhr': _zuhr!,
                'Asr': _asr!,
                'Maghrib': _maghrib!,
                'Ishaa': _ishaa!,
              },
            ),
            const SizedBox(
              height: 20,
            ),
          ]),
        );
      } else if (_navIndex == 1) {
        _currentScreen = "Qibla";
        content = Compass(
          lat: _pickedLocation!.latitude,
          lng: _pickedLocation!.longitude,
        );
      }
    }

    return MaterialApp(
      title: 'Azan',
      home: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.webp'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Scaffold(
            drawer: _pickedLocation != null
                ? MainDrawer(
                    lat: _pickedLocation!.latitude,
                    lng: _pickedLocation!.longitude,
                    setIndex: setScreen,
                  )
                : null,
            backgroundColor:
                Colors.transparent, // Make the scaffold transparent
            appBar: AppBar(
                title: Text(_currentScreen),
                backgroundColor:
                    Colors.transparent, // Make the app bar transparent
                elevation: 0),
            // drawer: Drawer(),
            body: Container(
              child: content,
            ),
            floatingActionButton: _navIndex == 0
                ? FloatingActionButton(
                    onPressed: _getCurrentLocation,
                    backgroundColor: Colors.white,
                    child: const Icon(
                      Icons.update,
                      color: Colors.black,
                    ),
                  )
                : null,
            bottomNavigationBar: BottomNavigationBar(
              selectedItemColor: Colors.white,
              backgroundColor: Colors.black.withOpacity(0.3),
              onTap: (index) {
                setState(() {
                  if (!_isGettingLocation) _navIndex = index;
                });
              },
              currentIndex: _navIndex,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.timer,
                    size: 25,
                  ),
                  label: 'Prayer Times',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.explore,
                    size: 25,
                  ),
                  label: 'Qibla',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
