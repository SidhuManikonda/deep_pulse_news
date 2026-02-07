import '../models/state.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';

abstract class StateRepository {
  Future<List<State>> getStates();
  Future<State?> getStateById(int id);
  Future<State?> createState(State state);
  Future<State?> updateState(int id, State state);
}

class StateRepositoryImpl implements StateRepository {
  final ApiService _apiService;

  StateRepositoryImpl({ApiService? apiService})
    : _apiService = apiService ?? ApiService.instance;

  @override
  Future<List<State>> getStates() async {
    try {
      final response = await _apiService.get(AppConstants.states, useAuth: false);

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
  Future<State?> getStateById(int id) async {
    try {
      final response = await _apiService.get('${AppConstants.states}/$id', useAuth: false);

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      final stateData = response['state'];
      return State.fromJson(stateData);
    } catch (e) {
      throw Exception('Failed to fetch state: $e');
    }
  }

  @override
  Future<State?> createState(State state) async {
    try {
      final requestBody = {
        'name': state.name,
        'is_active': state.isActive ? 1 : 0,
      };

      final response = await _apiService.post(
        AppConstants.states,
        body: requestBody,
        useAuth: false,
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      if (response.containsKey('state')) {
        return State.fromJson(response['state']);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to create state: $e');
    }
  }

  @override
  Future<State?> updateState(int id, State state) async {
    try {
      final requestBody = {
        'name': state.name,
        'is_active': state.isActive ? 1 : 0,
      };

      final response = await _apiService.put(
        '${AppConstants.states}/$id',
        requestBody,
        useAuth: false,
      );

      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }

      if (response.containsKey('state')) {
        return State.fromJson(response['state']);
      }

      return null;
    } catch (e) {
      throw Exception('Failed to update state: $e');
    }
  }
}
