import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../data/services/tts_cache_service.dart';
import '../../core/theme/app_theme.dart';
import '../providers/settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.appBarGradientOf(context),
          ),
        ),
      ),
      body: Container(
        decoration: AppTheme.gradientBoxOf(context),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildTutorialSection(context),
              const SizedBox(height: 16),
              _buildAppearanceSection(context, ref),
              const SizedBox(height: 16),
              _buildAiSettingsSection(context, ref),
              const SizedBox(height: 16),
              _buildAboutSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialSection(BuildContext context) {
    return Container(
      decoration: AppTheme.playfulCardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(
                  Icons.school_rounded,
                  size: 18,
                  color: AppTheme.isDarkMode(context)
                      ? AppTheme.darkAccent
                      : AppTheme.sweetPink,
                ),
                const SizedBox(width: 8),
                Text(
                  '帮助',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.sweetPink.withValues(alpha: 0.8),
                    AppTheme.lavender.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.school_rounded, color: Colors.white),
            ),
            title: const Text('使用教程'),
            subtitle: const Text('快速了解点读鸭的使用方法'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.sweetPink,
                    AppTheme.honeyYellow,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '推荐',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onTap: () {
              context.push('/tutorial');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);

    return Container(
      decoration: AppTheme.playfulCardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(
                  Icons.palette_rounded,
                  size: 18,
                  color: AppTheme.isDarkMode(context)
                      ? AppTheme.darkAccent
                      : AppTheme.honeyYellow,
                ),
                const SizedBox(width: 8),
                Text(
                  '外观',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
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
          ),
        ],
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

  Widget _buildAiSettingsSection(BuildContext context, WidgetRef ref) {
    final hasApiKey = ref.watch(hasApiKeyProvider);

    return Container(
      decoration: AppTheme.playfulCardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(
                  Icons.auto_fix_high_rounded,
                  size: 18,
                  color: AppTheme.isDarkMode(context)
                      ? AppTheme.darkSecondary
                      : AppTheme.gentleGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI功能',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          _buildSettingTile(
            context: context,
            icon: Icons.auto_fix_high_rounded,
            iconColors: [AppTheme.gentleGreen, AppTheme.calmBlue],
            title: 'AI设置',
            subtitle: hasApiKey ? '已配置智谱AI' : '未配置，点击设置',
            subtitleColor: hasApiKey
                ? AppTheme.secondaryOf(context)
                : AppTheme.primaryOf(context),
            badge: hasApiKey ? '已启用' : null,
            badgeColor: AppTheme.secondaryOf(context),
            onTap: () {
              context.push('/settings/ai');
            },
          ),
          Divider(
              height: 1,
              indent: 76,
              endIndent: 20,
              color: AppTheme.dividerColorOf(context)),
          _buildSettingTile(
            context: context,
            icon: Icons.record_voice_over_rounded,
            iconColors: [AppTheme.honeyYellow, AppTheme.softOrange],
            title: '语音设置',
            subtitle: 'TTS音色、语速调节',
            onTap: () {
              context.push('/settings/voice');
            },
          ),
          Divider(
              height: 1,
              indent: 76,
              endIndent: 20,
              color: AppTheme.dividerColorOf(context)),
          _buildCacheTile(context),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required List<Color> iconColors,
    required String title,
    required String subtitle,
    Color? subtitleColor,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: iconColors.map((c) => c.withValues(alpha: 0.8)).toList(),
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: subtitleColor),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (badgeColor ?? AppTheme.secondaryOf(context))
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: badgeColor ?? AppTheme.secondaryOf(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      onTap: onTap,
    );
  }

  Widget _buildCacheTile(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getCacheInfo(),
      builder: (context, snapshot) {
        final cacheSize = snapshot.data?['size'] ?? 0;
        final fileCount = snapshot.data?['count'] ?? 0;

        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.lavender.withValues(alpha: 0.8),
                  AppTheme.calmBlue.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.storage_rounded, color: Colors.white),
          ),
          title: const Text('缓存管理'),
          subtitle: Text(
            cacheSize > 0
                ? '${(cacheSize / 1024 / 1024).toStringAsFixed(1)}MB · $fileCount 个文件'
                : '暂无缓存',
            style: TextStyle(
              color: cacheSize > 0
                  ? AppTheme.primaryOf(context)
                  : AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onTap: () {
            context.push('/settings/cache');
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getCacheInfo() async {
    final size = await TtsCacheService.instance.getCacheSize();
    final count = await TtsCacheService.instance.getCacheFileCount();
    return {'size': size, 'count': count};
  }

  Widget _buildAboutSection(BuildContext context) {
    return Container(
      decoration: AppTheme.playfulCardDecorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppTheme.calmBlue,
                ),
                const SizedBox(width: 8),
                Text(
                  '关于',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.calmBlue.withValues(alpha: 0.8),
                    AppTheme.lavender.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  const Icon(Icons.info_outline_rounded, color: Colors.white),
            ),
            title: const Text('关于点读鸭'),
            subtitle: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                return Text('版本 ${snapshot.data?.version ?? '1.0.0'}');
              },
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onTap: () async {
              final packageInfo = await PackageInfo.fromPlatform();
              if (!context.mounted) return;
              showAboutDialog(
                context: context,
                applicationName: '点读鸭',
                applicationVersion: packageInfo.version,
                applicationLegalese: '© ${DateTime.now().year}',
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      '一款专为儿童读本设计的点读应用，支持ML Kit文字识别和AI强化功能。',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
