import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/pages/home_page.dart';
import '../../presentation/pages/book_detail_page.dart';
import '../../presentation/pages/book_manage_page.dart';
import '../../presentation/pages/settings_page.dart';
import '../../data/models/book_model.dart';

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
          final book = state.extra as BookModel;
          return BookDetailPage(book: book);
        },
      ),
      GoRoute(
        path: '/book/:id/manage',
        name: 'book_manage',
        builder: (context, state) {
          final book = state.extra as BookModel;
          return BookManagePage(book: book);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('错误')),
      body: Center(child: Text('页面不存在: ${state.error}')),
    ),
  );
});