import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../help_content_data.dart';

final appearanceSections = <HelpSection>[
  HelpSection(
    title: '进入外观设置',
    accentColor: AppTheme.lavender,
    items: [
      HelpParagraph('书架首页 → 齿轮图标 → "外观设置"。'),
    ],
  ),
  HelpSection(
    title: '三种主题模式',
    accentColor: AppTheme.softOrange,
    items: [
      HelpTable(headers: ['模式', '说明'], rows: [
        ['亮色 ☀️', '浅色背景，适合白天阅读'],
        ['暗色 🌙', '深色背景，暗光环境下更护眼'],
        ['跟随系统 ⚙️', '根据设备的系统主题设置自动切换'],
      ]),
      HelpParagraph('选择后即时生效，页面提供实时预览区域展示效果。'),
    ],
  ),
];
