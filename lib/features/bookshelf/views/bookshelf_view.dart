import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/models/book_item.dart';
import '../../../core/services/app_log_service.dart';
import '../../../core/services/library_service.dart';
import '../../book/views/book_detail_view.dart';
import '../../reader/views/reader_view.dart';

class BookshelfView extends StatefulWidget {
  const BookshelfView({super.key});

  @override
  State<BookshelfView> createState() => _BookshelfViewState();
}

class _BookshelfViewState extends State<BookshelfView> {
  final LibraryService _libraryService = LibraryService.instance;

  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    _libraryService.groupListenable.addListener(_syncSelectedGroup);
  }

  @override
  void dispose() {
    _libraryService.groupListenable.removeListener(_syncSelectedGroup);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('书架'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _openBookshelfMenu(context),
          child: const Icon(CupertinoIcons.ellipsis),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<List<ShelfBookItem>>(
          valueListenable: _libraryService.shelfListenable,
          builder: (context, _, _) {
            return ValueListenableBuilder<List<BookshelfGroupItem>>(
              valueListenable: _libraryService.groupListenable,
              builder: (context, groups, _) {
                return ValueListenableBuilder<BookshelfSortType>(
                  valueListenable: _libraryService.shelfSortListenable,
                  builder: (context, _, _) {
                    final selectedGroup = _resolveSelectedGroup(groups);
                    final selectedGroupId = selectedGroup?.id;
                    final visibleGroups = _libraryService.shelfVisibleGroups();
                    final shelfBooks = _libraryService.shelfBooksByGroup(
                      groupId: selectedGroupId,
                    );
                    final currentSort = _libraryService.effectiveSortForGroup(
                      selectedGroupId,
                    );

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        _buildGroupCard(context, visibleGroups, selectedGroupId),
                        const SizedBox(height: 14),
                        _buildShelfCard(
                          context,
                          shelfBooks,
                          currentSort,
                          selectedGroup,
                        ),
                        const SizedBox(height: 14),
                        _ShelfSummary(
                          totalCount: _libraryService.shelfBooks.length,
                          filteredCount: shelfBooks.length,
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    List<BookshelfGroupItem> groups,
    String? selectedGroupId,
  ) {
    return ShadCard(
      title: const Text('分组视图'),
      description: const Text('对齐 legado：显示分组 + 分组筛选'),
      footer: Row(
        children: [
          Expanded(
            child: ShadButton.outline(
              onPressed: () => _openGroupManage(context),
              child: const Text('分组管理'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ShadButton.secondary(
              onPressed: _selectedGroupId == null
                  ? null
                  : () {
                      setState(() => _selectedGroupId = null);
                      AppLogService.instance.put('书架分组切换：全部');
                    },
              child: const Text('清除筛选'),
            ),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _GroupBadge(
            title: '全部',
            selected: selectedGroupId == null,
            onTap: () {
              setState(() => _selectedGroupId = null);
              AppLogService.instance.put('书架分组切换：全部');
            },
          ),
          ...groups.map(
            (group) => _GroupBadge(
              title: group.name,
              selected: selectedGroupId == group.id,
              onTap: () {
                setState(() => _selectedGroupId = group.id);
                AppLogService.instance.put('书架分组切换：${group.name}');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShelfCard(
    BuildContext context,
    List<ShelfBookItem> shelfBooks,
    BookshelfSortType currentSort,
    BookshelfGroupItem? selectedGroup,
  ) {
    final title = selectedGroup == null ? '最近阅读' : '分组书架';
    final description = selectedGroup == null
        ? '继续上次阅读的章节'
        : '当前分组：${selectedGroup.name}';

    final removableTarget = shelfBooks.isEmpty ? null : shelfBooks.last;

    return ShadCard(
      title: Text(title),
      description: Text(description),
      footer: Row(
        children: [
          Expanded(
            child: ShadButton.secondary(
              onPressed: removableTarget == null
                  ? null
                  : () {
                      _libraryService.removeFromShelf(removableTarget.book.id);
                      AppLogService.instance.put(
                        '书架移除：${removableTarget.book.title}',
                      );
                    },
              child: const Text('移除一本'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ShadButton(
              onPressed: shelfBooks.isEmpty
                  ? null
                  : () => _openReader(context, shelfBooks.first),
              child: const Text('继续阅读'),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ShadBadge.secondary(
                child: Text('排序：${currentSort.label}'),
              ),
              if (selectedGroup != null && selectedGroup.followGlobalSort)
                const ShadBadge.outline(child: Text('分组排序：跟随全局')),
            ],
          ),
          const SizedBox(height: 10),
          if (shelfBooks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('当前分组暂无书籍'),
            )
          else
            Column(
              children: shelfBooks
                  .map(
                    (shelfBook) => Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _BookRow(shelfBook: shelfBook),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  void _syncSelectedGroup() {
    if (!mounted || _selectedGroupId == null) {
      return;
    }

    final group = _libraryService.groupById(_selectedGroupId!);
    if (group == null || !group.show) {
      setState(() => _selectedGroupId = null);
    }
  }

  BookshelfGroupItem? _resolveSelectedGroup(List<BookshelfGroupItem> groups) {
    if (_selectedGroupId == null) {
      return null;
    }

    for (final group in groups) {
      if (group.id == _selectedGroupId && group.show) {
        return group;
      }
    }

    return null;
  }

  void _openBookshelfMenu(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('书架菜单'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showSortSelector(context);
            },
            child: const Text('切换排序'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _openGroupManage(context);
            },
            child: const Text('分组管理'),
          ),
          if (_selectedGroupId != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                setState(() => _selectedGroupId = null);
                AppLogService.instance.put('书架分组切换：全部');
              },
              child: const Text('返回全部'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showSortSelector(BuildContext pageContext) {
    final selectedGroup = _selectedGroupId == null
        ? null
        : _libraryService.groupById(_selectedGroupId!);

    final currentSort = _libraryService.effectiveSortForGroup(_selectedGroupId);
    final globalSort = _libraryService.shelfSortListenable.value;

    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('排序方式'),
        message: Text(
          selectedGroup == null
              ? '当前：全局排序'
              : '当前分组：${selectedGroup.name}',
        ),
        actions: [
          if (selectedGroup != null)
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await _libraryService.setGroupSort(selectedGroup.id, null);
                AppLogService.instance.put(
                  '分组排序切换：${selectedGroup.name}（跟随全局 ${globalSort.label}）',
                );
              },
              child: Text(
                selectedGroup.followGlobalSort
                    ? '✓ 跟随全局（${globalSort.label}）'
                    : '跟随全局（${globalSort.label}）',
              ),
            ),
          ...BookshelfSortType.values.map(
            (sortType) => CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                if (selectedGroup == null) {
                  await _libraryService.setGlobalShelfSort(sortType);
                  AppLogService.instance.put('全局排序切换：${sortType.label}');
                } else {
                  await _libraryService.setGroupSort(
                    selectedGroup.id,
                    sortType,
                  );
                  AppLogService.instance.put(
                    '分组排序切换：${selectedGroup.name}（${sortType.label}）',
                  );
                }
                if (mounted) {
                  setState(() {});
                }
              },
              child: Text(
                currentSort == sortType
                    ? '✓ ${sortType.label}'
                    : sortType.label,
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

  Future<void> _openGroupManage(BuildContext context) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => const _BookshelfGroupManageView(),
      ),
    );
  }

  void _openReader(BuildContext context, ShelfBookItem shelfBook) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => ReaderView(
          bookId: shelfBook.book.id,
          bookTitle: shelfBook.book.title,
          chapterTitle: shelfBook.readingState.chapterTitle,
          chapters: shelfBook.book.chapters,
          sourceName: shelfBook.book.sourceName,
        ),
      ),
    );
  }
}

class _BookshelfGroupManageView extends StatefulWidget {
  const _BookshelfGroupManageView();

  @override
  State<_BookshelfGroupManageView> createState() =>
      _BookshelfGroupManageViewState();
}

class _BookshelfGroupManageViewState extends State<_BookshelfGroupManageView> {
  final LibraryService _libraryService = LibraryService.instance;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('分组管理'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showCreateGroupDialog,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<List<BookshelfGroupItem>>(
          valueListenable: _libraryService.groupListenable,
          builder: (context, groups, _) {
            final sorted = _libraryService.allGroups();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                ShadCard(
                  title: const Text('分组列表'),
                  description: const Text('对齐 legado：新增/改名/显隐/顺序/排序策略'),
                  child: sorted.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('暂无分组，请先新增分组。'),
                        )
                      : Column(
                          children: sorted.asMap().entries.map((entry) {
                            final index = entry.key;
                            final group = entry.value;
                            final sortType = group.followGlobalSort
                                ? null
                                : BookshelfSortType.fromCode(group.bookSort);

                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _GroupManageTile(
                                group: group,
                                index: index,
                                canMoveUp: index > 0,
                                canMoveDown: index < sorted.length - 1,
                                sortLabel: sortType?.label ?? '跟随全局',
                                onRename: () => _showRenameGroupDialog(group),
                                onDelete: () => _confirmDeleteGroup(group),
                                onMoveUp: index > 0
                                    ? () => _moveGroup(group.id, index - 1)
                                    : null,
                                onMoveDown: index < sorted.length - 1
                                    ? () => _moveGroup(group.id, index + 1)
                                    : null,
                                onSort: () => _showGroupSortSelector(group),
                                onToggleVisible: (value) async {
                                  await _libraryService.setGroupVisible(
                                    group.id,
                                    value,
                                  );
                                  AppLogService.instance.put(
                                    value
                                        ? '分组显示：${group.name}'
                                        : '分组隐藏：${group.name}',
                                  );
                                },
                                onToggleRefresh: (value) async {
                                  await _libraryService.setGroupEnableRefresh(
                                    group.id,
                                    value,
                                  );
                                  AppLogService.instance.put(
                                    value
                                        ? '分组刷新启用：${group.name}'
                                        : '分组刷新停用：${group.name}',
                                  );
                                },
                              ),
                            );
                          }).toList(growable: false),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _moveGroup(String groupId, int targetIndex) async {
    await _libraryService.moveGroup(groupId, targetIndex);
    AppLogService.instance.put('调整分组顺序');
  }

  Future<void> _showCreateGroupDialog() async {
    final controller = TextEditingController();

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('新增分组'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '输入分组名称',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              final name = controller.text.trim();
              try {
                await _libraryService.createGroup(name);
                AppLogService.instance.put('新增分组：$name');
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
              } on FormatException catch (error) {
                _showNotice('保存失败', error.message);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameGroupDialog(BookshelfGroupItem group) async {
    final controller = TextEditingController(text: group.name);

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('重命名分组'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: '输入分组名称',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              final name = controller.text.trim();
              try {
                await _libraryService.renameGroup(group.id, name);
                AppLogService.instance.put('重命名分组：${group.name} -> $name');
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
              } on FormatException catch (error) {
                _showNotice('保存失败', error.message);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteGroup(BookshelfGroupItem group) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('删除分组'),
        content: Text('确认删除「${group.name}」？删除后该分组书籍将归到“未分组”。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              await _libraryService.removeGroup(group.id);
              AppLogService.instance.put('删除分组：${group.name}');
              if (!dialogContext.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showGroupSortSelector(BookshelfGroupItem group) {
    final globalSort = _libraryService.shelfSortListenable.value;
    final currentSort = _libraryService.effectiveSortForGroup(group.id);

    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text('分组排序：${group.name}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.of(sheetContext).pop();
              await _libraryService.setGroupSort(group.id, null);
              AppLogService.instance.put(
                '分组排序切换：${group.name}（跟随全局 ${globalSort.label}）',
              );
            },
            child: Text(
              group.followGlobalSort
                  ? '✓ 跟随全局（${globalSort.label}）'
                  : '跟随全局（${globalSort.label}）',
            ),
          ),
          ...BookshelfSortType.values.map(
            (sortType) => CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await _libraryService.setGroupSort(group.id, sortType);
                AppLogService.instance.put(
                  '分组排序切换：${group.name}（${sortType.label}）',
                );
              },
              child: Text(
                !group.followGlobalSort && currentSort == sortType
                    ? '✓ ${sortType.label}'
                    : sortType.label,
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

  void _showNotice(String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _GroupManageTile extends StatelessWidget {
  const _GroupManageTile({
    required this.group,
    required this.index,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.sortLabel,
    required this.onRename,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onSort,
    required this.onToggleVisible,
    required this.onToggleRefresh,
  });

  final BookshelfGroupItem group;
  final int index;
  final bool canMoveUp;
  final bool canMoveDown;
  final String sortLabel;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onSort;
  final ValueChanged<bool> onToggleVisible;
  final ValueChanged<bool> onToggleRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: theme.radius,
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${index + 1}. ${group.name}',
                  style: theme.textTheme.large.copyWith(
                    color: theme.colorScheme.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ShadBadge.secondary(child: Text('排序：$sortLabel')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('显示'),
                    const SizedBox(width: 8),
                    ShadSwitch(
                      value: group.show,
                      onChanged: onToggleVisible,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Text('启用刷新'),
                    const SizedBox(width: 8),
                    ShadSwitch(
                      value: group.enableRefresh,
                      onChanged: onToggleRefresh,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ShadButton.outline(
                onPressed: onMoveUp,
                child: const Text('上移'),
              ),
              ShadButton.outline(
                onPressed: onMoveDown,
                child: const Text('下移'),
              ),
              ShadButton.secondary(onPressed: onSort, child: const Text('排序')),
              ShadButton.secondary(onPressed: onRename, child: const Text('编辑')),
              ShadButton.destructive(onPressed: onDelete, child: const Text('删除')),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupBadge extends StatelessWidget {
  const _GroupBadge({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: selected
          ? ShadBadge.secondary(child: Text('✓ $title'))
          : ShadBadge.outline(child: Text(title)),
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({required this.shelfBook});

  final ShelfBookItem shelfBook;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: theme.radius,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openReader(context, shelfBook),
        onLongPress: () {
          Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (context) => BookDetailView(book: shelfBook.book),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shelfBook.book.title,
                    style: theme.textTheme.large.copyWith(
                      color: theme.colorScheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ShadBadge.secondary(child: Text(shelfBook.book.status)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              shelfBook.readingState.chapterTitle,
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 10),
            ShadProgress(value: shelfBook.readingState.progress, minHeight: 6),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${(shelfBook.readingState.progress * 100).round()}%',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                const Spacer(),
                Text(
                  LibraryService.instance.relativeUpdatedAt(
                    shelfBook.readingState.updatedAt,
                  ),
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static void _openReader(BuildContext context, ShelfBookItem shelfBook) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => ReaderView(
          bookId: shelfBook.book.id,
          bookTitle: shelfBook.book.title,
          chapterTitle: shelfBook.readingState.chapterTitle,
          chapters: shelfBook.book.chapters,
          sourceName: shelfBook.book.sourceName,
        ),
      ),
    );
  }
}

class _ShelfSummary extends StatelessWidget {
  const _ShelfSummary({required this.totalCount, required this.filteredCount});

  final int totalCount;
  final int filteredCount;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
      title: const Text('书架统计'),
      description: const Text('本地缓存统计（演示数据）'),
      footer: Text(
        '排序语义对齐 legado：最近阅读 / 最新章节 / 书名 / 手动 / 综合时间 / 作者。',
        style: theme.textTheme.small.copyWith(
          color: theme.colorScheme.mutedForeground,
        ),
      ),
      child: Row(
        children: [
          _SummaryItem(label: '全部', value: '$totalCount'),
          _SummaryItem(label: '当前筛选', value: '$filteredCount'),
          _SummaryItem(
            label: '连载中',
            value: '${(filteredCount * 0.5).round()}',
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.h3.copyWith(
              color: theme.colorScheme.foreground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
