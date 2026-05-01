import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user.dart';
import '../../extensions/user_extensions.dart';
import '../../providers/app_providers.dart';

class RoleBasedBottomNav extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const RoleBasedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authViewModel = ref.watch(authViewModelProvider);
    final user = authViewModel.user;

    if (user == null) {
      // Default navigation for non-authenticated users
      return _buildDefaultBottomNav(context);
    }

    final navItems = user.availableNavigation;
    final bottomNavItems = _getBottomNavItems(navItems, user);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        final route = bottomNavItems[index]['route'] as String;
        if (route.startsWith('/')) {
          Navigator.pushNamed(context, route);
        } else {
          onTap(index);
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey[600],
      items: bottomNavItems.map((item) {
        return BottomNavigationBarItem(
          icon: _getIcon(item['icon'] as String),
          label: item['label'] as String,
        );
      }).toList(),
    );
  }

  Widget _buildDefaultBottomNav(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey[600],
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.newspaper),
          label: 'News',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.sports_soccer),
          label: 'Sports',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getBottomNavItems(List<NavigationItem> navItems, User user) {
    final items = <Map<String, dynamic>>[];

    // Always include Home
    items.add({
      'icon': 'home',
      'label': 'Home',
      'route': 'home',
    });

    // Add News
    items.add({
      'icon': 'newspaper',
      'label': 'News',
      'route': 'news',
    });

    // Add role-specific items
    if (user.canUploadContent) {
      items.add({
        'icon': 'upload',
        'label': 'Upload',
        'route': '/upload',
      });
    }

    if (user.canModerateContent) {
      items.add({
        'icon': 'moderate',
        'label': 'Moderate',
        'route': '/moderate',
      });
    } else if (user.primaryRole.level >= 3) {
      // For dist-reporter and above, show a "More" tab for additional features
      items.add({
        'icon': 'more',
        'label': 'More',
        'route': 'more',
      });
    }

    // Always include Profile
    items.add({
      'icon': 'profile',
      'label': 'Profile',
      'route': '/profile',
    });

    return items;
  }

  Widget _getIcon(String iconName) {
    switch (iconName) {
      case 'home':
        return const Icon(Icons.home);
      case 'newspaper':
        return const Icon(Icons.newspaper);
      case 'upload':
        return const Icon(Icons.upload);
      case 'moderate':
        return const Icon(Icons.admin_panel_settings);
      case 'more':
        return const Icon(Icons.more_horiz);
      case 'profile':
        return const Icon(Icons.person);
      case 'users':
        return const Icon(Icons.people);
      case 'admin':
        return const Icon(Icons.admin_panel_settings);
      default:
        return const Icon(Icons.circle);
    }
  }
}
