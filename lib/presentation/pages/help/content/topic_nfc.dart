import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../help_content_data.dart';

final nfcSections = <HelpSection>[
  HelpSection(
    title: 'NFC 功能开关',
    accentColor: AppTheme.honeyYellow,
    items: [
      HelpBulletList([
        '进入设置页面（书架右上角齿轮图标）',
        '在"设备功能"区域找到 NFC 功能开关',
        '开启后阅读页面出现 NFC 相关按钮',
        '关闭后所有 NFC 功能将被禁用',
      ]),
      HelpTip('NFC 开关仅在支持 NFC 的设备上显示。'),
    ],
  ),
  HelpSection(
    title: 'NFC 标签绑定（写入）',
    accentColor: AppTheme.softOrange,
    items: [
      HelpNumberedList([
        '确保 NFC 功能已开启',
        '在阅读模式下，长按某个文字方块',
        '弹出对话框显示要绑定的文字内容，点击"开始绑定"',
        '手机弹出 NFC 写入提示',
        '将空白 NFC 标签贴近手机背部 NFC 感应区域',
        '写入成功后对话框自动关闭',
      ]),
      HelpParagraph('支持的标签类型：ISO 14443（NFC-A）和 ISO 15693（NFC-V）格式的 NDEF 兼容标签。'),
      HelpWarning('写入失败常见原因：\n• 标签不支持 NDEF 格式\n• 标签已写保护（只读）\n• 标签存储空间不足'),
    ],
  ),
  HelpSection(
    title: 'Android 端读取',
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpTable(headers: ['模式', '说明'], rows: [
        ['后台读取', '即使应用未打开，靠近标签即可自动启动应用并跳转'],
        ['前台读取', '应用在前台时自动持续监听 NFC 标签，无需手动操作'],
      ]),
      HelpTip('Android 端体验最流畅：靠近标签 → 自动播放，全程无感。'),
    ],
  ),
  HelpSection(
    title: 'iOS 端读取',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpNumberedList([
        '进入绘本阅读页面',
        '点击导航栏中的 NFC 图标按钮',
        '系统弹出扫描提示',
        '将标签靠近手机顶部背部',
        '应用自动跳转并朗读，弹窗保持开启',
        '可继续扫描下一个标签，或手动关闭',
      ]),
    ],
  ),
  HelpSection(
    title: 'iOS 与 Android 核心区别',
    accentColor: AppTheme.sweetPink,
    items: [
      HelpTable(headers: ['特性', 'Android', 'iOS'], rows: [
        ['后台自动启动', '✅ 支持', '❌ 不支持'],
        ['需手动触发', '❌ 不需要', '✅ 需点击按钮'],
        ['系统弹窗', '无', '有（无法隐藏）'],
        ['连续扫描', '自动持续', '手动开启后可持续'],
      ]),
      HelpWarning('iOS 系统的 NFC 弹窗无法隐藏，这是苹果系统层面的安全限制。'),
    ],
  ),
  HelpSection(
    title: '标签选择建议',
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpBulletList([
        'NTAG215（504 字节可用）：性价比高，适合大多数场景',
        'NTAG216（888 字节可用）：空间更大',
        '标签应为 NDEF 可写格式',
        '建议购买空白标签',
      ]),
    ],
  ),
];
