class BookItem {
  const BookItem({
    required this.id,
    required this.title,
    required this.author,
    required this.intro,
    required this.status,
    required this.lastChapter,
    required this.tags,
    required this.chapters,
    required this.group,
    required this.sourceName,
    required this.sourceUrl,
    required this.bookUrl,
    this.latestChapterUpdatedAt,
  });

  final String id;
  final String title;
  final String author;
  final String intro;
  final String status;
  final String lastChapter;
  final List<String> tags;
  final List<String> chapters;
  final String group;
  final String sourceName;
  final String sourceUrl;
  final String bookUrl;
  final DateTime? latestChapterUpdatedAt;

  BookItem copyWith({
    String? id,
    String? title,
    String? author,
    String? intro,
    String? status,
    String? lastChapter,
    List<String>? tags,
    List<String>? chapters,
    String? group,
    String? sourceName,
    String? sourceUrl,
    String? bookUrl,
    DateTime? latestChapterUpdatedAt,
  }) {
    return BookItem(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      intro: intro ?? this.intro,
      status: status ?? this.status,
      lastChapter: lastChapter ?? this.lastChapter,
      tags: tags ?? this.tags,
      chapters: chapters ?? this.chapters,
      group: group ?? this.group,
      sourceName: sourceName ?? this.sourceName,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      bookUrl: bookUrl ?? this.bookUrl,
      latestChapterUpdatedAt:
          latestChapterUpdatedAt ?? this.latestChapterUpdatedAt,
    );
  }
}

class ShelfReadingState {
  const ShelfReadingState({
    required this.chapterTitle,
    required this.progress,
    required this.updatedAt,
  });

  final String chapterTitle;
  final double progress;
  final DateTime updatedAt;

