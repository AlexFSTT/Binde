import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/story_model.dart';
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

  File? _selectedFile;
  String _mediaType = 'image';
  bool _isUploading = false;

  // Overlays — draggable text & emoji
  final List<_EditableOverlay> _overlays = [];
  int? _activeOverlayIndex;

  // Location
  String? _locationName;

  // Text editor
  bool _showTextEditor = false;
  final TextEditingController _textEditController = TextEditingController();
  Color _textColor = Colors.white;
  bool _textHasBg = true;
  double _textFontSize = 24;

  // Available text colors
  static const _textColors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.cyan,
    Colors.blue,
    Colors.purple,
    Colors.pink,
  ];

  // Popular sticker emojis
  static const _stickerEmojis = [
    '😂', '❤️', '🔥', '😍', '🎉', '👏', '💯', '🙌',
    '😎', '🤩', '💪', '🎊', '⭐', '🌈', '🦋', '🌺',
    '🍕', '🎸', '🏆', '💎', '🚀', '🎯', '🍀', '🌟',
  ];

  @override
  void dispose() {
    _textEditController.dispose();
    super.dispose();
  }

  // ============ MEDIA PICKING ============

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

  // ============ TEXT OVERLAY ============

  void _openTextEditor() {
    _textEditController.clear();
    _textColor = Colors.white;
    _textHasBg = true;
    _textFontSize = 24;
    setState(() => _showTextEditor = true);
  }

  void _addTextOverlay() {
    if (_textEditController.text.trim().isEmpty) {
      setState(() => _showTextEditor = false);
      return;
    }

    setState(() {
      _overlays.add(_EditableOverlay(
        overlay: StoryOverlay(
          type: 'text',
          content: _textEditController.text.trim(),
          x: 0.5,
          y: 0.4,
          color: '#${_textColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
          fontSize: _textFontSize,
          hasBg: _textHasBg,
        ),
      ));
      _showTextEditor = false;
    });
    _textEditController.clear();
  }

  // ============ EMOJI STICKERS ============

  void _showStickerPicker() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: 280,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Stickers', style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: cs.onSurface,
            )),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _stickerEmojis.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _addEmojiOverlay(_stickerEmojis[i]);
                  },
                  child: Center(
                    child: Text(_stickerEmojis[i],
                        style: const TextStyle(fontSize: 28)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addEmojiOverlay(String emoji) {
    setState(() {
      _overlays.add(_EditableOverlay(
        overlay: StoryOverlay(
          type: 'emoji',
          content: emoji,
          x: 0.5,
          y: 0.4 + (_overlays.length * 0.05), // Slight offset for each new one
          scale: 1.5,
        ),
      ));
    });
  }

  // ============ LOCATION ============

  void _showLocationDialog() {
    final controller = TextEditingController(text: _locationName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.location_on, size: 20),
            const SizedBox(width: 8),
            Text(context.tr('add_location')),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.tr('location_hint'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          if (_locationName != null)
            TextButton(
              onPressed: () {
                setState(() => _locationName = null);
                Navigator.pop(ctx);
              },
              child: Text(context.tr('remove'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              setState(() => _locationName = text.isEmpty ? null : text);
              Navigator.pop(ctx);
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }

  // ============ PUBLISH ============

  Future<void> _publish() async {
    if (_selectedFile == null) return;

    setState(() => _isUploading = true);

    final storyOverlays = _overlays.map((e) => e.overlay).toList();

    final story = await _storyService.createStory(
      file: _selectedFile!,
      mediaType: _mediaType,
      overlays: storyOverlays,
      locationName: _locationName,
    );

    if (mounted) {
      setState(() => _isUploading = false);
      if (story != null) {
        Navigator.pop(context, true);
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

  // ============ OVERLAY INTERACTION ============

  void _onOverlayPanUpdate(int index, DragUpdateDetails details, Size screenSize) {
    setState(() {
      final o = _overlays[index].overlay;
      _overlays[index] = _EditableOverlay(
        overlay: o.copyWith(
          x: (o.x + details.delta.dx / screenSize.width).clamp(0.05, 0.95),
          y: (o.y + details.delta.dy / screenSize.height).clamp(0.05, 0.95),
        ),
      );
    });
  }

  void _deleteOverlay(int index) {
    setState(() {
      _overlays.removeAt(index);
      _activeOverlayIndex = null;
    });
  }

  // ============ BUILD ============

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _showTextEditor
          ? null
          : AppBar(
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
                      style: FilledButton.styleFrom(backgroundColor: cs.primary),
                    ),
                  ),
              ],
            ),
      body: _selectedFile == null
          ? _buildPicker(cs)
          : _showTextEditor
              ? _buildTextEditor(cs)
              : _buildEditor(cs),
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
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPickerBtn(Icons.camera_alt_rounded,
                  context.tr('camera'), cs.primary, _takePhoto),
              const SizedBox(width: 20),
              _buildPickerBtn(Icons.image_rounded,
                  context.tr('photo'), Colors.green, _pickImage),
              const SizedBox(width: 20),
              _buildPickerBtn(
                  Icons.videocam_rounded, 'Video', Colors.red, _pickVideo),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickerBtn(
      IconData icon, String label, Color color, VoidCallback onTap) {
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
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEditor(ColorScheme cs) {
    return LayoutBuilder(builder: (context, constraints) {
      final screenSize = Size(constraints.maxWidth, constraints.maxHeight);

      return Stack(
        fit: StackFit.expand,
        children: [
          // Media preview
          if (_mediaType == 'image')
            Image.file(_selectedFile!, fit: BoxFit.contain)
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam, size: 60, color: cs.primary),
                  const SizedBox(height: 12),
                  Text('Video selected',
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.6))),
                ],
              ),
            ),

          // Draggable overlays
          ..._overlays.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final o = item.overlay;

            return Positioned(
              left: o.x * screenSize.width - 50,
              top: o.y * screenSize.height - 25,
              child: GestureDetector(
                onPanUpdate: (d) => _onOverlayPanUpdate(i, d, screenSize),
                onTap: () => setState(() => _activeOverlayIndex =
                    _activeOverlayIndex == i ? null : i),
                onLongPress: () => _deleteOverlay(i),
                child: Transform.rotate(
                  angle: o.rotation,
                  child: Transform.scale(
                    scale: o.scale,
                    child: o.isEmoji
                        ? Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Text(o.content,
                                  style: const TextStyle(fontSize: 40)),
                              if (_activeOverlayIndex == i)
                                Positioned(
                                  right: -8,
                                  top: -8,
                                  child: _buildDeleteBadge(),
                                ),
                            ],
                          )
                        : Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: o.hasBg == true
                                      ? Colors.black.withValues(alpha: 0.5)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  o.content,
                                  style: TextStyle(
                                    color: o.color != null
                                        ? Color(int.parse(
                                                '0xFF${o.color!.replaceFirst('#', '')}'))
                                        : Colors.white,
                                    fontSize: o.fontSize ?? 24,
                                    fontWeight: FontWeight.w600,
                                    shadows: o.hasBg != true
                                        ? const [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 4,
                                              offset: Offset(1, 1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                              if (_activeOverlayIndex == i)
                                Positioned(
                                  right: -8,
                                  top: -8,
                                  child: _buildDeleteBadge(),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          }),

          // Location badge
          if (_locationName != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(_locationName!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom toolbar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildToolBtn(Icons.refresh, context.tr('change'),
                        () => setState(() => _selectedFile = null)),
                    _buildToolBtn(
                        Icons.text_fields, context.tr('text'), _openTextEditor),
                    _buildToolBtn(Icons.emoji_emotions, 'Stickers',
                        _showStickerPicker),
                    _buildToolBtn(Icons.location_on,
                        context.tr('location'), _showLocationDialog),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildDeleteBadge() {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.close, size: 12, color: Colors.white),
    );
  }

  Widget _buildToolBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
        ],
      ),
    );
  }

  // ============ TEXT EDITOR ============

  Widget _buildTextEditor(ColorScheme cs) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _showTextEditor = false),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  // Background toggle
                  GestureDetector(
                    onTap: () => setState(() => _textHasBg = !_textHasBg),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _textHasBg
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.format_color_fill,
                              size: 16, color: Colors.white.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text('BG',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _addTextOverlay,
                    style: FilledButton.styleFrom(backgroundColor: cs.primary),
                    child: Text(context.tr('done')),
                  ),
                ],
              ),
            ),

            // Font size slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Text('A',
                      style: TextStyle(color: Colors.white54, fontSize: 14)),
                  Expanded(
                    child: Slider(
                      value: _textFontSize,
                      min: 14,
                      max: 48,
                      activeColor: cs.primary,
                      onChanged: (v) => setState(() => _textFontSize = v),
                    ),
                  ),
                  const Text('A',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // Text input preview
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _textHasBg
                        ? Colors.black.withValues(alpha: 0.5)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _textEditController,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    maxLines: null,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: _textFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: context.tr('type_text'),
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: _textFontSize),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),

            // Color picker
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _textColors.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => setState(() => _textColor = _textColors[i]),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _textColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _textColor == _textColors[i]
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.2),
                        width: _textColor == _textColors[i] ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Internal editable overlay wrapper
class _EditableOverlay {
  StoryOverlay overlay;
  _EditableOverlay({required this.overlay});
}