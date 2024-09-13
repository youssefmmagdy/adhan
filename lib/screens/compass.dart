import 'dart:convert';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/material.dart';
import "package:http/http.dart" as http;
import 'dart:math' as math;

class Compass extends StatefulWidget {
  const Compass({super.key, required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  State<Compass> createState() => _CompassState();
}

class _CompassState extends State<Compass> {
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

  void _getCompass() async {
    final url = Uri.parse(
        "http://api.aladhan.com/v1/qibla/${widget.lat}/${widget.lng}");
    final response = await http.get(url);
    final responseData = json.decode(response.body);
    _dir = responseData["data"]["direction"];
  }

  var flag = false;

  @override
  Widget build(BuildContext context) {
    if (!flag) {
      flag = true;
      _getCompass();
    }

    return Scaffold(
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
                      angle:
                          (_dir ?? 0) - _heading! * (math.pi / 180) + math.pi,
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
                          _dir == null ? 'Calculating...' : '${_dir!.toStringAsFixed(2)}°',
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
}
