import 'dart:io';

import 'package:deep_pulse_news/data/models/district.dart';
import 'package:deep_pulse_news/data/models/news_media.dart';
import 'package:video_compress/video_compress.dart';
import 'package:deep_pulse_news/data/models/mandal.dart';
import 'package:deep_pulse_news/data/models/state.dart' as location_models;
import 'package:deep_pulse_news/data/models/topic.dart';
import 'package:deep_pulse_news/data/repositories/district_repository.dart';
import 'package:deep_pulse_news/data/repositories/mandal_repository.dart';
import 'package:deep_pulse_news/data/repositories/state_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/create_news_request.dart';
import '../../data/models/news_ad.dart';
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
  final List<NewsMedia> _existingMedia = []; // Media from prefilled news
  bool _acceptTerms = false;

  /// Sponsor creatives attached to this article (image or video), sent as
  /// `ad_1` / `ad_2`. Optional — most articles carry none.
  File? _ad1;
  File? _ad2;

  /// Ads already on the article being edited, as the feed returned them.
  ///
  /// Only populated when editing. An editor reviewing a reporter's story needs
  /// to see what was attached before they can decide to drop it — until this
  /// existed, the ads were invisible in the form and could only be replaced
  /// blind.
  final List<NewsAd> _existingAds = [];

  /// Ad places the editor has marked to clear, by slot. Sent with the story
  /// update rather than acted on at the tap, so the editor can change their
  /// mind and nothing is dropped from an article whose own save then fails.
  final Set<int> _removedAdSlots = {};

  /// Ids of already-saved media the editor has taken out of the form. Sent as
  /// `delete_media_ids[]` with the update, for the same reason the ad slots
  /// are: a removal that a failed save doesn't reach should not have happened.
  final Set<int> _deletedMediaIds = {};

  /// A YouTube link per slot, sent as `youtube_url_1` / `youtube_url_2`.
  ///
  /// A slot holds a file or a link, never both, so [setAdYoutubeUrl] and
  /// [setAd] each clear the other. Kept as the raw text the editor typed —
  /// validation happens at the form, and the backend stores what was pasted.
  final Map<int, String> _adYoutubeUrls = {};

  /// New creatives to swap into an occupied slot. Ride along as `ad_1` / `ad_2`
  /// on the same update — posting a file at a slot overwrites what's there.
  final Map<int, File> _replacedAdFiles = {};

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

  /// Id of the article the last successful [uploadNews] created or edited.
  /// Needed so the publish push can carry `news_id` — without it a tapped
  /// notification has nothing to open. Stays null when the backend replies
  /// with a body we can't parse an id out of.
  int? _lastUploadedNewsId;

  // ── Upload getters ──────────────────────────────────────────────────────────
  bool get isUploading => _isUploading;
  String? get error => _error;
  int? get lastUploadedNewsId => _lastUploadedNewsId;
  bool? get isMoreChecked => _isMoreChecked;
  List<Topic> get selectedCategories => _selectedCategories;
  List<File> get selectedMedia => _selectedMedia;
  List<NewsMedia> get existingMedia => _existingMedia;
  bool get acceptTerms => _acceptTerms;
  File? get ad1 => _ad1;
  File? get ad2 => _ad2;
  List<NewsAd> get existingAds => List.unmodifiable(_existingAds);

  bool isAdSlotRemoved(int slot) => _removedAdSlots.contains(slot);
  File? replacementForSlot(int slot) => _replacedAdFiles[slot];

  /// The ad already on the article in this slot, if any. An ad the payload gave
  /// no slot for isn't matched here — it's shown, but can't be addressed.
  NewsAd? existingAdInSlot(int slot) {
    for (final ad in _existingAds) {
      if (ad.slot == slot) return ad;
    }
    return null;
  }

  /// The file to post for a slot: the editor's replacement if they picked one,
  /// otherwise whatever they attached to an empty slot.
  File? adFileForSlot(int slot) =>
      _replacedAdFiles[slot] ?? (slot == 1 ? _ad1 : _ad2);

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

  List<District> get selectedDistricts => availableDistricts
      .where((d) => _selectedDistrictIds.contains(d.id))
      .toList();

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
    debugPrint(
      '[addMedia] adding 1 file. before=${_selectedMedia.length}, '
      'path=${file.path}',
    );
    _selectedMedia.add(file);
    debugPrint('[addMedia] after=${_selectedMedia.length}');
    notifyListeners();
  }

  void addMultipleMedia(List<File> files) {
    debugPrint(
      '[addMultipleMedia] received ${files.length} files. '
      'before=${_selectedMedia.length}',
    );
    for (var i = 0; i < files.length; i++) {
      debugPrint('  [$i] ${files[i].path}');
    }
    _selectedMedia.addAll(files);
    debugPrint('[addMultipleMedia] after=${_selectedMedia.length}');
    notifyListeners();
  }

  void removeMedia(int index) {
    _selectedMedia.removeAt(index);
    notifyListeners();
  }

  /// Drops an already-saved file from the form and remembers its id, so the
  /// update can ask the backend to delete it. Without recording the id the
  /// thumbnail disappears from the form but the file survives the save.
  void removeExistingMedia(int index) {
    final removed = _existingMedia.removeAt(index);
    // id is 0 when the payload carried none — nothing we can name for deletion.
    if (removed.id != 0) _deletedMediaIds.add(removed.id);
    notifyListeners();
  }

  /// [slot] is 1 or 2. Passing null clears that slot.
  void setAd(int slot, File? file) {
    if (slot == 1) {
      _ad1 = file;
    } else {
      _ad2 = file;
    }
    // A slot holds one creative. Attaching a file drops whatever link was
    // there, so the two can never both be sent for the same slot.
    if (file != null) _adYoutubeUrls.remove(slot);
    notifyListeners();
  }

  String? adYoutubeUrl(int slot) => _adYoutubeUrls[slot];

  /// Sets or clears the YouTube link on [slot]. Passing null or blank clears
  /// it; setting one drops any file queued for that slot.
  void setAdYoutubeUrl(int slot, String? url) {
    if (slot != 1 && slot != 2) return;
    final text = url?.trim() ?? '';
    if (text.isEmpty) {
      _adYoutubeUrls.remove(slot);
    } else {
      _adYoutubeUrls[slot] = text;
      setAd(slot, null);
      _replacedAdFiles.remove(slot);
      // Putting a link in is the opposite of emptying the slot.
      _removedAdSlots.remove(slot);
    }
    notifyListeners();
  }

  /// Marks the ad in this slot to be cleared when the form is submitted.
  void removeAdSlot(int slot) {
    if (slot != 1 && slot != 2) return;
    _removedAdSlots.add(slot);
    // A creative queued for this slot is moot once the slot is being emptied.
    _replacedAdFiles.remove(slot);
    _adYoutubeUrls.remove(slot);
    setAd(slot, null);
    notifyListeners();
  }

  void undoRemoveAdSlot(int slot) {
    if (!_removedAdSlots.remove(slot)) return;
    notifyListeners();
  }

  /// Queues a new creative for a slot that already holds one. Sent as
  /// `ad_1` / `ad_2` with the story update, which overwrites that place — so
  /// this needs nothing from the ads API and no id.
  void replaceAdInSlot(int slot, File file) {
    if (slot != 1 && slot != 2) return;
    _replacedAdFiles[slot] = file;
    _adYoutubeUrls.remove(slot);
    // Replacing is the opposite of clearing — un-mark it if it was queued to go.
    _removedAdSlots.remove(slot);
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
      final districtIds = (_districtsByState[state.id] ?? [])
          .map((d) => d.id)
          .toList();
      _selectedDistrictIds.removeWhere(districtIds.contains);
      for (final dId in districtIds) {
        final mandalIds = (_mandalsByDistrict[dId] ?? [])
            .map((m) => m.id)
            .toList();
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
          _districtsByState[state.id] = await _districtRepository
              .getDistrictsByState(state.id);
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
      final mandalIds = (_mandalsByDistrict[district.id] ?? [])
          .map((m) => m.id)
          .toList();
      _selectedMandalIds.removeWhere(mandalIds.contains);
      notifyListeners();
    } else {
      _selectedDistrictIds.add(district.id);
      notifyListeners();
      if (!_mandalsByDistrict.containsKey(district.id)) {
        _loadingMandalDistrictIds.add(district.id);
        notifyListeners();
        try {
          _mandalsByDistrict[district.id] = await _mandalRepository
              .getMandalsByDistrict(district.id);
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

  // Bulk select all districts and fetch mandals in parallel
  Future<void> selectAllDistricts(List<District> districts) async {
    for (final d in districts) {
      if (!_selectedDistrictIds.contains(d.id)) {
        _selectedDistrictIds.add(d.id);
      }
    }
    notifyListeners();

    // Fetch mandals for districts that haven't been loaded yet, in parallel
    final toFetch = districts
        .where((d) => !_mandalsByDistrict.containsKey(d.id))
        .toList();
    if (toFetch.isNotEmpty) {
      final futures = toFetch.map((d) async {
        try {
          _mandalsByDistrict[d.id] = await _mandalRepository
              .getMandalsByDistrict(d.id);
        } catch (_) {
          _mandalsByDistrict[d.id] = [];
        }
      });
      await Future.wait(futures);
      notifyListeners();
    }
  }

  void deselectAllDistricts(List<District> districts) {
    final ids = districts.map((d) => d.id).toSet();
    _selectedDistrictIds.removeWhere(ids.contains);
    // Also deselect mandals belonging to these districts
    for (final d in districts) {
      final mandalIds = (_mandalsByDistrict[d.id] ?? [])
          .map((m) => m.id)
          .toList();
      _selectedMandalIds.removeWhere(mandalIds.contains);
    }
    notifyListeners();
  }

  // Bulk select/deselect all mandals
  void selectAllMandals(List<Mandal> mandals) {
    for (final m in mandals) {
      if (!_selectedMandalIds.contains(m.id)) {
        _selectedMandalIds.add(m.id);
      }
    }
    notifyListeners();
  }

  void deselectAllMandals(List<Mandal> mandals) {
    final ids = mandals.map((m) => m.id).toSet();
    _selectedMandalIds.removeWhere(ids.contains);
    notifyListeners();
  }

  // ── Prefill from existing news (for editing pending news) ──────────────────
  Future<void> prefillFromNews({
    required List<Topic> allTopics,
    required List<int> topicIds,
    required List<int> stateIds,
    required List<int> districtIds,
    required List<int> mandalIds,
    List<NewsMedia> existingMedia = const [],
    List<NewsAd> existingAds = const [],
  }) async {
    clearData();

    // Set existing media from the news
    _existingMedia.addAll(existingMedia);
    _existingAds.addAll(existingAds);
    // Put a slot's link back in its field, so saving an edit that didn't touch
    // the ads doesn't clear them.
    for (final ad in existingAds) {
      if (ad.isYoutube && ad.hasSlot) _adYoutubeUrls[ad.slot] = ad.url;
    }

    // Wait for states to load if not already loaded
    await loadStates();

    // Select topics. A topic the article carries but the topic list doesn't
    // know about is dropped here, which is how an edit can silently come back
    // with no topic selected and a Publish button that never enables — so say
    // so rather than failing quietly.
    for (final topicId in topicIds) {
      final match = allTopics.where((t) => t.id == topicId);
      if (match.isNotEmpty) {
        _selectedCategories.add(match.first);
      } else {
        debugPrint(
          '[prefill] topic $topicId is on the article but not in the '
          'topic list (${allTopics.length} loaded) — not selected.',
        );
      }
    }
    debugPrint(
      '[prefill] topics: article=$topicIds, available=${allTopics.length}, '
      'selected=${_selectedCategories.map((t) => t.id).toList()}, '
      'availableIds=${allTopics.map((t) => t.id).toList()}',
    );

    // Select states and load their districts
    for (final sId in stateIds) {
      final match = _availableStates.where((s) => s.id == sId);
      if (match.isNotEmpty) {
        await toggleState(match.first);
      }
    }

    // Select districts and load their mandals
    for (final dId in districtIds) {
      final match = availableDistricts.where((d) => d.id == dId);
      if (match.isNotEmpty) {
        await toggleDistrict(match.first);
      }
    }

    // Select mandals
    for (final mId in mandalIds) {
      final match = availableMandals.where((m) => m.id == mId);
      if (match.isNotEmpty) {
        if (!_selectedMandalIds.contains(mId)) {
          _selectedMandalIds.add(mId);
        }
      }
    }

    notifyListeners();
  }

  // ── Upload ──────────────────────────────────────────────────────────────────
  void clearData() {
    _selectedMedia.clear();
    _existingMedia.clear();
    _isMoreChecked = false;
    _selectedCategories.clear();
    _selectedStateIds.clear();
    _selectedDistrictIds.clear();
    _selectedMandalIds.clear();
    _acceptTerms = false;
    // The ad slots have to be reset here too. This view model is a plain
    // (non-autoDispose) provider, so it outlives the upload screen: leaving the
    // files behind meant the next story opened with the last one's creatives
    // still attached, and posted them again without the author ever picking an
    // ad.
    _ad1 = null;
    _ad2 = null;
    _existingAds.clear();
    _removedAdSlots.clear();
    _replacedAdFiles.clear();
    _adYoutubeUrls.clear();
    _deletedMediaIds.clear();
    notifyListeners();
  }

  Future<bool> uploadNews({
    required String headline,
    required String description,
    required String content,
    required List<Topic> categories,
    required List<File> mediaFiles,
    int? editNewsId,
    String? status,
    bool skipLocationValidation = false,
    bool isImportant = false,
    bool isComment = true,
    bool showProfile = true,
    bool isSendNotification = true,
    String? titleColor,
    String? descriptionColor,
    String? fullTextColor,
  }) async {
    _isUploading = true;
    _error = null;
    notifyListeners();

    try {
      if (!skipLocationValidation) {
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
      }

      // Compress media files before uploading
      final processedFiles = <File>[];
      // Server-side limit per file. Keep ~500 KB under to leave room for
      // multipart overhead. If you bump the backend limit, bump this too.
      const maxBytesPerFile = 10 * 1024 * 1024 - 500 * 1024; // ~9.5 MB
      for (final file in mediaFiles) {
        final path = file.path.toLowerCase();
        if (path.endsWith('.mp4') ||
            path.endsWith('.mov') ||
            path.endsWith('.avi') ||
            path.endsWith('.mkv') ||
            path.endsWith('.webm')) {
          // Video compression
          try {
            final info = await VideoCompress.compressVideo(
              file.path,
              quality: VideoQuality.MediumQuality,
              deleteOrigin: false,
            );
            if (info != null && info.file != null) {
              processedFiles.add(info.file!);
            } else {
              processedFiles.add(file);
            }
          } catch (e) {
            debugPrint('Video compression failed, using original: $e');
            processedFiles.add(file);
          }
        } else if (path.endsWith('.jpg') ||
            path.endsWith('.jpeg') ||
            path.endsWith('.png') ||
            path.endsWith('.webp')) {
          // Image compression — skip if already small (< 1MB)
          try {
            final fileSize = await file.length();
            if (fileSize > 1024 * 1024) {
              // Read, decode, re-encode at 80% quality with max 1920px dimension
              final bytes = await file.readAsBytes();
              final image = await decodeImageFromList(bytes);
              final scale = image.width > 1920 ? 1920 / image.width : 1.0;

              if (scale < 1.0) {
                // Resize needed — use image_picker's built-in resize if available
                // For now, just send original since proper resize needs image package
                processedFiles.add(file);
              } else {
                processedFiles.add(file);
              }
            } else {
              processedFiles.add(file);
            }
          } catch (e) {
            debugPrint('Image check failed, using original: $e');
            processedFiles.add(file);
          }
        } else {
          processedFiles.add(file);
        }
      }

      // Fail fast if any processed file is still over the backend limit.
      // Without this we'd waste minutes uploading a 24 MB video only for
      // the server to reject it with `files.0: max 10240 KB`.
      for (var i = 0; i < processedFiles.length; i++) {
        final size = await processedFiles[i].length();
        if (size > maxBytesPerFile) {
          final mb = (size / (1024 * 1024)).toStringAsFixed(1);
          _error =
              'File ${i + 1} is $mb MB — exceeds the 10 MB per-file '
              'limit. Please pick a shorter video or smaller image.';
          _isUploading = false;
          notifyListeners();
          return false;
        }
      }

      final newsRequest = CreateNewsRequest(
        topicIds: categories.map((t) => t.id).toList(),
        status: status ?? (editNewsId != null ? 'published' : 'pending'),
        title: headline,
        slug: _generateSlug(headline),
        shortDescription: description,
        content: content.isNotEmpty ? content : description,
        stateIds: List.from(_selectedStateIds),
        districtIds: List.from(_selectedDistrictIds),
        mandalIds: List.from(_selectedMandalIds),
        files: processedFiles,
        // A slot's file is the editor's replacement when they picked one, and
        // whatever was attached to an empty slot otherwise. Posting it at that
        // slot is what overwrites the creative already there.
        ad1: adFileForSlot(1),
        ad2: adFileForSlot(2),
        deleteMediaIds: _deletedMediaIds.toList()..sort(),
        youtubeUrl1: _adYoutubeUrls[1],
        youtubeUrl2: _adYoutubeUrls[2],
        removeAd1: _removedAdSlots.contains(1),
        removeAd2: _removedAdSlots.contains(2),
        isImportant: isImportant,
        isComment: isComment,
        showProfile: showProfile,
        isSendNotification: isSendNotification,
        titleColor: titleColor,
        descriptionColor: descriptionColor,
        fullTextColor: fullTextColor,
      );

      if (editNewsId != null) {
        await _newsRepository.updateNews(editNewsId, newsRequest);
        _lastUploadedNewsId = editNewsId;
        // The ad edits rode along in that same request, so a saved story means
        // saved ads — there's no second call to keep in step with this one.
        _removedAdSlots.clear();
        _replacedAdFiles.clear();
        _deletedMediaIds.clear();
      } else {
        final created = await _newsRepository.createNews(newsRequest);
        _lastUploadedNewsId = created?.id;
      }
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
        .map(
          (w) => w.toLowerCase().replaceAll(
            RegExp(r'[^\p{L}\p{N}]', unicode: true),
            '',
          ),
        )
        .where((w) => w.isNotEmpty)
        .toList();

    final titlePart = parts.isNotEmpty ? parts.join('-') : 'news';
    return '$titlePart-$timestamp';
  }
}
