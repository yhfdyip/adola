import 'package:adola/core/models/book_item.dart';
import 'package:adola/core/models/reader_state.dart';
import 'package:adola/core/services/library_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final service = LibraryService.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service.debugResetForTests();
  });

  group('LibraryService source scope', () {
    test('按书源 URL 过滤搜索结果', () {
      final source = service.allEnabledSourceItems().first;

      final results = service.searchBooks(
        '',
        scope: SearchScope.source(source.url, sourceLabel: source.name),
      );

      expect(results, isNotEmpty);
      expect(results.every((book) => book.sourceUrl == source.url), isTrue);
    });

    test('未知书源 URL 时无结果', () {
      final results = service.searchBooks(
        '',
        scope: const SearchScope.source('https://unknown.example'),
      );

      expect(results, isEmpty);
    });
  });

  group('LibraryService group manage', () {
    test('新增、重命名、删除分组', () async {
      await service.createGroup('测试分组');
      final created = service.groupByName('测试分组');
      expect(created, isNotNull);

      await service.renameGroup(created!.id, '测试分组2');
      expect(service.groupByName('测试分组'), isNull);
      expect(service.groupByName('测试分组2'), isNotNull);

      await service.removeGroup(created.id);
      expect(service.groupByName('测试分组2'), isNull);
    });

    test('隐藏分组后不再出现在可用分组', () async {
      final fantasy = service.groupByName('奇幻分组');
      expect(fantasy, isNotNull);

      await service.setGroupVisible(fantasy!.id, false);

      final enabledGroups = service.allEnabledGroups();
      expect(enabledGroups.contains('奇幻分组'), isFalse);
    });

    test('删除分组后书籍归到未分组', () async {
      final suspense = service.groupByName('悬疑分组');
      expect(suspense, isNotNull);

      await service.removeGroup(suspense!.id);

      final book = service
          .allBooks()
          .firstWhere((item) => item.id == 'book_001');
      expect(book.group, '未分组');
    });
  });


  group('LibraryService reader draft', () {
    test('正文与替换规则可保存并在重启后恢复', () async {
      await service.saveReaderDraft(
        'book_001',
        const ReaderBookDraftState(
          chapterContentOverrides: {
            0: ['编辑段落 A', '编辑段落 B'],
          },
          chapterTitleOverrides: {
            0: '第 121 章 雨后（修订）',
          },
          replaceRules: [
            ReaderReplaceRuleState(
              name: '替换示例',
              pattern: '雨后',
              replacement: '晴后',
              enabled: true,
              isRegex: false,
            ),
          ],
          config: ReaderViewConfigState(
            tone: 'dark',
            pageAnim: 'slide',
            imageStyle: 'full',
            progressBehavior: 'chapter',
            fontSize: 20,
            lineHeight: 1.9,
            letterSpacing: 0.2,
            boldText: true,
            expandTextMenu: true,
            replaceRuleEnabled: false,
            reSegmentEnabled: true,
            sameTitleRemoved: true,
            reverseContent: true,
            simulatedReading: true,
            showReadTitleAddition: false,
            followSystemTts: false,
            readAloudSpeed: 1.5,
            readAloudTimerMinutes: 15,
          ),
        ),
      );

      final saved = service.readerDraftByBookId('book_001');
      expect(saved.chapterContentOverrides[0], ['编辑段落 A', '编辑段落 B']);
      expect(saved.chapterTitleOverrides[0], '第 121 章 雨后（修订）');
      expect(saved.replaceRules.single.name, '替换示例');
      expect(saved.config, isNotNull);
      expect(saved.config!.tone, 'dark');
      expect(saved.config!.replaceRuleEnabled, isFalse);

      service.debugResetForTests();
      await service.ensureInitialized();

      final restored = service.readerDraftByBookId('book_001');
      expect(restored.chapterContentOverrides[0], ['编辑段落 A', '编辑段落 B']);
      expect(restored.chapterTitleOverrides[0], '第 121 章 雨后（修订）');
      expect(restored.replaceRules.single.pattern, '雨后');
      expect(restored.replaceRules.single.replacement, '晴后');
      expect(restored.config, isNotNull);
      expect(restored.config!.tone, 'dark');
      expect(restored.config!.pageAnim, 'slide');
      expect(restored.config!.progressBehavior, 'chapter');
      expect(restored.config!.readAloudTimerMinutes, 15);
    });

    test('空草稿会清理持久化记录', () async {
      await service.saveReaderDraft(
        'book_001',
        const ReaderBookDraftState(
          chapterContentOverrides: {
            0: ['保留段落'],
          },
        ),
      );
      expect(service.readerDraftByBookId('book_001').isEmpty, isFalse);

      await service.saveReaderDraft('book_001', const ReaderBookDraftState());
      expect(service.readerDraftByBookId('book_001').isEmpty, isTrue);

      service.debugResetForTests();
      await service.ensureInitialized();
      expect(service.readerDraftByBookId('book_001').isEmpty, isTrue);
    });


    test('默认配置不会占用持久化草稿', () async {
      await service.saveReaderDraft(
        'book_001',
        const ReaderBookDraftState(config: ReaderViewConfigState()),
      );

      expect(service.readerDraftByBookId('book_001').isEmpty, isTrue);

      service.debugResetForTests();
      await service.ensureInitialized();
      expect(service.readerDraftByBookId('book_001').isEmpty, isTrue);
    });


    test('全局阅读配置可持久化恢复', () async {
      await service.saveReaderGlobalConfig(
        const ReaderViewConfigState(
          tone: 'dark',
          pageAnim: 'slide',
          readAloudSpeed: 1.2,
          followSystemTts: false,
        ),
      );

      expect(service.readerGlobalConfig().tone, 'dark');
      expect(service.readerGlobalConfig().pageAnim, 'slide');

      service.debugResetForTests();
      await service.ensureInitialized();

      expect(service.readerGlobalConfig().tone, 'dark');
      expect(service.readerGlobalConfig().pageAnim, 'slide');
      expect(service.readerGlobalConfig().followSystemTts, isFalse);
    });

    test('全局与书籍配置可分层共存', () async {
      await service.saveReaderGlobalConfig(
        const ReaderViewConfigState(
          tone: 'warm',
          pageAnim: 'cover',
          progressBehavior: 'page',
        ),
      );

      await service.saveReaderDraft(
        'book_001',
        const ReaderBookDraftState(
          config: ReaderViewConfigState(
            tone: 'dark',
            pageAnim: 'slide',
            progressBehavior: 'chapter',
          ),
        ),
      );

      expect(service.readerGlobalConfig().tone, 'warm');
      expect(service.readerDraftByBookId('book_001').config?.tone, 'dark');
      expect(service.readerDraftByBookId('book_002').config, isNull);

      service.debugResetForTests();
      await service.ensureInitialized();

      expect(service.readerGlobalConfig().tone, 'warm');
      expect(service.readerDraftByBookId('book_001').config?.tone, 'dark');
      expect(service.readerDraftByBookId('book_002').config, isNull);
    });
  });

  group('LibraryService shelf sort', () {
    test('全局排序切换为最新章节', () async {
      await service.setGlobalShelfSort(BookshelfSortType.latestChapter);

      final sorted = service.shelfBooksByGroup();
      expect(sorted.first.book.id, 'book_002');
    });

    test('分组排序覆盖全局排序', () async {
      final realityBook = service
          .allBooks()
          .firstWhere((item) => item.id == 'book_004');
      service.addToShelf(realityBook);

      await service.setGlobalShelfSort(BookshelfSortType.recentRead);
      final realityGroup = service.groupByName('现实分组');
      expect(realityGroup, isNotNull);

      await service.setGroupSort(realityGroup!.id, BookshelfSortType.title);
      final scoped = service.shelfBooksByGroup(groupId: realityGroup.id);

      expect(scoped.length, 2);
      expect(scoped.first.book.title, '海风向北');
      expect(scoped.last.book.title, '霜港手札');
    });
  });
}
