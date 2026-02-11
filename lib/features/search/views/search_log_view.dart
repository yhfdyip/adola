import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/services/app_log_service.dart';

class SearchLogView extends StatelessWidget {
  const SearchLogView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('日志'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: AppLogService.instance.clear,
          child: Text(
            '清空',
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<List<AppLogEntry>>(
          valueListenable: AppLogService.instance.logListenable,
          builder: (context, logs, _) {
            if (logs.isEmpty) {
              return Center(
                child: Text(
                  '暂无日志',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: logs
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LogTile(entry: entry),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final AppLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!entry.hasDetail) {
          return;
        }

        showCupertinoDialog<void>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('日志详情'),
            content: Text(entry.detail!),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: theme.radius,
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatTime(entry.time),
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              entry.message,
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute:$second';
  }
}

