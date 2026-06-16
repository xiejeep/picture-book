import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../help_content_data.dart';

final voiceSections = <HelpSection>[
  HelpSection(
    title: '两种语音引擎对比',
    accentColor: AppTheme.softOrange,
    items: [
      HelpTable(headers: ['引擎', '网络', '平台', '推荐场景'], rows: [
        ['系统 TTS', '无需联网', 'iOS / Android', '最简单，离线可用'],
        ['Supertonic（本地）', '无需联网', 'iOS / Android', '免费离线 AI 语音'],
      ]),
    ],
  ),
  HelpSection(
    title: '系统 TTS',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpBulletList([
        '使用设备自带的语音引擎，离线可用',
        '语速范围：10% ~ 100%（7 档）',
        '无需配置 API Key',
        '移动端可用',
      ]),
    ],
  ),
  HelpSection(
    title: 'Supertonic 本地语音',
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpBulletList([
        '使用设备端 AI 模型进行离线语音合成',
        '完全离线，无需联网，无需 API Key',
        '语速范围：50% ~ 200%（30 档）',
        '支持扩散步数调节（1~20，默认 8）',
        '步数越高音质越好但生成速度越慢',
        '仅移动端可用（iOS / Android）',
      ]),
      HelpParagraph('10 种音色：男声 M1~M5（默认 M1），女声 F1~F5。'),
    ],
  ),
  HelpSection(
    title: '如何选择',
    accentColor: AppTheme.honeyYellow,
    items: [
      HelpTable(headers: ['场景', '推荐引擎'], rows: [
        ['完全离线使用', 'Supertonic 或 系统 TTS'],
        ['追求最佳音质', 'Supertonic（免费离线 AI 语音）'],
        ['考虑到费用', 'Supertonic（免费离线，音质优于系统 TTS）'],
        ['保存电量', '系统 TTS（最轻量）'],
      ]),
    ],
  ),
];
