import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/book_item.dart';
import '../models/reader_state.dart';

class LibraryService {
  LibraryService._();

  static final LibraryService instance = LibraryService._();

  static const String _sourceStorageKey = 'adola.book_sources.v1';
  static const String _groupStorageKey = 'adola.bookshelf_groups.v1';
  static const String _shelfSortStorageKey = 'adola.bookshelf_sort.v1';
  static const String _readerDraftStorageKey = 'adola.reader_draft.v1';
  static const String _readerGlobalConfigStorageKey =
      'adola.reader_global_config.v1';

  static const String _ungroupedName = '未分组';

  static const List<BookSourceItem> _defaultSources = [
    BookSourceItem(
      url: 'https://book.source-a.example',
      name: '默认书源 A',
      host: 'api.source-a.example',
      group: '默认',
      enabled: true,
      enabledExplore: true,
      customOrder: 0,
    ),
    BookSourceItem(
      url: 'https://book.source-b.example',
      name: '备用书源 B',
      host: 'rss.source-b.example',
      group: '默认',
      enabled: true,
      enabledExplore: true,
      customOrder: 1,
    ),
    BookSourceItem(
      url: 'https://book.source-c.example',
      name: '极速书源 C',
      host: 'api.source-c.example',
      group: '默认',
      enabled: true,
      enabledExplore: true,
      customOrder: 2,
    ),
    BookSourceItem(
      url: 'http://localhost:8080',
      name: '本地测试源',
      host: 'localhost',
      group: '本地',
      enabled: false,
      enabledExplore: false,
      customOrder: 3,
    ),
  ];

  static const List<BookshelfGroupItem> _defaultGroups = [
    BookshelfGroupItem(id: 'group_suspense', name: '悬疑分组', order: 0),
    BookshelfGroupItem(id: 'group_fantasy', name: '奇幻分组', order: 1),
    BookshelfGroupItem(id: 'group_reality', name: '现实分组', order: 2),
    BookshelfGroupItem(id: 'group_scifi', name: '科幻分组', order: 3),
  ];

  static const BookshelfSortType _defaultSortType =
      BookshelfSortType.recentRead;

  static final List<BookItem> _seedCatalog = [
    BookItem(
      id: 'book_001',
      title: '长夜行',
      author: '江见川',
      intro: '城市悬疑，雨夜追踪一条被刻意抹去的线索。',
      status: '连载',
      lastChapter: '第 121 章 雨后',
      tags: ['悬疑', '都市'],
      chapters: ['第 119 章 暗线', '第 120 章 旧案', '第 121 章 雨后'],
      group: '悬疑分组',
      sourceName: '默认书源 A',
      sourceUrl: 'https://book.source-a.example',
      bookUrl: 'https://book.source-a.example/book_001',
      latestChapterUpdatedAt: DateTime(2026, 2, 11, 8, 30),
    ),
    BookItem(
      id: 'book_002',
      title: '灰塔纪事',
      author: '木原',
      intro: '在灰塔城的边缘，一群人试图重写旧秩序。',
      status: '连载',
      lastChapter: '第 58 章 逆光',
      tags: ['奇幻', '群像'],
      chapters: ['第 56 章 冷湖', '第 57 章 余烬', '第 58 章 逆光'],
      group: '奇幻分组',
      sourceName: '备用书源 B',
      sourceUrl: 'https://book.source-b.example',
      bookUrl: 'https://book.source-b.example/book_002',
      latestChapterUpdatedAt: DateTime(2026, 2, 11, 9, 50),
    ),
    BookItem(
      id: 'book_003',
      title: '霜港手札',
      author: '沈鹿',
      intro: '北方港城的漫长冬季，记忆像结霜的玻璃。',
      status: '完结',
      lastChapter: '番外 2 雪线',
      tags: ['现实', '治愈'],
      chapters: ['终章 灯塔', '番外 1 潮声', '番外 2 雪线'],
      group: '现实分组',
      sourceName: '极速书源 C',
      sourceUrl: 'https://book.source-c.example',
      bookUrl: 'https://book.source-c.example/book_003',
      latestChapterUpdatedAt: DateTime(2026, 2, 10, 20, 20),
    ),
    BookItem(
      id: 'book_004',
      title: '海风向北',
      author: '迟夜',
      intro: '一场跨越海岸线的旅程，也是一场和解。',
      status: '连载',
      lastChapter: '第 42 章 远岸',
      tags: ['成长', '现实'],
      chapters: ['第 40 章 回响', '第 41 章 风眼', '第 42 章 远岸'],
      group: '现实分组',
      sourceName: '备用书源 B',
      sourceUrl: 'https://book.source-b.example',
      bookUrl: 'https://book.source-b.example/book_004',
      latestChapterUpdatedAt: DateTime(2026, 2, 11, 7, 40),
    ),
    BookItem(
      id: 'book_005',
      title: '月下编年',
      author: '文舟',
      intro: '午夜钟声之后，城市进入另一套时间。',
      status: '完结',
      lastChapter: '第 88 章 长灯',
      tags: ['科幻', '悬疑'],
      chapters: ['第 86 章 薄暮', '第 87 章 失重', '第 88 章 长灯'],
      group: '科幻分组',
      sourceName: '默认书源 A',
      sourceUrl: 'https://book.source-a.example',
      bookUrl: 'https://book.source-a.example/book_005',
      latestChapterUpdatedAt: DateTime(2026, 2, 9, 23, 12),
    ),
  ];

