import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/daos/word_dao.dart';
import '../../../../core/database/daos/user_stats_dao.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/services/global_stats_notifier.dart';
import '../../../../core/widgets/animated_speaker_button.dart';
import 'package:flutter_animate/flutter_animate.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final WordDao _wordDao = WordDao();
  final UserStatsDao _userStatsDao = UserStatsDao();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _words = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  // Filters
  int? _masteryFilter; // null=全部, 0=未学, 1=学习中, 2=已掌握
  String? _currentBookId; // null = All Books
  String? _currentUnit;
  
  // Metadata
  List<dynamic> _books = [];
  Map<int, int> _counts = {0: 0, 1: 0, 2: 0};
  List<String> _units = [];

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    _searchController.addListener(_onSearchChanged);
    GlobalStatsNotifier.instance.addListener(_fullReload);
  }

  @override
  void dispose() {
    GlobalStatsNotifier.instance.removeListener(_fullReload);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Debounce can be added if needed
    _reload();
  }

  Future<void> _loadMetadata() async {
    try {
        // Load books
        final String jsonString = await rootBundle.loadString('assets/data/books_manifest.json');
        _books = jsonDecode(jsonString);
        
        // Load user stats for default book
        final stats = await _userStatsDao.getUserStats();
        
        // Default to user's book, or first book, but allowing null for "All"
        if (stats.currentBookId.isNotEmpty) {
           _currentBookId = stats.currentBookId;
        } else if (_books.isNotEmpty) {
           _currentBookId = _books[0]['id'];
        }
            
        // Load units for this book
        await _loadUnits();
        
        _reload();
    } catch (e) {
        debugPrint("Error loading metadata: $e");
    }
  }

  Future<void> _loadUnits() async {
    if (_currentBookId == null || _currentBookId!.isEmpty) {
        _units = [];
        _currentUnit = null;
        setState(() {});
        return;
    }
    _units = await _wordDao.getUnitsForBook(_currentBookId!);
    _units.sort(_naturalCompare); // Apply natural sort
    _currentUnit = null; 
    setState(() {});
  }

  int _naturalCompare(String a, String b) {
    final RegExp regex = RegExp(r'(\d+)|(\D+)');
    final Iterable<Match> aMatches = regex.allMatches(a);
    final Iterable<Match> bMatches = regex.allMatches(b);
    
    final Iterator<Match> aIterator = aMatches.iterator;
    final Iterator<Match> bIterator = bMatches.iterator;
    
    while (aIterator.moveNext() && bIterator.moveNext()) {
      final String aPart = aIterator.current.group(0)!;
      final String bPart = bIterator.current.group(0)!;
      
      final int? aInt = int.tryParse(aPart);
      final int? bInt = int.tryParse(bPart);
      
      if (aInt != null && bInt != null) {
        final int compare = aInt.compareTo(bInt);
        if (compare != 0) return compare;
      } else if (aInt != null) {
        return -1; // Numbers come before text
      } else if (bInt != null) {
        return 1;
      } else {
        final int compare = aPart.compareTo(bPart);
        if (compare != 0) return compare;
      }
    }
    
    if (aIterator.moveNext()) return 1;
    if (bIterator.moveNext()) return -1;
    
    return 0;
  }

  /// Full reload - called when data is restored from backup
  /// This reloads book context AND word data
  Future<void> _fullReload() async {
    try {
      // Re-read user's current book from database
      final stats = await _userStatsDao.getUserStats();
      if (stats.currentBookId.isNotEmpty) {
        _currentBookId = stats.currentBookId;
      }
      await _loadUnits();
    } catch (e) {
      debugPrint("Error in full reload: $e");
    }
    await _reload();
  }

  /// Regular reload - just refreshes word list with current filters
  Future<void> _reload() async {
    setState(() {
      _words = [];
      _offset = 0;
      _hasMore = true;
      _isLoading = true;
    });
    // Update counts whenever filter context changes (book, unit, search)
    _updateCounts();
    await _loadMore();
  }

  Future<void> _updateCounts() async {
    final counts = await _wordDao.getWordCounts(
        bookId: _currentBookId,
        unit: _currentUnit,
        searchQuery: _searchController.text
    );
    if (mounted) {
        setState(() {
            _counts = counts;
        });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore) {
       setState(() => _isLoading = false);
       return;
    }

    final newWords = await _wordDao.getDictionaryWords(
      limit: _limit,
      offset: _offset,
      masteryFilter: _masteryFilter,
      searchQuery: _searchController.text,
      bookId: _currentBookId,
      unit: _currentUnit
    );

    if (mounted) {
      setState(() {
        _words.addAll(newWords);
        _offset += newWords.length;
        _hasMore = newWords.length >= _limit;
        _isLoading = false;
      });
    }
  }

  void _onFilterChanged(int? filter) {
    if (_masteryFilter == filter) return;
    setState(() {
      _masteryFilter = filter;
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader()
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: -0.2, end: 0, curve: Curves.easeOutQuad),
            
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildFilters(), 
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _isLoading && _words.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : NotificationListener<ScrollNotification>(
                            onNotification: (ScrollNotification scrollInfo) {
                              if (!_isLoading && _hasMore && scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                                _loadMore();
                              }
                              return false;
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _words.length + (_hasMore ? 1 : 0),
                              separatorBuilder: (c, i) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                if (index == _words.length) {
                                   return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
                                }
                                return _buildWordItem(_words[index])
                                    .animate(delay: (50 * index).clamp(0, 500).ms) // Staggered list
                                    .fadeIn(duration: 300.ms)
                                    .slideX(begin: 0.1, end: 0);
                              },
                            ),
                          ),
                  ),
                ],
              )
              .animate()
              .fadeIn(duration: 500.ms, delay: 200.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
                Text("词典", style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textHighEmphasis)),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildBookSelector(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: AppColors.shadowWhite, blurRadius: 10, offset: const Offset(0, 4))
              ]
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                icon: Icon(Icons.search_rounded, color: AppColors.textMediumEmphasis),
                border: InputBorder.none,
                hintText: "搜索单词...",
                hintStyle: TextStyle(color: AppColors.textMediumEmphasis),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBookSelector() {
    String currentBookName = "全部教材";
    if (_currentBookId != null && _currentBookId!.isNotEmpty) {
       final book = _books.firstWhere((b) => b['id'] == _currentBookId, orElse: () => null);
       if (book != null) currentBookName = book['name'];
    }
    
    return InkWell(
        onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (context) {
                return Container(
                  constraints: const BoxConstraints(maxHeight: 500),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Title
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '切换教材',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textHighEmphasis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Divider
                      Divider(height: 1, color: Colors.grey.shade100),
                      // Items
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _books.length + 1,
                          separatorBuilder: (context, index) => const SizedBox(height: 4),
                          itemBuilder: (ctx, i) {
                            final isAllBooks = i == 0;
                            final book = isAllBooks ? null : _books[i - 1];
                            final id = isAllBooks ? null : book['id'];
                            final String label = isAllBooks ? "全部教材" : book['name'];
                            final bool isSelected = _currentBookId == id;

                            return InkWell(
                              onTap: () async {
                                Navigator.pop(context);
                                _currentBookId = id;
                                await _loadUnits();
                                _reload();
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isSelected ? Icons.check_circle_rounded : (isAllBooks ? Icons.all_inclusive_rounded : Icons.menu_book_rounded),
                                        color: isSelected ? AppColors.primary : Colors.grey.shade400,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            label,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                              color: isSelected ? AppColors.primary : AppColors.textHighEmphasis,
                                            ),
                                          ),
                                          if (isAllBooks)
                                            Text(
                                              "查看所有已添加单词",
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 12,
                                                color: isSelected ? AppColors.primary.withValues(alpha: 0.7) : Colors.grey.shade500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_rounded, color: AppColors.primary, size: 22),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Safe area padding
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                    ],
                  ),
                );
              },
            );
        },
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                ]
            ),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                     const Icon(Icons.menu_book_rounded, size: 16, color: AppColors.primary),
                     const SizedBox(width: 8),
                     Flexible(
                        child: Text(
                            currentBookName, 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis, 
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textHighEmphasis)
                        )
                     ),
                     const SizedBox(width: 4),
                     const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMediumEmphasis)
                ],
            )
        )
    );
  }

  Widget _buildFilters() {
    int total = (_counts[0] ?? 0) + (_counts[1] ?? 0) + (_counts[2] ?? 0);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
           // Unit Selector
            if (_units.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildDropdownChip(
                      _currentUnit == null ? "所有单元" : _currentUnit!,
                      () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (context) {
                              return Container(
                                constraints: const BoxConstraints(maxHeight: 500),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Handle
                                    Container(
                                      margin: const EdgeInsets.only(top: 12),
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    // Title
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                                      child: Row(
                                        children: [
                                          Text(
                                            '选择单元',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textHighEmphasis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Divider
                                    Divider(height: 1, color: Colors.grey.shade100),
                                    // Items
                                    Flexible(
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        itemCount: _units.length + 1,
                                        separatorBuilder: (context, index) => const SizedBox(height: 4),
                                        itemBuilder: (ctx, i) {
                                          final isAllUnits = i == 0;
                                          final unit = isAllUnits ? null : _units[i - 1];
                                          final bool isSelected = _currentUnit == unit;
                                          final String label = isAllUnits ? "所有单元" : unit!;

                                          return InkWell(
                                            onTap: () {
                                              Navigator.pop(context);
                                              setState(() => _currentUnit = unit);
                                              _reload();
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 16),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              decoration: BoxDecoration(
                                                color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.grey.shade100,
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Icon(
                                                      isSelected ? Icons.check_circle_rounded : (isAllUnits ? Icons.all_inclusive_rounded : Icons.circle_outlined),
                                                      color: isSelected ? AppColors.primary : Colors.grey.shade400,
                                                      size: 20,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Text(
                                                      label,
                                                      style: GoogleFonts.plusJakartaSans(
                                                        fontSize: 15,
                                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                        color: isSelected ? AppColors.primary : AppColors.textHighEmphasis,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isSelected)
                                                    const Icon(Icons.check_rounded, color: AppColors.primary, size: 22),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    // Safe area padding
                                    SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                                  ],
                                ),
                              );
                            },
                          );
                      }
                  ),
              ),
        
          _buildFilterChip("全部 ($total)", null),
          const SizedBox(width: 8),
          _buildFilterChip("未学 (${_counts[0] ?? 0})", 0),
          const SizedBox(width: 8),
          _buildFilterChip("学习中 (${_counts[1] ?? 0})", 1),
          const SizedBox(width: 8),
          _buildFilterChip("已掌握 (${_counts[2] ?? 0})", 2),
        ],
      ),
    );
  }

  Widget _buildDropdownChip(String label, VoidCallback onTap) {
      return InkWell(
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                  children: [
                      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 16)
                  ]
              )
          )
      );
  }

  Widget _buildFilterChip(String label, int? value) {
    final isSelected = _masteryFilter == value;
    return GestureDetector(
      onTap: () => _onFilterChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
           color: isSelected ? AppColors.primary : Colors.white,
           borderRadius: BorderRadius.circular(20),
           border: isSelected ? null : Border.all(color: Colors.grey.shade200),
           boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : null
        ),
        child: Text(label, style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textMediumEmphasis,
          fontWeight: FontWeight.bold,
          fontSize: 14
        )),
      ),
    );
  }

  Widget _buildWordItem(Map<String, dynamic> item) {
    // item contains word fields + status fields
    final text = item['text'] as String;
    final meaning = item['meaning'] as String;
    final mastery = item['mastery_level'] as int? ?? 0; // null if not learned (left join)
    final isLearned = (item['is_learned'] as int? ?? 0) == 1;
    final interval = item['interval'] as int? ?? 1;

    Color badgeColor = Colors.grey.shade400;
    String badgeText = "未开始";
    IconData badgeIcon = Icons.circle_outlined;

    if (isLearned) {
      if (mastery == 2) {
        badgeColor = Colors.green;
        badgeText = "已掌握";
        badgeIcon = Icons.check_circle;
      } else {
        // Learning - differentiate by interval
        // interval 1-2: just started (light orange)
        // interval 3-7: progressing (orange)
        // interval 8+: almost there (yellow-green)
        if (interval >= 8) {
          badgeColor = const Color(0xFF8BC34A); // Light green - almost mastered
          badgeText = "熟练中";
          badgeIcon = Icons.trending_up;
        } else if (interval >= 3) {
          badgeColor = const Color(0xFFFF9800); // Orange - progressing
          badgeText = "学习中";
          badgeIcon = Icons.schedule;
        } else {
          badgeColor = const Color(0xFFFFB74D); // Light orange - just started
          badgeText = "初学";
          badgeIcon = Icons.flag;
        }
      }
    }

    return BubblyButton(
      onPressed: () => _showWordDetail(item),
      color: Colors.white,
      shadowColor: AppColors.shadowWhite,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: Row(
          children: [
            Container(
                width: 4, height: 40,
                decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(2)
                ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textHighEmphasis)),
                  const SizedBox(height: 4),
                  Text(meaning, style: const TextStyle(fontSize: 14, color: AppColors.textMediumEmphasis), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                    Icon(badgeIcon, size: 16, color: badgeColor),
                    const SizedBox(height: 4),
                    Text(badgeText, style: TextStyle(fontSize: 12, color: badgeColor, fontWeight: FontWeight.bold)),
                ],
            )
          ],
        ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          const Text("没有找到单词", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showWordDetail(Map<String, dynamic> item) async {
    final wordId = item['id'] as String;
    
    // Fetch full detail including examples
    final Word? fullWord = await _wordDao.getWordDetails(wordId);
    if (fullWord == null) return;
    
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _WordDetailDialog(
        fullWord: fullWord,
        item: item,
      ),
    );
  }


}

