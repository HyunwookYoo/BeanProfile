import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'features/beans/bean_list_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/settings_screen.dart';
import 'theme.dart';

// 앱 UI가 전부 한국어라 날짜 선택기 같은 시스템 위젯도 한국어로 맞춘다.
// 위젯 테스트는 BeanProfileApp이 아니라 자체 MaterialApp을 띄우므로(test/helpers.dart
// wrapApp), 설정을 여기 한 벌만 두고 양쪽이 공유해야 테스트가 실제 화면과 어긋나지 않는다.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];
const appSupportedLocales = [Locale('ko')];

class BeanProfileApp extends StatelessWidget {
  const BeanProfileApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'BeanProfile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: const HomeShell(),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _tabs = [BeanListScreen(), ProfileScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.coffee_outlined), selectedIcon: Icon(Icons.coffee), label: '원두'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: '취향'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
