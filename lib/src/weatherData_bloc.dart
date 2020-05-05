import 'dart:async';
import 'package:geocoder/geocoder.dart';
import 'package:rxdart/rxdart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soleil_app/src/data/dataType.dart';
import 'package:soleil_app/src/data/hourlyTimeSeries.dart';
import 'package:soleil_app/src/data/dailyTimeSeries.dart';
import 'package:soleil_app/src/apiKeys.dart';
import 'package:soleil_app/src/exceptions.dart';
import 'package:soleil_app/src/utilities.dart';

class WeatherDataBloc {
  final _hourlyTimeSeriesListSubject =
      BehaviorSubject<List<HourlyTimeSeries>>();
  final _dailyTimeSeriesListSubject = BehaviorSubject<List<DailyTimeSeries>>();
  final _coordinatesController = StreamController<Coordinates>();

  Stream<List<HourlyTimeSeries>> get hourlyTimeSeriesList =>
      _hourlyTimeSeriesListSubject.stream;
  Stream<List<DailyTimeSeries>> get dailyTimeSeriesList =>
      _dailyTimeSeriesListSubject.stream;
  Sink<Coordinates> get coordinates => _coordinatesController.sink;

  // API keys and URL
  static Map<String, String> _credentials;

  WeatherDataBloc() {
    // Load API keys from secret json file that isn't included in version control
    loadAPIKeys().then((credentials) {
      _credentials = Map.from(credentials['http-request-headers']);
    });

    // Get default coordinates from shared preferences on disk
    SharedPreferences.getInstance().then((prefs) {
      if (prefs.getBool('default_coords_set') ?? false) {
        coordinates.add(Coordinates(
            prefs.getDouble('default_lat'), prefs.getDouble('default_long')));
      }
    });
    // Listen to a change to the requested coordinates and execute
    _coordinatesController.stream.listen((coordinates) async {
      _updateWeatherData(DataType.DAILY, coordinates);
      _updateWeatherData(DataType.HOURLY, coordinates);
    });
  }

  Future<void> _updateWeatherData(
      DataType type, Coordinates coordinates) async {
    // API http request url.
    final _url =
        '${getBaseUrl(type)}latitude=${coordinates.latitude}&longitude=${coordinates.longitude}';
    final res = await http.get(_url, headers: _credentials);
    if (res.statusCode == 200) {
      // Get list of hourly data as geojson.
      final timeSeriesList = await parseMetOfficeData(res.body);
      if (timeSeriesList.isNotEmpty) {
        // Deserialise the data into xTimeSeries objects and add to BehaviourSubject.
        switch (type) {
          case DataType.DAILY:
            _dailyTimeSeriesListSubject
                .add(deserializeDailyData(timeSeriesList));
            break;
          case DataType.HOURLY:
            _hourlyTimeSeriesListSubject
                .add(deserializeHourlyData(timeSeriesList));
            break;
          default:
            throw MetOfficeApiError(
                'Invalid DataType ($type) when updating weather data.');
        }
      }
    } else {
      throw MetOfficeApiError('HTTP GET request error: ${res.body}');
    }
  }

  Future<void> saveDefaultLocation(Coordinates coordinates) async {
    // Load shared preferences from disk.
    final perfs = await SharedPreferences.getInstance();
    perfs.setDouble('default_lat', coordinates.latitude);
    perfs.setDouble('default_long', coordinates.longitude);
    perfs.setBool('default_coords_set', true);
    this.coordinates.add(coordinates);
  }

  void close() {
    _coordinatesController.close();
  }
}
