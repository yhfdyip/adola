import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../features/bookshelf/views/bookshelf_view.dart';
import '../features/discovery/views/discovery_view.dart';
import '../features/search/views/search_view.dart';
import '../features/settings/views/settings_view.dart';
import '../features/source/views/source_list_view.dart';
import '../core/services/app_log_service.dart';
import 'theme/adola_theme.dart';

class AdolaApp extends StatefulWidget {
  const AdolaApp({super.key});

  @override
  State<AdolaApp> createState() => _AdolaAppState();
}

class _AdolaAppState extends State<AdolaApp> with WidgetsBindingObserver {
  late Brightness _platformBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _applySystemUiOverlayStyle(_platformBrightness);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    final nextBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (nextBrightness != _platformBrightness) {
      setState(() => _platformBrightness = nextBrightness);
      _applySystemUiOverlayStyle(nextBrightness);
    }
  }

  void _applySystemUiOverlayStyle(Brightness brightness) {
    SystemChrome.setSystemUIOverlayStyle(
      brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'Adola',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: AdolaTheme.light,
      darkTheme: AdolaTheme.dark,
      builder: (context, child) {
        return CupertinoTheme(
          data: AdolaTheme.cupertinoTheme(context),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _MainScreen(),
    );
  }
}

class _MainScreen extends StatelessWidget {
  const _MainScreen();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: AdolaTheme.tabBarBackground(theme.brightness),
        activeColor: theme.colorScheme.primary,
        inactiveColor: theme.colorScheme.mutedForeground,
        border: AdolaTheme.tabBarBorder(theme),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.book),
            activeIcon: Icon(CupertinoIcons.book_fill),
            label: '书架',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.compass),
            activeIcon: Icon(CupertinoIcons.compass_fill),
            label: '发现',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.search),
            label: '搜索',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.cloud),
            activeIcon: Icon(CupertinoIcons.cloud_fill),
            label: '书源',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.gear),
            activeIcon: Icon(CupertinoIcons.gear_solid),
            label: '设置',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          defaultTitle: 'Adola',
          builder: (context) {
            switch (index) {
              case 0:
                return const BookshelfView();
              case 1:
                return const DiscoveryView();
              case 2:
                return const SearchView();
              case 3:
                return const SourceListView();
              case 4:
                return const SettingsView();
              default:
                return const BookshelfView();
            }
          },
        );
      },
    );
  }
}

Future<void> reportGlobalFlutterError(FlutterErrorDetails details) async {
  FlutterError.presentError(details);
  debugPrint('[flutter-error] ${details.exceptionAsString()}');
  AppLogService.instance.put(
    '[flutter-error] ${details.exceptionAsString()}',
    error: details.exception,
    stackTrace: details.stack,
  );
  if (details.stack != null) {
    debugPrintStack(stackTrace: details.stack);
  }
}

Future<void> reportGlobalPlatformError(Object error, StackTrace stack) async {
  debugPrint('[platform-error] $error');
  AppLogService.instance.put(
    '[platform-error] $error',
    error: error,
    stackTrace: stack,
  );
  debugPrintStack(stackTrace: stack);
}

void registerGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    unawaited(reportGlobalFlutterError(details));
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(reportGlobalPlatformError(error, stack));
    return true;
  };
}
