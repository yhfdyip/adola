import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/models/book_item.dart';
import '../../../core/services/app_log_service.dart';
import '../../../core/services/library_service.dart';
import '../../search/views/search_view.dart';

class SourceListView extends StatefulWidget {
  const SourceListView({super.key});

  @override
  State<SourceListView> createState() => _SourceListViewState();
}

class _SourceListViewState extends State<SourceListView> {
  final LibraryService _libraryService = LibraryService.instance;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('书源')),
      child: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<List<BookSourceItem>>(
          valueListenable: _libraryService.sourceListenable,
          builder: (context, sources, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _buildSourceCard(context, sources),
                const SizedBox(height: 14),
                const _DebugHintCard(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSourceCard(BuildContext context, List<BookSourceItem> sources) {
    return ShadCard(
      title: const Text('书源列表'),
      description: const Text('对齐 legado：新增/导入/导出/启停 管理闭环'),
      footer: Row(
        children: [
          Expanded(
            child: ShadButton.secondary(
              onPressed: () => _showImportSheet(context),
              child: const Text('导入'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ShadButton.outline(
              onPressed: sources.isEmpty ? null : _exportSources,
              child: const Text('导出'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ShadButton(
              onPressed: () => _showSourceEditDialog(context),
              child: const Text('新增'),
            ),
          ),
        ],
      ),
      child: sources.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('暂无书源，请先导入或新增。'),
            )
          : Column(
              children: sources
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _SourceTile(
                        source: item,
                        onToggleEnabled: (enabled) async {
                          await _libraryService.setSourceEnabled(
                            item.url,
                            enabled,
                          );
                          AppLogService.instance.put(
                            enabled
                                ? '启用书源：${item.name}'
                                : '停用书源：${item.name}',
                          );
                        },
                        onEdit: () => _showSourceEditDialog(
                          context,
                          source: item,
                        ),
                        onDelete: () => _confirmDeleteSource(context, item),
                        onSearchFromSource: () => _copySourceSearchHint(item),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  Future<void> _showImportSheet(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('导入书源'),
        message: const Text('支持 legado 风格 JSON 数组（字段：url/name/host）'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _showImportFromJsonDialog(context);
            },
            child: const Text('粘贴 JSON 导入'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _pasteFromClipboard();
            },
            child: const Text('从剪贴板导入'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _showImportFromJsonDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController();

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('导入书源 JSON'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            maxLines: 8,
            placeholder: '粘贴 JSON 数组',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _importByJsonText(controller.text);
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _showNotice('剪贴板为空', '未检测到可导入内容');
      return;
    }
    await _importByJsonText(text);
  }

  Future<void> _importByJsonText(String rawJson) async {
    final trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      _showNotice('导入失败', '内容不能为空');
      return;
    }

    try {
      final sources = _libraryService.parseSourcesJson(trimmed);
      await _libraryService.importSources(sources);
      AppLogService.instance.put('导入书源：${sources.length} 条');
      _showNotice('导入成功', '已导入 ${sources.length} 条书源');
    } on FormatException catch (error) {
      _showNotice('导入失败', error.message);
    } catch (_) {
      _showNotice('导入失败', 'JSON 格式不正确');
    }
  }

  Future<void> _exportSources() async {
    final sourceJson = _libraryService.exportSourcesJson();
    await Clipboard.setData(ClipboardData(text: sourceJson));
    AppLogService.instance.put('导出书源：${_libraryService.allSources().length} 条');
    _showNotice('导出成功', '书源 JSON 已复制到剪贴板');
  }

  Future<void> _copySourceSearchHint(BookSourceItem source) async {
    AppLogService.instance.put('从书源管理发起搜索：${source.name}');
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => SearchView(
          initialScope: SearchScope.source(source.url, sourceLabel: source.name),
        ),
      ),
    );
  }

  Future<void> _showSourceEditDialog(
    BuildContext context, {
    BookSourceItem? source,
  }) async {
    final isEdit = source != null;
    final nameController = TextEditingController(text: source?.name ?? '');
    final urlController = TextEditingController(text: source?.url ?? '');
    final hostController = TextEditingController(text: source?.host ?? '');
    final groupController = TextEditingController(text: source?.group ?? '');
    bool enabled = source?.enabled ?? true;
    bool enabledExplore = source?.enabledExplore ?? true;

    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return CupertinoAlertDialog(
            title: Text(isEdit ? '编辑书源' : '新增书源'),
            content: Column(
              children: [
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: nameController,
                  placeholder: '书源名称',
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: urlController,
                  placeholder: '书源 URL',
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: hostController,
                  placeholder: 'Host',
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: groupController,
                  placeholder: '分组（可选）',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(child: Text('启用书源')),
                    CupertinoSwitch(
                      value: enabled,
                      onChanged: (value) => setState(() => enabled = value),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('启用发现')),
                    CupertinoSwitch(
                      value: enabledExplore,
                      onChanged: (value) =>
                          setState(() => enabledExplore = value),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final url = urlController.text.trim();
                  final host = hostController.text.trim();
                  final group = groupController.text.trim();

                  if (name.isEmpty || url.isEmpty || host.isEmpty) {
                    _showNotice('保存失败', '名称/URL/Host 不能为空');
                    return;
                  }

                  final target = BookSourceItem(
                    url: url,
                    name: name,
                    host: host,
                    group: group.isEmpty ? null : group,
                    enabled: enabled,
                    enabledExplore: enabledExplore,
                    customOrder: source?.customOrder ?? 0,
                    lastUpdateTime: DateTime.now(),
                  );

                  await _libraryService.upsertSource(target);
                  AppLogService.instance.put(
                    isEdit ? '更新书源：$name' : '新增书源：$name',
                  );

                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  _showNotice('保存成功', isEdit ? '书源已更新' : '书源已新增');
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteSource(
    BuildContext context,
    BookSourceItem source,
  ) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('删除书源'),
        content: Text('确认删除「${source.name}」？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              await _libraryService.removeSource(source.url);
              AppLogService.instance.put('删除书源：${source.name}');
              if (!context.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
              _showNotice('删除成功', '书源已移除：${source.name}');
            },
            child: const Text('删除'),
          ),
        ],
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

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.onToggleEnabled,
    required this.onEdit,
    required this.onDelete,
    required this.onSearchFromSource,
  });

  final BookSourceItem source;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSearchFromSource;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      style: theme.textTheme.large.copyWith(
                        color: theme.colorScheme.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      source.host,
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ShadBadge.outline(child: Text('URL ${source.url}')),
                        if (source.hasGroup)
                          ShadBadge.secondary(child: Text('分组 ${source.group}')),
                        ShadBadge.outline(
                          child: Text(source.enabledExplore ? '发现启用' : '发现停用'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  ShadSwitch(
                    value: source.enabled,
                    onChanged: onToggleEnabled,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    source.enabled ? '已启用' : '已停用',
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ShadButton.outline(
                  onPressed: onSearchFromSource,
                  child: const Text('定位搜索'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadButton.secondary(onPressed: onEdit, child: const Text('编辑')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadButton.destructive(
                  onPressed: onDelete,
                  child: const Text('删除'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebugHintCard extends StatelessWidget {
  const _DebugHintCard();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
      title: const Text('调试说明'),
      child: Text(
        '当前书源管理对齐 legado 的核心流程：新增、编辑、导入、导出、启停与搜索联动。',
        style: theme.textTheme.small.copyWith(
          color: theme.colorScheme.mutedForeground,
        ),
      ),
    );
  }
}
