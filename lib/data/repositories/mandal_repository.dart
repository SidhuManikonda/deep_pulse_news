import '../models/mandal.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';

abstract class MandalRepository {
  Future<List<Mandal>> getMandalsByDistrict(int districtId);
  Future<Mandal?> getMandalById(int id);
  Future<Mandal?> createMandal(Mandal mandal);
  Future<Mandal?> updateMandal(int id, Mandal mandal);
}

class MandalRepositoryImpl implements MandalRepository {
  final ApiService _apiService;

  MandalRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;

  @override
  Future<List<Mandal>> getMandalsByDistrict(int districtId) async {
    try {
      final response = await _apiService.get('${AppConstants.mandals}/$districtId', useAuth: false);

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      // The API returns {"district": [DistrictWithMandals]}
      // We need to extract mandals from the district object
      final districtData = response['district'];
      if (districtData is List && districtData.isNotEmpty) {
        final districtObj = districtData[0];
        if (districtObj.containsKey('mandals')) {
          final mandalsData = districtObj['mandals'] as List<dynamic>;
          return mandalsData.map((mandalJson) => Mandal.fromJson(mandalJson)).toList();
        }
      }

      return [];
    } catch (e) {
      throw Exception('Failed to fetch mandals: $e');
    }
  }

  @override
  Future<Mandal?> getMandalById(int id) async {
    try {
      final response = await _apiService.get('${AppConstants.mandals}/$id', useAuth: false);

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      final mandalData = response['mandal'];
      return Mandal.fromJson(mandalData);
    } catch (e) {
      throw Exception('Failed to fetch mandal: $e');
    }
  }

  @override
  Future<Mandal?> createMandal(Mandal mandal) async {
    try {
      final requestBody = {
        'district_id': mandal.districtId,
        'name': mandal.name,
        'is_active': mandal.isActive ? 1 : 0,
      };

      final response = await _apiService.post(
        AppConstants.mandals,
        body: requestBody,
        useAuth: false,
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      if (response.containsKey('mandal')) {
        return Mandal.fromJson(response['mandal']);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to create mandal: $e');
    }
  }

  @override
  Future<Mandal?> updateMandal(int id, Mandal mandal) async {
    try {
      final requestBody = {
        'district_id': mandal.districtId,
        'name': mandal.name,
        'is_active': mandal.isActive ? 1 : 0,
      };

      final response = await _apiService.put(
        '${AppConstants.mandals}/$id',
        requestBody,
        useAuth: false,
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      if (response.containsKey('mandal')) {
        return Mandal.fromJson(response['mandal']);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to update mandal: $e');
    }
  }
}
