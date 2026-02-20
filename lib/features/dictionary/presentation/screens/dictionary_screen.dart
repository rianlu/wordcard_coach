import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/daos/word_dao.dart';
import '../../../../core/database/daos/user_stats_dao.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/widgets/bubbly_button.dart';
import '../../../../core/database/models/word.dart';
import '../../../../core/services/global_stats_notifier.dart';
import '../../../../core/widgets/animated_speaker_button.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/database/models/word_progress.dart';
import '../widgets/word_detail_sheet.dart';
import '../widgets/dictionary_word_tile.dart';
import 'dictionary_search_screen.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final WordDao _wordDao = WordDao();
  final UserStatsDao _userStatsDao = UserStatsDao();
  
  // List state
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _words = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 40;
  
  int _requestVersion = 0;
  bool _isOpeningWordDialog = false;

  // 逻辑处理
  int? _masteryFilter; // 掌握度处理
  String? _currentBookId; // 逻辑处理
  String? _currentUnit;
  
  // 逻辑处理
  List<dynamic> _books = [];
  Map<int, int> _counts = {0: 0, 1: 0, 2: 0};
  List<String> _units = [];

  @override
  void initState() {
    super.initState();
    _loadMetadata();
    // Search listener removed
    _scrollController.addListener(_onScroll);
    GlobalStatsNotifier.instance.addListener(_fullReload);
  }

  @override
  void dispose() {
    GlobalStatsNotifier.instance.removeListener(_fullReload);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || !_hasMore) return;
    if (_scrollController.position.extentAfter < 800) {
      _loadMore();
    }
  }

  Future<void> _loadMetadata() async {
    try {
        _books = await DatabaseHelper().loadBooksManifest();
        
        // 逻辑处理
        final stats = await _userStatsDao.getUserStats();
        
        // 逻辑处理
        final bool hasCurrentBook = _books.any((b) => b['id'] == stats.currentBookId);
        if (stats.currentBookId.isNotEmpty && hasCurrentBook) {
           _currentBookId = stats.currentBookId;
        } else if (_books.isNotEmpty) {
           _currentBookId = _books[0]['id'];
        } else {
           _currentBookId = null;
        }
            
        // 逻辑处理
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
    _units.sort(_naturalCompare); // 逻辑处理
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
        return -1; // 逻辑处理
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

  /// 逻辑处理
  /// 逻辑处理
  Future<void> _fullReload() async {
    try {
      // 逻辑处理
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

  /// 逻辑处理
  Future<void> _reload() async {
    final int requestId = ++_requestVersion;
    setState(() {
      _words = [];
      _offset = 0;
      _hasMore = true;
      _isLoading = true;
    });
    await _updateCounts(requestId);
    await _loadMore(requestId: requestId, force: true);
  }

  Future<void> _updateCounts(int requestId) async {
    final counts = await _wordDao.getWordCounts(
        bookId: _currentBookId,
        unit: _currentUnit,
        searchQuery: "" 
    );
    if (mounted && requestId == _requestVersion) {
        setState(() {
            _counts = counts;
        });
    }
  }

  Future<void> _loadMore({int? requestId, bool force = false}) async {
    final int activeRequestId = requestId ?? _requestVersion;
    if (!force && _isLoading) return;
    if (!_hasMore) {
       return;
    }
    setState(() => _isLoading = true);

    final newWords = await _wordDao.getDictionaryWords(
      limit: _limit,
      offset: _offset,
      masteryFilter: _masteryFilter,
      searchQuery: "",
      bookId: _currentBookId,
      unit: _currentUnit
    );

    if (mounted && activeRequestId == _requestVersion) {
      setState(() {
        _words.addAll(newWords);
        _offset += newWords.length;
        _hasMore = newWords.length >= _limit;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
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
                        : ListView.separated(
                            controller: _scrollController,
                            cacheExtent: 1400,
                            padding: const EdgeInsets.all(16),
                            itemCount: _words.length + ((_isLoading && _words.isNotEmpty) ? 1 : 0),
                            separatorBuilder: (c, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              if (index == _words.length) {
                                 return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
                              }
                              return DictionaryWordTile(
                                item: _words[index],
                                onTap: () => DictionaryWordTile.showDetail(context, _words[index]),
                              );
                            },
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
          // Search Bar Button (Navigates to Search Screen)
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const DictionarySearchScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: AppColors.shadowWhite, blurRadius: 10, offset: Offset(0, 4))
                ]
              ),
              child: Row(
                children: const [
                  Icon(Icons.search_rounded, color: AppColors.textMediumEmphasis),
                  SizedBox(width: 12),
                  Text(
                    "搜索单词...",
                    style: TextStyle(color: AppColors.textMediumEmphasis, fontSize: 16),
                  ),
                ],
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
       final idx = _books.indexWhere((b) => b['id'] == _currentBookId);
       if (idx >= 0) {
         final book = _books[idx];
         currentBookName = (book['name'] ?? currentBookName).toString();
       }
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
                      // 逻辑处理
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // 逻辑处理
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
                      // 逻辑处理
                      Divider(height: 1, color: Colors.grey.shade100),
                      // 逻辑处理
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
                      // 逻辑处理
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
           // 逻辑处理
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
                                    // 逻辑处理
                                    Container(
                                      margin: const EdgeInsets.only(top: 12),
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    // 逻辑处理
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
                                    // 逻辑处理
                                    Divider(height: 1, color: Colors.grey.shade100),
                                    // 逻辑处理
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
                                    // 逻辑处理
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




}


