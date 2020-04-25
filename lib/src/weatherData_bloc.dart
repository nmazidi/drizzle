import 'dart:async';
import 'dart:collection';
import 'package:rxdart/rxdart.dart';
import 'package:http/http.dart' as http;
import 'timeSeries.dart';
import 'apiKeys.dart';

class WeatherDataBloc {
  HashMap<int, TimeSeries> _cachedData;

  final _timeSeriesListSubject = BehaviorSubject<List<TimeSeries>>();
  final _coordinatesController = StreamController<List<double>>();

  Stream<List<TimeSeries>> get timeSeriesList => _timeSeriesListSubject.stream;
  Sink<List<double>> get coordinates => _coordinatesController.sink;

  var _timeSeriesList = <TimeSeries>[];

  // API keys and URL
  static String _clientID, _clientSecret;
  static const _baseUrl =
      'https://api-metoffice.apiconnect.ibmcloud.com/metoffice/production/v0/forecasts/point/hourly?';

  WeatherDataBloc() {
    // Load API keys from secret json file that isn't included in version control
    loadAPIKeys().then((credentials) {
      _clientID = credentials['client-id'];
      _clientSecret = credentials['client-secret'];
    });
    // HashMap to store cached data in
    _cachedData = HashMap<int, TimeSeries>();
    // Listen to a change to the requested coordinates and execute
    _coordinatesController.stream.listen((coordinates) async {});
  }
}
