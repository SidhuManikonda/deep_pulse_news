import 'dart:io';

import 'package:deep_pulse_news/data/models/district.dart';
import 'package:deep_pulse_news/data/models/mandal.dart';
import 'package:deep_pulse_news/data/models/state.dart' as location_models;
import 'package:deep_pulse_news/data/models/topic.dart';
import 'package:deep_pulse_news/data/repositories/district_repository.dart';
import 'package:deep_pulse_news/data/repositories/mandal_repository.dart';
import 'package:deep_pulse_news/data/repositories/state_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/create_news_request.dart';
import '../../data/repositories/news_repository.dart';

final newsUploadViewModelProvider = ChangeNotifierProvider<NewsUploadViewModel>(
  (ref) => NewsUploadViewModel(),
);

class NewsUploadViewModel extends ChangeNotifier {
  final NewsRepository _newsRepository = NewsRepositoryImpl();
  final StateRepository _stateRepository = StateRepositoryImpl();
  final DistrictRepository _districtRepository = DistrictRepositoryImpl();
  final MandalRepository _mandalRepository = MandalRepositoryImpl();

  // Upload state
  bool _isUploading = false;
  String? _error;
  bool? _isMoreChecked = false;
  final List<Topic> _selectedCategories = [];
  final List<File> _selectedMedia = [];
  bool _acceptTerms = false;

  // Location data
  List<location_models.State> _availableStates = [];
  bool _isLoadingStates = false;
  String? _statesError;
  final Map<int, List<District>> _districtsByState = {};
  final Set<int> _loadingDistrictStateIds = {};
  final Map<int, List<Mandal>> _mandalsByDistrict = {};
  final Set<int> _loadingMandalDistrictIds = {};

  // Location selections
  final List<int> _selectedStateIds = [];
  final List<int> _selectedDistrictIds = [];
  final List<int> _selectedMandalIds = [];

  // ── Upload getters ──────────────────────────────────────────────────────────
  bool get isUploading => _isUploading;
  String? get error => _error;
  bool? get isMoreChecked => _isMoreChecked;
  List<Topic> get selectedCategories => _selectedCategories;
  List<File> get selectedMedia => _selectedMedia;
  bool get acceptTerms => _acceptTerms;

  // ── Location getters ────────────────────────────────────────────────────────
  List<location_models.State> get availableStates => _availableStates;
  bool get isLoadingStates => _isLoadingStates;
  String? get statesError => _statesError;
  bool get isLoadingAnyDistricts => _loadingDistrictStateIds.isNotEmpty;
  bool get isLoadingAnyMandals => _loadingMandalDistrictIds.isNotEmpty;

  List<int> get selectedStateIds => List.unmodifiable(_selectedStateIds);
  List<int> get selectedDistrictIds => List.unmodifiable(_selectedDistrictIds);
  List<int> get selectedMandalIds => List.unmodifiable(_selectedMandalIds);

  List<location_models.State> get selectedStates =>
      _availableStates.where((s) => _selectedStateIds.contains(s.id)).toList();

  List<District> get availableDistricts => _selectedStateIds
      .expand((id) => _districtsByState[id] ?? <District>[])
      .toList();

  List<District> get selectedDistricts =>
      availableDistricts.where((d) => _selectedDistrictIds.contains(d.id)).toList();

  List<Mandal> get availableMandals => _selectedDistrictIds
      .expand((id) => _mandalsByDistrict[id] ?? <Mandal>[])
      .toList();

  List<Mandal> get selectedMandals =>
      availableMandals.where((m) => _selectedMandalIds.contains(m.id)).toList();

  // ── Upload setters ──────────────────────────────────────────────────────────
  void setIsMoreChecked(bool? value) {
    _isMoreChecked = value ?? false;
    notifyListeners();
  }

  void toggleCategory(Topic category) {
    if (_selectedCategories.any((t) => t.id == category.id)) {
      _selectedCategories.removeWhere((t) => t.id == category.id);
    } else {
      _selectedCategories.add(category);
    }
    notifyListeners();
  }

  bool isCategorySelected(Topic category) =>
      _selectedCategories.any((t) => t.id == category.id);

  void addMedia(File file) {
    _selectedMedia.add(file);
    notifyListeners();
  }

  void addMultipleMedia(List<File> files) {
    _selectedMedia.addAll(files);
    notifyListeners();
  }

  void removeMedia(int index) {
    _selectedMedia.removeAt(index);
    notifyListeners();
  }

  void setAcceptTerms(bool value) {
    _acceptTerms = value;
    notifyListeners();
  }

  // ── Location methods ────────────────────────────────────────────────────────
  Future<void> loadStates() async {
    if (_availableStates.isNotEmpty) return;
    _isLoadingStates = true;
    _statesError = null;
    notifyListeners();
    try {
      _availableStates = await _stateRepository.getStates();
    } catch (e) {
      _statesError = e.toString();
    }
    _isLoadingStates = false;
    notifyListeners();
  }