  ShelfReadingState copyWith({
    String? chapterTitle,
    double? progress,
    DateTime? updatedAt,
  }) {
    return ShelfReadingState(
      chapterTitle: chapterTitle ?? this.chapterTitle,
      progress: progress ?? this.progress,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ShelfBookItem {
  const ShelfBookItem({
    required this.book,
    required this.readingState,
    this.manualOrder = 0,
  });

  final BookItem book;
  final ShelfReadingState readingState;
  final int manualOrder;

  ShelfBookItem copyWith({
    BookItem? book,
    ShelfReadingState? readingState,
    int? manualOrder,
  }) {
    return ShelfBookItem(
      book: book ?? this.book,
      readingState: readingState ?? this.readingState,
      manualOrder: manualOrder ?? this.manualOrder,
    );
  }
}

enum BookshelfSortType {
  recentRead(code: 0, label: '最近阅读'),
  latestChapter(code: 1, label: '最新章节'),
  title(code: 2, label: '书名'),
  manual(code: 3, label: '手动顺序'),
  hybrid(code: 4, label: '综合时间'),
  author(code: 5, label: '作者');

  const BookshelfSortType({required this.code, required this.label});

  final int code;
  final String label;

  static BookshelfSortType fromCode(int code) {
    for (final item in values) {
      if (item.code == code) {
        return item;
      }
    }
    return BookshelfSortType.recentRead;
  }
}

class BookshelfGroupItem {
  const BookshelfGroupItem({
    required this.id,
    required this.name,
    required this.order,
    this.show = true,
    this.enableRefresh = true,
    this.bookSort = -1,
  });

  final String id;
  final String name;
  final int order;
  final bool show;
  final bool enableRefresh;
  final int bookSort;

  bool get followGlobalSort => bookSort < 0;

  int effectiveSort(int globalSortCode) {
    if (bookSort < 0) {
      return globalSortCode;
    }
    return bookSort;
  }

  BookshelfGroupItem copyWith({
    String? id,
    String? name,
    int? order,
    bool? show,
    bool? enableRefresh,
    int? bookSort,
  }) {
    return BookshelfGroupItem(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      show: show ?? this.show,
      enableRefresh: enableRefresh ?? this.enableRefresh,
      bookSort: bookSort ?? this.bookSort,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'order': order,
      'show': show,
      'enableRefresh': enableRefresh,
      'bookSort': bookSort,
    };
  }

  static BookshelfGroupItem fromJson(Map<String, Object?> json) {
    return BookshelfGroupItem(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      order: json['order'] as int? ?? 0,
      show: json['show'] as bool? ?? true,
      enableRefresh: json['enableRefresh'] as bool? ?? true,
      bookSort: json['bookSort'] as int? ?? -1,
    );
  }
}

class BookSourceItem {
  const BookSourceItem({
    required this.url,
    required this.name,
    required this.host,
    this.group,
    this.enabled = true,
    this.enabledExplore = true,
    this.customOrder = 0,
    this.lastUpdateTime,
  });

  final String url;
  final String name;
  final String host;
  final String? group;
  final bool enabled;
  final bool enabledExplore;
  final int customOrder;
  final DateTime? lastUpdateTime;

  bool get hasGroup => (group ?? '').trim().isNotEmpty;

  BookSourceItem copyWith({
    String? url,
    String? name,
    String? host,
    String? group,
    bool? enabled,
    bool? enabledExplore,
    int? customOrder,
    DateTime? lastUpdateTime,
  }) {
    return BookSourceItem(
      url: url ?? this.url,
      name: name ?? this.name,
      host: host ?? this.host,
      group: group ?? this.group,
      enabled: enabled ?? this.enabled,
      enabledExplore: enabledExplore ?? this.enabledExplore,
      customOrder: customOrder ?? this.customOrder,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'url': url,
      'name': name,
      'host': host,
      'group': group,
      'enabled': enabled,
      'enabledExplore': enabledExplore,
      'customOrder': customOrder,
      'lastUpdateTime': lastUpdateTime?.millisecondsSinceEpoch,
    };
  }

  static BookSourceItem fromJson(Map<String, Object?> json) {
    final lastUpdateRaw = json['lastUpdateTime'];
    final lastUpdateTime =
        lastUpdateRaw is int
        ? DateTime.fromMillisecondsSinceEpoch(lastUpdateRaw)
        : null;

    return BookSourceItem(
      url: (json['url'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      host: (json['host'] as String? ?? '').trim(),
      group: (json['group'] as String?)?.trim(),
      enabled: json['enabled'] as bool? ?? true,
      enabledExplore: json['enabledExplore'] as bool? ?? true,
      customOrder: json['customOrder'] as int? ?? 0,
      lastUpdateTime: lastUpdateTime,
    );
  }
}

class SearchKeywordItem {
  const SearchKeywordItem({
    required this.keyword,
    required this.usage,
    required this.updatedAt,
  });

  final String keyword;
  final int usage;
  final DateTime updatedAt;

  SearchKeywordItem copyWith({
    String? keyword,
    int? usage,
    DateTime? updatedAt,
  }) {
    return SearchKeywordItem(
      keyword: keyword ?? this.keyword,
      usage: usage ?? this.usage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum SearchScopeType { all, group, source }

class SearchScope {
  const SearchScope._({
    required this.type,
    required this.value,
    this.sourceLabel,
  });

  const SearchScope.all() : this._(type: SearchScopeType.all, value: '');

  const SearchScope.group(String group)
    : this._(type: SearchScopeType.group, value: group);

  const SearchScope.source(String sourceUrl, {String? sourceLabel})
    : this._(
        type: SearchScopeType.source,
        value: sourceUrl,
        sourceLabel: sourceLabel,
      );

  final SearchScopeType type;
  final String value;
  final String? sourceLabel;

  bool get isAll => type == SearchScopeType.all;

  bool get isSource => type == SearchScopeType.source;

  List<String> get displayNames {
    if (isAll || value.isEmpty) {
      return const [];
    }
    if (isSource) {
      return [sourceLabel?.trim().isNotEmpty == true ? sourceLabel! : value];
    }
    return [value];
  }

  String get display {
    if (isAll || value.isEmpty) {
      return '全部书源';
    }
    if (isSource && sourceLabel?.trim().isNotEmpty == true) {
      return sourceLabel!;
    }
    return value;
  }

  SearchScope withSourceLabel(String sourceLabel) {
    if (!isSource) {
      return this;
    }
    return SearchScope.source(value, sourceLabel: sourceLabel);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SearchScope &&
        other.type == type &&
        other.value == value &&
        other.sourceLabel == sourceLabel;
  }

  @override
  int get hashCode => Object.hash(type, value, sourceLabel);
}
