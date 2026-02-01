import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../services/swirls_service.dart';

/// Screen pentru upload de Swirl (video scurt)
class SwirlUploadScreen extends StatefulWidget {
  const SwirlUploadScreen({super.key});

  @override
  State<SwirlUploadScreen> createState() => _SwirlUploadScreenState();
}

class _SwirlUploadScreenState extends State<SwirlUploadScreen> {
  final SwirlsService _swirlsService = SwirlsService();
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  String? _selectedCategory;
  XFile? _selectedVideo;
  VideoPlayerController? _videoController;
  int _videoDuration = 0;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  final List<String> _categories = [
    'Entertainment',
    'Education',
    'Sports',
    'Music',
    'Gaming',
    'Comedy',
    'Food',
    'Travel',
    'Fashion',
    'Technology',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      final video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10), // Max 10 minutes
      );

      if (video != null) {
        // Dispose old controller if exists
        _videoController?.dispose();

        // Initialize new video controller
        final controller = VideoPlayerController.file(File(video.path));
        await controller.initialize();

        final duration = controller.value.duration.inSeconds;

        // Validare durată
        if (!_swirlsService.validateDuration(duration)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_swirlsService.getDurationErrorMessage(duration)),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          controller.dispose();
          return;
        }

        setState(() {
          _selectedVideo = video;
          _videoController = controller;
          _videoDuration = duration;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadSwirl() async {
    if (!_formKey.currentState!.validate() || _selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields and select a video'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Simulare progress pentru upload
      for (var i = 0; i <= 30; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted) {
          setState(() {
            _uploadProgress = i / 100;
          });
        }
      }

      // Upload video
      final fileName = 'swirl_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final videoUrl = await _swirlsService.uploadVideo(
        _selectedVideo!.path,
        fileName,
      );

      // Update progress
      if (mounted) {
        setState(() {
          _uploadProgress = 0.7;
        });
      }

      // Create swirl in database
      await _swirlsService.createSwirl(
        title: _titleController.text.trim(),
        videoUrl: videoUrl,
        durationSeconds: _videoDuration,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        category: _selectedCategory,
      );

      // Complete progress
      if (mounted) {
        setState(() {
          _uploadProgress = 1.0;
        });
      }

      // Show success and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Swirl uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to refresh feed
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Swirl'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Video preview / picker
              _buildVideoSection(colorScheme),
              const SizedBox(height: 24),
              
              // Title field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'Give your swirl a catchy title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  if (value.trim().length < 3) {
                    return 'Title must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Description field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Tell viewers what your swirl is about',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              
              // Category dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                hint: const Text('Select a category'),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              
              // Upload progress
              if (_isUploading) ...[
                LinearProgressIndicator(
                  value: _uploadProgress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_uploadProgress * 100).toInt()}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.primary),
                ),
                const SizedBox(height: 16),
              ],
              
              // Upload button
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadSwirl,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload),
                label: Text(_isUploading ? 'Uploading...' : 'Upload Swirl'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              
              // Info text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Requirements',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('• Video duration: 10 seconds to 10 minutes'),
                    const Text('• Format: MP4, MOV, AVI'),
                    const Text('• Vertical videos work best (9:16)'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoSection(ColorScheme colorScheme) {
    if (_selectedVideo == null) {
      return GestureDetector(
        onTap: _pickVideo,
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outline,
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Select Video',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to choose a video from gallery',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Video preview
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: _videoController != null
              ? AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                )
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
        ),
        const SizedBox(height: 12),
        
        // Video info and actions
        Row(
          children: [
            Icon(Icons.timer, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              _formatDuration(_videoDuration),
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Change Video'),
            ),
          ],
        ),
        
        // Play/Pause button
        Center(
          child: IconButton(
            icon: Icon(
              _videoController?.value.isPlaying ?? false
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
              size: 48,
              color: colorScheme.primary,
            ),
            onPressed: () {
              setState(() {
                if (_videoController?.value.isPlaying ?? false) {
                  _videoController?.pause();
                } else {
                  _videoController?.play();
                }
              });
            },
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}