  Future<void> retryLoadStates() async {
    _availableStates = [];
    await loadStates();
  }

  Future<void> toggleState(location_models.State state) async {
    if (_selectedStateIds.contains(state.id)) {
      _selectedStateIds.remove(state.id);
      // Cascade-deselect districts & mandals belonging to this state
      final districtIds =
          (_districtsByState[state.id] ?? []).map((d) => d.id).toList();
      _selectedDistrictIds.removeWhere(districtIds.contains);
      for (final dId in districtIds) {
        final mandalIds =
            (_mandalsByDistrict[dId] ?? []).map((m) => m.id).toList();
        _selectedMandalIds.removeWhere(mandalIds.contains);
      }
      notifyListeners();
    } else {
      _selectedStateIds.add(state.id);
      notifyListeners();
      if (!_districtsByState.containsKey(state.id)) {
        _loadingDistrictStateIds.add(state.id);
        notifyListeners();
        try {
          _districtsByState[state.id] =
              await _districtRepository.getDistrictsByState(state.id);
        } catch (_) {
          _districtsByState[state.id] = [];
        }
        _loadingDistrictStateIds.remove(state.id);
        notifyListeners();
      }
    }
  }

  Future<void> toggleDistrict(District district) async {
    if (_selectedDistrictIds.contains(district.id)) {
      _selectedDistrictIds.remove(district.id);
      // Cascade-deselect mandals belonging to this district
      final mandalIds =
          (_mandalsByDistrict[district.id] ?? []).map((m) => m.id).toList();
      _selectedMandalIds.removeWhere(mandalIds.contains);
      notifyListeners();
    } else {
      _selectedDistrictIds.add(district.id);
      notifyListeners();
      if (!_mandalsByDistrict.containsKey(district.id)) {
        _loadingMandalDistrictIds.add(district.id);
        notifyListeners();
        try {
          _mandalsByDistrict[district.id] =
              await _mandalRepository.getMandalsByDistrict(district.id);
        } catch (_) {
          _mandalsByDistrict[district.id] = [];
        }
        _loadingMandalDistrictIds.remove(district.id);
        notifyListeners();
      }
    }
  }

  void toggleMandal(Mandal mandal) {
    if (_selectedMandalIds.contains(mandal.id)) {
      _selectedMandalIds.remove(mandal.id);
    } else {
      _selectedMandalIds.add(mandal.id);
    }
    notifyListeners();
  }

  // ── Upload ──────────────────────────────────────────────────────────────────
  void clearData() {
    _selectedMedia.clear();
    _isMoreChecked = false;
    _selectedCategories.clear();
    _selectedStateIds.clear();
    _selectedDistrictIds.clear();
    _selectedMandalIds.clear();
    _acceptTerms = false;
    notifyListeners();
  }

  Future<bool> uploadNews({
    required String headline,
    required String description,
    required String content,
    required List<Topic> categories,
    required List<File> mediaFiles,
  }) async {
    _isUploading = true;
    _error = null;
    notifyListeners();

    try {
      if (_selectedStateIds.isEmpty) {
        _error = 'Please select at least one state.';
        _isUploading = false;
        notifyListeners();
        return false;
      }
      if (_selectedDistrictIds.isEmpty) {
        _error = 'Please select at least one district.';
        _isUploading = false;
        notifyListeners();
        return false;
      }
      if (_selectedMandalIds.isEmpty) {
        _error = 'Please select at least one mandal.';
        _isUploading = false;
        notifyListeners();
        return false;
      }

      final newsRequest = CreateNewsRequest(
        topicIds: categories.map((t) => t.id).toList(),
        status: 'pending',
        title: headline,
        slug: _generateSlug(headline),
        shortDescription: description,
        content: content.isNotEmpty ? content : description,
        stateIds: List.from(_selectedStateIds),
        districtIds: List.from(_selectedDistrictIds),
        mandalIds: List.from(_selectedMandalIds),
        files: mediaFiles,
      );

      await _newsRepository.createNews(newsRequest);
      _isUploading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to upload news: $e';
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _generateSlug(String title) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (title.trim().isEmpty) return 'news-$timestamp';

    // Split on whitespace, take first 4 words
    // Keep Unicode letters & numbers from any language (Telugu, Hindi, Arabic, etc.)
    // Strip everything else (punctuation, symbols, zero-width chars)
    final parts = title
        .trim()
        .split(RegExp(r'\s+'))
        .take(4)
        .map((w) => w
            .toLowerCase()
            .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
        .where((w) => w.isNotEmpty)
        .toList();

    final titlePart = parts.isNotEmpty ? parts.join('-') : 'news';
    return '$titlePart-$timestamp';
  }
}
