import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/toast_util.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于我们'),
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
              children: [
                _buildHeroSection(context),
                const SizedBox(height: 24),
                _buildInfoSection(context),
                const SizedBox(height: 24),
                _buildContactSection(context),
                const SizedBox(height: 24),
                _buildFooterSection(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      decoration: AppTheme.playfulCardDecorationOf(context),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.softOrange.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/logo.png',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AppConstants.appName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '1.0.0';
              final buildNumber = snapshot.data?.buildNumber;
              return Text(
                '版本 $version${buildNumber != null ? ' ($buildNumber)' : ''}',
                style: TextStyle(
                  fontSize: AppFontSize.base,
                  color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            '一款专为儿童英语读本设计的智能点读应用，\n让阅读变得更有趣、更高效。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFontSize.base,
              height: 1.6,
              color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
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
                  Icons.star_rounded,
                  size: 18,
                  color: AppTheme.primaryOf(context),
                ),
                const SizedBox(width: 8),
                Text(
                  '核心功能',
                  style: TextStyle(
                    fontSize: AppFontSize.base,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          _buildFeatureItem(
            context,
            icon: Icons.document_scanner_rounded,
            title: '智能点读',
            subtitle: '拍照识别英文文本，点击即可朗读，让英语学习更直观',
          ),
          _buildFeatureItem(
            context,
            icon: Icons.auto_awesome_rounded,
            title: 'AI 增强',
            subtitle: '基于智谱 GLM 大模型，智能强化识别结果，提升准确度',
          ),
          _buildFeatureItem(
            context,
            icon: Icons.record_voice_over_rounded,
            title: '高质量语音',
            subtitle: '支持 GLM-TTS 和 Supertonic 离线语音合成，发音标准自然',
          ),
          _buildFeatureItem(
            context,
            icon: Icons.book_rounded,
            title: '读本管理',
            subtitle: '创建和管理多个英语读本，每页支持独立识别和点读',
          ),
          _buildFeatureItem(
            context,
            icon: Icons.nfc_rounded,
            title: 'NFC 快捷播放',
            subtitle: '支持 NFC 标签绑定，靠近即可自动播放指定内容',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryOf(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: AppTheme.primaryOf(context),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AppFontSize.md,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: AppFontSize.sm,
                    height: 1.4,
                    color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
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
                  Icons.mail_outline_rounded,
                  size: 18,
                  color: AppTheme.primaryOf(context),
                ),
                const SizedBox(width: 8),
                Text(
                  '联系我们',
                  style: TextStyle(
                    fontSize: AppFontSize.base,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          _buildContactItem(
            context,
            icon: Icons.email_rounded,
            label: '邮箱',
            value: 'classhorse@foxmail.com',
            onTap: () {
              Clipboard.setData(const ClipboardData(text: 'classhorse@foxmail.com'));
              ToastUtil.success('邮箱已复制到剪贴板');
            },
          ),
          _buildContactItem(
            context,
            icon: Icons.chat_rounded,
            label: '微信',
            value: 'classhorse2025',
            onTap: () {
              Clipboard.setData(const ClipboardData(text: 'classhorse2025'));
              ToastUtil.success('微信号已复制到剪贴板');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: '$label: $value',
      hint: '点击复制',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryOf(context).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: AppTheme.primaryOf(context),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: AppFontSize.md,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurfaceOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.copy_rounded,
                size: 18,
                color: AppTheme.primaryOf(context).withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterSection(BuildContext context) {
    return Container(
      decoration: AppTheme.playfulCardDecorationOf(context),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          Text(
            '感谢使用 ${AppConstants.appName}',
            style: TextStyle(
              fontSize: AppFontSize.md,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceOf(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '© ${DateTime.now().year} ${AppConstants.appName}',
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '让每个孩子都能享受阅读的乐趣',
            style: TextStyle(
              fontSize: AppFontSize.sm,
              color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
