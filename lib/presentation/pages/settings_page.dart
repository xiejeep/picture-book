import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_settings_page.dart';
import 'voice_settings_page.dart';
import 'cache_management_page.dart';
import 'tutorial_page.dart';
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
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppTheme.softOrange,
                Color(0xFFFF8C42),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: AppTheme.warmGradientBox,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildTutorialSection(context),
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
      decoration: AppTheme.playfulCardDecoration,
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
                  color: AppTheme.sweetPink,
                ),
                const SizedBox(width: 8),
                Text(
                  '帮助',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warmBrown.withOpacity(0.7),
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
                    AppTheme.sweetPink.withOpacity(0.8),
                    AppTheme.lavender.withOpacity(0.8),
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
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TutorialPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAiSettingsSection(BuildContext context, WidgetRef ref) {
    final hasApiKey = ref.watch(hasApiKeyProvider);

    return Container(
      decoration: AppTheme.playfulCardDecoration,
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
                  color: AppTheme.gentleGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI功能',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warmBrown.withOpacity(0.7),
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
            subtitleColor: hasApiKey ? AppTheme.gentleGreen : AppTheme.softOrange,
            badge: hasApiKey ? '已启用' : null,
            badgeColor: AppTheme.gentleGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiSettingsPage()),
              );
            },
          ),
          Divider(height: 1, indent: 76, endIndent: 20, color: Colors.grey.shade200),
          _buildSettingTile(
            context: context,
            icon: Icons.record_voice_over_rounded,
            iconColors: [AppTheme.honeyYellow, AppTheme.softOrange],
            title: '语音设置',
            subtitle: 'TTS音色、语速调节',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VoiceSettingsPage()),
              );
            },
          ),
          Divider(height: 1, indent: 76, endIndent: 20, color: Colors.grey.shade200),
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
            colors: iconColors.map((c) => c.withOpacity(0.8)).toList(),
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
                color: (badgeColor ?? AppTheme.gentleGreen).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: badgeColor ?? AppTheme.gentleGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppTheme.softGray,
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
                  AppTheme.lavender.withOpacity(0.8),
                  AppTheme.calmBlue.withOpacity(0.8),
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
              color: cacheSize > 0 ? AppTheme.gentleGreen : Colors.grey,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppTheme.softGray,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CacheManagementPage()),
            );
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
      decoration: AppTheme.playfulCardDecoration,
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
                    color: AppTheme.warmBrown.withOpacity(0.7),
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
                    AppTheme.calmBlue.withOpacity(0.8),
                    AppTheme.lavender.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.info_outline_rounded, color: Colors.white),
            ),
            title: const Text('关于点读鸭'),
            subtitle: const Text('版本 1.0.0'),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.softGray,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '点读鸭',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024',
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      '一款专为儿童点读本设计的点读应用，支持ML Kit文字识别和AI强化功能。',
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