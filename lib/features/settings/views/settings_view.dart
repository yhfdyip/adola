import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _followSystem = true;
  bool _useVolumeTurnPage = false;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('设置')),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ShadCard(
              title: const Text('外观'),
              child: Column(
                children: [
                  _SettingRow(
                    title: '跟随系统深色模式',
                    value: _followSystem,
                    onChanged: (value) => setState(() => _followSystem = value),
                  ),
                  const SizedBox(height: 8),
                  _SettingRow(
                    title: '音量键翻页',
                    value: _useVolumeTurnPage,
                    onChanged: (value) =>
                        setState(() => _useVolumeTurnPage = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ShadCard(
              title: const Text('关于'),
              description: const Text('许可证已移除'),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CupertinoListTile.notched(
                    title: Text('版本'),
                    additionalInfo: Text('0.1.0-ios-preview'),
                  ),
                  CupertinoListTile.notched(
                    title: Text('数据同步'),
                    additionalInfo: Text('未启用'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: theme.radius,
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.large.copyWith(
                color: theme.colorScheme.foreground,
              ),
            ),
          ),
          ShadSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
