import 'package:flutter/material.dart';
import '../../models/lesson_model.dart';
import '../../services/learn_service.dart';
import 'lesson_detail_screen.dart';

class LessonsListScreen extends StatefulWidget {
  const LessonsListScreen({super.key});

  @override
  State<LessonsListScreen> createState() => _LessonsListScreenState();
}

class _LessonsListScreenState extends State<LessonsListScreen> {
  final LearnService _learnService = LearnService();
  
  List<Lesson> _lessons = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Încarcă lecțiile și categoriile în paralel
      final results = await Future.wait([
        _learnService.getLessons(),
        _learnService.getCategories(),
      ]);

      setState(() {
        _lessons = results[0] as List<Lesson>;
        _categories = results[1] as List<String>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Lesson> get _filteredLessons {
    if (_selectedCategory == null) {
      return _lessons;
    }
    return _lessons.where((l) => l.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _lessons.isEmpty
                  ? _buildEmptyView()
                  : _buildLessonsList(colorScheme),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Eroare la încărcare',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Eroare necunoscută',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Încearcă din nou'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text('Nu există lecții disponibile.'),
        ],
      ),
    );
  }

  Widget _buildLessonsList(ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // Filtre categorii
          if (_categories.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // Buton "Toate"
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('Toate'),
                      selected: _selectedCategory == null,
                      onSelected: (selected) {
                        setState(() => _selectedCategory = null);
                      },
                    ),
                  ),
                  // Butoane pentru fiecare categorie
                  ..._categories.map((category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = selected ? category : null;
                        });
                      },
                    ),
                  )),
                ],
              ),
            ),

          // Lista de lecții
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _filteredLessons.length,
              itemBuilder: (context, index) {
                final lesson = _filteredLessons[index];
                return _buildLessonCard(lesson, colorScheme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(Lesson lesson, ColorScheme colorScheme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LessonDetailScreen(lesson: lesson),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon sau imagine
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(lesson.category),
                  color: colorScheme.primary,
                  size: 30,
                ),
              ),

              const SizedBox(width: 16),

              // Conținut text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Categorie
                    if (lesson.category != null)
                      Text(
                        lesson.category!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),

                    const SizedBox(height: 4),

                    // Titlu
                    Text(
                      lesson.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Descriere
                    if (lesson.description != null)
                      Text(
                        lesson.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Durată
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          lesson.formattedDuration,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Săgeată
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'basics':
        return Icons.star_outline;
      case 'features':
        return Icons.widgets_outlined;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'games':
        return Icons.sports_esports_outlined;
      default:
        return Icons.school_outlined;
    }
  }
}