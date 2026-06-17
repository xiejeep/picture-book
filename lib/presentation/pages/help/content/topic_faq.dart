import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../help_content_data.dart';

final faqSections = <HelpSection>[
  HelpSection(
    title: 'OCR 识别不准确怎么办？',
    accentColor: AppTheme.softOrange,
    items: [
      HelpBulletList([
        '确保拍摄时光线充足、图片清晰',
        '点击"新建块"进入绘制模式，手动框选识别不准确的区域',
        '选中文字方块后点击底部工具栏"编辑"按钮手动修改文字',
        '使用 AI 强化自动修正识别错误',
      ]),
    ],
  ),
  HelpSection(
    title: 'AI 强化功能无法使用？',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpBulletList([
        '确认已在「AI 设置」中配置了有效的 API Key',
        '点击"测试连接"检查 API Key 是否有效',
        '确认网络连接正常',
        '免费模型 GLM-4V-Flash 即可满足日常使用',
      ]),
    ],
  ),
  HelpSection(
    title: '朗读没有声音？',
    accentColor: AppTheme.sweetPink,
    items: [
      HelpBulletList([
        '检查设备音量是否开启',
        '确认已在语音设置中选择了朗读引擎',
        '在语音设置中确认语速未调到最低',
      ]),
    ],
  ),
  HelpSection(
    title: '如何获取智谱 AI API Key？',
    accentColor: AppTheme.lavender,
    items: [
      HelpNumberedList([
        '访问 open.bigmodel.cn',
        '注册/登录账号',
        '进入 API Key 管理页面',
        '创建新的 API Key 并复制',
        '粘贴到应用的「AI 设置」中',
      ]),
    ],
  ),
  HelpSection(
    title: '如何删除绘本？',
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpBulletList([
        '在书架首页长按要删除的绘本卡片',
        '选择"删除读本"',
        '在确认对话框中确认删除',
      ]),
      HelpWarning('删除后无法恢复，请谨慎操作。'),
    ],
  ),
  HelpSection(
    title: '支持哪些语言识别？',
    accentColor: AppTheme.softOrange,
    items: [
      HelpParagraph('目前支持英文文字识别。中文文字会被自动过滤，不会出现在识别结果中。'),
    ],
  ),
  HelpSection(
    title: '缓存占用空间太大怎么办？',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpBulletList([
        '进入「设置 → 缓存管理」查看缓存大小',
        '点击"清空缓存"释放存储空间',
        '缓存超过 50 MB 时会自动清理',
      ]),
    ],
  ),
  HelpSection(
    title: '不联网能使用点读鸭吗？',
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpParagraph('可以。使用本地 OCR + 系统 TTS 或 Supertonic，完全不联网。'),
      HelpParagraph('需要联网仅：AI 强化识别。'),
    ],
  ),
  HelpSection(
    title: 'NFC 标签靠近没有反应？',
    accentColor: AppTheme.honeyYellow,
    items: [
      HelpBulletList([
        'Android：确认系统 NFC 已开启，应用内 NFC 开关已开启',
        'iOS：需手动点击阅读页面的 NFC 图标按钮触发扫描',
        '确认标签为 NDEF 格式的 ISO14443 或 ISO15693 标签',
        '尝试将标签靠近手机不同区域（通常在顶部背部）',
      ]),
      HelpTip('长按文字方块可绑定 NFC 标签，绑定后靠近即可自动播放。'),
    ],
  ),
  HelpSection(
    title: 'iOS 为什么不能像 Android 那样自动读取？',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpParagraph('这是苹果 iOS 系统的安全限制，无法绕过。iOS 要求用户必须先打开应用并主动点击扫描按钮。'),
    ],
  ),
  HelpSection(
    title: 'Supertonic 和系统 TTS 怎么选？',
    accentColor: AppTheme.sweetPink,
    items: [
      HelpTable(headers: ['场景', '推荐引擎', '原因'], rows: [
        ['完全离线', 'Supertonic 或系统 TTS', '无需网络'],
        ['最佳音质', 'Supertonic', '免费且离线，AI 合成效果最佳'],
        ['省钱', 'Supertonic', '免费且离线，音质优于系统 TTS'],
        ['省电', '系统 TTS', '最轻量'],
      ]),
    ],
  ),
  HelpSection(
    title: '如何将绘本分享给其他设备？',
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpNumberedList([
        '长按绘本卡片 → "分享" → 通过系统分享发送 .ddb 文件',
        '在另一台设备上打开点读鸭 → 点击导入图标',
        '.ddb 格式支持 iOS ↔ Android 跨平台导入',
      ]),
    ],
  ),
];
