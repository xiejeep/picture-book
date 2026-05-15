import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/pages/home_page.dart';
import '../../presentation/pages/book_detail_page.dart';
import '../../presentation/pages/book_manage_page.dart';
import '../../presentation/pages/settings_page.dart';
import '../../presentation/pages/ai_settings_page.dart';
import '../../presentation/pages/voice_settings_page.dart';
import '../../presentation/pages/cache_management_page.dart';
import '../../presentation/pages/tutorial_page.dart';
import '../../data/models/book_model.dart';
import '../../core/theme/app_theme.dart';

Widget _buildErrorPage(BuildContext context, GoRouterState state) {
  return Scaffold(
    backgroundColor: AppTheme.warmCream,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.softOrange, const Color(0xFFFF8C42)],
              ),
              borderRadius: BorderRadius.circular(40),
            ),
            child:
                const Icon(Icons.error_outline, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            '页面不存在',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.warmBrown,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请返回首页继续使用',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.warmBrown.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.softOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => context.go('/'),
            child: const Text('返回首页'),
          ),
        ],
      ),
    ),
  );
}

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/book/:id',
        name: 'book_detail',
        builder: (context, state) {
          final book = state.extra;
          if (book == null || book is! BookModel) {
            return _buildErrorPage(context, state);
          }
          return BookDetailPage(book: book);
        },
      ),
      GoRoute(
        path: '/book/:id/manage',
        name: 'book_manage',
        builder: (context, state) {
          final book = state.extra;
          if (book == null || book is! BookModel) {
            return _buildErrorPage(context, state);
          }
          return BookManagePage(book: book);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
        routes: [
          GoRoute(
            path: 'ai',
            name: 'ai_settings',
            builder: (context, state) => const AiSettingsPage(),
          ),
          GoRoute(
            path: 'voice',
            name: 'voice_settings',
            builder: (context, state) => const VoiceSettingsPage(),
          ),
          GoRoute(
            path: 'cache',
            name: 'cache_management',
            builder: (context, state) => const CacheManagementPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/tutorial',
        name: 'tutorial',
        builder: (context, state) => const TutorialPage(),
      ),
    ],
    errorBuilder: _buildErrorPage,
  );
});
