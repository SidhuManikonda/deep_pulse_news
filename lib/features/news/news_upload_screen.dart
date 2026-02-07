import 'package:deep_pulse_news/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../shared/widgets/auto_scaled_text.dart';
import '../../shared/widgets/custom_button.dart';
import 'news_upload_view_model.dart';

class NewsUploadScreen extends ConsumerStatefulWidget {
  const NewsUploadScreen({super.key});

  @override
  ConsumerState<NewsUploadScreen> createState() => _NewsUploadScreenState();
}

class _NewsUploadScreenState extends ConsumerState<NewsUploadScreen> {
  final _headlineController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _moreController = TextEditingController();
  
  String? _selectedCategory;
  final List<File> _selectedMedia = [];
  bool _acceptTerms = false;

  @override
  void initState() {
    super.initState();
    ref.read(topicViewModelProvider).loadTopics();
  }

  @override
  void dispose() {
    _headlineController.dispose();
    _descriptionController.dispose();
    _moreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uploadViewModel = ref.watch(newsUploadViewModelProvider);
    final topicViewModel = ref.watch(topicViewModelProvider);
    final categories = topicViewModel.topics.map((topic) => topic.name).toList();
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: AutoScaledText(
          'Upload News',
          style: TextStyle(
            fontSize: appFontSizeHeader,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.headlineLarge?.color,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload section
            _buildUploadSection(),
            
            const SizedBox(height: 24),
            
            // Headline section
            _buildHeadlineSection(),
            
            const SizedBox(height: 24),
            
            // Description section
            _buildDescriptionSection(),
            
            const SizedBox(height: 24),
            
            // More section
            _buildMoreSection(),
            
            const SizedBox(height: 24),
            
            // Category selection
            _buildCategorySection(categories),
            
            const SizedBox(height: 24),
            
            // Terms and conditions
            _buildTermsSection(),
            
            const SizedBox(height: 24),
            
            // Send button
            _buildSendButton(uploadViewModel),
            
            const SizedBox(height: 16),
            
            // Note
            _buildNoteSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoScaledText(
          'Upload (For Reporter and Reader)',
          style: TextStyle(
            fontSize: appFontSizeBody,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            // Media upload area
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _showMediaPicker,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).appGrey300,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _selectedMedia.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add,
                              size: 40,
                              color: Theme.of(context).appGrey400,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 2,
                              width: 60,
                              decoration: BoxDecoration(
                                color: Colors.purple,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ],
                        )
                      : _buildMediaPreview(),
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Media type label
            Expanded(
              child: AutoScaledText(
                'Photos /\nVideo/\nAudio',
                style: TextStyle(
                  fontSize: appFontSizeBody,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaPreview() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _selectedMedia.length,
      itemBuilder: (context, index) {
        final file = _selectedMedia[index];
        final extension = file.path.toLowerCase().split('.').last;
        final isImage = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
        final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'wmv'].contains(extension);
        final isAudio = ['mp3', 'wav', 'm4a', 'aac', 'flac'].contains(extension);

        Widget mediaWidget;
        if (isImage) {
          mediaWidget = Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: FileImage(file),
                fit: BoxFit.cover,
              ),
            ),
          );
        } else if (isVideo) {
          mediaWidget = Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
            ),
            child: const Icon(
              Icons.video_file,
              size: 50,
              color: Colors.grey,
            ),
          );
        } else if (isAudio) {
          mediaWidget = Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
            ),
            child: const Icon(
              Icons.audio_file,
              size: 50,
              color: Colors.grey,
            ),
          );
        } else {
          mediaWidget = Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
            ),
            child: const Icon(
              Icons.file_present,
              size: 50,
              color: Colors.grey,
            ),
          );
        }

        return Stack(
          children: [
            mediaWidget,
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeMedia(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeadlineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AutoScaledText(
              'Headline',
              style: TextStyle(
                fontSize: appFontSizeBody,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const Spacer(),
            AutoScaledText(
              '${_headlineController.text.length} / 100',
              style: TextStyle(
                fontSize: appFontSizeCaption,
                color: Theme.of(context).appGrey600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AutoScaledText(
          'Letters in colour option',
          style: TextStyle(
            fontSize: appFontSizeCaption,
            color: Theme.of(context).appGrey600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _headlineController,
          maxLength: 100,
          maxLines: 2,
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).appGrey300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).appGrey300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            counterText: '',
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoScaledText(
          'Description',
          style: TextStyle(
            fontSize: appFontSizeBody,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 5,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).appGrey300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).appGrey300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildMoreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: true,
              onChanged: (value) {},
              activeColor: Colors.blue,
            ),
            const SizedBox(width: 8),
            AutoScaledText(
              'More',
              style: TextStyle(
                fontSize: appFontSizeBody,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _moreController,
          maxLines: 4,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).appGrey300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).appGrey300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(List<String> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoScaledText(
          'Select category',
          style: TextStyle(
            fontSize: appFontSizeBody,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 12),
        
        ...List.generate(categories.length, (index) {
          final category = categories[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Radio<String>(
                  value: category,
                  groupValue: _selectedCategory,
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  activeColor: Colors.blue,
                ),
                const SizedBox(width: 8),
                AutoScaledText(
                  category,
                  style: TextStyle(
                    fontSize: appFontSizeBody,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTermsSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _acceptTerms,
          onChanged: (value) {
            setState(() {
              _acceptTerms = value ?? false;
            });
          },
          activeColor: Colors.blue,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AutoScaledText(
            'Accept terms and conditions',
            style: TextStyle(
              fontSize: appFontSizeBody,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton(NewsUploadViewModel uploadViewModel) {
    final isFormValid = _headlineController.text.isNotEmpty &&
        _descriptionController.text.isNotEmpty &&
        _selectedCategory != null &&
        _acceptTerms;

    return SizedBox(
      width: double.infinity,
      child: CustomButton(
        text: uploadViewModel.isUploading ? 'SENDING...' : 'SEND',
        onPressed: isFormValid && !uploadViewModel.isUploading
            ? _handleSendNews
            : null,
        backgroundColor: const Color(0xFF4CAF50),
        textColor: Colors.white,
      ),
    );
  }

  Widget _buildNoteSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AutoScaledText(
            'Note: Send to Admin, sub admin and Editor with his ( sender ) name and mobile number',
            style: TextStyle(
              fontSize: appFontSizeCaption,
              color: Colors.red.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose Photos'),
              onTap: () {
                Navigator.pop(context);
                _pickPhotos();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Choose Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickMediaFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhotos() async {
    PermissionStatus status = await Permission.photos.request();
    if (status.isGranted) {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedMedia.addAll(images.map((xFile) => File(xFile.path)));
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied for accessing photos')),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    PermissionStatus status = await Permission.videos.request();
    if (status.isGranted) {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _selectedMedia.add(File(video.path));
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied for accessing videos')),
        );
      }
    }
  }

  Future<void> _pickMediaFromCamera() async {
    PermissionStatus status = await Permission.camera.request();
    if (status.isGranted) {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        setState(() {
          _selectedMedia.add(File(photo.path));
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied for camera access')),
        );
      }
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);
    });
  }

  void _handleSendNews() async {
    final uploadViewModel = ref.read(newsUploadViewModelProvider);
    
    final success = await uploadViewModel.uploadNews(
      headline: _headlineController.text,
      description: _descriptionController.text,
      content: _moreController.text,
      category: _selectedCategory!,
      mediaFiles: _selectedMedia,
    );
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('News uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(uploadViewModel.error ?? 'Failed to upload news'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
