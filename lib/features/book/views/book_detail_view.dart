import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/models/book_item.dart';
import '../../../core/services/library_service.dart';
import '../../reader/views/reader_view.dart';

class BookDetailView extends StatefulWidget {
  const BookDetailView({super.key, required this.book});

  final BookItem book;

  @override
  State<BookDetailView> createState() => _BookDetailViewState();
}

class _BookDetailViewState extends State<BookDetailView> {
  final LibraryService _libraryService = LibraryService.instance;

  late BookItem _book;
  late String _currentSource;
  late String _currentSourceUrl;
  late DateTime _tocUpdatedAt;
  late List<String> _chapters;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    final source = _libraryService.resolveSource(
      sourceUrl: _book.sourceUrl,
      sourceName: _book.sourceName,
    );

    if (source != null) {
      _currentSource = source.name;
      _currentSourceUrl = source.url;
      _book = _book.copyWith(sourceName: source.name, sourceUrl: source.url);
    } else {
      _currentSource = _book.sourceName;
      _currentSourceUrl = _book.sourceUrl;
    }

    _tocUpdatedAt = DateTime.now();
    _chapters = _buildMockChapters(_currentSource);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final inShelf = _libraryService.isInShelf(_book.id);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_book.title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showMoreActions(context, inShelf),
          child: Icon(
            CupertinoIcons.ellipsis,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ShadCard(
              title: Text(_book.title),
              description: Text('${_book.author} · $_currentSource'),
              footer: Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: () {
                        if (inShelf) {
                          _libraryService.removeFromShelf(_book.id);
                          setState(() {});
                          return;
                        }

                        _libraryService.addToShelf(_book);
                        setState(() {});
                        _showNoticeDialog(
                          '已加入书架',
                          '《${_book.title}》已加入书架。',
                        );
                      },
                      child: Text(inShelf ? '移出书架' : '加入书架'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ShadButton(
                      onPressed: () => _startReading(context),
                      child: const Text('开始阅读'),
                    ),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _book.intro,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ShadBadge.secondary(child: Text(_book.status)),
                      ShadBadge.outline(child: Text(_book.group)),
                      ..._book.tags.map(
                        (tag) => ShadBadge.outline(child: Text(tag)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ShadCard(
              title: const Text('目录预览'),
              description: Text(
                '$_currentSource · ${_formatTime(_tocUpdatedAt)}',
              ),
              child: Column(
                children: _chapters
                    .map(
                      (chapter) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _openChapter(context, chapter),
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: theme.radius,
                            border: Border.all(color: theme.colorScheme.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  chapter,
                                  style: theme.textTheme.small.copyWith(
                                    color: theme.colorScheme.foreground,
                                  ),
                                ),
                              ),
                              Icon(
                                CupertinoIcons.chevron_forward,
                                size: 12,
                                color: theme.colorScheme.mutedForeground,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreActions(BuildContext context, bool inShelf) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(_book.title),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _startReading(context);
            },
            child: const Text('开始阅读'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() => _tocUpdatedAt = DateTime.now());
            },
            child: const Text('刷新详情'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _refreshToc();
            },
            child: const Text('刷新目录'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showSourceSelector(context);
            },
            child: const Text('切换书源'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _openTocPreview(context);
            },
            child: const Text('查看目录'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _copyBookUrl();
            },
            child: const Text('复制书籍链接'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _copyTocUrl();
            },
            child: const Text('复制目录链接'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _shareBook();
            },
            child: const Text('分享书籍信息'),
          ),
          if (inShelf)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _libraryService.pinShelfBook(_book.id);
                _showNoticeDialog('已置顶', '《${_book.title}》已置顶到书架前列。');
              },
              child: const Text('置顶书架'),
            ),
          if (inShelf)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _libraryService.removeFromShelf(_book.id);
                setState(() {});
              },
              child: const Text('移出书架'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showSourceSelector(BuildContext pageContext) {
    final sourceOptions = _libraryService.allEnabledSourceItems();

    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('切换书源'),
        message: Text('当前：$_currentSource'),
        actions: sourceOptions
            .map(
              (source) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _switchSource(source.url, source.name);
                },
                child: Text(
                  source.url == _currentSourceUrl ? '✓ ${source.name}' : source.name,
                ),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _openTocPreview(BuildContext pageContext) {
    final theme = ShadTheme.of(pageContext);
    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => Container(
        height: 360,
        decoration: BoxDecoration(
          color: theme.colorScheme.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Text(
                '目录（$_currentSource）',
                textAlign: TextAlign.center,
                style: theme.textTheme.large.copyWith(
                  color: theme.colorScheme.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ..._chapters.map(
                (chapter) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openChapter(pageContext, chapter);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: theme.radius,
                      border: Border.all(color: theme.colorScheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            chapter,
                            style: theme.textTheme.small.copyWith(
                              color: theme.colorScheme.foreground,
                            ),
                          ),
                        ),
                        Icon(
                          CupertinoIcons.play_arrow_solid,
                          size: 12,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startReading(BuildContext context) {
    final shelfBook = _libraryService.shelfBookById(_book.id);
    final preferredChapter = _resolveReadableChapter(
      shelfBook?.readingState.chapterTitle,
    );
    _openChapter(context, preferredChapter);
  }

  String _resolveReadableChapter(String? preferredChapter) {
    final normalizedPreferredChapter = preferredChapter == null
        ? null
        : _normalizedChapter(preferredChapter);
    final normalizedLastChapter = _normalizedChapter(_book.lastChapter);

    for (final chapter in _chapters) {
      if (normalizedPreferredChapter != null &&
          _normalizedChapter(chapter) == normalizedPreferredChapter) {
        return chapter;
      }
    }

    for (final chapter in _chapters) {
      if (_normalizedChapter(chapter) == normalizedLastChapter) {
        return chapter;
      }
    }

    return _chapters.first;
  }

  String _normalizedChapter(String chapter) {
    final suffixStart = chapter.indexOf('（');
    if (suffixStart > 0 && chapter.endsWith('）')) {
      return chapter.substring(0, suffixStart);
    }
    return chapter;
  }

  void _switchSource(String sourceUrl, String sourceName) {
    setState(() {
      _currentSource = sourceName;
      _currentSourceUrl = sourceUrl;
      _book = _libraryService.replaceBookSource(
        book: _book,
        sourceUrl: sourceUrl,
        sourceName: sourceName,
      );
      _refreshTocData();
    });
  }

  void _refreshToc() {
    setState(_refreshTocData);
  }

  void _refreshTocData() {
    _tocUpdatedAt = DateTime.now();
    _chapters = _buildMockChapters(_currentSource);
  }

  List<String> _buildMockChapters(String source) {
    final base = _book.chapters;
    switch (source) {
      case '备用书源 B':
        return base.map((chapter) => '$chapter（B）').toList(growable: false);
      case '极速书源 C':
        return base.map((chapter) => '$chapter（C）').toList(growable: false);
      default:
        return List<String>.of(base, growable: false);
    }
  }

  void _openChapter(BuildContext context, String chapter) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => ReaderView(
          bookId: _book.id,
          bookTitle: _book.title,
          chapterTitle: chapter,
          chapters: _chapters,
          sourceName: _currentSource,
        ),
      ),
    );
  }

  Future<void> _copyBookUrl() async {
    await _copyToClipboard(_book.bookUrl, '已复制书籍链接');
  }

  Future<void> _copyTocUrl() async {
    await _copyToClipboard('${_book.bookUrl}/toc', '已复制目录链接');
  }

  Future<void> _shareBook() async {
    final shareText =
        '${_book.title} - ${_book.author}\n'
        '书源：$_currentSource\n'
        '链接：${_book.bookUrl}';
    await _copyToClipboard(shareText, '已复制分享内容');
  }

  Future<void> _copyToClipboard(String text, String successTitle) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    _showNoticeDialog(successTitle, text);
  }

  void _showNoticeDialog(String title, String content) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '更新于 $hour:$minute';
  }
}
