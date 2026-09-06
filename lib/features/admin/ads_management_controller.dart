import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/models/district.dart';
import '../../data/models/feed_ad.dart';
import '../../data/models/mandal.dart';
import '../../data/models/state.dart' as location_models;
import '../../data/repositories/ads_repository.dart';
import '../../data/repositories/district_repository.dart';
import '../../data/repositories/mandal_repository.dart';
import '../../data/repositories/state_repository.dart';

/// Backs the Ads Management screen: the list, and the create/edit form with
/// its location targeting.
///
/// Targeting is held here rather than reusing the news upload view model —
/// that one carries a whole article in progress, and sharing it would let an
/// ad edit stomp on a half-written story.
class AdsManagementController extends ChangeNotifier {
  final AdsRepository _adsRepository;
  final StateRepository _stateRepository = StateRepositoryImpl();
  final DistrictRepository _districtRepository = DistrictRepositoryImpl();
  final MandalRepository _mandalRepository = MandalRepositoryImpl();

  AdsManagementController({AdsRepository? adsRepository})
    : _adsRepository = adsRepository ?? AdsRepositoryImpl();

  // ── List ──────────────────────────────────────────────────────────────────
  List<FeedAd> _ads = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  /// null = every status.
  String? _statusFilter;

  List<FeedAd> get ads => _ads;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String? get statusFilter => _statusFilter;

