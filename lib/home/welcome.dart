import 'dart:convert';

import 'package:example/common/header.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class Welcome extends StatefulWidget {
  const Welcome({super.key});

  @override
  State<StatefulWidget> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  bool _loading = false;
  Position? _location;

  @override
  void initState() {
    super.initState();
    _loading = true;
    _getLocation().then((position) {
      debugPrint('Location: $position');
      setState(() {
        _location = position;
        _loading = false;
      });
    });
  }

  Future<Position> _getLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is permanently denied');
    }
    return await GeolocatorPlatform.instance.getCurrentPosition();
  }

  Future<List<dynamic>> _getTimeseries(String latitude, String longitude) async {
    final response = await http.get(
      Uri.https('api.met.no', 'weatherapi/locationforecast/2.0/compact', {'lat': latitude, 'lon': longitude}),
      headers: {'User-Agent': 'MyApp/1.0 (ylari.ainjarv@gmail.com)'},
    );
    if (response.statusCode != 200) {
      throw Exception("HTTP error ${response.statusCode}");
    }
    final data = jsonDecode(response.body);
    debugPrint('Data: $data');
    return data["properties"]["timeseries"];
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Scaffold(
            appBar: Header(title: 'Weather Forecast'),
            body: FutureBuilder(
              future: _getTimeseries(_location!.latitude.toString(), _location!.longitude.toString()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final items = snapshot.data as List<dynamic>;
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final time = DateFormat('dd.MM.yyyy HH:mm:ss').format(DateTime.parse(item['time']).toLocal());
                    final details = item['data']['instant']['details'];
                    final temperature = details['air_temperature'];
                    final humidity = details['relative_humidity'];
                    final pressure = details['air_pressure_at_sea_level'];
                    final wind = details['wind_speed'];
                    String next = '';
                    if (item['data']['next_1_hours'] != null) {
                      next = item['data']['next_1_hours']['summary']['symbol_code'] ?? '';
                    }
                    return ListTile(
                      leading: Text('${index + 1}'),
                      title: Text(time, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Temperature: $temperature °C\n'
                        'Humidity: $humidity %\n'
                        'Pressure: $pressure hPa\n'
                        'Wind speed: $wind m/s\n',
                      ),
                      trailing: next != '' ? Image.asset('assets/symbols/$next.png') : null,
                    );
                  },
                );
              },
            ),
          );
  }
}
