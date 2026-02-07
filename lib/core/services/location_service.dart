import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static LocationService? _instance;
  LocationService._internal();
  
  static LocationService get instance {
    _instance ??= LocationService._internal();
    return _instance!;
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current position with error handling
  Future<LocationResult> getCurrentPosition() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.error('Location services are disabled. Please enable location services in your device settings.');
      }

      // Check permissions
      LocationPermission permission = await checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.error('Location permissions are denied. Please grant location permission to auto-detect your location.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.error('Location permissions are permanently denied. Please enable location permission in app settings.');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return LocationResult.success(position);
    } catch (e) {
      return LocationResult.error('Failed to get current location: ${e.toString()}');
    }
  }

  /// Convert coordinates to address using reverse geocoding
  Future<AddressResult> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isEmpty) {
        return AddressResult.error('No address found for the current location.');
      }

      final placemark = placemarks.first;
      return AddressResult.success(LocationAddress(
        state: placemark.administrativeArea ?? '',
        district: placemark.subAdministrativeArea ?? '',
        locality: placemark.locality ?? '',
        subLocality: placemark.subLocality ?? '',
        country: placemark.country ?? '',
        postalCode: placemark.postalCode ?? '',
        fullAddress: _formatAddress(placemark),
      ));
    } catch (e) {
      return AddressResult.error('Failed to get address: ${e.toString()}');
    }
  }

  /// Get current location with address
  Future<CurrentLocationResult> getCurrentLocationWithAddress() async {
    final positionResult = await getCurrentPosition();
    
    if (positionResult.isError) {
      return CurrentLocationResult.error(positionResult.error!);
    }

    final position = positionResult.position!;
    final addressResult = await getAddressFromCoordinates(
      position.latitude, 
      position.longitude,
    );

    if (addressResult.isError) {
      return CurrentLocationResult.error(addressResult.error!);
    }

    return CurrentLocationResult.success(
      position: position,
      address: addressResult.address!,
    );
  }

  /// Format placemark into readable address
  String _formatAddress(Placemark placemark) {
    final parts = <String>[];
    
    if (placemark.subLocality?.isNotEmpty == true) {
      parts.add(placemark.subLocality!);
    }
    if (placemark.locality?.isNotEmpty == true) {
      parts.add(placemark.locality!);
    }
    if (placemark.subAdministrativeArea?.isNotEmpty == true) {
      parts.add(placemark.subAdministrativeArea!);
    }
    if (placemark.administrativeArea?.isNotEmpty == true) {
      parts.add(placemark.administrativeArea!);
    }
    if (placemark.country?.isNotEmpty == true) {
      parts.add(placemark.country!);
    }

    return parts.join(', ');
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}

// Result classes for better error handling
class LocationResult {
  final Position? position;
  final String? error;
  final bool isSuccess;

  LocationResult.success(this.position) : error = null, isSuccess = true;
  LocationResult.error(this.error) : position = null, isSuccess = false;

  bool get isError => !isSuccess;
}

class AddressResult {
  final LocationAddress? address;
  final String? error;
  final bool isSuccess;

  AddressResult.success(this.address) : error = null, isSuccess = true;
  AddressResult.error(this.error) : address = null, isSuccess = false;

  bool get isError => !isSuccess;
}

class CurrentLocationResult {
  final Position? position;
  final LocationAddress? address;
  final String? error;
  final bool isSuccess;

  CurrentLocationResult.success({
    required this.position,
    required this.address,
  }) : error = null, isSuccess = true;

  CurrentLocationResult.error(this.error) 
    : position = null, address = null, isSuccess = false;

  bool get isError => !isSuccess;
}

class LocationAddress {
  final String state;
  final String district;
  final String locality;
  final String subLocality;
  final String country;
  final String postalCode;
  final String fullAddress;

  LocationAddress({
    required this.state,
    required this.district,
    required this.locality,
    required this.subLocality,
    required this.country,
    required this.postalCode,
    required this.fullAddress,
  });

  @override
  String toString() => fullAddress;
}
