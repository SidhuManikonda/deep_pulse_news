import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaPickerService {
  final ImagePicker _picker = ImagePicker();

  /// Pick multiple photos from gallery
  Future<List<File>> pickImages() async {
    final status = await Permission.photos.request();
    if (!status.isGranted) {
      throw 'Photo permission denied';
    }

    final images = await _picker.pickMultiImage();
    return images.map((x) => File(x.path)).toList();
  }

  /// Pick single video from gallery
  Future<File?> pickVideo() async {
    final status = await Permission.videos.request();
    if (!status.isGranted) {
      throw 'Video permission denied';
    }

    final video = await _picker.pickVideo(source: ImageSource.gallery);
    return video != null ? File(video.path) : null;
  }

  /// Capture photo from camera
  Future<File?> capturePhoto() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      throw 'Camera permission denied';
    }

    final image = await _picker.pickImage(source: ImageSource.camera);
    return image != null ? File(image.path) : null;
  }
}
