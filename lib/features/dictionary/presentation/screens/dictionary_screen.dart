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
  }

  @override
  void dispose() {
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
            _buildHeader(),
            _buildFilters(),
            Expanded(
              child: _words.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification scrollInfo) {
                        if (!_isLoading && _hasMore &&
                            scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                          _loadMore(); 
                          return true; 
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
                          return _buildWordItem(_words[index]);
                        },
                      ),
                    ),
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
            showModalBottomSheet(context: context, 
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (c) {
                return Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24))
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                    const Text("切换教材", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    IconButton(
                                        icon: const Icon(Icons.close, color: Colors.grey),
                                        onPressed: () => Navigator.pop(context),
                                    )
                                ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                                child: ListView.separated(
                                    itemCount: _books.length + 1,
                                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                                    itemBuilder: (ctx, i) {
                                        if (i == 0) {
                                            return ListTile(
                                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                                leading: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                        color: _currentBookId == null ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade100,
                                                        borderRadius: BorderRadius.circular(12)
                                                    ),
                                                    child: Icon(Icons.all_inclusive, color: _currentBookId == null ? AppColors.primary : Colors.grey)
                                                ),
                                                title: const Text("全部教材", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                                subtitle: const Text("查看所有已添加单词", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                                trailing: _currentBookId == null ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                                                onTap: () async {
                                                    Navigator.pop(context);
                                                    _currentBookId = null;
                                                    await _loadUnits(); // Clear units
                                                    _reload();
                                                },
                                            );
                                        }
                                        final book = _books[i-1];
                                        final isSelected = book['id'] == _currentBookId;
                                        return ListTile(
                                            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                            leading: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                    color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(12)
                                                ),
                                                child: Icon(Icons.menu_book, color: isSelected ? AppColors.primary : Colors.grey)
                                            ),
                                            title: Text(book['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                            trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                                            onTap: () async {
                                                Navigator.pop(context);
                                                _currentBookId = book['id'];
                                                await _loadUnits();
                                                _reload();
                                            },
                                        );
                                    }
                                )
                            )
                        ]
                    ),
                );
            });
        },
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
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
                         showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (c) {
                             return Container(
                                height: 400,
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        const Text("选择单元", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 16),
                                        Expanded(
                                            child: ListView.builder(
                                                itemCount: _units.length + 1,
                                                itemBuilder: (ctx, i) {
                                                    if (i == 0) {
                                                         return ListTile(
                                                            title: const Text("所有单元"),
                                                            leading: const Icon(Icons.all_inclusive),
                                                            onTap: () {
                                                                Navigator.pop(context);
                                                                setState(() => _currentUnit = null);
                                                                _reload();
                                                            },
                                                         );
                                                    }
                                                    final unit = _units[i-1];
                                                    return ListTile(
                                                        title: Text(unit),
                                                        selected: _currentUnit == unit,
                                                        onTap: () {
                                                            Navigator.pop(context);
                                                            setState(() => _currentUnit = unit);
                                                            _reload();
                                                        },
                                                    );
                                                }
                                            )
                                        )
                                    ],
                                )
                             );
                         });
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
           boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null
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

    Color badgeColor = Colors.grey.shade400;
    String badgeText = "未开始";
    IconData badgeIcon = Icons.circle_outlined;

    if (isLearned) {
      if (mastery == 2) {
        badgeColor = Colors.green;
        badgeText = "已掌握";
        badgeIcon = Icons.check_circle;
      } else {
        badgeColor = const Color(0xFFFFA000); // Amber
        badgeText = "学习中";
        badgeIcon = Icons.schedule;
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

    // Progress Info
    final isLearned = (item['is_learned'] as int? ?? 0) == 1;
    final nextReviewTs = item['next_review_date'] as int?;
    final interval = item['interval'] as int?;
    final ef = item['easiness_factor'] as double?;
    final mastery = item['mastery_level'] as int? ?? 0;

    // Memory strength (0.0 to 1.0) for visualization
    // Logic: if mastered, >0.8. If learning, 0.3-0.8 depending on interval. If new, 0.
    double memoryStrength = 0.0;
    Color memoryColor = Colors.grey;
    if (isLearned) {
        if (mastery == 2) {
             double ratio = (interval ?? 1) / 30.0; // cap at 30 days
             if (ratio > 1.0) ratio = 1.0;
             memoryStrength = 0.8 + (ratio * 0.2); // 0.8 - 1.0
             memoryColor = Colors.green;
        } else {
             // learning
             double ratio = (interval ?? 1) / 21.0;
             memoryStrength = 0.2 + (ratio * 0.6); // 0.2 - 0.8
             memoryColor = Colors.amber;
        }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
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
                      // Header with Audio
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Expanded(
                               child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                       Text(fullWord.text, style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textHighEmphasis)),
                                       const SizedBox(height: 4),
                                       Text(fullWord.phonetic, style: const TextStyle(fontSize: 18, color: AppColors.textMediumEmphasis, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
                                   ]
                               )
                           ),
                           Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                              ),
                              child: IconButton(
                                  icon: const Icon(Icons.volume_up, color: Colors.white),
                                  onPressed: () => AudioService().playWord(fullWord),
                              ),
                           )
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      const Text("中文释义", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(fullWord.meaning, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHighEmphasis)),
                      
                      const SizedBox(height: 24),
                      Container(padding: const EdgeInsets.symmetric(vertical: 8), width: double.infinity, height: 1, color: Colors.grey.shade100),
                      const SizedBox(height: 16),
                      
                      // Mastery Bar
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
                                      Text(mastery == 2 ? "已掌握" : "学习中", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: memoryColor)),
                                      Text("下次复习: ${_formatNextReview(nextReviewTs)}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                              ),
                              const SizedBox(height: 24),
                          ]
                      ),
                      
                      // Examples Section
                      if (fullWord.examples.isNotEmpty)
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  const Text("例句", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 12),
                                  ...fullWord.examples.map((ex) => Container(
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
                                  )).toList(),
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
}