  static final List<ShelfBookItem> _initialShelf = [
    ShelfBookItem(
      book: _seedCatalog.firstWhere((book) => book.id == 'book_001'),
      readingState: ShelfReadingState(
        chapterTitle: '第 121 章 雨后',
        progress: 0.72,
        updatedAt: DateTime(2026, 2, 11, 10, 30),
      ),
      manualOrder: 0,
    ),
    ShelfBookItem(
      book: _seedCatalog.firstWhere((book) => book.id == 'book_002'),
      readingState: ShelfReadingState(
        chapterTitle: '第 58 章 逆光',
        progress: 0.31,
        updatedAt: DateTime(2026, 2, 11, 9, 20),
      ),
      manualOrder: 1,
    ),
    ShelfBookItem(
      book: _seedCatalog.firstWhere((book) => book.id == 'book_003'),
      readingState: ShelfReadingState(
        chapterTitle: '番外 2 雪线',
        progress: 0.95,
        updatedAt: DateTime(2026, 2, 10, 21, 0),
      ),
      manualOrder: 2,
    ),
  ];

  static final List<SearchKeywordItem> _initialSearchHistory = [
    SearchKeywordItem(
      keyword: '长夜',
      usage: 4,
      updatedAt: DateTime(2026, 2, 11, 10, 20),
    ),
    SearchKeywordItem(
      keyword: '霜港',
      usage: 2,
      updatedAt: DateTime(2026, 2, 10, 22, 15),
    ),
    SearchKeywordItem(
      keyword: '科幻',
      usage: 1,
      updatedAt: DateTime(2026, 2, 9, 20, 5),
    ),
  ];

  final ValueNotifier<List<ShelfBookItem>> shelfListenable = ValueNotifier(
    List.unmodifiable(_initialShelf),
  );

  final ValueNotifier<List<SearchKeywordItem>> searchHistoryListenable =
      ValueNotifier(List.unmodifiable(_initialSearchHistory));

  final ValueNotifier<List<BookSourceItem>> sourceListenable = ValueNotifier(
    List.unmodifiable(_defaultSources),
  );

  final ValueNotifier<List<BookshelfGroupItem>> groupListenable = ValueNotifier(
    List.unmodifiable(_defaultGroups),
  );

  final ValueNotifier<BookshelfSortType> shelfSortListenable = ValueNotifier(
    _defaultSortType,
  );

  bool _initialized = false;
  List<BookItem> _catalog = List.unmodifiable(_seedCatalog);
  Map<String, ReaderBookDraftState> _readerDrafts = const {};
  ReaderViewConfigState _readerGlobalConfig = ReaderViewConfigState.defaults;

  List<ShelfBookItem> get shelfBooks => shelfListenable.value;

  ShelfBookItem? shelfBookById(String bookId) {
    for (final item in shelfListenable.value) {
      if (item.book.id == bookId) {
        return item;
      }
    }
    return null;
  }

  List<BookItem> allBooks() {
    return List.unmodifiable(_catalog);
  }

  List<BookshelfGroupItem> allGroups() {
    return List.unmodifiable(_sortGroups(groupListenable.value));
  }

  List<BookshelfGroupItem> allVisibleGroups() {
    return List.unmodifiable(
      allGroups().where((group) => group.show).toList(growable: false),
    );
  }

