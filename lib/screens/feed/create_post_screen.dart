import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/feed_service.dart';
import '../../l10n/app_localizations.dart';

/// Ecran pentru crearea unei postări noi — cu preview live
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
  String _visibility = 'public';
  bool _isPosting = false;

  String? _myName;
  String? _myAvatar;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
    _contentController.addListener(() => setState(() {}));
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

  Future<void> _pickVideo() async {
    // Placeholder — video picking (future feature)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('coming_soon'))),
      );
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
          SnackBar(
            content: Text(context.tr('failed_create_post')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('create_post')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _canPost && !_isPosting ? _submitPost : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: _isPosting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(context.tr('post')),
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
                  // Header: avatar + name + visibility
                  _buildUserHeader(cs),

                  const SizedBox(height: 16),

                  // Text input + media toolbar in one container
                  _buildInputBox(cs),

                  const SizedBox(height: 20),

                  // Live preview
                  if (_contentController.text.trim().isNotEmpty || _selectedImage != null)
                    _buildLivePreview(cs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(ColorScheme cs) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: cs.primaryContainer,
          backgroundImage: _myAvatar != null ? NetworkImage(_myAvatar!) : null,
          child: _myAvatar == null
              ? Text(
                  (_myName ?? '?')[0].toUpperCase(),
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 2),
            InkWell(
              onTap: _toggleVisibility,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _visibility == 'public' ? Icons.public : Icons.people,
                      size: 14,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _visibility == 'public'
                          ? context.tr('post_public')
                          : context.tr('post_friends'),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputBox(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.15),
        ),
        color: cs.surfaceContainerLowest,
      ),
      child: Column(
        children: [
          // Text input
          TextField(
            controller: _contentController,
            maxLines: null,
            minLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: context.tr('whats_on_your_mind'),
              hintStyle: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.35),
                fontSize: 17,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            ),
            style: const TextStyle(fontSize: 17),
          ),

          // Thin divider
          Divider(
            height: 1,
            color: cs.outline.withValues(alpha: 0.1),
            indent: 14,
            endIndent: 14,
          ),

          // Media toolbar (image + video icons)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                // Photo picker
                IconButton(
                  onPressed: _pickImage,
                  icon: Icon(Icons.image_outlined, color: Colors.green[600], size: 24),
                  tooltip: context.tr('add_photo'),
                  splashRadius: 22,
                ),
                // Video picker
                IconButton(
                  onPressed: _pickVideo,
                  icon: Icon(Icons.videocam_outlined, color: Colors.red[400], size: 24),
                  tooltip: 'Video',
                  splashRadius: 22,
                ),
                const Spacer(),
                // Visibility pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _visibility == 'public' ? Icons.public : Icons.people,
                        size: 14,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _visibility == 'public'
                            ? context.tr('post_public')
                            : context.tr('post_friends_only'),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5),
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

  Widget _buildLivePreview(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview label
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            context.tr('preview'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.4),
              letterSpacing: 0.5,
            ),
          ),
        ),

        // Preview card (mimics feed post card)
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: cs.primaryContainer,
                      backgroundImage:
                          _myAvatar != null ? NetworkImage(_myAvatar!) : null,
                      child: _myAvatar == null
                          ? Text(
                              (_myName ?? '?')[0].toUpperCase(),
                              style: TextStyle(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
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
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              timeago.format(DateTime.now()),
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.45),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _visibility == 'friends'
                                  ? Icons.people_outline
                                  : Icons.public,
                              size: 12,
                              color: cs.onSurface.withValues(alpha: 0.35),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Text content
              if (_contentController.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    _contentController.text.trim(),
                    style: const TextStyle(fontSize: 14, height: 1.4),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              // Image preview
              if (_selectedImage != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      child: Image.file(
                        _selectedImage!,
                        width: double.infinity,
                        height: 200,
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
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),

              // Fake action bar
              if (_selectedImage == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Row(
                    children: [
                      Icon(Icons.thumb_up_outlined,
                          size: 16, color: cs.onSurface.withValues(alpha: 0.25)),
                      const SizedBox(width: 6),
                      Text(context.tr('like'),
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.25))),
                      const SizedBox(width: 20),
                      Icon(Icons.chat_bubble_outline,
                          size: 16, color: cs.onSurface.withValues(alpha: 0.25)),
                      const SizedBox(width: 6),
                      Text(context.tr('comment'),
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.25))),
                      const SizedBox(width: 20),
                      Icon(Icons.share_outlined,
                          size: 16, color: cs.onSurface.withValues(alpha: 0.25)),
                      const SizedBox(width: 6),
                      Text(context.tr('share'),
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.25))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}