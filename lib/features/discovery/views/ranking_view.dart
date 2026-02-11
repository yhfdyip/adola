import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/models/book_item.dart';
import '../../../core/services/library_service.dart';
import '../../book/views/book_detail_view.dart';

class RankingView extends StatelessWidget {
  const RankingView({super.key});

  static final List<BookItem> _items = LibraryService.instance.allBooks();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('热榜')),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ShadCard(
              title: const Text('实时热榜'),
              description: const Text('演示数据 · 每小时更新一次'),
              child: Column(
                children: _items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: theme.radius,
                      border: Border.all(color: theme.colorScheme.border),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '#${index + 1}',
                            style: theme.textTheme.small.copyWith(
                              color: index < 3
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.mutedForeground,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.large.copyWith(
                                  color: theme.colorScheme.foreground,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.author,
                                style: theme.textTheme.small.copyWith(
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ShadButton.ghost(
                          onPressed: () {
                            Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                builder: (context) =>
                                    BookDetailView(book: item),
                              ),
                            );
                          },
                          child: const Text('查看'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