class _WordDetailDialog extends StatefulWidget {
  final Word fullWord;
  final Map<String, dynamic> item;

  const _WordDetailDialog({
    required this.fullWord,
    required this.item,
  });

  @override
  State<_WordDetailDialog> createState() => _WordDetailDialogState();
}

class _WordDetailDialogState extends State<_WordDetailDialog> {
  bool _isPlaying = false;

  Future<void> _playAudio() async {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);
    try {
      await AudioService().playWord(widget.fullWord);
    } finally {
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      }
    }
  }

  String _formatNextReview(int? timestamp) {
    if (timestamp == null || timestamp == 0) return "-";
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = date.difference(now);
    
    if (diff.isNegative) {
      return "待复习";
    } else if (diff.inHours < 24 && date.day == now.day) {
      return "今天";
    } else if (date.day == now.add(const Duration(days: 1)).day) {
      return "明天";
    } else {
      return "${date.year}/${date.month}/${date.day}";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Progress Info
    final isLearned = (widget.item['is_learned'] as int? ?? 0) == 1;
    final nextReviewTs = widget.item['next_review_date'] as int?;
    final interval = widget.item['interval'] as int?;
    final mastery = widget.item['mastery_level'] as int? ?? 0;

    double memoryStrength = 0.0;
    Color memoryColor = Colors.grey;
    String memoryLabel = "未学习";
    
    if (isLearned) {
        final int currentInterval = interval ?? 1;
        if (mastery == 2) {
             double ratio = currentInterval / 30.0; // cap at 30 days
             if (ratio > 1.0) ratio = 1.0;
             memoryStrength = 0.8 + (ratio * 0.2); // 0.8 - 1.0
             memoryColor = Colors.green;
             memoryLabel = "已掌握";
        } else {
             if (currentInterval >= 8) {
               memoryStrength = 0.65 + (currentInterval / 21.0) * 0.15;
               if (memoryStrength > 0.8) memoryStrength = 0.8;
               memoryColor = const Color(0xFF8BC34A); 
               memoryLabel = "熟练中";
             } else if (currentInterval >= 3) {
               memoryStrength = 0.35 + (currentInterval / 8.0) * 0.3;
               memoryColor = const Color(0xFFFF9800); 
               memoryLabel = "学习中";
             } else {
               memoryStrength = 0.15 + (currentInterval / 3.0) * 0.2;
               memoryColor = const Color(0xFFFFB74D); 
               memoryLabel = "初学";
             }
        }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 40, offset: Offset(0, 10))
                ]
            ),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Expanded(
                             child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                     Text(widget.fullWord.text, style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textHighEmphasis)),
                                     const SizedBox(height: 4),
                                     Text(widget.fullWord.displayPhonetic, style: const TextStyle(fontSize: 18, color: AppColors.textMediumEmphasis, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
                                 ]
                             )
                         ),
                         AnimatedSpeakerButton(
                             onPressed: _playAudio,
                             isPlaying: _isPlaying,
                             size: 32,
                         ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    const Text("中文释义", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(widget.fullWord.meaning, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHighEmphasis)),
                    
                    const SizedBox(height: 24),
                    Container(padding: const EdgeInsets.symmetric(vertical: 8), width: double.infinity, height: 1, color: Colors.grey.shade100),
                    const SizedBox(height: 16),
                    
                    if (isLearned) 
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Row(
                                children: const [
                                    Icon(Icons.memory, size: 16, color: AppColors.secondary),
                                    SizedBox(width: 8),
                                    Text("记忆强度", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHighEmphasis)),
                                ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                    value: memoryStrength,
                                    minHeight: 12,
                                    backgroundColor: Colors.grey.shade100,
                                    valueColor: AlwaysStoppedAnimation<Color>(memoryColor),
                                ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                    Text(memoryLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: memoryColor)),
                                    Text("下次复习: ${_formatNextReview(nextReviewTs)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                            ),
                            const SizedBox(height: 24),
                        ]
                    ),
                    
                    if (widget.fullWord.examples.isNotEmpty)
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                const Text("例句", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                const SizedBox(height: 12),
                                ...widget.fullWord.examples.map((ex) => Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12)
                                    ),
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            Text(ex['en'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textHighEmphasis)),
                                            const SizedBox(height: 4),
                                            Text(ex['cn'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textMediumEmphasis)),
                                        ],
                                    ),
                                )),
                                const SizedBox(height: 24),
                            ],
                        ),
                    
                    SizedBox(
                        width: double.infinity,
                        child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("关闭", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                        )
                    )
                ],
            ),
          ),
        ),
      ),
    );
  }
}
