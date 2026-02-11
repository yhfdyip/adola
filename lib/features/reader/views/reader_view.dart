import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/models/reader_state.dart';
import '../../../core/services/app_log_service.dart';
import '../../../core/services/library_service.dart';
import '../../search/views/search_log_view.dart';

enum _ReaderTone { follow, warm, dark }

enum _ReaderPageAnim { cover, slide, simulation, scroll, none }

enum _ReaderImageStyle { normal, full, text, single }

enum _ReadProgressBehavior { page, chapter }

class _SearchHit {
  const _SearchHit({required this.paragraphIndex, required this.start});

  final int paragraphIndex;
  final int start;
}

class ReaderView extends StatefulWidget {
  const ReaderView({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.chapterTitle,
    this.chapters = const [],
    this.sourceName,
    this.initialSearchWord,
  });

  final String bookId;
  final String bookTitle;
  final String chapterTitle;
  final List<String> chapters;
  final String? sourceName;
  final String? initialSearchWord;

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  final LibraryService _libraryService = LibraryService.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  double _fontSize = 18;
  double _lineHeight = 1.75;
  double _letterSpacing = 0;
  bool _boldText = false;
  bool _showToolbar = true;
  bool _showSearchPanel = false;
  bool _autoPage = false;
  bool _expandTextMenu = false;
  String _selectedText = '';
  late double _progress;
  late List<String> _originChapters;
  late List<String> _chapters;
  late int _chapterIndex;
  late List<GlobalKey> _paragraphKeys;
  _ReaderTone _tone = _ReaderTone.follow;
  _ReaderPageAnim _pageAnim = _ReaderPageAnim.cover;
  _ReaderImageStyle _imageStyle = _ReaderImageStyle.normal;
  _ReadProgressBehavior _progressBehavior = _ReadProgressBehavior.page;

  bool _readAloudRunning = false;
  bool _readAloudPaused = false;
  bool _followSystemTts = true;
  double _readAloudSpeed = 1.0;
  int _readAloudTimerMinutes = 0;

  bool _replaceRuleEnabled = true;
  bool _reSegmentEnabled = false;
  bool _sameTitleRemoved = false;
  bool _reverseContent = false;
  bool _simulatedReading = false;
  bool _showReadTitleAddition = true;

  final Map<int, List<String>> _editedChapterParagraphs = {};
  final Map<int, String> _editedChapterTitles = {};
  List<ReaderReplaceRuleState> _replaceRules = const [
    ReaderReplaceRuleState(
      name: '压缩空白',
      pattern: r'\s{2,}',
      replacement: ' ',
      enabled: true,
      isRegex: true,
    ),
  ];

  Timer? _autoPageTimer;

  List<_SearchHit> _searchHits = const [];
  int _searchHitIndex = -1;

  static const List<String> _baseParagraphs = [
    '雨停后，巷口只剩屋檐落下的细水声。',
    '他沿着青石路往前走，鞋底踩过积水，留下断续的倒影。',
    '远处路灯忽明忽暗，像一封没有写完的信，停在深夜的句号前。',
    '手机屏幕轻轻震动，新的线索只写了四个字：别回头看。',
    '他停了一秒，还是把外套领子往上拢了拢，继续向前。',
    '城市在凌晨时分变得陌生而诚实，每一扇窗都像在守口如瓶。',
  ];

