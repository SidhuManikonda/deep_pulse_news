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
import '../../data/repositories/topics_repository.dart';
import '../../data/models/topic.dart';

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
  final TopicsRepository _topicsRepository = TopicsRepositoryImpl();

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

  /// The YouTube link standing in for an uploaded creative. An ad carries a
  /// file or a link, never both, so [setMedia] and [setYoutubeUrl] clear each
  /// other.
  String? _youtubeUrl;
  String _formStatus = 'published';

  /// Optional headline shown over the creative, and what a reader may do with
  /// this ad. All three permissions default to on: a new ad behaves the way
  /// every ad did before these existed.
  String _title = '';
  bool _isShareable = true;
  bool _isLikeable = true;
  bool _isReportable = true;

  FeedAd? get editing => _editing;
  File? get media => _media;
  String? get youtubeUrl => _youtubeUrl;
  String get formStatus => _formStatus;
  String get title => _title;
  bool get isShareable => _isShareable;
  bool get isLikeable => _isLikeable;
  bool get isReportable => _isReportable;
  bool get isEditing => _editing != null;

  /// True when the form has enough to submit. A new ad needs a creative; an
  /// edit can keep the one it already has. Either way at least one topic is
  /// required — the endpoint rejects an ad without one
  /// (`topic_id => required|array|min:1`), so the button stays disabled rather
  /// than letting the admin upload a file and then be told no.
  bool get canSubmit =>
      (_media != null || _youtubeUrl != null || _editing != null) &&
      _selectedTopicIds.isNotEmpty;

  void startCreate() {
    _error = null;
    _editing = null;
    _media = null;
    _youtubeUrl = null;
    _formStatus = 'published';
    _title = '';
    _isShareable = true;
    _isLikeable = true;
    _isReportable = true;
    _selectedTopicIds.clear();
    _selectedStateIds.clear();
    _selectedDistrictIds.clear();
    _selectedMandalIds.clear();
    notifyListeners();
  }

  void startEdit(FeedAd ad) {
    _editing = ad;
    _error = null;
    _media = null; // keep the existing creative unless a new one is picked
    _youtubeUrl = ad.isYoutube ? ad.url : null;
    _formStatus = ad.status;
    _title = ad.title;
    _isShareable = ad.isShareable;
    _isLikeable = ad.isLikeable;
    _isReportable = ad.isReportable;
    _selectedTopicIds
      ..clear()
      ..addAll(ad.topicIds);
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
    // Attaching a file drops whatever link was there, so the two can never
    // both be sent for one ad.
    if (file != null) _youtubeUrl = null;
    notifyListeners();
  }

  /// Sets or clears the ad's YouTube link. Passing null or blank clears it;
  /// setting one drops any file queued for the ad.
  void setYoutubeUrl(String? url) {
    final text = url?.trim() ?? '';
    if (text.isEmpty) {
      _youtubeUrl = null;
    } else {
      _youtubeUrl = text;
      _media = null;
    }
    notifyListeners();
  }

  void setTitle(String value) {
    _title = value;
    // No notify: the field drives itself, and rebuilding on every keystroke
    // would fight the TextField's own cursor.
  }

  void setShareable(bool value) {
    _isShareable = value;
    notifyListeners();
  }

  void setLikeable(bool value) {
    _isLikeable = value;
    notifyListeners();
  }

  void setReportable(bool value) {
    _isReportable = value;
    notifyListeners();
  }

  /// Dismisses the save error shown in the form. Also called when the form is
  /// opened, so a previous failure doesn't greet the next ad.
  void clearError() {
    if (_error == null) return;
    _error = null;
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
            media: _media,
            youtubeUrl: _youtubeUrl,
            title: _title.trim(),
            isShareable: _isShareable,
            isLikeable: _isLikeable,
            isReportable: _isReportable,
            status: _formStatus,
            topicIds: _selectedTopicIds.toList(),
            stateIds: _selectedStateIds.toList(),
            districtIds: _selectedDistrictIds.toList(),
            mandalIds: _selectedMandalIds.toList(),
          )
        : await _adsRepository.updateAd(
            id: _editing!.id,
            media: _media,
            youtubeUrl: _youtubeUrl,
            title: _title.trim(),
            isShareable: _isShareable,
            isLikeable: _isLikeable,
            isReportable: _isReportable,
            status: _formStatus,
            topicIds: _selectedTopicIds.toList(),
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

  // ── Topics ────────────────────────────────────────────────────────────────
  // Unlike location targeting, this is not optional: the save endpoint
  // declares `topic_id => required|array|min:1`, so an ad always belongs to at
  // least one topic.
  List<Topic> _topics = [];
  bool _isLoadingTopics = false;
  final Set<int> _selectedTopicIds = {};

  List<Topic> get topics => _topics;
  bool get isLoadingTopics => _isLoadingTopics;
  Set<int> get selectedTopicIds => _selectedTopicIds;

  Future<void> loadTopics() async {
    if (_topics.isNotEmpty || _isLoadingTopics) return;
    _isLoadingTopics = true;
    notifyListeners();
    try {
      _topics = await _topicsRepository.getTopics();
    } catch (e) {
      // Same handling as the states list: the form stays usable and the save
      // button reports the real reason if it comes to that.
      debugPrint('[AdsController] loadTopics failed: $e');
    }
    _isLoadingTopics = false;
    notifyListeners();
  }

  void toggleTopic(Topic topic) {
    if (!_selectedTopicIds.remove(topic.id)) _selectedTopicIds.add(topic.id);
    notifyListeners();
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

  /// Test seam: populates the list without an HTTP round trip, so the filter
  /// rules can be exercised directly.
  @visibleForTesting
  void debugSeedAds(List<FeedAd> ads) {
    _ads = ads;
  }

  // ── List filters ──────────────────────────────────────────────────────────
  // Narrow the management list by where an ad runs, what it runs against and
  // when it last changed. Applied here rather than as query parameters: the
  // list endpoint only understands `status`, and it returns every ad in one
  // page, so filtering the loaded rows is both possible and instant.
  //
  // Selections are kept apart from the form's (`_selectedStateIds` and
  // friends) on purpose — filtering the list while an ad is open for edit must
  // not rewrite that ad's targeting.
  final Set<int> _filterTopicIds = {};
  final Set<int> _filterStateIds = {};
  final Set<int> _filterDistrictIds = {};
  final Set<int> _filterMandalIds = {};
  DateTime? _filterFrom;
  DateTime? _filterTo;

  Set<int> get filterTopicIds => _filterTopicIds;
  Set<int> get filterStateIds => _filterStateIds;
  Set<int> get filterDistrictIds => _filterDistrictIds;
  Set<int> get filterMandalIds => _filterMandalIds;
  DateTime? get filterFrom => _filterFrom;
  DateTime? get filterTo => _filterTo;

  /// Districts and mandals offered in the filter, following the states and
  /// districts the filter itself has picked.
  List<District> get filterDistricts => _filterStateIds
      .expand((id) => _districtsByState[id] ?? const <District>[])
      .toList();

  List<Mandal> get filterMandals => _filterDistrictIds
      .expand((id) => _mandalsByDistrict[id] ?? const <Mandal>[])
      .toList();

  bool get hasLocationFilter =>
      _filterStateIds.isNotEmpty ||
      _filterDistrictIds.isNotEmpty ||
      _filterMandalIds.isNotEmpty;

  bool get hasActiveFilters =>
      hasLocationFilter ||
      _filterTopicIds.isNotEmpty ||
      _filterFrom != null ||
      _filterTo != null;

  /// How many filters are on, for the "N" badge on the clear button.
  int get activeFilterCount =>
      (_filterTopicIds.isEmpty ? 0 : 1) +
      (hasLocationFilter ? 1 : 0) +
      (_filterFrom == null && _filterTo == null ? 0 : 1);

  /// The rows the list should show: [ads] with every active filter applied.
  ///
  /// Filter kinds are combined with AND — a topic *and* a place *and* a date
  /// range — while choices inside one kind are OR, so picking two topics
  /// widens rather than narrows.
  List<FeedAd> get visibleAds {
    if (!hasActiveFilters) return _ads;
    return _ads.where((ad) {
      if (_filterTopicIds.isNotEmpty &&
          !ad.topicIds.any(_filterTopicIds.contains)) {
        return false;
      }
      if (hasLocationFilter && !_matchesLocationFilter(ad)) return false;

      if (_filterFrom != null || _filterTo != null) {
        // `updated_at` arrives as UTC while the day boundaries below are
        // local, so it is compared in local time. Without this an ad touched
        // after 05:30 UTC reads as the previous day in India (UTC+5:30) and
        // the filter quietly loses it.
        final when = ad.updatedAt?.toLocal();
        // An ad with no date can't satisfy a date filter, so it drops out
        // rather than silently passing.
        if (when == null) return false;
        if (_filterFrom != null && when.isBefore(_filterFrom!)) return false;
        if (_filterTo != null && when.isAfter(_filterTo!)) return false;
      }
      return true;
    }).toList();
  }

  /// An ad with no targeting runs everywhere, so it belongs in the results for
  /// any place asked about — excluding it would hide exactly the ads that do
  /// run in the filtered location.
  bool _matchesLocationFilter(FeedAd ad) {
    if (ad.locations.isEmpty) return true;
    if (_filterStateIds.isNotEmpty &&
        ad.stateLocations.any((l) => _filterStateIds.contains(l.id))) {
      return true;
    }
    if (_filterDistrictIds.isNotEmpty &&
        ad.districtLocations.any((l) => _filterDistrictIds.contains(l.id))) {
      return true;
    }
    if (_filterMandalIds.isNotEmpty &&
        ad.mandalLocations.any((l) => _filterMandalIds.contains(l.id))) {
      return true;
    }
    return false;
  }

  void toggleFilterTopic(int topicId) {
    if (!_filterTopicIds.remove(topicId)) _filterTopicIds.add(topicId);
    notifyListeners();
  }

  Future<void> toggleFilterState(int stateId) async {
    if (_filterStateIds.remove(stateId)) {
      // Drop anything underneath it, so a cleared state can't leave its
      // districts filtering the list invisibly.
      for (final d in _districtsByState[stateId] ?? const <District>[]) {
        _filterDistrictIds.remove(d.id);
        for (final m in _mandalsByDistrict[d.id] ?? const <Mandal>[]) {
          _filterMandalIds.remove(m.id);
        }
      }
      notifyListeners();
      return;
    }

    _filterStateIds.add(stateId);
    notifyListeners();
    if (!_districtsByState.containsKey(stateId)) {
      try {
        _districtsByState[stateId] = await _districtRepository
            .getDistrictsByState(stateId);
      } catch (e) {
        debugPrint('[AdsController] filter districts failed: $e');
        _districtsByState[stateId] = const [];
      }
      notifyListeners();
    }
  }

  Future<void> toggleFilterDistrict(int districtId) async {
    if (_filterDistrictIds.remove(districtId)) {
      for (final m in _mandalsByDistrict[districtId] ?? const <Mandal>[]) {
        _filterMandalIds.remove(m.id);
      }
      notifyListeners();
      return;
    }

    _filterDistrictIds.add(districtId);
    notifyListeners();
    if (!_mandalsByDistrict.containsKey(districtId)) {
      try {
        _mandalsByDistrict[districtId] = await _mandalRepository
            .getMandalsByDistrict(districtId);
      } catch (e) {
        debugPrint('[AdsController] filter mandals failed: $e');
        _mandalsByDistrict[districtId] = const [];
      }
      notifyListeners();
    }
  }

  void toggleFilterMandal(int mandalId) {
    if (!_filterMandalIds.remove(mandalId)) _filterMandalIds.add(mandalId);
    notifyListeners();
  }

  /// [from] and [to] are whole days; [to] is widened to the end of its day so
  /// picking the same date twice means "that day", not an empty instant.
  void setDateFilter(DateTime? from, DateTime? to) {
    _filterFrom = from == null
        ? null
        : DateTime(from.year, from.month, from.day);
    _filterTo = to == null
        ? null
        : DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    notifyListeners();
  }

  void clearFilters() {
    _filterTopicIds.clear();
    _filterStateIds.clear();
    _filterDistrictIds.clear();
    _filterMandalIds.clear();
    _filterFrom = null;
    _filterTo = null;
    notifyListeners();
  }
}
