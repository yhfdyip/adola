import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/models/book_item.dart';
import '../../../core/services/app_log_service.dart';
import '../../../core/services/library_service.dart';
import '../../book/views/book_detail_view.dart';
import '../../source/views/source_list_view.dart';
import 'search_log_view.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key, this.initialScope});

  final SearchScope? initialScope;

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final LibraryService _libraryService = LibraryService.instance;
  final TextEditingController _keywordController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _precisionSearch = false;
  SearchScope _searchScope = const SearchScope.all();
  bool _showInputHelp = true;
  late List<BookItem> _results;

  @override
  void initState() {
    super.initState();
    if (widget.initialScope != null) {
      _searchScope = widget.initialScope!;
    }
    _searchScope = _normalizedScope(_searchScope);
    _results = _libraryService.searchBooks(
      '',
      scope: _searchScope,
      precision: _precisionSearch,
    );
    _libraryService.sourceListenable.addListener(_handleSourcesUpdated);
    _focusNode.addListener(_handleFocusChanged);
    _keywordController.addListener(_handleKeywordChanged);
  }

  @override
  void dispose() {
    _libraryService.sourceListenable.removeListener(_handleSourcesUpdated);
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _keywordController
      ..removeListener(_handleKeywordChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('搜索'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _openSearchMenu(context),
          child: const Icon(CupertinoIcons.ellipsis),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildSearchCard(context),
            const SizedBox(height: 14),
            _buildSearchConfigCard(),
            if (_showInputHelp) ...[
              const SizedBox(height: 14),
              _buildInputHelpCard(context),
            ],
            const SizedBox(height: 14),
            _ResultCard(results: _results),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard(BuildContext context) {
    return ShadCard(
      title: const Text('全站搜索'),
      description: const Text('对齐 legado：历史、范围、精准搜索'),
      child: Column(
        children: [
          ShadInput(
            controller: _keywordController,
            focusNode: _focusNode,
            placeholder: const Text('输入书名或作者'),
            leading: const Icon(CupertinoIcons.search),
            onSubmitted: (_) => _submitSearch(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ShadButton(
                  onPressed: _submitSearch,
                  child: const Text('搜索'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadButton.outline(
                  onPressed: _clearSearch,
                  child: const Text('清空'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchConfigCard() {
    return ShadCard(
      title: const Text('当前搜索配置'),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ShadBadge.secondary(child: Text('范围：${_searchScope.display}')),
          ShadBadge.outline(
            child: Text(_precisionSearch ? '精准搜索：开启' : '精准搜索：关闭'),
          ),
          if (_searchScope.isSource) ShadBadge.outline(child: Text('模式：单书源')),
        ],
      ),
    );
  }

  Widget _buildInputHelpCard(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ValueListenableBuilder<List<SearchKeywordItem>>(
      valueListenable: _libraryService.searchHistoryListenable,
      builder: (context, _, _) {
        final keyword = _keywordController.text.trim();
        final historyItems = _libraryService.searchHistory(keyword);
        final shelfMatches = _libraryService.searchShelfBooks(keyword);

        return ShadCard(
          title: const Text('输入帮助'),
          description: const Text('对齐 legado：书架匹配 + 搜索历史'),
          footer: Row(
            children: [
              ShadButton.ghost(
                onPressed: historyItems.isEmpty
                    ? null
                    : () => _confirmClearHistory(context),
                child: const Text('清空历史'),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (shelfMatches.isNotEmpty) ...[
                Text(
                  '书架匹配',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: shelfMatches
                      .map(
                        (item) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                builder: (context) =>
                                    BookDetailView(book: item.book),
                              ),
                            );
                          },
                          child: ShadBadge.secondary(
                            child: Text(item.book.title),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                '搜索历史',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              if (historyItems.isEmpty)
                Text(
                  '暂无搜索历史',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: historyItems
                      .map(
                        (item) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _useHistoryKeyword(item.keyword),
                          onLongPress: () =>
                              _confirmDeleteHistory(context, item.keyword),
                          child: ShadBadge.outline(
                            child: Text('${item.keyword} · ${item.usage}次'),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleFocusChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      if (_focusNode.hasFocus) {
        _showInputHelp = true;
      } else if (_keywordController.text.trim().isNotEmpty &&
          _results.isNotEmpty) {
        _showInputHelp = false;
      }
    });
  }

  void _handleKeywordChanged() {
    if (!mounted) {
      return;
    }
    if (_focusNode.hasFocus) {
      setState(() => _showInputHelp = true);
    }
  }

  void _submitSearch() {
    final keyword = _keywordController.text.trim();
    AppLogService.instance.put(
      keyword.isEmpty ? '执行搜索（空关键字）' : '执行搜索：$keyword（${_searchScope.display}）',
    );
    _executeSearch(saveKeyword: true);
  }

  void _handleSourcesUpdated() {
    if (!mounted) {
      return;
    }

    final normalizedScope = _normalizedScope(_searchScope);
    final results = _libraryService.searchBooks(
      _keywordController.text.trim(),
      scope: normalizedScope,
      precision: _precisionSearch,
    );

    setState(() {
      _searchScope = normalizedScope;
      _results = results;
    });
  }

  void _executeSearch({required bool saveKeyword, String? overrideKeyword}) {
    final keyword = (overrideKeyword ?? _keywordController.text).trim();
    final normalizedScope = _normalizedScope(_searchScope);

    if (saveKeyword) {
      _libraryService.saveSearchKeyword(keyword);
    }

    final results = _libraryService.searchBooks(
      keyword,
      scope: normalizedScope,
      precision: _precisionSearch,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _searchScope = normalizedScope;
      _results = results;
      _showInputHelp = false;
    });

    if (keyword.isNotEmpty && results.isEmpty && !normalizedScope.isAll) {
      AppLogService.instance.put('当前范围无结果：$keyword（${normalizedScope.display}）');
      _showScopedEmptyDialog(keyword);
    }
  }

  void _clearSearch() {
    _keywordController.clear();
    _focusNode.requestFocus();
    setState(() {
      _results = _libraryService.searchBooks(
        '',
        scope: _searchScope,
        precision: _precisionSearch,
      );
      _showInputHelp = true;
    });
  }

  void _useHistoryKeyword(String keyword) {
    _keywordController
      ..text = keyword
      ..selection = TextSelection.collapsed(offset: keyword.length);

    final shelfMatches = _libraryService.searchShelfBooks(keyword);
    if (shelfMatches.isEmpty) {
      AppLogService.instance.put('点击历史关键词：$keyword');
      _executeSearch(saveKeyword: false, overrideKeyword: keyword);
      return;
    }

    setState(() => _showInputHelp = true);
  }

  void _openSearchMenu(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('搜索菜单'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() => _precisionSearch = !_precisionSearch);
              if (_keywordController.text.trim().isNotEmpty) {
                _executeSearch(saveKeyword: false);
              }
            },
            child: Text(_precisionSearch ? '关闭精准搜索' : '开启精准搜索'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showScopeSelector(context);
            },
            child: const Text('设置搜索范围'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (context) => const SourceListView(),
                ),
              );
            },
            child: const Text('书源管理'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (context) => const SearchLogView(),
                ),
              );
            },
            child: const Text('搜索日志'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _confirmClearHistory(context);
            },
            child: const Text('清空搜索历史'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showScopeSelector(BuildContext pageContext) {
    final groups = _libraryService.allEnabledGroups();
    final sources = _libraryService.allEnabledSourceItems();

    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('搜索范围'),
        message: Text('当前：${_searchScope.display}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _applyScope(const SearchScope.all());
            },
            child: Text(_searchScope.isAll ? '✓ 全部书源' : '全部书源'),
          ),
          ...groups.map(
            (group) => CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _applyScope(SearchScope.group(group));
              },
              child: Text(
                _searchScope.type == SearchScopeType.group &&
                        _searchScope.value == group
                    ? '✓ 分组：$group'
                    : '分组：$group',
              ),
            ),
          ),
          ...sources.map(
            (source) => CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _applyScope(
                  SearchScope.source(source.url, sourceLabel: source.name),
                );
              },
              child: Text(
                _searchScope.type == SearchScopeType.source &&
                        _searchScope.value == source.url
                    ? '✓ 书源：${source.name}'
                    : '书源：${source.name}',
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _applyScope(SearchScope scope) {
    final normalized = _normalizedScope(scope);
    setState(() => _searchScope = normalized);

    final scopeLabel = normalized.isAll
        ? '全部书源'
        : normalized.isSource
        ? '书源 ${normalized.display}'
        : '分组 ${normalized.display}';
    AppLogService.instance.put('搜索范围切换：$scopeLabel');

    _executeSearch(saveKeyword: false);
  }

  SearchScope _normalizedScope(SearchScope scope) {
    if (!scope.isSource) {
      return scope;
    }

    final byUrl = _libraryService.sourceByUrl(scope.value);
    if (byUrl != null && byUrl.enabled) {
      if (scope.sourceLabel == byUrl.name) {
        return scope;
      }
      return scope.withSourceLabel(byUrl.name);
    }

    final byName = _libraryService.sourceByName(scope.value);
    if (byName != null && byName.enabled) {
      return SearchScope.source(byName.url, sourceLabel: byName.name);
    }

    return const SearchScope.all();
  }

  Future<void> _showScopedEmptyDialog(String keyword) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) {
        final title = _precisionSearch ? '分组无结果' : '范围无结果';
        final content = _precisionSearch
            ? '${_searchScope.display} 下未命中，是否关闭精准搜索再试？'
            : '${_searchScope.display} 下未命中，是否切换到全部书源？';

        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (_precisionSearch) {
                  setState(() => _precisionSearch = false);
                } else {
                  setState(() => _searchScope = const SearchScope.all());
                }
                _executeSearch(saveKeyword: false, overrideKeyword: keyword);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteHistory(
    BuildContext context,
    String keyword,
  ) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('删除历史'),
        content: Text('确认删除「$keyword」？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _libraryService.deleteSearchKeyword(keyword);
              AppLogService.instance.put('删除搜索历史：$keyword');
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('清空历史'),
        content: const Text('确认清空所有搜索历史吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _libraryService.clearSearchHistory();
              AppLogService.instance.put('清空搜索历史');
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.results});

  final List<BookItem> results;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ValueListenableBuilder<List<ShelfBookItem>>(
      valueListenable: LibraryService.instance.shelfListenable,
      builder: (context, _, _) {
        return ShadCard(
          title: const Text('结果预览（Mock）'),
          description: const Text('点击条目进入详情'),
          child: results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    '没有找到相关书籍',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                )
              : Column(
                  children: results
                      .map(
                        (item) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                builder: (context) =>
                                    BookDetailView(book: item),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: theme.radius,
                              border: Border.all(
                                color: theme.colorScheme.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    CupertinoIcons.book_fill,
                                    size: 18,
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: theme.textTheme.large
                                                  .copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .foreground,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                          if (LibraryService.instance.isInShelf(
                                            item.id,
                                          ))
                                            const ShadBadge.secondary(
                                              child: Text('已在书架'),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.author,
                                        style: theme.textTheme.small.copyWith(
                                          color:
                                              theme.colorScheme.mutedForeground,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.group} · ${item.sourceName}',
                                        style: theme.textTheme.small.copyWith(
                                          color:
                                              theme.colorScheme.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }
}