  Future<void> loadAds({String? status, bool keepFilter = true}) async {
    if (!keepFilter) _statusFilter = status;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _ads = await _adsRepository.listAds(status: _statusFilter);
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setStatusFilter(String? status) async {
    if (_statusFilter == status) return;
    _statusFilter = status;
    await loadAds();
  }

  // ── Row actions ───────────────────────────────────────────────────────────
  // Each refreshes the list afterwards rather than mutating locally: publish
  // and republish change server-side ordering, so a local edit would leave the
  // list in an order the backend disagrees with.

  Future<bool> publish(int id) => _run(() => _adsRepository.publish(id));
  Future<bool> unpublish(int id) => _run(() => _adsRepository.unpublish(id));
  Future<bool> republish(int id) => _run(() => _adsRepository.republish(id));
  Future<bool> softDelete(int id) => _run(() => _adsRepository.softDelete(id));
  Future<bool> restore(int id) => _run(() => _adsRepository.restore(id));
  Future<bool> forceDelete(int id) =>
      _run(() => _adsRepository.forceDelete(id));

  Future<bool> _run(Future<bool> Function() action) async {
    _isSaving = true;
    notifyListeners();
    final ok = await action();
    _isSaving = false;
    if (ok) {
      await loadAds();
    } else {
      notifyListeners();
    }
    return ok;
  }

  // ── Form ──────────────────────────────────────────────────────────────────
  FeedAd? _editing;
  File? _media;
  String _formStatus = 'published';

  FeedAd? get editing => _editing;
  File? get media => _media;
  String get formStatus => _formStatus;
  bool get isEditing => _editing != null;

  /// True when the form has enough to submit. A new ad needs a creative; an
  /// edit can keep the one it already has.
  bool get canSubmit => _media != null || _editing != null;

  void startCreate() {
    _editing = null;
    _media = null;
    _formStatus = 'published';
    _selectedStateIds.clear();
    _selectedDistrictIds.clear();
    _selectedMandalIds.clear();
    notifyListeners();
  }

  void startEdit(FeedAd ad) {
    _editing = ad;
    _media = null; // keep the existing creative unless a new one is picked
    _formStatus = ad.status;
    _selectedStateIds
      ..clear()
      ..addAll(ad.stateLocations.map((l) => l.id));
    _selectedDistrictIds
      ..clear()
      ..addAll(ad.districtLocations.map((l) => l.id));
    _selectedMandalIds
      ..clear()
      ..addAll(ad.mandalLocations.map((l) => l.id));
    notifyListeners();
  }

  void setMedia(File? file) {
    _media = file;
    notifyListeners();
  }

  void setFormStatus(String status) {
    _formStatus = status;
    notifyListeners();
  }

  Future<bool> submit() async {
    if (!canSubmit) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();

    // null means saved; anything else is the server's reason for refusing.
    final failure = _editing == null
        ? await _adsRepository.createAd(
            media: _media!,
            status: _formStatus,
            stateIds: _selectedStateIds.toList(),
            districtIds: _selectedDistrictIds.toList(),
            mandalIds: _selectedMandalIds.toList(),
          )
        : await _adsRepository.updateAd(
            id: _editing!.id,
            media: _media,
            status: _formStatus,
            stateIds: _selectedStateIds.toList(),
            districtIds: _selectedDistrictIds.toList(),
            mandalIds: _selectedMandalIds.toList(),
          );

    _isSaving = false;
    if (failure == null) {
      await loadAds();
      return true;
    }

    // Show what the server actually said. "Could not save the ad" told the
    // admin nothing they could act on, and the real reason — file type, size,
    // missing targeting — was only ever visible in a debug log.
    _error = failure;
    notifyListeners();
    return false;
  }

  // ── Location targeting ────────────────────────────────────────────────────
  // Same cascade as the news upload form: districts load per selected state,
  // mandals per selected district, so several districts can be targeted at
  // once and their mandals shown together.
  List<location_models.State> _states = [];
  final Map<int, List<District>> _districtsByState = {};
  final Map<int, List<Mandal>> _mandalsByDistrict = {};
  bool _isLoadingStates = false;

  final Set<int> _selectedStateIds = {};
  final Set<int> _selectedDistrictIds = {};
  final Set<int> _selectedMandalIds = {};

  List<location_models.State> get states => _states;
  bool get isLoadingStates => _isLoadingStates;

  Set<int> get selectedStateIds => _selectedStateIds;
  Set<int> get selectedDistrictIds => _selectedDistrictIds;
  Set<int> get selectedMandalIds => _selectedMandalIds;

  List<District> get availableDistricts => _selectedStateIds
      .expand((id) => _districtsByState[id] ?? const <District>[])
      .toList();

  List<Mandal> get availableMandals => _selectedDistrictIds
      .expand((id) => _mandalsByDistrict[id] ?? const <Mandal>[])
      .toList();

  Future<void> loadStates() async {
    if (_states.isNotEmpty || _isLoadingStates) return;
    _isLoadingStates = true;
    notifyListeners();
    try {
      _states = await _stateRepository.getStates();
    } catch (e) {
      debugPrint('[AdsController] loadStates failed: $e');
    }
    _isLoadingStates = false;
    notifyListeners();
  }

  Future<void> toggleState(location_models.State state) async {
    if (_selectedStateIds.remove(state.id)) {
      // Cascade off anything that belonged to it, so a deselected state can't
      // leave orphan districts in the payload.
      final districtIds = (_districtsByState[state.id] ?? const <District>[])
          .map((d) => d.id);
      for (final id in districtIds) {
        _selectedDistrictIds.remove(id);
        for (final m in _mandalsByDistrict[id] ?? const <Mandal>[]) {
          _selectedMandalIds.remove(m.id);
        }
      }
      notifyListeners();
      return;
    }

    _selectedStateIds.add(state.id);
    notifyListeners();
    if (!_districtsByState.containsKey(state.id)) {
      try {
        _districtsByState[state.id] = await _districtRepository
            .getDistrictsByState(state.id);
      } catch (_) {
        _districtsByState[state.id] = const [];
      }
      notifyListeners();
    }
  }

  Future<void> toggleDistrict(District district) async {
    if (_selectedDistrictIds.remove(district.id)) {
      for (final m in _mandalsByDistrict[district.id] ?? const <Mandal>[]) {
        _selectedMandalIds.remove(m.id);
      }
      notifyListeners();
      return;
    }

    _selectedDistrictIds.add(district.id);
    notifyListeners();
    if (!_mandalsByDistrict.containsKey(district.id)) {
      try {
        _mandalsByDistrict[district.id] = await _mandalRepository
            .getMandalsByDistrict(district.id);
      } catch (_) {
        _mandalsByDistrict[district.id] = const [];
      }
      notifyListeners();
    }
  }

  void toggleMandal(Mandal mandal) {
    if (!_selectedMandalIds.remove(mandal.id)) {
      _selectedMandalIds.add(mandal.id);
    }
    notifyListeners();
  }
}
