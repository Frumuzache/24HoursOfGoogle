import 'dart:convert' as convert;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class NearbyPlace {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distance;

  NearbyPlace({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distance,
  });
}

class LocationService {
  static const String _placesApiKey = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: '',
  );
  
  static const Map<String, List<String>> placeKeywords = {
    'park': ['park', 'parks', 'nature', 'outdoor', 'walking', 'verde'],
    'cafe': ['cafe', 'café', 'coffee', 'tea', 'espresso', 'coffee shop'],
    'church': ['church', 'temple', 'mosque', 'synagogue', 'religious', 'worship', 'biserică'],
    'gym': ['gym', 'fitness', 'exercise', 'workout', '健身房', 'sală'],
    'library': ['library', 'book', 'reading', 'study', 'bibliotecă'],
    'restaurant': ['restaurant', 'food', 'eat', 'dinner', 'lunch', 'meal', 'restaurant', 'masă'],
    'pharmacy': ['pharmacy', 'drugstore', 'medicine', 'farmacie', 'medicament'],
    'hospital': ['hospital', 'clinic', 'medical', 'doctor', 'spital'],
    'parking': ['parking', 'garage', 'parcare'],
    'store': ['store', 'shop', 'market', 'mall', 'supermarket', 'magazin'],
  };

  static const Map<String, String> placeTypes = {
    'park': 'park',
    'cafe': 'cafe',
    'church': 'church',
    'gym': 'gym_fitness_center',
    'library': 'library',
    'restaurant': 'restaurant',
    'pharmacy': 'pharmacy',
    'hospital': 'hospital',
    'parking': 'parking',
    'store': 'supermarket',
  };

  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled');
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied');
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied');
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (e) {
      print('Failed to get location: $e');
      return null;
    }
  }

  String generateGoogleMapsSearchLink({
    required String placeType,
    required double latitude,
    required double longitude,
  }) {
    final query = Uri.encodeComponent(placeType);
    return 'https://www.google.com/maps/search/$query/@$latitude,$longitude,15z';
  }

  String generateGoogleMapsSearchLinkWithoutLocation({
    required String placeType,
  }) {
    final query = Uri.encodeComponent('$placeType near me');
    return 'https://www.google.com/maps/search/?api=1&query=$query';
  }

  String generateGoogleMapsDirectionsLink({
    required double destLatitude,
    required double destLongitude,
    double? originLatitude,
    double? originLongitude,
  }) {
    if (originLatitude == null || originLongitude == null) {
      return 'https://www.google.com/maps/search/?api=1&query=$destLatitude,$destLongitude';
    }
    return 'https://www.google.com/maps/dir/$originLatitude,$originLongitude/$destLatitude,$destLongitude';
  }

  String? detectPlaceType(String message) {
    final lower = message.toLowerCase();
    for (final entry in placeKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  Future<List<NearbyPlace>> searchNearbyPlaces(String placeType, {int maxResults = 3}) async {
    final position = await getCurrentLocation();
    if (position == null) return [];

    if (_placesApiKey.isEmpty) {
      print('GOOGLE_PLACES_API_KEY is missing from --dart-define');
      return [];
    }

    final googlePlaceType = placeTypes[placeType] ?? placeType;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=${position.latitude},${position.longitude}'
      '&radius=3000'
      '&type=$googlePlaceType'
      '&key=$_placesApiKey',
    );

    try {
      final response = await http.get(url).timeout(Duration(seconds: 10));
      
      if (response.statusCode != 200) {
        print('Places API error: ${response.statusCode}');
        return [];
      }

      final data = convert.jsonDecode(response.body);
      if (data['status'] != 'OK') {
        print('Places API status: ${data['status']}');
        return [];
      }

      final results = data['results'] as List;
      final places = <NearbyPlace>[];

      for (var i = 0; i < results.length && i < maxResults; i++) {
        final place = results[i];
        final location = place['geometry']['location'];
        
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          location['lat'],
          location['lng'],
        );

        places.add(NearbyPlace(
          name: place['name'] ?? '',
          address: place['vicinity'] ?? '',
          latitude: location['lat'],
          longitude: location['lng'],
          distance: distance,
        ));
      }

      return places;
    } catch (e) {
      print('Failed to search places: $e');
      return [];
    }
  }

  Future<String?> findNearbyPlace(String placeType) async {
    final position = await getCurrentLocation();
    if (position == null) return null;

    final link = generateGoogleMapsSearchLink(
      placeType: placeType,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    return link;
  }

  Future<NearbyPlace?> getClosestPlace(String placeType) async {
    final places = await searchNearbyPlaces(placeType, maxResults: 1);
    return places.isNotEmpty ? places.first : null;
  }

  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}