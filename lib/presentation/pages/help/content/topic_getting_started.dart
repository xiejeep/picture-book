import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../help_content_data.dart';

final gettingStartedSections = <HelpSection>[
  HelpSection(
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpParagraph('启动应用后进入书架首页。首次使用时书架为空，页面中央显示引导提示。'),
    ],
  ),
  HelpSection(
    title: '创建第一本读本',
    accentColor: AppTheme.softOrange,
    items: [
      HelpNumberedList([
        '点击页面中央的"创建第一个读本"按钮，或右下角橙色"+"悬浮按钮',
        '在弹出的对话框中输入绘本名称（如"My First Book"）',
        '点击"创建"',
      ]),
    ],
  ),
  HelpSection(
    title: '添加页面并识别文字',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpParagraph('创建后会自动进入文字识别页面：'),
      HelpNumberedList([
        '选择"从相册选择"或"拍照"获取绘本页面图片',
        '可选择裁剪图片（支持自由裁剪、4:3、16:9 等比例）',
        '应用自动运行 OCR 识别，完成后页面上出现彩色文字方块',
        '点击右上角保存图标保存页面',
      ]),
    ],
  ),
  HelpSection(
    title: '开始点读',
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpNumberedList([
        '返回书架，点击刚创建的绘本卡片',
        '进入阅读模式，点击页面上的文字方块即可听到朗读',
      ]),
    ],
  ),
  HelpSection(
    title: '新建绘本',
    accentColor: AppTheme.softOrange,
    items: [
      HelpNumberedList([
        '在书架首页，点击右下角橙色"+"悬浮按钮',
        '在弹出的对话框中输入绘本名称',
        '点击"创建"，系统自动创建并跳转到第一页的文字识别页面',
      ]),
    ],
  ),
  HelpSection(
    title: '书架操作',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpTable(headers: ['操作', '方法'], rows: [
        ['打开阅读', '点击绘本卡片'],
        ['编辑绘本', '长按绘本卡片 → 选择"编辑"'],
        ['删除绘本', '长按绘本卡片 → 选择"删除读本" → 确认删除'],
        ['导出绘本', '长按绘本卡片 → 选择"导出" → 分享或保存'],
        ['导入绘本', '点击导航栏文件导入图标 → 选择 .ddb 文件'],
      ]),
    ],
  ),
];