  @override
  void initState() {
    super.initState();
    final shelfItem = _libraryService.shelfBookById(widget.bookId);
    _progress = shelfItem?.readingState.progress ?? 0.12;

    final chapterCandidates = widget.chapters.isNotEmpty
        ? widget.chapters
        : [widget.chapterTitle];
    _originChapters = List<String>.from(chapterCandidates, growable: false);
    _chapters = List<String>.from(_originChapters, growable: true);

    final chapterIndexFromParam = _chapters.indexOf(widget.chapterTitle);
    final chapterIndexFromShelf = shelfItem == null
        ? -1
        : _chapters.indexOf(shelfItem.readingState.chapterTitle);

    if (chapterIndexFromParam >= 0) {
      _chapterIndex = chapterIndexFromParam;
    } else if (chapterIndexFromShelf >= 0) {
      _chapterIndex = chapterIndexFromShelf;
    } else {
      _chapterIndex = 0;
    }

    _restoreReaderDraft();
    _paragraphKeys = _buildParagraphKeys();

    final initialSearchWord = widget.initialSearchWord?.trim();
    if (initialSearchWord != null && initialSearchWord.isNotEmpty) {
      _searchController.text = initialSearchWord;
      _showSearchPanel = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runSearch(initialSearchWord);
      });
    }
  }

  @override
  void dispose() {
    _autoPageTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String get _currentChapter => _chapters[_chapterIndex];

  bool get _hasPreviousChapter => _chapterIndex > 0;

  bool get _hasNextChapter => _chapterIndex < _chapters.length - 1;

  String get _searchQuery => _searchController.text.trim();

  List<String> get _currentParagraphs {
    final paragraphs = _paragraphsByChapterIndex(_chapterIndex);
    if (_reverseContent) {
      return List.unmodifiable(paragraphs.reversed.toList(growable: false));
    }
    return paragraphs;
  }


  void _restoreReaderDraft() {
    _restoreReaderConfig(_libraryService.readerGlobalConfig());

    final draft = _libraryService.readerDraftByBookId(widget.bookId);
    if (draft.isEmpty) {
      return;
    }

    _editedChapterParagraphs
      ..clear()
      ..addAll(
        draft.chapterContentOverrides.map(
          (chapterIndex, lines) => MapEntry(
            chapterIndex,
            List<String>.from(lines, growable: false),
          ),
        ),
      );

    _editedChapterTitles
      ..clear()
      ..addAll(
        draft.chapterTitleOverrides.map(
          (chapterIndex, chapterTitle) => MapEntry(chapterIndex, chapterTitle),
        ),
      );

    for (final entry in _editedChapterTitles.entries) {
      if (entry.key < 0 || entry.key >= _chapters.length) {
        continue;
      }
      _chapters[entry.key] = entry.value;
    }

    if (draft.replaceRules.isNotEmpty) {
      _replaceRules = List<ReaderReplaceRuleState>.from(draft.replaceRules);
    }

    final config = draft.config;
    if (config != null) {
      _restoreReaderConfig(config);
    }
  }

  _ReaderTone _toneFromName(String name) {
    for (final tone in _ReaderTone.values) {
      if (tone.name == name) {
        return tone;
      }
    }
    return _ReaderTone.follow;
  }

  _ReaderPageAnim _pageAnimFromName(String name) {
    for (final anim in _ReaderPageAnim.values) {
      if (anim.name == name) {
        return anim;
      }
    }
    return _ReaderPageAnim.cover;
  }

  _ReaderImageStyle _imageStyleFromName(String name) {
    for (final style in _ReaderImageStyle.values) {
      if (style.name == name) {
        return style;
      }
    }
    return _ReaderImageStyle.normal;
  }

  _ReadProgressBehavior _progressBehaviorFromName(String name) {
    for (final behavior in _ReadProgressBehavior.values) {
      if (behavior.name == name) {
        return behavior;
      }
    }
    return _ReadProgressBehavior.page;
  }

  void _restoreReaderConfig(ReaderViewConfigState config) {
    _tone = _toneFromName(config.tone);
    _pageAnim = _pageAnimFromName(config.pageAnim);
    _imageStyle = _imageStyleFromName(config.imageStyle);
    _progressBehavior = _progressBehaviorFromName(config.progressBehavior);
    _fontSize = config.fontSize.clamp(14, 30).toDouble();
    _lineHeight = config.lineHeight.clamp(1.4, 2.2).toDouble();
    _letterSpacing = config.letterSpacing.clamp(-0.2, 2.0).toDouble();
    _boldText = config.boldText;
    _expandTextMenu = config.expandTextMenu;
    _replaceRuleEnabled = config.replaceRuleEnabled;
    _reSegmentEnabled = config.reSegmentEnabled;
    _sameTitleRemoved = config.sameTitleRemoved;
    _reverseContent = config.reverseContent;
    _simulatedReading = config.simulatedReading;
    _showReadTitleAddition = config.showReadTitleAddition;
    _followSystemTts = config.followSystemTts;
    _readAloudSpeed = config.readAloudSpeed.clamp(0.5, 3.0).toDouble();
    _readAloudTimerMinutes = config.readAloudTimerMinutes < 0
        ? 0
        : config.readAloudTimerMinutes;
  }

  ReaderViewConfigState _currentReaderConfig() {
    return ReaderViewConfigState(
      tone: _tone.name,
      pageAnim: _pageAnim.name,
      imageStyle: _imageStyle.name,
      progressBehavior: _progressBehavior.name,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      letterSpacing: _letterSpacing,
      boldText: _boldText,
      expandTextMenu: _expandTextMenu,
      replaceRuleEnabled: _replaceRuleEnabled,
      reSegmentEnabled: _reSegmentEnabled,
      sameTitleRemoved: _sameTitleRemoved,
      reverseContent: _reverseContent,
      simulatedReading: _simulatedReading,
      showReadTitleAddition: _showReadTitleAddition,
      followSystemTts: _followSystemTts,
      readAloudSpeed: _readAloudSpeed,
      readAloudTimerMinutes: _readAloudTimerMinutes,
    );
  }

  void _persistReaderConfigInBackground() {
    unawaited(_persistReaderConfig());
  }

  Future<void> _persistReaderConfig() async {
    final config = _currentReaderConfig();
    await _libraryService.saveReaderGlobalConfig(config);
    await _persistReaderDraft();
  }

  List<GlobalKey> _buildParagraphKeys() {
    return List<GlobalKey>.generate(
      _currentParagraphs.length,
      (_) => GlobalKey(),
    );
  }

  List<String> _rawParagraphsByChapterIndex(int chapterIndex) {
    return _editedChapterParagraphs[chapterIndex] ?? _baseParagraphs;
  }

  List<String> _paragraphsByChapterIndex(int chapterIndex) {
    final chapterTitle = _chapters[chapterIndex];
    var paragraphs = List<String>.from(_rawParagraphsByChapterIndex(chapterIndex));

    if (_sameTitleRemoved) {
      paragraphs = paragraphs
          .where((paragraph) => paragraph.trim() != chapterTitle.trim())
          .toList(growable: false);
    } else {
      paragraphs = [chapterTitle, ...paragraphs];
    }

    if (_reSegmentEnabled) {
      paragraphs = _reSegmentParagraphs(paragraphs);
    }

    if (_replaceRuleEnabled) {
      paragraphs = paragraphs
          .map(_applyReplaceRulesToParagraph)
          .toList(growable: false);
    }

    return List.unmodifiable(
      paragraphs.where((paragraph) => paragraph.trim().isNotEmpty),
    );
  }

  List<String> _reSegmentParagraphs(List<String> source) {
    final output = <String>[];
    for (final paragraph in source) {
      final normalized = paragraph
          .replaceAll('。', '。\n')
          .replaceAll('！', '！\n')
          .replaceAll('？', '？\n');
      final parts = normalized
          .split('\n')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty);
      output.addAll(parts);
    }
    return output;
  }

  String _applyReplaceRulesToParagraph(String paragraph) {
    var result = paragraph;
    for (final rule in _replaceRules) {
      if (!rule.enabled || rule.pattern.trim().isEmpty) {
        continue;
      }

      if (rule.isRegex) {
        try {
          result = result.replaceAll(RegExp(rule.pattern), rule.replacement);
        } on FormatException {
          continue;
        }
      } else {
        result = result.replaceAll(rule.pattern, rule.replacement);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final paragraphs = _currentParagraphs;
    final backgroundColor = _backgroundColor(theme);
    final textColor = _textColor(theme);
    final paragraphStyle = TextStyle(
      fontSize: _fontSize,
      height: _lineHeight,
      letterSpacing: _letterSpacing,
      fontWeight: _boldText ? FontWeight.w600 : FontWeight.w400,
      color: textColor,
    );

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_currentChapter),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.only(right: 4),
              onPressed: _openSearchPanel,
              child: Icon(
                CupertinoIcons.search,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showReadActions(context),
              child: Icon(
                CupertinoIcons.ellipsis_circle,
                size: 20,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          color: backgroundColor,
          child: Column(
            children: [
              if (_showSearchPanel) _buildSearchPanel(theme),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _showToolbar = !_showToolbar),
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                    children: [
                      Text(
                        widget.bookTitle,
                        style: theme.textTheme.muted.copyWith(
                          color: _mutedTextColor(theme),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (_showReadTitleAddition && widget.sourceName != null)
                        Text(
                          widget.sourceName!,
                          style: theme.textTheme.small.copyWith(
                            color: _mutedTextColor(theme),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        _currentChapter,
                        style: theme.textTheme.h3.copyWith(color: textColor),
                      ),
                      const SizedBox(height: 14),
                      ...paragraphs.asMap().entries.map((entry) {
                        final paragraphIndex = entry.key;
                        final paragraph = entry.value;
                        final hitStarts = _hitStartsByParagraph(paragraphIndex);
                        final selectedHitStart = _selectedHitStart(
                          paragraphIndex,
                        );

                        return GestureDetector(
                          onLongPress: () =>
                              _showTextActions(context, paragraph.trim()),
                          child: Padding(
                            key: _paragraphKeys[paragraphIndex],
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RichText(
                              text: _buildHighlightedSpan(
                                text: paragraph,
                                query: _searchQuery,
                                hitStarts: hitStarts,
                                selectedStart: selectedHitStart,
                                textStyle: paragraphStyle,
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      Text(
                        '阅读进度 ${(100 * _progress).round()}%',
                        style: theme.textTheme.small.copyWith(
                          color: _mutedTextColor(theme),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _showToolbar
                    ? _ReaderToolbar(
                        progress: _progress,
                        onProgressChanged: (value) {
                          setState(() => _progress = value);
                          _persistProgress();
                        },
                        fontSize: _fontSize,
                        lineHeight: _lineHeight,
                        autoPage: _autoPage,
                        onToggleAutoPage: _toggleAutoPage,
                        onOpenSearch: _openSearchPanel,
                        onDecrease: () {
                          setState(
                            () => _fontSize = (_fontSize - 1).clamp(14, 30),
                          );
                          _persistReaderConfigInBackground();
                        },
                        onIncrease: () {
                          setState(
                            () => _fontSize = (_fontSize + 1).clamp(14, 30),
                          );
                          _persistReaderConfigInBackground();
                        },
                        hasPreviousChapter: _hasPreviousChapter,
                        hasNextChapter: _hasNextChapter,
                        onPreviousChapter: _goPreviousChapter,
                        onNextChapter: _goNextChapter,
                        onOpenToc: () => _openTocPreview(context),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPanel(ShadThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.border, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ShadInput(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  placeholder: const Text('搜索当前章节内容'),
                  onSubmitted: _runSearch,
                ),
              ),
              const SizedBox(width: 8),
              ShadButton.secondary(
                onPressed: () => _runSearch(_searchController.text),
                child: const Text('查找'),
              ),
              const SizedBox(width: 8),
              ShadButton.outline(
                onPressed: _closeSearchPanel,
                child: const Text('关闭'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ShadButton.outline(
                onPressed: _searchHits.isEmpty
                    ? null
                    : () => _moveSearchHit(-1),
                child: const Text('上一个'),
              ),
              const SizedBox(width: 8),
              ShadButton.outline(
                onPressed: _searchHits.isEmpty ? null : () => _moveSearchHit(1),
                child: const Text('下一个'),
              ),
              const Spacer(),
              Text(
                _searchHits.isEmpty
                    ? '无结果'
                    : '${_searchHitIndex + 1}/${_searchHits.length}',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReadActions(BuildContext pageContext) {
    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(widget.bookTitle),
        message: Text('当前章节：$_currentChapter · ${_progressBehaviorLabel()}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _openSearchPanel();
              _logReaderAction('打开章节内搜索');
            },
            child: const Text('搜索内容'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _openTocPreview(pageContext);
              _logReaderAction('打开目录');
            },
            child: const Text('目录'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _toggleAutoPage();
            },
            child: Text(_autoPage ? '停止自动翻页' : '自动翻页'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showReadAloudSheet(pageContext);
            },
            child: Text('朗读${_readAloudRunning ? '（运行中）' : ''}'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showReplaceRuleSheet(pageContext);
            },
            child: Text('替换规则${_replaceRuleEnabled ? '（启用）' : '（停用）'}'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showReadStyleSheet(pageContext);
            },
            child: const Text('阅读风格'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showMoreSettingsSheet(pageContext);
            },
            child: const Text('更多配置'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showAdvancedMenuSheet(pageContext);
            },
            child: const Text('高级菜单'),
          ),
          if (_hasPreviousChapter)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _goPreviousChapter();
              },
              child: const Text('上一章'),
            ),
          if (_hasNextChapter)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                _goNextChapter();
              },
              child: const Text('下一章'),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() => _showToolbar = !_showToolbar);
              _logReaderAction(_showToolbar ? '显示工具栏' : '隐藏工具栏');
            },
            child: Text(_showToolbar ? '隐藏工具栏' : '显示工具栏'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showReadAloudSheet(BuildContext pageContext) {
    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('朗读控制'),
        message: Text(
          '状态：${_readAloudStatusLabel()} · 语速 ${_readAloudSpeed.toStringAsFixed(1)}x'
          ' · 定时 ${_readAloudTimerMinutes == 0 ? '关闭' : '$_readAloudTimerMinutes分钟'}',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _toggleReadAloud();
            },
            child: Text(_readAloudRunning
                ? (_readAloudPaused ? '继续朗读' : '暂停朗读')
                : '开始朗读'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              if (!_readAloudRunning) {
                _showInfoDialog('朗读控制', '当前未在朗读。');
                return;
              }
              _stopReadAloud();
            },
            child: Text(_readAloudRunning ? '停止朗读' : '停止朗读（未启动）'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _readAloudPrevParagraph();
            },
            child: const Text('朗读上一段'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _readAloudNextParagraph();
            },
            child: const Text('朗读下一段'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showReadAloudSpeedSheet(pageContext);
            },
            child: const Text('设置语速'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showReadAloudTimerSheet(pageContext);
            },
            child: const Text('设置定时'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() => _followSystemTts = !_followSystemTts);
              _persistReaderConfigInBackground();
              _logReaderAction(
                _followSystemTts ? '朗读设置：跟随系统 TTS' : '朗读设置：自定义语速',
              );
            },
            child: Text(_followSystemTts ? '✓ 跟随系统 TTS' : '自定义语速'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _openTocPreview(pageContext);
            },
            child: const Text('打开目录'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showReadAloudSpeedSheet(BuildContext pageContext) {
    const speedOptions = [0.8, 1.0, 1.2, 1.5, 2.0];
    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('朗读语速'),
        actions: speedOptions
            .map(
              (speed) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _readAloudSpeed = speed);
                  _persistReaderConfigInBackground();
                  _logReaderAction('朗读语速切换：${speed.toStringAsFixed(1)}x');
                },
                child: Text(
                  _readAloudSpeed == speed
                      ? '✓ ${speed.toStringAsFixed(1)}x'
                      : '${speed.toStringAsFixed(1)}x',
                ),
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showReadAloudTimerSheet(BuildContext pageContext) {
    const timerOptions = [0, 5, 10, 15, 30, 60];
    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('朗读定时'),
        actions: timerOptions
            .map(
              (minutes) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _readAloudTimerMinutes = minutes);
                  _persistReaderConfigInBackground();
                  _logReaderAction(
                    minutes == 0
                        ? '朗读定时关闭'
                        : '朗读定时设置：$minutes 分钟',
                  );
                },
                child: Text(
                  _readAloudTimerMinutes == minutes
                      ? minutes == 0
                          ? '✓ 关闭定时'
                          : '✓ $minutes分钟'
                      : minutes == 0
                          ? '关闭定时'
                          : '$minutes分钟',
                ),
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showReplaceRuleSheet(BuildContext pageContext) {
    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('替换规则'),
        message: Text(
          '状态：${_replaceRuleEnabled ? '启用' : '停用'}'
          ' · 分段：${_reSegmentEnabled ? '重分段' : '原始分段'}'
          ' · 去重标题：${_sameTitleRemoved ? '开启' : '关闭'}',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() {
                _replaceRuleEnabled = !_replaceRuleEnabled;
                _paragraphKeys = _buildParagraphKeys();
              });
              _reapplySearchIfNeeded();
              _persistReaderConfigInBackground();
              _logReaderAction(
                _replaceRuleEnabled ? '替换规则启用' : '替换规则停用',
              );
            },
            child: Text(_replaceRuleEnabled ? '关闭替换规则' : '开启替换规则'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() {
                _reSegmentEnabled = !_reSegmentEnabled;
                _paragraphKeys = _buildParagraphKeys();
              });
              _reapplySearchIfNeeded();
              _persistReaderConfigInBackground();
              _logReaderAction(
                _reSegmentEnabled ? '正文重分段开启' : '正文重分段关闭',
              );
            },
            child: Text(_reSegmentEnabled ? '✓ 重分段已启用' : '启用重分段'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() {
                _sameTitleRemoved = !_sameTitleRemoved;
                _paragraphKeys = _buildParagraphKeys();
              });
              _reapplySearchIfNeeded();
              _persistReaderConfigInBackground();
              _logReaderAction(
                _sameTitleRemoved ? '去除同标题段落开启' : '去除同标题段落关闭',
              );
            },
            child: Text(_sameTitleRemoved ? '✓ 去除同标题' : '去除同标题'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showEffectiveReplacesDialog();
            },
            child: const Text('有效替换规则'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showReplaceRuleEditorSheet(pageContext);
            },
            child: const Text('编辑替换规则'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showReadStyleSheet(BuildContext pageContext) {
    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('阅读风格'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() => _tone = _ReaderTone.follow);
              _persistReaderConfigInBackground();
              _logReaderAction('阅读风格：跟随主题');
            },
            child: Text(_tone == _ReaderTone.follow ? '✓ 跟随主题' : '跟随主题'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() => _tone = _ReaderTone.warm);
              _persistReaderConfigInBackground();
              _logReaderAction('阅读风格：暖色阅读');
            },
            child: Text(_tone == _ReaderTone.warm ? '✓ 暖色阅读' : '暖色阅读'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() => _tone = _ReaderTone.dark);
              _persistReaderConfigInBackground();
              _logReaderAction('阅读风格：深色阅读');
            },
            child: Text(_tone == _ReaderTone.dark ? '✓ 深色阅读' : '深色阅读'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() => _lineHeight = (_lineHeight - 0.1).clamp(1.4, 2.2));
              _persistReaderConfigInBackground();
              _logReaderAction('减小行距');
            },
            child: const Text('减小行距'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() => _lineHeight = (_lineHeight + 0.1).clamp(1.4, 2.2));
              _persistReaderConfigInBackground();
              _logReaderAction('增大行距');
            },
            child: const Text('增大行距'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(
                () => _letterSpacing = (_letterSpacing - 0.1).clamp(-0.2, 2.0),
              );
              _persistReaderConfigInBackground();
              _logReaderAction('减小字距');
            },
            child: const Text('减小字距'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(
                () => _letterSpacing = (_letterSpacing + 0.1).clamp(-0.2, 2.0),
              );
              _persistReaderConfigInBackground();
              _logReaderAction('增大字距');
            },
            child: const Text('增大字距'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() => _boldText = !_boldText);
              _persistReaderConfigInBackground();
              _logReaderAction(_boldText ? '开启粗体文字' : '关闭粗体文字');
            },
            child: Text(_boldText ? '关闭粗体文字' : '开启粗体文字'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showMoreSettingsSheet(BuildContext pageContext) {
    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('更多配置'),
        message: Text('页面动画：${_pageAnimLabel()} · 图片样式：${_imageStyleLabel()}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _jumpToTop();
              _logReaderAction('回到章节顶部');
            },
            child: const Text('回到章节顶部'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() {
                _fontSize = 18;
                _lineHeight = 1.75;
                _letterSpacing = 0;
                _boldText = false;
                _tone = _ReaderTone.follow;
                _pageAnim = _ReaderPageAnim.cover;
                _imageStyle = _ReaderImageStyle.normal;
              });
              _persistReaderConfigInBackground();
              _logReaderAction('重置阅读样式');
            },
            child: const Text('重置阅读样式'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showPageAnimSheet(pageContext);
            },
            child: const Text('页面动画'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showImageStyleSheet(pageContext);
            },
            child: const Text('图片样式'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showProgressBehaviorSheet(pageContext);
            },
            child: const Text('进度条行为'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() => _showReadTitleAddition = !_showReadTitleAddition);
              _persistReaderConfigInBackground();
              _logReaderAction(
                _showReadTitleAddition ? '显示章节附加信息' : '隐藏章节附加信息',
              );
            },
            child: Text(_showReadTitleAddition ? '隐藏章节附加信息' : '显示章节附加信息'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() => _expandTextMenu = !_expandTextMenu);
              _persistReaderConfigInBackground();
              _logReaderAction(_expandTextMenu ? '展开文本菜单' : '折叠文本菜单');
            },
            child: Text(_expandTextMenu ? '折叠文本菜单' : '展开文本菜单'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _closeSearchPanel();
              _runSearch('');
              _logReaderAction('清空章节搜索结果');
            },
            child: const Text('清空章节搜索结果'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _openReaderLogs(pageContext);
              _logReaderAction('打开阅读日志');
            },
            child: const Text('阅读日志'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showInfoDialog('阅读帮助', '对齐 legado：支持朗读、替换规则与多级配置菜单。');
              _logReaderAction('打开阅读帮助');
            },
            child: const Text('帮助'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showAdvancedMenuSheet(BuildContext pageContext) {
    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('高级菜单'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _addBookmarkFromSelection(fallbackToChapter: true);
            },
            child: const Text('添加书签'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showContentEditSheet(pageContext);
            },
            child: const Text('编辑正文'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() => _simulatedReading = !_simulatedReading);
              _persistReaderConfigInBackground();
              _logReaderAction(_simulatedReading ? '开启模拟阅读' : '关闭模拟阅读');
            },
            child: Text(_simulatedReading ? '关闭模拟阅读' : '开启模拟阅读'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              setState(() {
                _reverseContent = !_reverseContent;
                _paragraphKeys = _buildParagraphKeys();
              });
              _reapplySearchIfNeeded();
              _persistReaderConfigInBackground();
              _logReaderAction(_reverseContent ? '反转正文开启' : '反转正文关闭');
            },
            child: Text(_reverseContent ? '关闭反转正文' : '开启反转正文'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showEffectiveReplacesDialog();
            },
            child: const Text('有效替换规则'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showPageAnimSheet(BuildContext pageContext) {
    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('页面动画'),
        actions: _ReaderPageAnim.values
            .map(
              (item) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _pageAnim = item);
                  _persistReaderConfigInBackground();
                  _logReaderAction('页面动画切换：${_pageAnimLabel(item)}');
                },
                child: Text(
                  _pageAnim == item
                      ? '✓ ${_pageAnimLabel(item)}'
                      : _pageAnimLabel(item),
                ),
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showImageStyleSheet(BuildContext pageContext) {
    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('图片样式'),
        actions: _ReaderImageStyle.values
            .map(
              (item) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _imageStyle = item);
                  _persistReaderConfigInBackground();
                  _logReaderAction('图片样式切换：${_imageStyleLabel(item)}');
                },
                child: Text(
                  _imageStyle == item
                      ? '✓ ${_imageStyleLabel(item)}'
                      : _imageStyleLabel(item),
                ),
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showProgressBehaviorSheet(BuildContext pageContext) {
    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('进度条行为'),
        actions: _ReadProgressBehavior.values
            .map(
              (item) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _progressBehavior = item);
                  _persistReaderConfigInBackground();
                  _logReaderAction('进度条行为切换：${_progressBehaviorLabel(item)}');
                },
                child: Text(
                  _progressBehavior == item
                      ? '✓ ${_progressBehaviorLabel(item)}'
                      : _progressBehaviorLabel(item),
                ),
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  String _readAloudStatusLabel() {
    if (!_readAloudRunning) {
      return '未启动';
    }
    if (_readAloudPaused) {
      return '已暂停';
    }
    return '朗读中';
  }

  String _progressBehaviorLabel([_ReadProgressBehavior? target]) {
    final behavior = target ?? _progressBehavior;
    switch (behavior) {
      case _ReadProgressBehavior.page:
        return '按页';
      case _ReadProgressBehavior.chapter:
        return '按章节';
    }
  }

  String _pageAnimLabel([_ReaderPageAnim? target]) {
    final anim = target ?? _pageAnim;
    switch (anim) {
      case _ReaderPageAnim.cover:
        return '覆盖';
      case _ReaderPageAnim.slide:
        return '滑动';
      case _ReaderPageAnim.simulation:
        return '仿真';
      case _ReaderPageAnim.scroll:
        return '滚动';
      case _ReaderPageAnim.none:
        return '无动画';
    }
  }

  String _imageStyleLabel([_ReaderImageStyle? target]) {
    final style = target ?? _imageStyle;
    switch (style) {
      case _ReaderImageStyle.normal:
        return '默认';
      case _ReaderImageStyle.full:
        return '全屏';
      case _ReaderImageStyle.text:
        return '文本';
      case _ReaderImageStyle.single:
        return '单图';
    }
  }

  void _toggleReadAloud() {
    if (_readAloudRunning) {
      setState(() => _readAloudPaused = !_readAloudPaused);
      _logReaderAction(_readAloudPaused ? '朗读暂停' : '朗读继续');
      return;
    }

    _stopAutoPage(silent: true);
    setState(() {
      _readAloudRunning = true;
      _readAloudPaused = false;
    });
    _logReaderAction('开始朗读');
  }

  void _stopReadAloud({bool silent = false}) {
    if (!_readAloudRunning && !_readAloudPaused) {
      return;
    }

    setState(() {
      _readAloudRunning = false;
      _readAloudPaused = false;
    });
    if (!silent) {
      _logReaderAction('停止朗读');
    }
  }

  void _readAloudPrevParagraph() {
    _logReaderAction('朗读上一段');
    _showInfoDialog('朗读定位', '已切换到上一段（示意）。');
  }

  void _readAloudNextParagraph() {
    _logReaderAction('朗读下一段');
    _showInfoDialog('朗读定位', '已切换到下一段（示意）。');
  }

  void _showEffectiveReplacesDialog() {
    final rules = <String>[
      if (_replaceRuleEnabled) '启用替换规则',
      if (_reSegmentEnabled) '正文重分段',
      if (_sameTitleRemoved) '去除同标题段落',
      ..._replaceRules
          .where((rule) => rule.enabled)
          .map((rule) => '${rule.name}：${rule.pattern} -> ${rule.replacement}'),
      '繁简转换（按全局设置）',
    ];

    _logReaderAction('查看有效替换规则');

    _showInfoDialog(
      '有效替换规则',
      rules.isEmpty ? '当前无生效规则。' : rules.join('\n'),
    );
  }

  String _contentForEditing(int chapterIndex) {
    return _rawParagraphsByChapterIndex(chapterIndex).join('\n');
  }

  List<String> _parseEditingContent(String content) {
    return content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  void _saveContentEdit({
    required int chapterIndex,
    required String chapterTitle,
    required String contentText,
    required bool resetContent,
  }) {
    final nextTitle = chapterTitle.trim().isEmpty
        ? _chapters[chapterIndex]
        : chapterTitle.trim();
    final previousTitle = _chapters[chapterIndex];
    final parsedParagraphs = _parseEditingContent(contentText);

    setState(() {
      _chapters[chapterIndex] = nextTitle;
      final originalTitle = _originChapters[chapterIndex];
      if (nextTitle == originalTitle) {
        _editedChapterTitles.remove(chapterIndex);
      } else {
        _editedChapterTitles[chapterIndex] = nextTitle;
      }

      if (resetContent) {
        _editedChapterParagraphs.remove(chapterIndex);
      } else {
        _editedChapterParagraphs[chapterIndex] =
            parsedParagraphs.isEmpty ? _baseParagraphs : parsedParagraphs;
      }
      _paragraphKeys = _buildParagraphKeys();
    });

    if (previousTitle != nextTitle) {
      _logReaderAction('正文编辑：章节标题 $previousTitle -> $nextTitle');
    }
    _logReaderAction(resetContent ? '正文编辑：重置正文' : '正文编辑：保存正文');
    _persistProgress();
    unawaited(_persistReaderDraft());

    final query = _searchQuery;
    if (query.isNotEmpty) {
      _runSearch(query);
    }
  }

  Future<void> _showContentEditSheet(BuildContext pageContext) async {
    final chapterIndex = _chapterIndex;
    final theme = ShadTheme.of(pageContext);
    final titleController = TextEditingController(
      text: _chapters[chapterIndex],
    );
    final contentController = TextEditingController(
      text: _contentForEditing(chapterIndex),
    );
    var resetContent = false;

    void saveAndClose(BuildContext sheetContext) {
      _saveContentEdit(
        chapterIndex: chapterIndex,
        chapterTitle: titleController.text,
        contentText: contentController.text,
        resetContent: resetContent,
      );
      Navigator.of(sheetContext).pop();
    }

    _logReaderAction('打开正文编辑');

    await showCupertinoModalPopup<void>(
      context: pageContext,
      barrierDismissible: false,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: theme.colorScheme.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '正文编辑',
                            style: theme.textTheme.large.copyWith(
                              color: theme.colorScheme.foreground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () => saveAndClose(sheetContext),
                            child: Text(
                              '关闭并保存',
                              style: theme.textTheme.small.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: titleController,
                        placeholder: '章节标题',
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: CupertinoTextField(
                          controller: contentController,
                          placeholder: '输入正文内容，每行作为一个段落',
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ShadButton.outline(
                              onPressed: () async {
                                final payload =
                                    '${titleController.text.trim()}\n${contentController.text.trim()}';
                                await Clipboard.setData(
                                  ClipboardData(text: payload.trim()),
                                );
                                if (!mounted) {
                                  return;
                                }
                                _logReaderAction('正文编辑：复制全部');
                                _showInfoDialog('已复制', '已复制当前标题与正文。');
                              },
                              child: const Text('复制全部'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ShadButton.secondary(
                              onPressed: () {
                                setSheetState(() {
                                  resetContent = true;
                                  contentController.text = _baseParagraphs.join('\n');
                                });
                              },
                              child: const Text('重置正文'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ShadButton(
                              onPressed: () => saveAndClose(sheetContext),
                              child: const Text('保存并关闭'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    contentController.dispose();
  }

  Future<ReaderReplaceRuleState?> _showReplaceRuleFormDialog(
    BuildContext pageContext, {
    ReaderReplaceRuleState? initialRule,
  }) async {
    final theme = ShadTheme.of(pageContext);
    final nameController = TextEditingController(text: initialRule?.name ?? '');
    final patternController = TextEditingController(
      text: initialRule?.pattern ?? '',
    );
    final replacementController = TextEditingController(
      text: initialRule?.replacement ?? '',
    );
    var enabled = initialRule?.enabled ?? true;
    var isRegex = initialRule?.isRegex ?? false;
    String? errorText;

    final result = await showCupertinoDialog<ReaderReplaceRuleState>(
      context: pageContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: Text(initialRule == null ? '新增替换规则' : '编辑替换规则'),
              content: Column(
                children: [
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: nameController,
                    placeholder: '规则名称',
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: patternController,
                    placeholder: '匹配内容',
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: replacementController,
                    placeholder: '替换为',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '启用',
                          style: theme.textTheme.small.copyWith(
                            color: theme.colorScheme.foreground,
                          ),
                        ),
                      ),
                      CupertinoSwitch(
                        value: enabled,
                        onChanged: (value) {
                          setDialogState(() => enabled = value);
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '使用正则',
                          style: theme.textTheme.small.copyWith(
                            color: theme.colorScheme.foreground,
                          ),
                        ),
                      ),
                      CupertinoSwitch(
                        value: isRegex,
                        onChanged: (value) {
                          setDialogState(() => isRegex = value);
                        },
                      ),
                    ],
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        errorText!,
                        style: theme.textTheme.small.copyWith(
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                CupertinoDialogAction(
                  onPressed: () {
                    final pattern = patternController.text.trim();
                    if (pattern.isEmpty) {
                      setDialogState(() => errorText = '匹配内容不能为空');
                      return;
                    }

                    Navigator.of(dialogContext).pop(
                      ReaderReplaceRuleState(
                        name: nameController.text.trim().isEmpty
                            ? pattern
                            : nameController.text.trim(),
                        pattern: pattern,
                        replacement: replacementController.text,
                        enabled: enabled,
                        isRegex: isRegex,
                      ),
                    );
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    patternController.dispose();
    replacementController.dispose();
    return result;
  }

  Future<void> _showReplaceRuleEditorSheet(BuildContext pageContext) async {
    final theme = ShadTheme.of(pageContext);
    final draftRules = _replaceRules.map((rule) => rule.copyWith()).toList();

    _logReaderAction('打开替换规则编辑');

    await showCupertinoModalPopup<void>(
      context: pageContext,
      barrierDismissible: false,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.76,
              decoration: BoxDecoration(
                color: theme.colorScheme.background,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '替换规则编辑',
                            style: theme.textTheme.large.copyWith(
                              color: theme.colorScheme.foreground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setState(() {
                                _replaceRules =
                                    List<ReaderReplaceRuleState>.from(draftRules);
                                _paragraphKeys = _buildParagraphKeys();
                              });
                              _logReaderAction('替换规则编辑：保存 ${draftRules.length} 条');
                              final query = _searchQuery;
                              if (query.isNotEmpty) {
                                _runSearch(query);
                              }
                              unawaited(_persistReaderDraft());
                              Navigator.of(sheetContext).pop();
                            },
                            child: Text(
                              '保存',
                              style: theme.textTheme.small.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ShadButton.secondary(
                          onPressed: () async {
                            final created = await _showReplaceRuleFormDialog(
                              sheetContext,
                            );
                            if (created == null) {
                              return;
                            }
                            setSheetState(() => draftRules.add(created));
                          },
                          child: const Text('新增规则'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: draftRules.isEmpty
                            ? Center(
                                child: Text(
                                  '暂无规则，点击上方“新增规则”创建。',
                                  style: theme.textTheme.small.copyWith(
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                ),
                              )
                            : ListView(
                                children: draftRules.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final rule = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      borderRadius: theme.radius,
                                      border: Border.all(
                                        color: theme.colorScheme.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                rule.name,
                                                style: theme.textTheme.small.copyWith(
                                                  color: theme.colorScheme.foreground,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            CupertinoSwitch(
                                              value: rule.enabled,
                                              onChanged: (value) {
                                                setSheetState(
                                                  () => draftRules[index] =
                                                      rule.copyWith(enabled: value),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          rule.isRegex
                                              ? '正则：${rule.pattern}'
                                              : '匹配：${rule.pattern}',
                                          style: theme.textTheme.small.copyWith(
                                            color: theme.colorScheme.mutedForeground,
                                          ),
                                        ),
                                        Text(
                                          '替换：${rule.replacement}',
                                          style: theme.textTheme.small.copyWith(
                                            color: theme.colorScheme.mutedForeground,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              onPressed: () async {
                                                final edited =
                                                    await _showReplaceRuleFormDialog(
                                                  sheetContext,
                                                  initialRule: rule,
                                                );
                                                if (edited == null) {
                                                  return;
                                                }
                                                setSheetState(
                                                  () => draftRules[index] = edited,
                                                );
                                              },
                                              child: Text(
                                                '编辑',
                                                style: theme.textTheme.small.copyWith(
                                                  color: theme.colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            CupertinoButton(
                                              padding: EdgeInsets.zero,
                                              onPressed: () {
                                                setSheetState(
                                                  () => draftRules.removeAt(index),
                                                );
                                              },
                                              child: Text(
                                                '删除',
                                                style: theme.textTheme.small.copyWith(
                                                  color: CupertinoColors.systemRed,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(growable: false),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openReaderLogs(BuildContext pageContext) {
    Navigator.of(pageContext).push(
      CupertinoPageRoute<void>(builder: (context) => const SearchLogView()),
    );
  }

  void _logReaderAction(String action) {
    AppLogService.instance.put('阅读器：$action');
  }

  void _showTextActions(BuildContext pageContext, String text) {
    _selectedText = text;

    if (_expandTextMenu) {
      _showExpandedTextActions(pageContext);
      return;
    }

    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('文本操作'),
        message: Text(_shortText(_selectedText)),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _copySelectedText();
            },
            child: const Text('复制'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _addBookmarkFromSelection();
            },
            child: const Text('添加书签'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _aloudSelectedText();
            },
            child: const Text('朗读所选'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _searchWithSelectedText();
            },
            child: const Text('章节内搜索'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showExpandedTextActions(pageContext);
            },
            child: const Text('更多动作'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showExpandedTextActions(BuildContext pageContext) {
    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('文本操作（完整）'),
        message: Text(_shortText(_selectedText)),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _copySelectedText();
            },
            child: const Text('复制文本'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _shareSelectedText();
            },
            child: const Text('分享文本（复制）'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _addBookmarkFromSelection();
            },
            child: const Text('添加书签'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _aloudSelectedText();
            },
            child: const Text('朗读所选'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _toggleReplaceRuleFromSelection();
            },
            child: const Text('替换规则'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _searchWithSelectedText();
            },
            child: const Text('章节内搜索'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _openDictWithSelectedText();
            },
            child: const Text('词典（复制关键词）'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _browserSearchSelectedText();
            },
            child: const Text('浏览器搜索（复制关键词）'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _addBookmarkFromSelection({bool fallbackToChapter = false}) {
    final content = _selectedText.trim();
    if (content.isEmpty && !fallbackToChapter) {
      _showInfoDialog('添加书签失败', '请先长按选择文本后再添加书签。');
      return;
    }

    final preview = content.isEmpty ? _currentChapter : _shortText(content);
    _logReaderAction('添加书签：$preview');
    _showInfoDialog('已添加书签', preview);
  }

  void _aloudSelectedText() {
    final content = _selectedText.trim();
    if (content.isEmpty) {
      _showInfoDialog('朗读失败', '请先长按选择文本后再朗读。');
      return;
    }

    if (!_readAloudRunning || _readAloudPaused) {
      setState(() {
        _readAloudRunning = true;
        _readAloudPaused = false;
      });
    }

    _logReaderAction('朗读所选：${_shortText(content)}');
    _showInfoDialog('朗读所选', _shortText(content));
  }

  void _toggleReplaceRuleFromSelection() {
    setState(() {
      _replaceRuleEnabled = !_replaceRuleEnabled;
      _paragraphKeys = _buildParagraphKeys();
    });
    _reapplySearchIfNeeded();
    _persistReaderConfigInBackground();
    _logReaderAction(_replaceRuleEnabled ? '替换规则启用（文本菜单）' : '替换规则停用（文本菜单）');
    _showInfoDialog('替换规则', _replaceRuleEnabled ? '已启用替换规则' : '已停用替换规则');
  }

  Future<void> _openDictWithSelectedText() async {
    final keyword = _selectedText.trim();
    if (keyword.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: keyword));
    if (!mounted) {
      return;
    }
    _logReaderAction('词典查询：${_shortText(keyword)}');
    _showInfoDialog('词典查询', '已复制关键词，可粘贴到词典应用查询。');
  }

  void _openSearchPanel() {
    setState(() => _showSearchPanel = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeSearchPanel() {
    setState(() {
      _showSearchPanel = false;
      _searchHitIndex = -1;
      _searchHits = const [];
    });
    _searchFocusNode.unfocus();
  }

  void _runSearch(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      setState(() {
        _searchHitIndex = -1;
        _searchHits = const [];
      });
      return;
    }

    final hits = <_SearchHit>[];
    final normalizedQuery = query.toLowerCase();

    for (
      var paragraphIndex = 0;
      paragraphIndex < _currentParagraphs.length;
      paragraphIndex++
    ) {
      final paragraph = _currentParagraphs[paragraphIndex];
      final normalizedParagraph = paragraph.toLowerCase();
      var start = normalizedParagraph.indexOf(normalizedQuery);
      while (start >= 0) {
        hits.add(_SearchHit(paragraphIndex: paragraphIndex, start: start));
        start = normalizedParagraph.indexOf(
          normalizedQuery,
          start + normalizedQuery.length,
        );
      }
    }

    setState(() {
      _showSearchPanel = true;
      _searchHits = hits;
      _searchHitIndex = hits.isEmpty ? -1 : 0;
    });

    if (hits.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSearchHit(_searchHitIndex);
      });
    }
  }

  void _moveSearchHit(int step) {
    if (_searchHits.isEmpty) {
      return;
    }

    final next = (_searchHitIndex + step).clamp(0, _searchHits.length - 1);
    if (next == _searchHitIndex) {
      return;
    }

    setState(() => _searchHitIndex = next);
    _scrollToSearchHit(_searchHitIndex);
  }

  void _scrollToSearchHit(int hitIndex) {
    if (hitIndex < 0 || hitIndex >= _searchHits.length) {
      return;
    }

    final paragraphIndex = _searchHits[hitIndex].paragraphIndex;
    final targetKey = _paragraphKeys[paragraphIndex];
    final targetContext = targetKey.currentContext;
    if (targetContext == null) {
      return;
    }

    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.2,
    );
  }

  List<int> _hitStartsByParagraph(int paragraphIndex) {
    return _searchHits
        .where((item) => item.paragraphIndex == paragraphIndex)
        .map((item) => item.start)
        .toList(growable: false);
  }

  int _selectedHitStart(int paragraphIndex) {
    if (_searchHitIndex < 0 || _searchHitIndex >= _searchHits.length) {
      return -1;
    }

    final selectedHit = _searchHits[_searchHitIndex];
    if (selectedHit.paragraphIndex != paragraphIndex) {
      return -1;
    }
    return selectedHit.start;
  }

  TextSpan _buildHighlightedSpan({
    required String text,
    required String query,
    required List<int> hitStarts,
    required int selectedStart,
    required TextStyle textStyle,
  }) {
    if (query.isEmpty || hitStarts.isEmpty) {
      return TextSpan(text: text, style: textStyle);
    }

    final children = <InlineSpan>[];
    final queryLength = query.length;
    var cursor = 0;

    for (final start in hitStarts) {
      if (start < cursor || start + queryLength > text.length) {
        continue;
      }

      if (cursor < start) {
        children.add(
          TextSpan(text: text.substring(cursor, start), style: textStyle),
        );
      }

      final highlightColor = start == selectedStart
          ? const Color(0x55FFD54F)
          : const Color(0x3390CAF9);

      children.add(
        TextSpan(
          text: text.substring(start, start + queryLength),
          style: textStyle.copyWith(
            backgroundColor: highlightColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = start + queryLength;
    }

    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor), style: textStyle));
    }

    return TextSpan(children: children, style: textStyle);
  }

  void _openTocPreview(BuildContext pageContext) {
    final theme = ShadTheme.of(pageContext);
    showCupertinoModalPopup<void>(
      context: pageContext,
      builder: (sheetContext) => Container(
        height: 380,
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
                '目录',
                textAlign: TextAlign.center,
                style: theme.textTheme.large.copyWith(
                  color: theme.colorScheme.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ..._chapters.asMap().entries.map((entry) {
                final chapterIndex = entry.key;
                final chapter = entry.value;
                final isCurrentChapter = chapterIndex == _chapterIndex;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _switchChapter(chapterIndex);
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
                              fontWeight: isCurrentChapter
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (isCurrentChapter)
                          Icon(
                            CupertinoIcons.check_mark,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _goPreviousChapter() {
    _switchChapter(_chapterIndex - 1);
  }

  void _goNextChapter() {
    _switchChapter(_chapterIndex + 1);
  }

  void _switchChapter(int nextChapterIndex) {
    if (nextChapterIndex < 0 || nextChapterIndex >= _chapters.length) {
      return;
    }
    if (nextChapterIndex == _chapterIndex) {
      return;
    }

    setState(() {
      _chapterIndex = nextChapterIndex;
      _progress = 0;
      _paragraphKeys = _buildParagraphKeys();
      _searchHits = const [];
      _searchHitIndex = -1;
    });
    _logReaderAction('切换章节：$_currentChapter');
    _persistProgress();

    final query = _searchQuery;
    if (query.isNotEmpty) {
      _runSearch(query);
    } else {
      _jumpToTop();
    }
  }

  void _toggleAutoPage() {
    if (_autoPage) {
      _stopAutoPage();
      return;
    }

    _stopReadAloud(silent: true);
    setState(() => _autoPage = true);
    _logReaderAction('开启自动翻页');

    _autoPageTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || !_autoPage) {
        timer.cancel();
        return;
      }

      final nextProgress = _progress + 0.05;
      if (nextProgress < 1) {
        setState(() => _progress = nextProgress);
        _persistProgress();
        return;
      }

      if (_hasNextChapter) {
        _switchChapter(_chapterIndex + 1);
        return;
      }

      _stopAutoPage();
    });
  }

  void _stopAutoPage({bool silent = false}) {
    _autoPageTimer?.cancel();
    if (!_autoPage) {
      return;
    }
    setState(() => _autoPage = false);
    if (!silent) {
      _logReaderAction('停止自动翻页');
    }
  }

  void _reapplySearchIfNeeded() {
    final query = _searchQuery;
    if (query.isNotEmpty) {
      _runSearch(query);
    }
  }

  void _jumpToTop() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _searchWithSelectedText() {
    final keyword = _selectedText.trim();
    if (keyword.isEmpty) {
      return;
    }

    _searchController.text = keyword;
    _showSearchPanel = true;
    _runSearch(keyword);
  }

  Future<void> _copySelectedText() async {
    if (_selectedText.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _selectedText));
    if (!mounted) {
      return;
    }
    _showInfoDialog('已复制文本', _shortText(_selectedText));
  }

  Future<void> _shareSelectedText() async {
    if (_selectedText.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(
        text: '${widget.bookTitle}\n$_currentChapter\n$_selectedText',
      ),
    );
    if (!mounted) {
      return;
    }
    _showInfoDialog('已复制分享文案', '可直接粘贴到其他应用进行分享。');
  }

  Future<void> _browserSearchSelectedText() async {
    final keyword = _selectedText.trim();
    if (keyword.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: keyword));
    if (!mounted) {
      return;
    }
    _showInfoDialog('已复制关键词', '可在浏览器粘贴后搜索：${_shortText(keyword)}');
  }

  Future<void> _showInfoDialog(String title, String content) async {
    await showCupertinoDialog<void>(
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

  String _shortText(String text) {
    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.length <= 36) {
      return normalized;
    }
    return '${normalized.substring(0, 36)}...';
  }

  Future<void> _persistReaderDraft() {
    final contentOverrides = _editedChapterParagraphs.map(
      (chapterIndex, lines) =>
          MapEntry(chapterIndex, List<String>.from(lines, growable: false)),
    );

    final titleOverrides = _editedChapterTitles.map(
      (chapterIndex, chapterTitle) => MapEntry(chapterIndex, chapterTitle),
    );

    final replaceRules = List<ReaderReplaceRuleState>.from(_replaceRules);
    final config = _currentReaderConfig();
    final globalConfig = _libraryService.readerGlobalConfig();

    return _libraryService.saveReaderDraft(
      widget.bookId,
      ReaderBookDraftState(
        chapterContentOverrides: contentOverrides,
        chapterTitleOverrides: titleOverrides,
        replaceRules: replaceRules,
        config: config.sameAs(globalConfig) ? null : config,
      ),
    );
  }

  void _persistProgress() {
    _libraryService.updateReadingProgress(
      bookId: widget.bookId,
      chapterTitle: _currentChapter,
      progress: _progress,
    );
  }

  Color _backgroundColor(ShadThemeData theme) {
    switch (_tone) {
      case _ReaderTone.follow:
        return theme.colorScheme.background;
      case _ReaderTone.warm:
        return const Color(0xFFF6EFD8);
      case _ReaderTone.dark:
        return const Color(0xFF101214);
    }
  }

  Color _textColor(ShadThemeData theme) {
    switch (_tone) {
      case _ReaderTone.follow:
        return theme.colorScheme.foreground;
      case _ReaderTone.warm:
        return const Color(0xFF4E4332);
      case _ReaderTone.dark:
        return const Color(0xFFE8E8E8);
    }
  }

  Color _mutedTextColor(ShadThemeData theme) {
    switch (_tone) {
      case _ReaderTone.follow:
        return theme.colorScheme.mutedForeground;
      case _ReaderTone.warm:
        return const Color(0xFF8A7A60);
      case _ReaderTone.dark:
        return const Color(0xFF9FA4AA);
    }
  }
}

class _ReaderToolbar extends StatelessWidget {
  const _ReaderToolbar({
    required this.progress,
    required this.onProgressChanged,
    required this.fontSize,
    required this.lineHeight,
    required this.autoPage,
    required this.onToggleAutoPage,
    required this.onOpenSearch,
    required this.onDecrease,
    required this.onIncrease,
    required this.hasPreviousChapter,
    required this.hasNextChapter,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onOpenToc,
  });

  final double progress;
  final ValueChanged<double> onProgressChanged;
  final double fontSize;
  final double lineHeight;
  final bool autoPage;
  final VoidCallback onToggleAutoPage;
  final VoidCallback onOpenSearch;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool hasPreviousChapter;
  final bool hasNextChapter;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onOpenToc;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        border: Border(
          top: BorderSide(color: theme.colorScheme.border, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '阅读进度',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CupertinoSlider(value: progress, onChanged: onProgressChanged),
          const SizedBox(height: 8),
          Row(
            children: [
              ShadButton.outline(
                onPressed: onDecrease,
                child: const Text('A-'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '字号 ${fontSize.toStringAsFixed(0)} · 行距 ${lineHeight.toStringAsFixed(1)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ShadButton(onPressed: onIncrease, child: const Text('A+')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ShadButton.outline(
                  onPressed: hasPreviousChapter ? onPreviousChapter : null,
                  child: const Text('上一章'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadButton.secondary(
                  onPressed: onOpenToc,
                  child: const Text('目录'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadButton(
                  onPressed: hasNextChapter ? onNextChapter : null,
                  child: const Text('下一章'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ShadButton.outline(
                  onPressed: onOpenSearch,
                  child: const Text('搜索'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadButton.secondary(
                  onPressed: onToggleAutoPage,
                  child: Text(autoPage ? '停止自动翻页' : '自动翻页'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
