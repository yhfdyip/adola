import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/services/library_service.dart';
import '../../book/views/book_detail_view.dart';
import 'ranking_view.dart';

class DiscoveryView extends StatelessWidget {
  const DiscoveryView({super.key});

  static const _channels = [
    (
      icon: CupertinoIcons.sparkles,
      title: '今日推荐',
      subtitle: '编辑精选热读书单',
      badge: 'HOT',
    ),
    (
      icon: CupertinoIcons.flame,
      title: '热榜',
      subtitle: '实时热门作品排行',
      badge: 'NEW',
    ),
    (
      icon: CupertinoIcons.layers,
      title: '分类',
      subtitle: '按题材筛选内容',
      badge: '12 类',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('发现')),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ShadCard(
              title: const Text('探索频道'),
              description: const Text('优先复刻 iOS 视觉风格'),
              child: Column(
                children: _channels
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _DiscoveryChannel(
                          icon: item.icon,
                          title: item.title,
                          subtitle: item.subtitle,
                          badge: item.badge,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            const _TopicSection(),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryChannel extends StatelessWidget {
  const _DiscoveryChannel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: theme.radius,
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (title == '热榜') {
            Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (context) => const RankingView(),
              ),
            );
          } else if (title == '今日推荐') {
            final recommendation = LibraryService.instance.allBooks().first;
            Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (context) => BookDetailView(book: recommendation),
              ),
            );
          }
        },
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.large.copyWith(
                      color: theme.colorScheme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            ShadBadge.outline(child: Text(badge)),
          ],
        ),
      ),
    );
  }
}

class _TopicSection extends StatelessWidget {
  const _TopicSection();

  static const _topics = ['都市', '科幻', '悬疑', '历史', '轻小说', '奇幻', '职场', '现实'];

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ShadCard(
      title: const Text('题材标签'),
      description: const Text('快速进入分类页'),
      footer: Row(
        children: [
          Icon(
            CupertinoIcons.info_circle,
            size: 14,
            color: theme.colorScheme.mutedForeground,
          ),
          const SizedBox(width: 6),
          Text(
            '仅实现 UI 与交互壳层，数据后续接 API。',
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _topics
            .map((topic) => ShadBadge.secondary(child: Text(topic)))
            .toList(),
      ),
    );
  }
}
