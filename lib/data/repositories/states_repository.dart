import '../models/state.dart';
import '../models/district.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';

abstract class StatesRepository {
  Future<List<State>> getStates();
  Future<State?> getStateWithDistricts(int stateId);
  Future<District?> getDistrictWithMandals(int districtId);
}

class StatesRepositoryImpl implements StatesRepository {
  final ApiService _apiService;

  StatesRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;

  @override
  Future<List<State>> getStates() async {
    try {
      final response = await _apiService.get(AppConstants.states);

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      final statesData = response['states'] as List<dynamic>;
      return statesData.map((stateJson) => State.fromJson(stateJson)).toList();
    } catch (e) {
      throw Exception('Failed to fetch states: $e');
    }
  }

  @override
  Future<State?> getStateWithDistricts(int stateId) async {
    try {
      final response = await _apiService.get(
        '${AppConstants.districts}/$stateId',
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      final stateData = response['state'];
      if (stateData is List && stateData.isNotEmpty) {
        // The API returns an array with one state object that has districts
        return State.fromJson(stateData[0]);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to fetch districts for state: $e');
    }
  }

  @override
  Future<District?> getDistrictWithMandals(int districtId) async {
    try {
      final response = await _apiService.get(
        '${AppConstants.mandals}/$districtId',
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      final districtData = response['district'];
      if (districtData is List && districtData.isNotEmpty) {
        // The API returns an array with one district object that has mandals
        return District.fromJson(districtData[0]);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to fetch mandals for district: $e');
    }
  }
}
