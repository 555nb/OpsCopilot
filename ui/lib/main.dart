import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'views/dashboard_view.dart';
import 'views/copilot_view.dart';
import 'views/runbook_view.dart';
import 'views/hosts_view.dart';

void main() {
  runApp(const OpsCopilotApp());
}

class OpsCopilotApp extends StatelessWidget {
  const OpsCopilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpsCopilot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2563EB),
          surface: Color(0xFF181B22),
        ),
        fontFamily: 'Segoe UI',
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final ApiService _apiService = ApiService();
  String? _pendingDoctorPrompt;

  void _triggerDoctorInChat(String prompt) {
    setState(() {
      _pendingDoctorPrompt = prompt;
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final views = [
      DashboardView(
        apiService: _apiService,
        onTriggerDoctor: _triggerDoctorInChat,
      ),
      CopilotView(
        apiService: _apiService,
        initialPrompt: _pendingDoctorPrompt,
      ),
      RunbookView(apiService: _apiService),
      HostsView(apiService: _apiService),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF181B22),
            elevation: 0,
            titleSpacing: 16,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.terminal, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'OpsCopilot',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'SRE 生产级副驾',
                    style: TextStyle(color: Color(0xFF34D399), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          body: Row(
            children: [
              if (isWide)
                NavigationRail(
                  backgroundColor: const Color(0xFF181B22),
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (idx) {
                    setState(() {
                      _currentIndex = idx;
                      _pendingDoctorPrompt = null;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: Color(0xFF60A5FA)),
                  unselectedIconTheme: const IconThemeData(color: Colors.grey),
                  selectedLabelTextStyle: const TextStyle(
                    color: Color(0xFF60A5FA),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelTextStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('系统监控'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.psychology_outlined),
                      selectedIcon: Icon(Icons.psychology),
                      label: Text('智能诊断'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.menu_book_outlined),
                      selectedIcon: Icon(Icons.menu_book),
                      label: Text('SRE 预案'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.dns_outlined),
                      selectedIcon: Icon(Icons.dns),
                      label: Text('节点资产'),
                    ),
                  ],
                ),
              if (isWide) const VerticalDivider(width: 1, color: Color(0xFF262B36)),
              Expanded(child: views[_currentIndex]),
            ],
          ),
          bottomNavigationBar: isWide
              ? null
              : BottomNavigationBar(
                  currentIndex: _currentIndex,
                  backgroundColor: const Color(0xFF181B22),
                  selectedItemColor: const Color(0xFF60A5FA),
                  unselectedItemColor: Colors.grey,
                  type: BottomNavigationBarType.fixed,
                  onTap: (idx) {
                    setState(() {
                      _currentIndex = idx;
                      _pendingDoctorPrompt = null;
                    });
                  },
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard),
                      label: '系统监控',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.psychology),
                      label: '智能诊断',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.menu_book),
                      label: 'SRE 预案',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.dns),
                      label: '节点资产',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
