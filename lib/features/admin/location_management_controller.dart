import 'package:flutter/material.dart';
import '../../data/models/state.dart' as location_models;
import '../../data/models/district.dart';
import '../../data/models/mandal.dart';
import '../../data/repositories/state_repository.dart';
import '../../data/repositories/district_repository.dart';
import '../../data/repositories/mandal_repository.dart';

enum LocationType { state, district, mandal }

class LocationManagementController extends ChangeNotifier {
  final StateRepository _stateRepository = StateRepositoryImpl();
  final DistrictRepository _districtRepository = DistrictRepositoryImpl();
  final MandalRepository _mandalRepository = MandalRepositoryImpl();

  // Data lists
  List<location_models.State> _states = [];
  List<District> _districts = [];
  List<Mandal> _mandals = [];

  // Selected items for cascading
  location_models.State? _selectedState;
  District? _selectedDistrict;

  // Loading states
  bool _isLoadingStates = false;
  bool _isLoadingDistricts = false;
  bool _isLoadingMandals = false;
  bool _isCreating = false;

  // Error states
  String? _statesError;
  String? _districtsError;
  String? _mandalsError;
  String? _createError;
  String? _updateError;

  // Current tab
  LocationType _currentType = LocationType.state;

  // Getters
  List<location_models.State> get states => _states;
  List<District> get districts => _districts;
  List<Mandal> get mandals => _mandals;
  location_models.State? get selectedState => _selectedState;
  District? get selectedDistrict => _selectedDistrict;
  bool get isLoadingStates => _isLoadingStates;
  bool get isLoadingDistricts => _isLoadingDistricts;
  bool get isLoadingMandals => _isLoadingMandals;
  bool get isCreating => _isCreating;
  String? get statesError => _statesError;
  String? get districtsError => _districtsError;
  String? get mandalsError => _mandalsError;
  String? get createError => _createError;
  String? get updateError => _updateError;
  LocationType get currentType => _currentType;

  void setCurrentType(LocationType type) {
    _currentType = type;
    _selectedState = null;
    _selectedDistrict = null;
    _districts = [];
    _mandals = [];
    notifyListeners();
  }

  // Fetch states
  Future<void> fetchStates({bool forceRefresh = false}) async {
    if (_isLoadingStates) return;
    if (!forceRefresh && _states.isNotEmpty) return;

    _isLoadingStates = true;
    _statesError = null;
    notifyListeners();

    try {
      _states = await _stateRepository.getStates();
    } catch (e) {
      _statesError = e.toString();
    } finally {
      _isLoadingStates = false;
      notifyListeners();
    }
  }

  // Select state and load districts
  Future<void> selectState(location_models.State? state) async {
    _selectedState = state;
    _selectedDistrict = null;
    _districts = [];
    _mandals = [];
    notifyListeners();

    if (state != null) {
      await fetchDistricts(state.id);
    }
  }

  // Fetch districts for selected state
  Future<void> fetchDistricts(int stateId) async {
    if (_isLoadingDistricts) return;

    _isLoadingDistricts = true;
    _districtsError = null;
    notifyListeners();

    try {
      _districts = await _districtRepository.getDistrictsByState(stateId);
    } catch (e) {
      _districtsError = e.toString();
    } finally {
      _isLoadingDistricts = false;
      notifyListeners();
    }
  }

  // Select district and load mandals
  Future<void> selectDistrict(District? district) async {
    _selectedDistrict = district;
    _mandals = [];
    notifyListeners();

    if (district != null) {
      await fetchMandals(district.id);
    }
  }

  // Fetch mandals for selected district
  Future<void> fetchMandals(int districtId) async {
    if (_isLoadingMandals) return;

    _isLoadingMandals = true;
    _mandalsError = null;
    notifyListeners();

    try {
      _mandals = await _mandalRepository.getMandalsByDistrict(districtId);
    } catch (e) {
      _mandalsError = e.toString();
    } finally {
      _isLoadingMandals = false;
      notifyListeners();
    }
  }

