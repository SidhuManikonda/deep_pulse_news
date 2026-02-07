import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/district.dart';
import '../../data/models/mandal.dart';
import '../../data/models/state.dart' as location_models;
import '../../data/repositories/district_repository.dart';
import '../../data/repositories/mandal_repository.dart';
import '../../data/repositories/state_repository.dart';

class LocationViewModel extends ChangeNotifier {
  final StateRepository _stateRepository;
  final DistrictRepository _districtRepository;
  final MandalRepository _mandalRepository;

  LocationViewModel({
    StateRepository? stateRepository,
    DistrictRepository? districtRepository,
    MandalRepository? mandalRepository,
  }) : _stateRepository = stateRepository ?? StateRepositoryImpl(),
       _districtRepository = districtRepository ?? DistrictRepositoryImpl(),
       _mandalRepository = mandalRepository ?? MandalRepositoryImpl();

  // States
  List<location_models.State> _states = [];
  List<location_models.State> get states => _states;
  bool _isLoadingStates = false;
  bool get isLoadingStates => _isLoadingStates;
  String? _statesError;
  String? get statesError => _statesError;

  // Districts
  List<District> _districts = [];
  List<District> get districts => _districts;
  bool _isLoadingDistricts = false;
  bool get isLoadingDistricts => _isLoadingDistricts;
  String? _districtsError;
  String? get districtsError => _districtsError;

  // Mandals
  List<Mandal> _mandals = [];
  List<Mandal> get mandals => _mandals;
  bool _isLoadingMandals = false;
  bool get isLoadingMandals => _isLoadingMandals;
  String? _mandalsError;
  String? get mandalsError => _mandalsError;

  // Selected values
  location_models.State? _selectedState;
  location_models.State? get selectedState => _selectedState;
  District? _selectedDistrict;
  District? get selectedDistrict => _selectedDistrict;
  Mandal? _selectedMandal;
  Mandal? get selectedMandal => _selectedMandal;

  // Load states
  Future<void> loadStates() async {
    _isLoadingStates = true;
    _statesError = null;
    notifyListeners();

    try {
      _states = await _stateRepository.getStates();
      _statesError = null;
    } catch (e) {
      _statesError = e.toString();
      _states = [];
    }

    _isLoadingStates = false;
    notifyListeners();
  }

  // Load districts for selected state
  Future<void> loadDistricts(int stateId) async {
    _isLoadingDistricts = true;
    _districtsError = null;
    _districts = [];
    _selectedDistrict = null;
    _mandals = [];
    _selectedMandal = null;
    notifyListeners();

    try {
      _districts = await _districtRepository.getDistrictsByState(stateId);
      _districtsError = null;
    } catch (e) {
      _districtsError = e.toString();
      _districts = [];
    }

    _isLoadingDistricts = false;
    notifyListeners();
  }

  // Load mandals for selected district
  Future<void> loadMandals(int districtId) async {
    _isLoadingMandals = true;
    _mandalsError = null;
    _mandals = [];
    _selectedMandal = null;
    notifyListeners();

    try {
      _mandals = await _mandalRepository.getMandalsByDistrict(districtId);
      _mandalsError = null;
    } catch (e) {
      _mandalsError = e.toString();
      _mandals = [];
    }

    _isLoadingMandals = false;
    notifyListeners();
  }

  // Set selected state
  void setSelectedState(location_models.State state) {
    _selectedState = state;
    _selectedDistrict = null;
    _selectedMandal = null;
    notifyListeners();
    loadDistricts(state.id);
  }

  // Set selected district
  void setSelectedDistrict(District district) {
    _selectedDistrict = district;
    _selectedMandal = null;
    notifyListeners();
    loadMandals(district.id);
  }

  // Set selected mandal
  void setSelectedMandal(Mandal mandal) {
    _selectedMandal = mandal;
    notifyListeners();
  }

  // Check if location selection is complete
  bool get isLocationComplete =>
      _selectedState != null &&
      _selectedDistrict != null &&
      _selectedMandal != null;

  // Reset all selections
  void reset() {
    _selectedState = null;
    _selectedDistrict = null;
    _selectedMandal = null;
    _districts = [];
    _mandals = [];
    notifyListeners();
  }

  // Retry loading states
  void retryLoadStates() {
    loadStates();
  }

  // Retry loading districts
  void retryLoadDistricts() {
    if (_selectedState != null) {
      loadDistricts(_selectedState!.id);
    }
  }

  // Retry loading mandals
  void retryLoadMandals() {
    if (_selectedDistrict != null) {
      loadMandals(_selectedDistrict!.id);
    }
  }
}
