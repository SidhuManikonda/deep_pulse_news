// import 'package:deep_pulse_news/data/models/news.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../../core/constants/app_font_sizes.dart';
// import '../../data/repositories/news_repository.dart';
// import '../../extensions/user_extensions.dart';
// import '../../features/auth/auth_view_model.dart';
// import '../../features/news/news_upload_screen.dart';
// import '../../providers/app_providers.dart';
// import 'notifications_view_model.dart';

// class NotificationsScreen extends ConsumerStatefulWidget {
//   const NotificationsScreen({super.key});

//   @override
//   ConsumerState<NotificationsScreen> createState() =>
//       _NotificationsScreenState();
// }

// class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
//   late NotificationsViewModel _viewModel;
//   late AuthViewModel _authViewModel;
//   String _sortBy = 'newest'; // Default sort by newest first

//   @override
//   void initState() {
//     super.initState();
//     final newsRepository = NewsRepositoryImpl();
//     _viewModel = NotificationsViewModel(newsRepository: newsRepository);

//     // Get auth view model from provider
//     _authViewModel = ref.read(authViewModelProvider);
//   }

//   @override
//   void dispose() {
//     _viewModel.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final currentUser = _authViewModel.user;

//     // Only admin, sub_admin, and dist-reporter can see pending news
//     final role = currentUser?.primaryRole.value ?? 'reader';
//     final canManageNews = role == 'admin' || role == 'sub_admin' || role == 'dist-reporter';
//     if (!canManageNews) {
//       return Scaffold(
//         backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//         appBar: AppBar(
//           backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//           elevation: 0,
//           title: Text(
//             'Notifications',
//             style: TextStyle(
//               fontSize: appFontSizeHeader,
//               fontWeight: FontWeight.bold,
//               color: Theme.of(context).textTheme.headlineLarge?.color,
//             ),
//           ),
//           centerTitle: true,
//         ),
//         body: Center(
//           child: Text(
//             'Access denied. Admin privileges required.',
//             style: TextStyle(
//               fontSize: scaledFontSize(14),
//               color: Theme.of(context).colorScheme.error,
//             ),
//           ),
//         ),
//       );
//     }

//     return Scaffold(
//       backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).scaffoldBackgroundColor,
//         elevation: 0,
//         title: Text(
//           'Pending News',
//           style: TextStyle(
//             fontSize: scaledFontSize(16),
//             fontWeight: FontWeight.bold,
//             color: Theme.of(context).textTheme.headlineLarge?.color,
//           ),
//         ),
//       ),
//       body: ListenableBuilder(
//         listenable: _viewModel,
//         builder: (context, child) {
//           if (_viewModel.isLoading) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           if (_viewModel.error != null) {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     Icons.error_outline,
//                     size: 48,
//                     color: Theme.of(context).colorScheme.error,
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     'Failed to load pending news',
//                     style: TextStyle(
//                       color: Theme.of(context).colorScheme.error,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   ElevatedButton(
//                     onPressed: () => _viewModel.refreshPendingNews(),
//                     child: const Text('Retry'),
//                   ),
//                 ],
//               ),
//             );
//           }

//           if (_viewModel.pendingNews.isEmpty) {
//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     Icons.notifications_none,
//                     size: 48,
//                     color: Theme.of(context).colorScheme.onSurfaceVariant,
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     'No pending news to review',
//                     style: TextStyle(
//                       fontSize: scaledFontSize(16),
//                       color: Theme.of(context).colorScheme.onSurface,
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           }

//           return RefreshIndicator(
//             onRefresh: _viewModel.refreshPendingNews,
//             child: ListView.builder(
//               padding: const EdgeInsets.all(16),
//               itemCount: _viewModel.pendingNews.length,
//               itemBuilder: (context, index) {
//                 final news = _viewModel.pendingNews[index];
//                 return _buildPendingNewsItem(context, news);
//               },
//             ),
//           );
//         },
//       ),
//     );
//   }

//   List<dynamic> _getSortedPendingNews() {
//     final newsList = List.from(_viewModel.pendingNews);
    
