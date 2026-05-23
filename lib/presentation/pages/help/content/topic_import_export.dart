import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../help_content_data.dart';

final importExportSections = <HelpSection>[
  HelpSection(
    title: '导出绘本',
    accentColor: AppTheme.softOrange,
    items: [
      HelpParagraph('将绘本打包为 .ddb 文件：'),
      HelpBulletList([
        '方式一：长按绘本卡片 → 选择"导出" → 通过系统分享菜单发送',
        '方式二：编辑页面 → 点击分享图标或保存图标',
      ]),
    ],
  ),
  HelpSection(
    title: '导入绘本',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpNumberedList([
        '在书架首页点击导航栏文件导入图标',
        '在文件选择器中选择 .ddb 或 .zip 文件',
        '应用自动解包并导入绘本',
        '如果书架中已有同名绘本，弹出对话框询问：',
      ]),
      HelpTable(headers: ['选项', '说明'], rows: [
        ['覆盖', '替换现有绘本'],
        ['新增', '重命名后导入（自动添加数字后缀）'],
        ['取消', '放弃导入'],
      ]),
    ],
  ),
  HelpSection(
    title: '.ddb 文件说明',
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpBulletList([
        '格式：ZIP 压缩包，包含绘本图片、封面和元数据',
        '内容：完整的绘本页面、文字方块位置和内容',
        '兼容性：iOS ↔ Android 完全互通',
        '图片质量不受压缩影响（原图保存）',
      ]),
    ],
  ),
  HelpSection(
    accentColor: AppTheme.sweetPink,
    items: [
      HelpWarning('导入的文件必须是 .ddb 或 .zip 格式。'),
    ],
  ),
];
