import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home/home_screen.dart';
import 'syllabus/syllabus_screen.dart';
import 'recall/recall_center_screen.dart';
import 'analytics/analytics_screen.dart';
import 'syllabus/syllabus_preview_screen.dart';
import '../providers/syllabus_provider.dart';

/// Riverpod provider for controlling the active navigation tab
class NavigationIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (index >= 0 && index <= 3) {
      state = index;
    }
  }
}

final navigationIndexProvider = NotifierProvider<NavigationIndexNotifier, int>(
  NavigationIndexNotifier.new,
);

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);

    // A newly generated syllabus is previewed before the student commits.
    ref.listen(
      syllabusProvider.select((s) => s.pendingSyllabus),
      (previous, next) {
        if (previous == null && next != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SyllabusPreviewScreen()),
          );
        }
      },
    );
    ref.listen(syllabusProvider.select((s) => s.errorMessage), (_, error) {
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    });

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: const [
          HomeScreen(),
          SyllabusScreen(),
          RecallCenterScreen(),
          AnalyticsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(navigationIndexProvider.notifier).setIndex(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Roadmap',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Review',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Progress',
          ),
        ],
      ),
    );
  }
}
