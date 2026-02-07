import '../models/district.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';

abstract class DistrictRepository {
  Future<List<District>> getDistrictsByState(int stateId);
  Future<District?> getDistrictById(int id);
  Future<District?> createDistrict(District district);
  Future<District?> updateDistrict(int id, District district);
}

class DistrictRepositoryImpl implements DistrictRepository {
  final ApiService _apiService;

  DistrictRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;

  @override
  Future<List<District>> getDistrictsByState(int stateId) async {
    try {
      final response = await _apiService.get('${AppConstants.districts}/$stateId', useAuth: false);

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      // The API returns {"state": [StateWithDistricts]}
      // We need to extract districts from the state object
      final stateData = response['state'];
      if (stateData is List && stateData.isNotEmpty) {
        final stateObj = stateData[0];
        if (stateObj.containsKey('districts')) {
          final districtsData = stateObj['districts'] as List<dynamic>;
          return districtsData.map((districtJson) => District.fromJson(districtJson)).toList();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch districts: $e');
    }
  }

  @override
  Future<District?> getDistrictById(int id) async {
    try {
      final response = await _apiService.get('${AppConstants.districts}/$id', useAuth: false);

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      final districtData = response['district'];
      return District.fromJson(districtData);
    } catch (e) {
      throw Exception('Failed to fetch district: $e');
    }
  }

  @override
  Future<District?> createDistrict(District district) async {
    try {
      final requestBody = {
        'state_id': district.stateId,
        'name': district.name,
        'is_active': district.isActive ? 1 : 0,
      };

      final response = await _apiService.post(
        AppConstants.districts,
        body: requestBody,
        useAuth: false,
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      if (response.containsKey('district')) {
        return District.fromJson(response['district']);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to create district: $e');
    }
  }

  @override
  Future<District?> updateDistrict(int id, District district) async {
    try {
      final requestBody = {
        'state_id': district.stateId,
        'name': district.name,
        'is_active': district.isActive ? 1 : 0,
      };

      final response = await _apiService.put(
        '${AppConstants.districts}/$id',
        requestBody,
        useAuth: false,
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      if (response.containsKey('district')) {
        return District.fromJson(response['district']);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to update district: $e');
    }
  }
}
