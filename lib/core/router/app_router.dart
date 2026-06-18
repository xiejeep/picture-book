import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/pages/home_page.dart';
import '../../presentation/pages/book_reader_page.dart';
import '../../presentation/pages/book_manage_page.dart';
import '../../presentation/pages/settings_page.dart';
import '../../presentation/pages/ai_settings_page.dart';
import '../../presentation/pages/voice_settings_page.dart';
import '../../presentation/pages/cache_management_page.dart';
import '../../presentation/pages/supertonic_model_page.dart';
import '../../presentation/pages/help/help_center_page.dart';
import '../../presentation/pages/help/help_topic_page.dart';
import '../../presentation/pages/about_page.dart';
import '../../presentation/pages/appearance_settings_page.dart';
import '../../data/models/book_model.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/nfc_service.dart';
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
    redirect: (context, state) {
      final uri = state.uri;
      if (uri.scheme == 'dianduya' && uri.host == 'play') {
        final segments = uri.pathSegments;
        if (segments.length == 3) {
          final bookId = segments[0];
          final pageId = segments[1];
          final blockId = segments[2];
          return '/book/$bookId?autoPlayPageId=$pageId&autoPlayBlockId=$blockId';
        }
      }
      if (uri.scheme == 'file' || uri.scheme == 'content') {
        return '/';
      }
      return null;
    },
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
          final bookId = state.pathParameters['id']!;
          final extra = state.extra;

          BookModel? book;
          if (extra is BookModel) {
            book = extra;
          } else {
            book = StorageService.instance.getBook(bookId);
          }

          if (book == null) {
            return _buildErrorPage(context, state);
          }

          final autoPlayPageId =
              state.uri.queryParameters['autoPlayPageId'];
          final autoPlayBlockId =
              state.uri.queryParameters['autoPlayBlockId'];

          return BookReaderPage(
            book: book,
            autoPlayPageId: autoPlayPageId,
            autoPlayBlockId: autoPlayBlockId,
          );
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
          GoRoute(
            path: 'supertonic',
            name: 'supertonic_model',
            builder: (context, state) => const SupertonicModelPage(),
          ),
          GoRoute(
            path: 'about',
            name: 'about',
            builder: (context, state) => const AboutPage(),
          ),
          GoRoute(
            path: 'appearance',
            name: 'appearance_settings',
            builder: (context, state) => const AppearanceSettingsPage(),
          ),
          GoRoute(
            path: 'help',
            name: 'help_center',
            builder: (context, state) => const HelpCenterPage(),
            routes: [
              GoRoute(
                path: ':topicId',
                name: 'help_topic',
                builder: (context, state) {
                  final topicId = state.pathParameters['topicId']!;
                  return HelpTopicPage(topicId: topicId);
                },
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: _buildErrorPage,
  );
});

String nfcPlayRoute(NfcAction action) {
  return '/book/${action.bookId}?autoPlayPageId=${action.pageId}&autoPlayBlockId=${action.blockId}';
}
