import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../providers/settings_provider.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('外观设置'),
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThemeSection(context, ref, currentMode),
                const SizedBox(height: 24),
                _buildPreviewSection(context, currentMode),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSection(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    return Container(
      decoration: AppTheme.playfulCardDecorationOf(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                '选择主题',
                style: TextStyle(
                  fontSize: AppFontSize.base,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                ),
              ),
            ),
            Row(
              children: [
                _buildThemeOption(
                  context: context,
                  ref: ref,
                  mode: ThemeMode.light,
                  icon: Icons.light_mode_rounded,
                  label: '亮色',
                  gradientColors: [AppTheme.honeyYellow, AppTheme.softOrange],
                  isSelected: currentMode == ThemeMode.light,
                ),
                const SizedBox(width: 12),
                _buildThemeOption(
                  context: context,
                  ref: ref,
                  mode: ThemeMode.dark,
                  icon: Icons.dark_mode_rounded,
                  label: '暗色',
                  gradientColors: [AppTheme.calmBlue, AppTheme.lavender],
                  isSelected: currentMode == ThemeMode.dark,
                ),
                const SizedBox(width: 12),
                _buildThemeOption(
                  context: context,
                  ref: ref,
                  mode: ThemeMode.system,
                  icon: Icons.settings_suggest_rounded,
                  label: '跟随系统',
                  gradientColors: [AppTheme.gentleGreen, AppTheme.calmBlue],
                  isSelected: currentMode == ThemeMode.system,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeMode mode,
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required bool isSelected,
  }) {
    final hints = {
      ThemeMode.light: '切换到亮色主题',
      ThemeMode.dark: '切换到暗色主题',
      ThemeMode.system: '主题跟随系统设置',
    };
    return Expanded(
      child: Semantics(
        label: '$label主题',
        hint: hints[mode],
        button: true,
        child: GestureDetector(
          onTap: () {
            ref.read(themeModeProvider.notifier).setThemeMode(mode);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors
                    .map((c) => c.withValues(alpha: 0.15))
                    .toList(),
              ),
              borderRadius: BorderRadius.circular(16),
              border: isSelected
                  ? Border.all(color: gradientColors[0], width: 2.5)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: gradientColors[0].withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? gradientColors[0]
                        : AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewSection(BuildContext context, ThemeMode currentMode) {
    final isDark = currentMode == ThemeMode.dark ||
        (currentMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Container(
      decoration: AppTheme.playfulCardDecorationOf(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                '预览',
                style: TextStyle(
                  fontSize: AppFontSize.base,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurface
                    : AppTheme.warmCream,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '页面标题',
                        style: TextStyle(
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.warmBrown,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOf(context).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          '标签',
                          style: TextStyle(
                            fontSize: AppFontSize.sm,
                            color: AppTheme.primaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '这是一段正文内容，用于展示当前主题下的文字样式效果，帮助你选择最舒适的视觉体验。',
                    style: TextStyle(
                      fontSize: AppFontSize.base,
                      height: 1.5,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppTheme.warmBrown.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOf(context).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            '主要按钮',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: AppFontSize.sm,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
