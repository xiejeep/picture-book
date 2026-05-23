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
    final nfcAvailableAsync = ref.watch(nfcAvailableProvider);

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
              _buildHelpCenterSection(context),
              const SizedBox(height: 16),
              _buildAiSettingsSection(context, ref),
              const SizedBox(height: 16),
              _buildAppearanceTile(context, ref),
              const SizedBox(height: 16),
              if (nfcAvailableAsync.hasValue && nfcAvailableAsync.value == true)
                _buildDeviceSection(context, ref),
              if (nfcAvailableAsync.hasValue && nfcAvailableAsync.value == true)
                const SizedBox(height: 16),
              _buildAboutSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpCenterSection(BuildContext context) {
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
              child: const Icon(Icons.help_outline_rounded, color: Colors.white),
            ),
            title: const Text('帮助中心'),
            subtitle: const Text('快速入门、功能详解、常见问题'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
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
              context.push('/settings/help');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSection(BuildContext context, WidgetRef ref) {
    final nfcEnabled = ref.watch(nfcEnabledProvider);

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
                  Icons.nfc_rounded,
                  size: 18,
                  color: AppTheme.isDarkMode(context)
                      ? AppTheme.darkAccent
                      : AppTheme.softOrange,
                ),
                const SizedBox(width: 8),
                Text(
                  '设备功能',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'NFC功能',
            hint: nfcEnabled ? '点击关闭NFC功能' : '点击开启NFC功能',
            container: true,
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.softOrange.withValues(alpha: 0.8),
                      AppTheme.honeyYellow.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.nfc_rounded, color: Colors.white),
              ),
              title: const Text('NFC功能'),
              subtitle: Text(
                nfcEnabled ? '已开启，可使用NFC标签点读' : '未开启',
                style: TextStyle(
                  color: nfcEnabled
                      ? AppTheme.secondaryOf(context)
                      : AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
                ),
              ),
              trailing: Switch(
                value: nfcEnabled,
                onChanged: (value) {
                  ref.read(nfcEnabledProvider.notifier).setNfcEnabled(value);
                },
                activeTrackColor: AppTheme.primaryOf(context).withValues(alpha: 0.5),
                activeThumbColor: AppTheme.primaryOf(context),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceTile(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);
    final modeLabel = {
      ThemeMode.light: '亮色',
      ThemeMode.dark: '暗色',
      ThemeMode.system: '跟随系统',
    }[currentMode];

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
          _buildSettingTile(
            context: context,
            icon: Icons.palette_rounded,
            iconColors: [AppTheme.honeyYellow, AppTheme.softOrange],
            title: '外观设置',
            subtitle: '当前：$modeLabel',
            onTap: () {
              context.push('/settings/appearance');
            },
          ),
        ],
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
            onTap: () => context.push('/settings/about'),
          ),
        ],
      ),
    );
  }
}
