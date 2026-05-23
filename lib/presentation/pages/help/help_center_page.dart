import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import 'help_content_data.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  static const _categories = <({String title, List<int> indices})>[
    (title: '基础入门', indices: [0, 1]),
    (title: '核心功能', indices: [2, 3, 4]),
    (title: '设置与管理', indices: [5, 6]),
    (title: '更多信息', indices: [7, 8]),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('帮助中心'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.appBarGradientOf(context),
          ),
        ),
      ),
      body: Container(
        decoration: AppTheme.gradientBoxOf(context),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final category in _categories)
                  _buildCategory(context, category.title, category.indices, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategory(
    BuildContext context,
    String title,
    List<int> indices,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.55),
              ),
            ),
          ),
          for (int r = 0; r < (indices.length + 1) ~/ 2; r++)
            Padding(
              padding: EdgeInsets.only(bottom: r < (indices.length - 1) ~/ 2 ? 0 : 0),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 12),
                        child: _buildTopicCard(
                          context,
                          helpTopics[indices[r * 2]],
                          isDark,
                        ),
                      ),
                    ),
                    if (r * 2 + 1 < indices.length)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 12),
                          child: _buildTopicCard(
                            context,
                            helpTopics[indices[r * 2 + 1]],
                            isDark,
                          ),
                        ),
                      )
                    else
                      const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, HelpTopic topic, bool isDark) {
    return Material(
      color: AppTheme.cardOf(context),
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/settings/help/${topic.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        topic.color.withValues(alpha: 0.8),
                        topic.color.withValues(alpha: 0.3),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(topic.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 12),
                Text(
                  topic.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  topic.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.5),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ),
    );
  }
}