  // Create state
  Future<bool> createState(String name) async {
    _isCreating = true;
    _createError = null;
    notifyListeners();

    try {
      final newState = location_models.State(
        id: 0,
        name: name,
        slug: '',
        isActive: true,
        createdAt: DateTime.now(),
      );
      final result = await _stateRepository.createState(newState);
      if (result != null) {
        _states.add(result);
        notifyListeners();
        return true;
      }
      _createError = 'Failed to create state';
      return false;
    } catch (e) {
      _createError = e.toString();
      return false;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  // Create district
  Future<bool> createDistrict(String name) async {
    if (_selectedState == null) {
      _createError = 'Please select a state first';
      notifyListeners();
      return false;
    }

    _isCreating = true;
    _createError = null;
    notifyListeners();

    try {
      final newDistrict = District(
        id: 0,
        stateId: _selectedState!.id,
        name: name,
        slug: '',
        isActive: true,
        createdAt: DateTime.now(),
      );
      final result = await _districtRepository.createDistrict(newDistrict);
      if (result != null) {
        _districts.add(result);
        notifyListeners();
        return true;
      }
      _createError = 'Failed to create district';
      return false;
    } catch (e) {
      _createError = e.toString();
      return false;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  // Create mandal
  Future<bool> createMandal(String name) async {
    if (_selectedDistrict == null) {
      _createError = 'Please select a district first';
      notifyListeners();
      return false;
    }

    _isCreating = true;
    _createError = null;
    notifyListeners();

    try {
      final newMandal = Mandal(
        id: 0,
        districtId: _selectedDistrict!.id,
        name: name,
        slug: '',
        isActive: true,
        createdAt: DateTime.now(),
      );
      final result = await _mandalRepository.createMandal(newMandal);
      if (result != null) {
        _mandals.add(result);
        notifyListeners();
        return true;
      }
      _createError = 'Failed to create mandal';
      return false;
    } catch (e) {
      _createError = e.toString();
      return false;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  // Delete (soft delete) state
  Future<bool> deleteState(location_models.State state) async {
    try {
      final deactivated = location_models.State(
        id: state.id,
        name: state.name,
        slug: state.slug,
        isActive: false,
        createdAt: state.createdAt,
      );
      final result = await _stateRepository.updateState(state.id, deactivated);
      if (result != null) {
        _states.removeWhere((s) => s.id == state.id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Delete (soft delete) district
  Future<bool> deleteDistrict(District district) async {
    try {
      final deactivated = District(
        id: district.id,
        stateId: district.stateId,
        name: district.name,
        slug: district.slug,
        isActive: false,
        createdAt: district.createdAt,
      );
      final result = await _districtRepository.updateDistrict(district.id, deactivated);
      if (result != null) {
        _districts.removeWhere((d) => d.id == district.id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Delete (soft delete) mandal
  Future<bool> deleteMandal(Mandal mandal) async {
    try {
      final deactivated = Mandal(
        id: mandal.id,
        districtId: mandal.districtId,
        name: mandal.name,
        slug: mandal.slug,
        isActive: false,
        createdAt: mandal.createdAt,
      );
      final result = await _mandalRepository.updateMandal(mandal.id, deactivated);
      if (result != null) {
        _mandals.removeWhere((m) => m.id == mandal.id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ── Rename ────────────────────────────────────────────────────────────────
  // PUT /states|/districts|/mandals/{id}. The repositories send the whole row,
  // so `is_active` and the parent id ride along unchanged and only the name
  // moves. Renaming keeps the id, so news already tagged to this location
  // stays linked — nothing to re-point.

  Future<bool> renameState(
    location_models.State state,
    String newName,
  ) async {
    return _runRename(() async {
      final result = await _stateRepository.updateState(
        state.id,
        location_models.State(
          id: state.id,
          name: newName,
          slug: state.slug,
          isActive: state.isActive,
          createdAt: state.createdAt,
        ),
      );
      if (result == null) return false;
      final i = _states.indexWhere((s) => s.id == state.id);
      if (i != -1) _states[i] = result;
      // The selector dropdowns hold the old object by reference; refresh it so
      // the district/mandal tabs don't keep showing the pre-rename label.
      if (_selectedState?.id == state.id) _selectedState = result;
      return true;
    });
  }

  Future<bool> renameDistrict(District district, String newName) async {
    return _runRename(() async {
      final result = await _districtRepository.updateDistrict(
        district.id,
        District(
          id: district.id,
          stateId: district.stateId,
          name: newName,
          slug: district.slug,
          isActive: district.isActive,
          createdAt: district.createdAt,
        ),
      );
      if (result == null) return false;
      final i = _districts.indexWhere((d) => d.id == district.id);
      if (i != -1) _districts[i] = result;
      if (_selectedDistrict?.id == district.id) _selectedDistrict = result;
      return true;
    });
  }

  Future<bool> renameMandal(Mandal mandal, String newName) async {
    return _runRename(() async {
      final result = await _mandalRepository.updateMandal(
        mandal.id,
        Mandal(
          id: mandal.id,
          districtId: mandal.districtId,
          name: newName,
          slug: mandal.slug,
          isActive: mandal.isActive,
          createdAt: mandal.createdAt,
        ),
      );
      if (result == null) return false;
      final i = _mandals.indexWhere((m) => m.id == mandal.id);
      if (i != -1) _mandals[i] = result;
      return true;
    });
  }

  Future<bool> _runRename(Future<bool> Function() action) async {
    _updateError = null;
    try {
      final ok = await action();
      if (!ok) _updateError = 'The server did not confirm the change';
      notifyListeners();
      return ok;
    } catch (e) {
      _updateError = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _createError = null;
    notifyListeners();
  }
}
