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
        '点击"创建第一个读本"按钮（书架为空时），或右下角橙色"+"悬浮按钮',
        '在弹出的对话框中输入绘本名称（如"My First Book"），点击"创建"',
        '从相册选择绘本页面图片，进入页面编辑器',
        '页面编辑器自动运行 OCR 识别，图片上出现彩色文字方块',
        '根据需要编辑文字块（请参考"文字识别与 AI"主题），点击右上角保存图标',
        '返回书架，点击绘本卡片开始阅读',
      ]),
    ],
  ),
  HelpSection(
    title: '编辑页面',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpParagraph('OCR 识别完成后，进入页面编辑器：'),
      HelpBulletList([
        '点击文字方块选中，拖动调整位置；拖动手柄调整大小',
        '选中后底部工具栏显示"编辑""试听""删除""AI强化"按钮',
        '点击"新建块"在图片上绘制新的文字识别区域',
        '点击右上角表格图标查看所有文字块的列表视图',
        '点击右上角保存图标，保存修改并返回书架',
      ]),
    ],
  ),
  HelpSection(
    title: '编辑读本',
    accentColor: AppTheme.softOrange,
    items: [
      HelpParagraph('长按书架上的绘本卡片，选择"编辑"，进入编辑读本页面：'),
      HelpBulletList([
        '修改读本名称，点击右侧保存按钮',
        '修改封面图片：可选择使用第一页作为封面，或自定义图片',
        '页面列表显示所有页面缩略图、页码和文字块数量',
        '点击页面进入页面编辑器，修改文字块',
        '长按页面右侧拖动手柄，拖拽调整页面顺序',
        '点击"添加页面"新增页面，点击删除图标移除页面',
      ]),
    ],
  ),
  HelpSection(
    title: '开始点读',
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpNumberedList([
        '返回书架，点击刚创建的绘本卡片',
        '进入阅读模式，点击页面上的橙色文字方块即可听到朗读',
      ]),
    ],
  ),
  HelpSection(
    title: '新建绘本（已有一本以上时）',
    accentColor: AppTheme.softOrange,
    items: [
      HelpNumberedList([
        '点击右下角橙色"+"悬浮按钮',
        '输入绘本名称，点击"创建"',
        '从相册选择图片，进入页面编辑器',
        '编辑完成后保存，返回书架',
      ]),
    ],
  ),
  HelpSection(
    title: '书架操作',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpParagraph('长按绘本卡片弹出操作菜单，包含以下选项：'),
      HelpTable(headers: ['操作', '方法'], rows: [
        ['打开阅读', '点击绘本卡片'],
        ['编辑读本', '长按 → 选择"编辑" → 进入编辑读本页面'],
        ['分享绘本', '长按 → 选择"分享" → 通过系统分享发送 .ddb 文件'],
        ['保存到手机', '长按 → 选择"保存到手机" → 保存到下载目录'],
        ['删除读本', '长按 → 选择"删除读本" → 确认删除'],
        ['导入绘本', '点击导航栏文件导入图标 → 选择 .ddb 或 .zip 文件'],
      ]),
    ],
  ),
];