  List<BookshelfGroupItem> shelfVisibleGroups() {
    final shelfGroupNames = shelfListenable.value
        .map((item) => item.book.group.trim())
        .where((name) => name.isNotEmpty)
        .toSet();

    return List.unmodifiable(
      allVisibleGroups()
          .where((group) => shelfGroupNames.contains(group.name))
          .toList(growable: false),
    );
  }

  BookshelfGroupItem? groupById(String groupId) {
    for (final group in groupListenable.value) {
      if (group.id == groupId) {
        return group;
      }
    }
    return null;
  }

  BookshelfGroupItem? groupByName(String name) {
    final normalized = name.trim();
    for (final group in groupListenable.value) {
      if (group.name == normalized) {
        return group;
      }
    }
    return null;
  }

  List<String> allEnabledGroups() {
    final visibleNames = allVisibleGroups().map((group) => group.name).toSet();
    final groups = <String>[];
    final seen = <String>{};

    for (final book in _catalog) {
      final groupName = book.group.trim();
      if (groupName.isEmpty || !visibleNames.contains(groupName)) {
        continue;
      }
      if (seen.add(groupName)) {
        groups.add(groupName);
      }
    }

    return List.unmodifiable(groups);
  }

  List<String> allEnabledSources() {
    final sources = allEnabledSourceItems();
    return List.unmodifiable(
      sources
          .map((source) => source.name)
          .toSet()
          .toList(growable: false),
    );
  }

  List<BookSourceItem> allSources() {
    return List.unmodifiable(sourceListenable.value);
  }

  List<BookSourceItem> allEnabledSourceItems() {
    return List.unmodifiable(
      sourceListenable.value.where((source) => source.enabled),
    );
  }

  BookSourceItem? sourceByUrl(String sourceUrl) {
    for (final source in sourceListenable.value) {
      if (source.url == sourceUrl) {
        return source;
      }
    }
    return null;
  }


