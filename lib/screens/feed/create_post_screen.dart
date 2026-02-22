import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/feed_service.dart';

/// Ecran pentru crearea unei postări noi
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final FeedService _feedService = FeedService();
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  String _visibility = 'public'; // 'public' sau 'friends'
  bool _isPosting = false;

  // Datele userului curent
  String? _myName;
  String? _myAvatar;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadMyProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _myName = profile['full_name'] as String?;
          _myAvatar = profile['avatar_url'] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (picked != null && mounted) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _removeImage() {
    setState(() => _selectedImage = null);
  }

  void _toggleVisibility() {
    setState(() {
      _visibility = _visibility == 'public' ? 'friends' : 'public';
    });
  }

  bool get _canPost =>
      _contentController.text.trim().isNotEmpty || _selectedImage != null;

  Future<void> _submitPost() async {
    if (!_canPost || _isPosting) return;

    setState(() => _isPosting = true);

    final post = await _feedService.createPost(
      content: _contentController.text.trim(),
      visibility: _visibility,
      imageFile: _selectedImage,
    );

    if (mounted) {
      setState(() => _isPosting = false);

      if (post != null) {
        Navigator.pop(context, post);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create post'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _canPost && !_isPosting ? _submitPost : null,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Post'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: avatar + nume + visibility
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: colorScheme.primaryContainer,
                        backgroundImage: _myAvatar != null
                            ? NetworkImage(_myAvatar!)
                            : null,
                        child: _myAvatar == null
                            ? Text(
                                (_myName ?? '?')[0].toUpperCase(),
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _myName ?? 'You',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Visibility picker
                          InkWell(
                            onTap: _toggleVisibility,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _visibility == 'public'
                                        ? Icons.public
                                        : Icons.people,
                                    size: 14,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _visibility == 'public'
                                        ? 'Public'
                                        : 'Friends',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    size: 16,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Text input
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.35),
                        fontSize: 18,
                      ),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontSize: 18),
                    onChanged: (_) => setState(() {}),
                  ),

                  // Preview imagine
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 12),
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImage!,
                            width: double.infinity,
                            height: 250,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _removeImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom toolbar
          Container(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                // Adaugă imagine
                IconButton(
                  onPressed: _pickImage,
                  icon: Icon(Icons.image_outlined,
                      color: Colors.green[600], size: 26),
                  tooltip: 'Add photo',
                ),
                const Spacer(),
                // Visibility indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _visibility == 'public' ? Icons.public : Icons.people,
                        size: 15,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _visibility == 'public' ? 'Public' : 'Friends only',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
