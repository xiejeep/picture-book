import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../help_content_data.dart';

final privacySections = <HelpSection>[
  HelpSection(
    title: 'AI 强化费用',
    accentColor: AppTheme.softOrange,
    items: [
      HelpTable(headers: ['模型', '输入价格', '输出价格'], rows: [
        ['GLM-4V-Flash', '免费', '免费'],
        ['GLM-4.6V-FlashX', '0.15 元/百万 token', '1.5 元/百万 token'],
        ['GLM-5V-Turbo', '5 元/百万 token', '22 元/百万 token'],
      ]),
      HelpTip('推荐日常使用免费模型 GLM-4V-Flash，零成本。'),
    ],
  ),
  HelpSection(
    title: 'TTS 费用',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpTable(headers: ['引擎', '费用', '说明'], rows: [
        ['系统 TTS', '免费', '设备自带引擎'],
        ['Supertonic', '免费', '设备端离线 AI 合成'],
      ]),
    ],
  ),
  HelpSection(
    title: '零成本方案',
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpTable(headers: ['方案', 'AI 强化', '语音'], rows: [
        ['全离线零成本 A', 'GLM-4V-Flash', '系统 TTS'],
        ['全离线零成本 B', 'GLM-4V-Flash', 'Supertonic'],
      ]),
      HelpTip('使用 Supertonic + GLM-4V-Flash 可实现完全零成本。AI 强化不联网也可用免费模型，Supertonic 离线运行。'),
    ],
  ),
  HelpSection(
    title: '网络使用说明',
    accentColor: AppTheme.sweetPink,
    items: [
      HelpParagraph('仅在使用 AI 强化时需要联网，所有请求均指向智谱 AI（open.bigmodel.cn）。'),
      HelpParagraph('以下功能完全离线：ML Kit OCR、系统 TTS、Supertonic、NFC、绘本管理、图片处理。'),
    ],
  ),
  HelpSection(
    title: '数据存储',
    accentColor: AppTheme.lavender,
    items: [
      HelpBulletList([
        '所有绘本数据（图片、文字）存储在设备本地',
        'AI设置、语音偏好存于 Hive 本地数据库',
        'API Key 存储在系统安全存储（Keychain/Keystore）',
        '无账号系统、无追踪 SDK、无广告、无崩溃上报',
      ]),
    ],
  ),
];
