import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaPickerService {
  final ImagePicker _picker = ImagePicker();

  /// Request the correct media permission based on Android version.
  /// Android 13+ uses granular permissions (photos/videos).
  /// Android 12 and below uses storage permission.
  Future<bool> _requestMediaPermission({bool isVideo = false}) async {
    if (!Platform.isAndroid) return true;

    // Try granular permission first (Android 13+)
    final granularPermission = isVideo ? Permission.videos : Permission.photos;
    var status = await granularPermission.status;

    if (status.isGranted) return true;

    // Request granular permission
    status = await granularPermission.request();
    if (status.isGranted) return true;

    // If granular fails (Android 12 and below), try storage permission
    if (status.isPermanentlyDenied || status.isDenied) {
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;
    }

    return false;
  }

  /// Pick multiple photos from gallery
  Future<List<File>> pickImages() async {
    final granted = await _requestMediaPermission();
    if (!granted) {
      // Still try — image_picker might handle it internally
      debugPrint('Media permission not explicitly granted, trying picker anyway');
    }

    try {
      final images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      return images.map((x) => File(x.path)).toList();
    } catch (e) {
      throw 'Failed to pick images: $e';
    }
  }

  /// Request audio media permission (Android 13+ READ_MEDIA_AUDIO, with a
  /// storage fallback for Android 12 and below).
  Future<bool> _requestAudioPermission() async {
    if (!Platform.isAndroid) return true;

    var status = await Permission.audio.status;
    if (status.isGranted) return true;

    status = await Permission.audio.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied || status.isDenied) {
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) return true;
    }
    return false;
  }

  /// Pick a single audio file. Uses file_picker since image_picker cannot
  /// select audio. The backend infers the media type from the uploaded file.
  Future<File?> pickAudio() async {
    final granted = await _requestAudioPermission();
    if (!granted) {
      debugPrint('Audio permission not explicitly granted, trying picker anyway');
    }

    try {
      final result = await FilePicker.pickFiles(type: FileType.audio);
      final path = result?.files.single.path;
      return path != null ? File(path) : null;
    } catch (e) {
      throw 'Failed to pick audio: $e';
    }
  }

  /// Pick single video from gallery
  Future<File?> pickVideo() async {
    final granted = await _requestMediaPermission(isVideo: true);
    if (!granted) {
      debugPrint('Video permission not explicitly granted, trying picker anyway');
    }

    try {
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      return video != null ? File(video.path) : null;
    } catch (e) {
      throw 'Failed to pick video: $e';
    }
  }

  /// Capture photo from camera
  Future<File?> capturePhoto() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      throw 'Camera permission denied';
    }

    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      throw 'Failed to capture photo: $e';
    }
  }
}
