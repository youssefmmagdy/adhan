import 'dart:async';
import 'dart:io';

import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter_compass/flutter_compass.dart';

import "package:path/path.dart" as path;
import "package:sqflite/sqflite.dart" as sql;
import "package:sqflite/sqlite_api.dart";
import 'package:adhan/loc.dart';
import 'package:adhan/date_picker.dart';
import 'package:adhan/main_drawer.dart';
import 'package:adhan/place.dart';
import 'package:adhan/prayer_times_card.dart';

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

String getNextPrayer(
    String fajr, String dhuhr, String asr, String maghrib, String isha) {
  final now = DateTime.now();
  now.add(const Duration(hours: 3));
  int min = 9999999;
  String next = "";
  Map<String, String> prayerTimes = {
    "Fajr": fajr,
    "Dhuhr": dhuhr,
    "Asr": asr,
    "Maghrib": maghrib,
    "Isha": isha,
  };

  prayerTimes.entries.map((entry) {
    final time = entry.value.split(':');
    final hours = int.parse(time[0]);
    final minutes = int.parse(time[1]);

    if (min > ((hours - now.hour) * 60 + (minutes - now.minute)) &&
        ((hours - now.hour) > 0 ||
            ((hours == now.hour) && (minutes - now.minute) > 0))) {
      min = (hours - now.hour) * 60 + (minutes - now.minute);
      next = entry.key;
    }
  }).toList();

  return next;
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

void cancelNotification(int id) async {
  await flutterLocalNotificationsPlugin.cancel(id);
}

void showSchduledNotification(int id, DateTime dateTime) async {
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

  // Get the current date and create a TZDateTime object
  final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
  tz.TZDateTime scheduledTime = tz.TZDateTime(tz.local, dateTime.year,
      dateTime.month, dateTime.day, dateTime.hour, dateTime.minute);

  // If the scheduled time is in the past, adjust to the next day
  if (scheduledTime.isBefore(now)) {
    scheduledTime = scheduledTime.add(const Duration(days: 1));
  }
  
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
  String? _dhuhr;
  String? _asr;
  String? _maghrib;
  String? _isha;
  String? _sunrise;
  String? _address;
  String? _today;
  String? _hijriDate;
  String? _todayDate;
  DateTime _selectedDate = DateTime.now();
  String? _nextPrayer;
  Duration? d1, d2;
  List<Map<String, String>> maps = [];
  String? _wierdDate;
  var _navIndex = 0;
  var _currentScreen = "Prayer Times";
  PlaceLocation? _pickedLocation;
  var _isGettingLocation = false;
  double? _dir;
  double? _heading = 0;

  @override
  void initState() {
    super.initState();
    FlutterCompass.events?.listen((event) {
      setState(() {
        _heading = event.heading;
      });
    });
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

  Future<Database> _getDatabase() async {
    final dbPath = await sql.getDatabasesPath();
    final db = await sql.openDatabase(
      path.join(dbPath, "prayers.db"),
      onCreate: (db, version) {
        return db.execute(
            "CREATE TABLE prayer_maps(id TEXT PRIMARY KEY, fajr TEXT, dhuhr TEXT, asr TEXT, maghrib TEXT, isha TEXT, sunrise TEXT, hijriDate TEXT, todayDate TEXT, today TEXT, lat REAL, lng REAL, wierdDate TEXT, address TEXT, compass REAL)");
      },
      version: 2,
    );
    return db;
  }

  String? _error;
  void _getCompass(double lat, double lng, bool isThereData) async {
    final url = Uri.parse("http://api.aladhan.com/v1/qibla/$lat/$lng");
    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        _error = "";
        loadPrayerTimes();
        return;
      }

      final responseData = json.decode(response.body);
      setState(() {
        _dir = responseData["data"]["direction"];
      });
    } on SocketException {
      // Handle network error
      
      setState(() {
        _error = 'No internet connection... Please open Internet Connection';
        _isGettingLocation = false;
        errors.add(Text(_error!));
        if (!isThereData) {
          _content = Center(
            child: Text(_error!),
          );
        }
      });
      loadPrayerTimes();
      return;
    } catch (e) {
      // Handle other types of exceptions
      
      setState(() {
        _error = 'An error occurred: $e';
        errors.add(Text(_error!));
        if (!isThereData) {
          _content = Center(
            child: Text(_error!),
          );
        }
      });
    }
  }

  void _getCurrentLocation() async {
    
    setState(() {
      _isGettingLocation = true;
    });
    final db = await _getDatabase();
    final tempMaps = await db.query("prayer_maps");
    
    List<double?>? location;
    try {
      NumberGenerator numberGenerator = NumberGenerator();
      location = await numberGenerator.generateNumbers();
    } catch (e) {}

    if (location == null) {
      if (tempMaps.isEmpty) {
        setState(() {
          _isGettingLocation = false;
          _error = "Please activate your Location";
          _content = const Center(child: Text("Please activate your Location"));
        });
        return;
      }
      _error = "Please activate your Location";
      errors.add(Text("Please activate your Location"));
      _isGettingLocation = false;
      loadPrayerTimes();
      return;
    }
    final lat = location[0], lng = location[1];

    if (lat == null || lng == null) {
      if (tempMaps.isEmpty) {
        setState(() {
          _isGettingLocation = false;
          _error = "Please activate your Location";
          _content = const Center(child: Text("Please activate your Location"));
        });
        return;
      }
      _error = "Please activate your Location";
      errors.add(Text("Please activate your Location"));
      loadPrayerTimes();
      return;
    }

    _getCompass(lat, lng, tempMaps.isNotEmpty);

    final url1 = Uri.parse(
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=AIzaSyDZiJXE4QVbPwqLJG3DuqEafGuEsbzcGco");
    try {
      final response1 = await http.get(url1);
      if (response1.statusCode != 200) {
        
        _error = "";
        loadPrayerTimes();
        return;
      }
      
      final responseData1 = json.decode(response1.body);
      setState(() {
        _address = responseData1['results'][0]['formatted_address'];
        _address = format(_address!);
      });
    } on SocketException {
      _error = "No internet connection... Please open Internet Connection";
      errors.add(Text(_error!));
      if (tempMaps.isEmpty) {
        _content = Center(
          child: Text(_error!),
        );
      }
      return;
    } catch (e) {
      _error = "Please open Internet Connection";
      errors.add(Text(_error!));
      if (tempMaps.isEmpty) {
        _content = Center(
          child: Text(_error!),
        );
      }
    }
    var y = 1;
    for (var i = 0; i < 30; i++) {
      
      cancelNotification(y);
      cancelNotification(y + 1);
      cancelNotification(y + 2);
      cancelNotification(y + 3);
      cancelNotification(y + 4);
      y += 5;
    }

    await db.delete("prayer_maps");
    maps.clear();
    var x = 1;
    for (var i = 0; i < 30; i++) {
      final selectedDate = _selectedDate.add(Duration(days: i));
      String day = selectedDate.day.toString(),
          month = selectedDate.month.toString(),
          year = selectedDate.year.toString();
      if (day.length == 1) day = "0$day";
      if (month.length == 1) month = "0$month";
      final http.Response response;
      try {
        final url = Uri.parse(
            "https://api.aladhan.com/v1/timings/$day-$month-$year?latitude=$lat&longitude=$lng&method=5");
        response = await http.get(url);
      } on SocketException {
        // Handle network error
        
        setState(() {
          _error = 'No internet connection... Please open Internet Connection';
          _isGettingLocation = false;
          errors.add(Text(_error!));
          if (tempMaps.isEmpty) {
            _content = Center(
              child: Text(_error!),
            );
          }
        });
        return;
      } catch (e) {
        // Handle other types of exceptions
        
        setState(() {
          _error = 'An error occurred: $e';
          _content = Center(child: Text(_error!));
        });
        return;
      }
      final responseData = json.decode(response.body);
      final fajr = responseData['data']["timings"]['Fajr'];
      final dhuhr = responseData['data']["timings"]['Dhuhr'];
      final asr = responseData['data']["timings"]['Asr'];
      final maghrib = responseData['data']["timings"]['Maghrib'];
      final isha = responseData['data']["timings"]['Isha'];
      final sunrise = responseData['data']["timings"]['Sunrise'];
      final hijriDate = responseData['data']["date"]["hijri"]["day"] +
          " " +
          responseData['data']["date"]["hijri"]["month"]["en"] +
          " " +
          responseData['data']["date"]["hijri"]["year"];
      final todayDate = responseData['data']["date"]["gregorian"]["date"];
      final today = responseData['data']["date"]["gregorian"]["weekday"]["en"];
      final wierdDate = responseData['data']["date"]["readable"];

      Map<String, String> map = {
        "Fajr": fajr,
        "Dhuhr": dhuhr,
        "Asr": asr,
        "Maghrib": maghrib,
        "Isha": isha,
        "Sunrise": sunrise,
        "HijriDate": hijriDate,
        "TodayDate": todayDate,
        "Today": today,
        "Lat": lat.toString(),
        "Lng": lng.toString(),
        "WierdDate": wierdDate,
      };

      db.insert("prayer_maps", {
        "id": i,
        "fajr": fajr,
        "dhuhr": dhuhr,
        "asr": asr,
        "maghrib": maghrib,
        "isha": isha,
        "sunrise": sunrise,
        "hijriDate": hijriDate,
        "todayDate": todayDate.toString(),
        "today": today,
        "lat": lat.toString(),
        "lng": lng.toString(),
        "wierdDate": wierdDate,
        "address": _address,
        "compass": _dir.toString(),
      });

      maps.add(map);

      DateTime now = DateTime.now();

      String time = fajr;
      List<String> timeParts = time.split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);

      showSchduledNotification(
          x,
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day,
              hour, minute));
      time = dhuhr;
      timeParts = time.split(':');
      hour = int.parse(timeParts[0]);
      minute = int.parse(timeParts[1]);
      showSchduledNotification(
          x + 1,
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day,
              hour, minute));
      time = asr;
      timeParts = time.split(':');
      hour = int.parse(timeParts[0]);
      minute = int.parse(timeParts[1]);
      showSchduledNotification(
          x + 2,
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day,
              hour, minute));
      time = maghrib;
      timeParts = time.split(':');
      hour = int.parse(timeParts[0]);
      minute = int.parse(timeParts[1]);
      showSchduledNotification(
          x + 3,
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day,
              hour, minute));
      time = isha;
      timeParts = time.split(':');
      hour = int.parse(timeParts[0]);
      minute = int.parse(timeParts[1]);
      showSchduledNotification(
          x + 4,
          DateTime(selectedDate.year, selectedDate.month, selectedDate.day,
              hour, minute));
      x += 5;
      if (i == 0) {
        loadPrayerTimes();
      }
    }
  }

  Widget? _content;
  void loadPrayerTimes() async {
    String day = _selectedDate.day.toString(),
        month = _selectedDate.month.toString();
    if (day.length == 1) day = "0$day";
    if (month.length == 1) month = "0$month";
    final db = await _getDatabase();
    final tmp = await db.query("prayer_maps");
    if (tmp.isEmpty) {
      setState(() {
        _isGettingLocation = false;
        _content = const Center(child: Text("Please open Internet Connection"));
      });
      return;
    }
    
    final maps1 = await db.query(
      "prayer_maps",
      where: "todayDate = ?",
      whereArgs: ["$day-$month-${_selectedDate.year}"],
    );

    String date = maps1[0]["todayDate"].toString();
    int year1 = DateTime.now().year,
        month1 = DateTime.now().month,
        day1 = DateTime.now().day;
    String s = "";
    int j = 0;
    for (int i = 0; i < date.length; i++) {
      if (date[i] == "-" && j == 0) {
        day1 = int.parse(s);
        s = "";
        j = 1;
      } else if (date[i] == "-" && j == 1) {
        month1 = int.parse(s);
        s = "";
        j = 2;
      } else {
        s += date[i];
      }
    }
    year1 = int.parse(s);
    setState(() {
      _selectedDate = DateTime(
        year1,
        month1,
        day1,
      );
      _fajr = maps1[0]["fajr"].toString();
      _dhuhr = maps1[0]["dhuhr"].toString();
      _asr = maps1[0]["asr"].toString();
      _maghrib = maps1[0]["maghrib"].toString();
      _isha = maps1[0]["isha"].toString();
      _sunrise = maps1[0]["sunrise"].toString();
      _hijriDate = maps1[0]["hijriDate"].toString();
      _todayDate = maps1[0]["todayDate"].toString();
      _today = maps1[0]["today"].toString();

      _pickedLocation = PlaceLocation(
        latitude: double.parse(maps1[0]["lat"].toString()),
        longitude: double.parse(maps1[0]["lng"].toString()),
      );
      _wierdDate = maps1[0]["wierdDate"].toString();
      _nextPrayer = getNextPrayer(_fajr!, _dhuhr!, _asr!, _maghrib!, _isha!);
      _nextPrayer ??= "Fajr";
      _address = maps1[0]["address"].toString();
      _dir = double.parse(maps1[0]["compass"].toString());
      _isGettingLocation = false;
    });
  }

  void seeIfTableEmpty() async {
    final db = await _getDatabase();
    // db.delete("prayer_maps");

    final data = await db.query("prayer_maps");

    if (data.isEmpty) {
      
      _getCurrentLocation();
    } else {
      loadPrayerTimes();
    }
  }

  List<Widget> errors = [];
  @override
  Widget build(BuildContext context) {
    
    if (_isGettingLocation) {
      _content = const Center(child: CircularProgressIndicator());
    } else if (_pickedLocation != null) {
      if (_navIndex == 0) {
        _currentScreen = "Prayer Times";
        _content = Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
                                _wierdDate!,
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
                "Sunrise": _sunrise!,
                'Dhuhr': _dhuhr!,
                'Asr': _asr!,
                'Maghrib': _maghrib!,
                'Isha': _isha!,
              },
              nextPrayer: _nextPrayer!,
            ),
            const SizedBox(
              height: 20,
            ),
          ]),
        );
      } else if (_navIndex == 1) {
        _currentScreen = "Qibla";
        _content = Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Center(
              child: _heading == null
                  ? const Text('Compass is not available')
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.rotate(
                          angle: (_dir ?? 0) -
                              _heading! * (math.pi / 180) +
                              math.pi,
                          child: Image.asset(
                            'assets/com1.png',
                          ),
                        ),
                        const SizedBox(height: 20),
                        Column(
                          children: [
                            const Text(
                              'Your Direction',
                              style: TextStyle(fontSize: 20),
                            ),
                            Text(
                              _heading == null
                                  ? 'Calculating...'
                                  : '${(_heading! + math.pi).toStringAsFixed(2)}°',
                              style: const TextStyle(fontSize: 20),
                            ),
                            const Text(
                              'Qibla Direction',
                              style: TextStyle(fontSize: 20),
                            ),
                            Text(
                              _dir == null
                                  ? 'Calculating...'
                                  : '${_dir!.toStringAsFixed(2)}°',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        );
      }
    } else if (!_isGettingLocation && (_content == null)) {
      seeIfTableEmpty();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove the debug banner

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
                    setIndex: (index) {
                      setState(() {
                        _navIndex = index;
                      });
                    },
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
              child: _content,
            ),
            floatingActionButton: _navIndex == 0
                ? FloatingActionButton(
                    onPressed: () {
                      _selectedDate = DateTime.now();
                      _getCurrentLocation();
                    },
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