//     switch (_sortBy) {
//       case 'newest':
//         newsList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
//         break;
//       case 'oldest':
//         newsList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
//         break;
//       case 'title_az':
//         newsList.sort((a, b) {
//           final aTitle = a.getPrimaryTranslation()?.title ?? '';
//           final bTitle = b.getPrimaryTranslation()?.title ?? '';
//           return aTitle.compareTo(bTitle);
//         });
//         break;
//       case 'title_za':
//         newsList.sort((a, b) {
//           final aTitle = a.getPrimaryTranslation()?.title ?? '';
//           final bTitle = b.getPrimaryTranslation()?.title ?? '';
//           return bTitle.compareTo(aTitle);
//         });
//         break;
//     }
    
//     return newsList;
//   }

//   Widget _buildPendingNewsItem(BuildContext context, News news) {
//     final primaryTranslation = news.getPrimaryTranslation();

//     return Card(
//       margin: const EdgeInsets.only(bottom: 16),
//       child: InkWell(
//         onTap: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => NewsUploadScreen(prefillNews: news),
//             ),
//           );
//         },
//         borderRadius: BorderRadius.circular(12),
//         child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Author info
//             Row(
//               children: [
//                 CircleAvatar(
//                   radius: 16,
//                   backgroundColor: Theme.of(
//                     context,
//                   ).colorScheme.primary.withOpacity(0.2),
//                   child: Icon(
//                     Icons.person,
//                     size: 16,
//                     color: Theme.of(context).colorScheme.primary,
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     news.authorName ?? 'Unknown Author',
//                     style: TextStyle(
//                       fontSize: scaledFontSize(14),
//                       fontWeight: FontWeight.w500,
//                       color: Theme.of(context).colorScheme.onSurface,
//                     ),
//                   ),
//                 ),
//                 // Status badge
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 4,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.orange.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Text(
//                     'Pending',
//                     style: TextStyle(
//                       fontSize: scaledFontSize(12),
//                       color: Colors.orange,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),

//             // News title
//             Text(
//               primaryTranslation?.title ?? 'No title',
//               style: TextStyle(
//                 fontSize: scaledFontSize(16),
//                 fontWeight: FontWeight.bold,
//                 color: Theme.of(context).colorScheme.onSurface,
//               ),
//             ),
//             const SizedBox(height: 8),

//             // News content preview
//             Text(
//               primaryTranslation?.content ?? 'No content',
//               style: TextStyle(
//                 fontSize: scaledFontSize(14),
//                 color: Theme.of(context).colorScheme.onSurfaceVariant,
//               ),
//               maxLines: 3,
//               overflow: TextOverflow.ellipsis,
//             ),
//             const SizedBox(height: 12),

//             // Action buttons
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     onPressed: () async {
//                       final success = await _viewModel.approveNews(news.id);
//                       if (success) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                             content: Text('News approved successfully'),
//                             backgroundColor: Colors.green,
//                           ),
//                         );
//                       } else {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                             content: Text('Failed to approve news'),
//                             backgroundColor: Colors.red,
//                           ),
//                         );
//                       }
//                     },
//                     icon: const Icon(Icons.check, size: 18),
//                     label: const Text('Approve'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.green,
//                       foregroundColor: Colors.white,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: OutlinedButton.icon(
//                     onPressed: () async {
//                       final success = await _viewModel.rejectNews(news.id);
//                       if (success) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                             content: Text('News rejected successfully'),
//                             backgroundColor: Colors.orange,
//                           ),
//                         );
//                       } else {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                             content: Text('Failed to reject news'),
//                             backgroundColor: Colors.red,
//                           ),
//                         );
//                       }
//                     },
//                     icon: const Icon(Icons.close, size: 18),
//                     label: const Text('Reject'),
//                     style: OutlinedButton.styleFrom(
//                       side: const BorderSide(color: Colors.red),
//                       foregroundColor: Colors.red,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: const Center(
        child: Text('Notifications will be displayed here.'),
      ),
    
    );
    
  }
}