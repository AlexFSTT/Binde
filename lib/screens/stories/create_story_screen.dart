import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/story_service.dart';
import '../../l10n/app_localizations.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final StoryService _storyService = StoryService();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textController = TextEditingController();

  File? _selectedFile;
  String _mediaType = 'image';
  bool _isUploading = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _selectedFile = File(picked.path);
        _mediaType = 'image';
      });
    }
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (picked != null) {
      setState(() {
        _selectedFile = File(picked.path);
        _mediaType = 'video';
      });
    }
  }

  Future<void> _takePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _selectedFile = File(picked.path);
        _mediaType = 'image';
      });
    }
  }

  Future<void> _publish() async {
    if (_selectedFile == null) return;

    setState(() => _isUploading = true);

    final story = await _storyService.createStory(
      file: _selectedFile!,
      mediaType: _mediaType,
      textOverlay:
          _textController.text.trim().isEmpty ? null : _textController.text.trim(),
    );

    if (mounted) {
      setState(() => _isUploading = false);
      if (story != null) {
        Navigator.pop(context, true); // Signal refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('error')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(context.tr('new_story')),
        actions: [
          if (_selectedFile != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _isUploading ? null : _publish,
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, size: 18),
                label: Text(context.tr('publish')),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                ),
              ),
            ),
        ],
      ),
      body: _selectedFile == null ? _buildPicker(cs) : _buildPreview(cs),
    );
  }

  Widget _buildPicker(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome,
              size: 60, color: cs.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 24),
          Text(
            context.tr('create_story_hint'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPickerButton(
                icon: Icons.camera_alt_rounded,
                label: context.tr('camera'),
                color: cs.primary,
                onTap: _takePhoto,
              ),
              const SizedBox(width: 20),
              _buildPickerButton(
                icon: Icons.image_rounded,
                label: context.tr('photo'),
                color: Colors.green,
                onTap: _pickImage,
              ),
              const SizedBox(width: 20),
              _buildPickerButton(
                icon: Icons.videocam_rounded,
                label: 'Video',
                color: Colors.red,
                onTap: _pickVideo,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildPreview(ColorScheme cs) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Preview
        if (_mediaType == 'image')
          Image.file(_selectedFile!, fit: BoxFit.contain)
        else
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam, size: 60, color: cs.primary),
                const SizedBox(height: 12),
                Text(
                  'Video selected',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),

        // Text overlay input at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: context.tr('add_text_overlay'),
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
        ),

        // Change media button
        Positioned(
          left: 16,
          bottom: 100,
          child: GestureDetector(
            onTap: () => setState(() => _selectedFile = null),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 22),
            ),
          ),
        ),
      ],
    );
  }
}