  ReaderBookDraftState readerDraftByBookId(String bookId) {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return const ReaderBookDraftState();
    }
    return _readerDrafts[normalizedBookId] ?? const ReaderBookDraftState();
  }

  ReaderViewConfigState readerGlobalConfig() {
    return _readerGlobalConfig;
  }

  Future<void> saveReaderGlobalConfig(ReaderViewConfigState config) async {
    _readerGlobalConfig = config;
    await _saveReaderGlobalConfig();
  }

  Future<void> saveReaderDraft(String bookId, ReaderBookDraftState draft) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return;
    }

    final next = Map<String, ReaderBookDraftState>.from(_readerDrafts);
    if (draft.isEmpty) {
      next.remove(normalizedBookId);
    } else {
      next[normalizedBookId] = draft;
    }

    _readerDrafts = Map.unmodifiable(next);
    await _saveReaderDrafts();
  }

  BookSourceItem? sourceByName(String sourceName) {
    for (final source in sourceListenable.value) {
      if (source.name == sourceName) {
        return source;
      }
    }
    return null;
  }

  BookSourceItem? resolveSource({String? sourceUrl, String? sourceName}) {
    if (sourceUrl != null && sourceUrl.trim().isNotEmpty) {
      final byUrl = sourceByUrl(sourceUrl.trim());
      if (byUrl != null) {
        return byUrl;
      }
    }
    if (sourceName != null && sourceName.trim().isNotEmpty) {
      final byName = sourceByName(sourceName.trim());
      if (byName != null) {
        return byName;
      }
    }
    return null;
  }

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    final preferences = await SharedPreferences.getInstance();
    await _loadSourcesFromPreferences(preferences);
    await _loadGroupsFromPreferences(preferences);
    await _loadReaderGlobalConfigFromPreferences(preferences);
    await _loadReaderDraftsFromPreferences(preferences);
    _loadShelfSortFromPreferences(preferences);
    _replaceShelf(shelfListenable.value);
  }

  Future<void> upsertSource(BookSourceItem source) async {
    final normalized = _normalizeSource(source);
    final next = [...sourceListenable.value];
    final index = next.indexWhere((item) => item.url == normalized.url);
    if (index >= 0) {
      next[index] = normalized.copyWith(lastUpdateTime: DateTime.now());
    } else {
      next.add(
        normalized.copyWith(
          customOrder: next.length,
          lastUpdateTime: DateTime.now(),
        ),
      );
    }
    await _replaceSources(next);
  }

  Future<void> removeSource(String sourceUrl) async {
    final next = sourceListenable.value
        .where((item) => item.url != sourceUrl)
        .toList(growable: false);
    await _replaceSources(next);
  }

  Future<void> setSourceEnabled(String sourceUrl, bool enabled) async {
    final next = sourceListenable.value
        .map(
          (item) => item.url == sourceUrl
              ? item.copyWith(enabled: enabled, lastUpdateTime: DateTime.now())
              : item,
        )
        .toList(growable: false);
    await _replaceSources(next);
  }

  Future<void> importSources(List<BookSourceItem> sources) async {
    if (sources.isEmpty) {
      return;
    }

    final next = [...sourceListenable.value];
    for (final source in sources) {
      final normalized = _normalizeSource(source);
      final index = next.indexWhere((item) => item.url == normalized.url);
      if (index >= 0) {
        next[index] = normalized.copyWith(lastUpdateTime: DateTime.now());
      } else {
        next.add(
          normalized.copyWith(
            customOrder: next.length,
            lastUpdateTime: DateTime.now(),
          ),
        );
      }
    }

    await _replaceSources(next);
  }

  String exportSourcesJson() {
    return const JsonEncoder.withIndent(
      '  ',
    ).convert(sourceListenable.value.map((item) => item.toJson()).toList());
  }

  List<BookSourceItem> parseSourcesJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      throw const FormatException('书源 JSON 顶层必须是数组');
    }

    final result = <BookSourceItem>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('书源 JSON 项必须是对象');
      }
      final source = _normalizeSource(BookSourceItem.fromJson(entry));
      if (source.url.isEmpty || source.name.isEmpty || source.host.isEmpty) {
        throw const FormatException('书源必须包含 url/name/host');
      }
      result.add(source);
    }

    return result;
  }

  Future<void> createGroup(
    String name, {
    bool show = true,
    bool enableRefresh = true,
    BookshelfSortType? sortType,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('分组名称不能为空');
    }
    if (groupByName(normalizedName) != null) {
      throw const FormatException('分组名称已存在');
    }

    final next = [
      ...groupListenable.value,
      BookshelfGroupItem(
        id: _nextGroupId(),
        name: normalizedName,
        order: groupListenable.value.length,
        show: show,
        enableRefresh: enableRefresh,
        bookSort: sortType?.code ?? -1,
      ),
    ];

    await _replaceGroups(next);
  }

  Future<void> renameGroup(String groupId, String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('分组名称不能为空');
    }

    final groups = [...groupListenable.value];
    final index = groups.indexWhere((group) => group.id == groupId);
    if (index < 0) {
      return;
    }

    final previous = groups[index];
    if (groups.any((group) => group.id != groupId && group.name == normalizedName)) {
      throw const FormatException('分组名称已存在');
    }

    groups[index] = previous.copyWith(name: normalizedName);
    _replaceCatalogGroupName(previous.name, normalizedName);
    _replaceShelfGroupName(previous.name, normalizedName);
    await _replaceGroups(groups);
  }

  Future<void> removeGroup(String groupId) async {
    final group = groupById(groupId);
    if (group == null) {
      return;
    }

    final next = groupListenable.value
        .where((item) => item.id != groupId)
        .toList(growable: false);

    _replaceCatalogGroupName(group.name, _ungroupedName);
    _replaceShelfGroupName(group.name, _ungroupedName);
    await _replaceGroups(next);
  }

  Future<void> setGroupVisible(String groupId, bool visible) async {
    final next = groupListenable.value
        .map(
          (item) =>
              item.id == groupId ? item.copyWith(show: visible) : item,
        )
        .toList(growable: false);
    await _replaceGroups(next);
  }

  Future<void> setGroupEnableRefresh(String groupId, bool enabled) async {
    final next = groupListenable.value
        .map(
          (item) => item.id == groupId
              ? item.copyWith(enableRefresh: enabled)
              : item,
        )
        .toList(growable: false);
    await _replaceGroups(next);
  }

  Future<void> setGroupSort(String groupId, BookshelfSortType? sortType) async {
    final next = groupListenable.value
        .map(
          (item) => item.id == groupId
              ? item.copyWith(bookSort: sortType?.code ?? -1)
              : item,
        )
        .toList(growable: false);
    await _replaceGroups(next);
  }

  Future<void> moveGroup(String groupId, int targetIndex) async {
    final groups = _sortGroups(groupListenable.value);
    final fromIndex = groups.indexWhere((group) => group.id == groupId);
    if (fromIndex < 0) {
      return;
    }
    if (targetIndex < 0 || targetIndex >= groups.length) {
      return;
    }
    if (fromIndex == targetIndex) {
      return;
    }

    final next = [...groups];
    final moved = next.removeAt(fromIndex);
    next.insert(targetIndex, moved);
    await _replaceGroups(next);
  }

  BookshelfSortType effectiveSortForGroup(String? groupId) {
    if (groupId == null || groupId.isEmpty) {
      return shelfSortListenable.value;
    }
    final group = groupById(groupId);
    if (group == null) {
      return shelfSortListenable.value;
    }
    return BookshelfSortType.fromCode(
      group.effectiveSort(shelfSortListenable.value.code),
    );
  }

  Future<void> setGlobalShelfSort(BookshelfSortType sortType) async {
    if (shelfSortListenable.value == sortType) {
      return;
    }

    shelfSortListenable.value = sortType;
    _replaceShelf(shelfListenable.value);
    await _saveShelfSort(sortType);
  }

  List<ShelfBookItem> shelfBooksByGroup({String? groupId}) {
    Iterable<ShelfBookItem> scoped = shelfListenable.value;
    if (groupId != null && groupId.isNotEmpty) {
      final group = groupById(groupId);
      if (group == null) {
        return const [];
      }
      scoped = scoped.where((item) => item.book.group == group.name);
    }

    final sorted = _sortShelf(
      scoped.toList(growable: false),
      effectiveSortForGroup(groupId),
    );

    return List.unmodifiable(sorted);
  }

  List<BookItem> searchBooks(
    String keyword, {
    SearchScope scope = const SearchScope.all(),
    bool precision = false,
  }) {
    final normalizedKeyword = keyword.trim().toLowerCase();

    final scopedBooks = _catalog.where((book) {
      if (scope.isAll) {
        return true;
      }
      if (scope.type == SearchScopeType.group) {
        return book.group == scope.value;
      }

      final sourceUrl = scope.value;
      if (sourceUrl.isNotEmpty) {
        return book.sourceUrl == sourceUrl;
      }
      return false;
    });

    if (normalizedKeyword.isEmpty) {
      return List.unmodifiable(scopedBooks);
    }

    return List.unmodifiable(
      scopedBooks.where((book) {
        final normalizedTitle = book.title.toLowerCase();
        final normalizedAuthor = book.author.toLowerCase();

        if (precision) {
          return normalizedTitle == normalizedKeyword ||
              normalizedAuthor == normalizedKeyword ||
              '$normalizedTitle-$normalizedAuthor' == normalizedKeyword;
        }

        return normalizedTitle.contains(normalizedKeyword) ||
            normalizedAuthor.contains(normalizedKeyword) ||
            book.tags.any(
              (tag) => tag.toLowerCase().contains(normalizedKeyword),
            );
      }),
    );
  }

  List<ShelfBookItem> searchShelfBooks(String keyword) {
    final normalizedKeyword = keyword.trim().toLowerCase();
    if (normalizedKeyword.isEmpty) {
      return const [];
    }

    return List.unmodifiable(
      shelfListenable.value.where(
        (item) =>
            item.book.title.toLowerCase().contains(normalizedKeyword) ||
            item.book.author.toLowerCase().contains(normalizedKeyword),
      ),
    );
  }

  List<SearchKeywordItem> searchHistory(String keyword) {
    final normalizedKeyword = keyword.trim().toLowerCase();
    final items = searchHistoryListenable.value;
    if (normalizedKeyword.isEmpty) {
      return items;
    }

    return List.unmodifiable(
      items.where(
        (item) => item.keyword.toLowerCase().contains(normalizedKeyword),
      ),
    );
  }

  void saveSearchKeyword(String keyword) {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final next = [...searchHistoryListenable.value];
    final targetIndex = next.indexWhere(
      (item) => item.keyword == normalizedKeyword,
    );

    if (targetIndex >= 0) {
      final target = next[targetIndex];
      next[targetIndex] = target.copyWith(
        usage: target.usage + 1,
        updatedAt: now,
      );
    } else {
      next.add(
        SearchKeywordItem(keyword: normalizedKeyword, usage: 1, updatedAt: now),
      );
    }

    next.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    searchHistoryListenable.value = List.unmodifiable(next);
  }

  void clearSearchHistory() {
    searchHistoryListenable.value = const [];
  }

  void deleteSearchKeyword(String keyword) {
    searchHistoryListenable.value = List.unmodifiable(
      searchHistoryListenable.value
          .where((item) => item.keyword != keyword)
          .toList(growable: false),
    );
  }

  bool isInShelf(String bookId) {
    return shelfListenable.value.any((item) => item.book.id == bookId);
  }

  void addToShelf(BookItem book) {
    if (isInShelf(book.id)) {
      return;
    }

    final chapterTitle = book.chapters.isNotEmpty ? book.chapters.first : '';
    final next = [
      ShelfBookItem(
        book: book,
        readingState: ShelfReadingState(
          chapterTitle: chapterTitle,
          progress: 0,
          updatedAt: DateTime.now(),
        ),
        manualOrder: _nextTopManualOrder(),
      ),
      ...shelfListenable.value,
    ];

    _replaceShelf(next);
  }

  void removeFromShelf(String bookId) {
    final next = shelfListenable.value
        .where((item) => item.book.id != bookId)
        .toList(growable: false);
    _replaceShelf(next);
  }

  BookItem replaceBookSource({
    required BookItem book,
    required String sourceUrl,
    required String sourceName,
  }) {
    return book.copyWith(sourceUrl: sourceUrl, sourceName: sourceName);
  }

  void updateReadingProgress({
    required String bookId,
    required String chapterTitle,
    required double progress,
  }) {
    final next = shelfListenable.value
        .map(
          (item) => item.book.id == bookId
              ? item.copyWith(
                  readingState: item.readingState.copyWith(
                    chapterTitle: chapterTitle,
                    progress: progress.clamp(0, 1),
                    updatedAt: DateTime.now(),
                  ),
                )
              : item,
        )
        .toList(growable: false);

    _replaceShelf(next);
  }

  void pinShelfBook(String bookId) {
    final target = shelfBookById(bookId);
    if (target == null) {
      return;
    }

    updateReadingProgress(
      bookId: bookId,
      chapterTitle: target.readingState.chapterTitle,
      progress: target.readingState.progress,
    );
  }

  String relativeUpdatedAt(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) {
      return '刚刚';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分钟前';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} 小时前';
    }
    return '昨天';
  }

  @visibleForTesting
  void debugResetForTests() {
    _initialized = false;
    _catalog = List.unmodifiable(_seedCatalog);
    sourceListenable.value = List.unmodifiable(_defaultSources);
    groupListenable.value = List.unmodifiable(_defaultGroups);
    shelfSortListenable.value = _defaultSortType;
    shelfListenable.value = List.unmodifiable(_initialShelf);
    searchHistoryListenable.value = List.unmodifiable(_initialSearchHistory);
    _readerDrafts = const {};
    _readerGlobalConfig = ReaderViewConfigState.defaults;
  }

  Future<void> _loadSourcesFromPreferences(SharedPreferences preferences) async {
    final raw = preferences.getString(_sourceStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return;
    }

    final next = <BookSourceItem>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }
      final source = BookSourceItem.fromJson(entry);
      if (source.url.isEmpty || source.name.isEmpty || source.host.isEmpty) {
        continue;
      }
      next.add(source);
    }

    if (next.isEmpty) {
      return;
    }

    sourceListenable.value = List.unmodifiable(_sortSources(next));
  }

  Future<void> _loadGroupsFromPreferences(SharedPreferences preferences) async {
    List<BookshelfGroupItem> loaded = _defaultGroups;
    final raw = preferences.getString(_groupStorageKey);

    if (raw != null && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final parsed = <BookshelfGroupItem>[];
        for (final entry in decoded) {
          if (entry is! Map<String, dynamic>) {
            continue;
          }
          final group = BookshelfGroupItem.fromJson(entry);
          if (group.id.isEmpty || group.name.isEmpty) {
            continue;
          }
          parsed.add(group);
        }

        if (parsed.isNotEmpty) {
          loaded = List.unmodifiable(_sortGroups(parsed));
        }
      }
    }

    final synced = _syncGroupsWithCatalog(loaded);
    groupListenable.value = List.unmodifiable(synced);

    if (!_groupsEqual(loaded, synced)) {
      await _saveGroups(synced, preferences: preferences);
    }
  }

  void _loadShelfSortFromPreferences(SharedPreferences preferences) {
    final code = preferences.getInt(_shelfSortStorageKey);
    shelfSortListenable.value = BookshelfSortType.fromCode(
      code ?? _defaultSortType.code,
    );
  }



  Future<void> _loadReaderGlobalConfigFromPreferences(
    SharedPreferences preferences,
  ) async {
    final raw = preferences.getString(_readerGlobalConfigStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      _readerGlobalConfig = ReaderViewConfigState.defaults;
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      _readerGlobalConfig = ReaderViewConfigState.defaults;
      return;
    }

    _readerGlobalConfig = ReaderViewConfigState.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Future<void> _saveReaderGlobalConfig({
    SharedPreferences? preferences,
  }) async {
    final pref = preferences ?? await SharedPreferences.getInstance();
    if (_readerGlobalConfig.isDefault) {
      await pref.remove(_readerGlobalConfigStorageKey);
      return;
    }

    await pref.setString(
      _readerGlobalConfigStorageKey,
      jsonEncode(_readerGlobalConfig.toJson()),
    );
  }

  Future<void> _loadReaderDraftsFromPreferences(
    SharedPreferences preferences,
  ) async {
    final raw = preferences.getString(_readerDraftStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return;
    }

    final next = <String, ReaderBookDraftState>{};
    for (final entry in decoded.entries) {
      final bookId = entry.key.toString().trim();
      if (bookId.isEmpty || entry.value is! Map) {
        continue;
      }

      final draft = ReaderBookDraftState.fromJson(
        (entry.value as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
      if (draft.isEmpty) {
        continue;
      }
      next[bookId] = draft;
    }

    _readerDrafts = Map.unmodifiable(next);
  }

  Future<void> _saveReaderDrafts({
    SharedPreferences? preferences,
  }) async {
    final pref = preferences ?? await SharedPreferences.getInstance();
    await pref.setString(
      _readerDraftStorageKey,
      jsonEncode(
        _readerDrafts.map(
          (bookId, draft) => MapEntry(bookId, draft.toJson()),
        ),
      ),
    );
  }

  Future<void> _replaceSources(List<BookSourceItem> sources) async {
    final sorted = _sortSources(sources);
    sourceListenable.value = List.unmodifiable(sorted);
    await _saveSources(sorted);
  }

  Future<void> _saveSources(List<BookSourceItem> sources) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _sourceStorageKey,
      jsonEncode(sources.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _replaceGroups(List<BookshelfGroupItem> groups) async {
    final normalized = _sortGroups(groups);
    groupListenable.value = List.unmodifiable(normalized);
    await _saveGroups(normalized);
  }

  Future<void> _saveGroups(
    List<BookshelfGroupItem> groups, {
    SharedPreferences? preferences,
  }) async {
    final pref = preferences ?? await SharedPreferences.getInstance();
    await pref.setString(
      _groupStorageKey,
      jsonEncode(groups.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _saveShelfSort(BookshelfSortType sortType) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_shelfSortStorageKey, sortType.code);
  }

  List<BookSourceItem> _sortSources(List<BookSourceItem> sources) {
    final sorted = [...sources]
      ..sort((left, right) {
        final orderCompare = left.customOrder.compareTo(right.customOrder);
        if (orderCompare != 0) {
          return orderCompare;
        }
        return left.name.compareTo(right.name);
      });

    return sorted
        .asMap()
        .entries
        .map(
          (entry) => entry.value.copyWith(
            customOrder: entry.key,
            lastUpdateTime: entry.value.lastUpdateTime ?? DateTime.now(),
          ),
        )
        .toList(growable: false);
  }

  List<BookshelfGroupItem> _sortGroups(List<BookshelfGroupItem> groups) {
    final sorted = [...groups]
      ..sort((left, right) {
        final orderCompare = left.order.compareTo(right.order);
        if (orderCompare != 0) {
          return orderCompare;
        }
        return left.name.compareTo(right.name);
      });

    return sorted
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(order: entry.key))
        .toList(growable: false);
  }

  bool _groupsEqual(
    List<BookshelfGroupItem> left,
    List<BookshelfGroupItem> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      final l = left[index];
      final r = right[index];
      if (l.id != r.id ||
          l.name != r.name ||
          l.order != r.order ||
          l.show != r.show ||
          l.enableRefresh != r.enableRefresh ||
          l.bookSort != r.bookSort) {
        return false;
      }
    }
    return true;
  }

  List<BookshelfGroupItem> _syncGroupsWithCatalog(
    List<BookshelfGroupItem> groups,
  ) {
    final next = [...groups];
    final names = next.map((item) => item.name).toSet();

    for (final book in _catalog) {
      final groupName = book.group.trim();
      if (groupName.isEmpty || names.contains(groupName)) {
        continue;
      }
      names.add(groupName);
      next.add(
        BookshelfGroupItem(
          id: _nextGroupId(),
          name: groupName,
          order: next.length,
        ),
      );
    }

    return _sortGroups(next);
  }

  void _replaceCatalogGroupName(String oldName, String newName) {
    final normalizedOld = oldName.trim();
    final normalizedNew = newName.trim();
    if (normalizedOld.isEmpty || normalizedNew.isEmpty) {
      return;
    }

    _catalog = List.unmodifiable(
      _catalog
          .map(
            (item) => item.group == normalizedOld
                ? item.copyWith(group: normalizedNew)
                : item,
          )
          .toList(growable: false),
    );
  }

  void _replaceShelfGroupName(String oldName, String newName) {
    final normalizedOld = oldName.trim();
    final normalizedNew = newName.trim();
    if (normalizedOld.isEmpty || normalizedNew.isEmpty) {
      return;
    }

    final next = shelfListenable.value
        .map(
          (item) => item.book.group == normalizedOld
              ? item.copyWith(book: item.book.copyWith(group: normalizedNew))
              : item,
        )
        .toList(growable: false);

    _replaceShelf(next);
  }

  void _replaceShelf(List<ShelfBookItem> items) {
    final deduped = _dedupShelf(items);
    final sorted = _sortShelf(deduped, shelfSortListenable.value);
    shelfListenable.value = List.unmodifiable(sorted);
  }

  List<ShelfBookItem> _dedupShelf(List<ShelfBookItem> items) {
    final seen = <String>{};
    final result = <ShelfBookItem>[];
    for (final item in items) {
      if (seen.add(item.book.id)) {
        result.add(item);
      }
    }
    return result;
  }

  List<ShelfBookItem> _sortShelf(
    List<ShelfBookItem> items,
    BookshelfSortType sortType,
  ) {
    final sorted = [...items]
      ..sort((left, right) {
        switch (sortType) {
          case BookshelfSortType.latestChapter:
            final leftValue =
                left.book.latestChapterUpdatedAt ?? left.readingState.updatedAt;
            final rightValue =
                right.book.latestChapterUpdatedAt ?? right.readingState.updatedAt;
            return rightValue.compareTo(leftValue);
          case BookshelfSortType.title:
            return left.book.title.compareTo(right.book.title);
          case BookshelfSortType.manual:
            final manualCompare = left.manualOrder.compareTo(right.manualOrder);
            if (manualCompare != 0) {
              return manualCompare;
            }
            return right.readingState.updatedAt.compareTo(
              left.readingState.updatedAt,
            );
          case BookshelfSortType.hybrid:
            final leftHybrid = _hybridTime(left);
            final rightHybrid = _hybridTime(right);
            return rightHybrid.compareTo(leftHybrid);
          case BookshelfSortType.author:
            return left.book.author.compareTo(right.book.author);
          case BookshelfSortType.recentRead:
            return right.readingState.updatedAt.compareTo(
              left.readingState.updatedAt,
            );
        }
      });
    return sorted;
  }

  DateTime _hybridTime(ShelfBookItem item) {
    final latest = item.book.latestChapterUpdatedAt;
    if (latest == null) {
      return item.readingState.updatedAt;
    }
    return latest.isAfter(item.readingState.updatedAt)
        ? latest
        : item.readingState.updatedAt;
  }

  int _nextTopManualOrder() {
    if (shelfListenable.value.isEmpty) {
      return 0;
    }
    var minOrder = shelfListenable.value.first.manualOrder;
    for (final item in shelfListenable.value) {
      minOrder = math.min(minOrder, item.manualOrder);
    }
    return minOrder - 1;
  }

  String _nextGroupId() {
    final randomPart = math.Random().nextInt(1 << 31);
    return 'group_${DateTime.now().microsecondsSinceEpoch}_$randomPart';
  }

  BookSourceItem _normalizeSource(BookSourceItem source) {
    return source.copyWith(
      url: source.url.trim(),
      name: source.name.trim(),
      host: source.host.trim(),
      group: source.group?.trim(),
    );
  }
}
