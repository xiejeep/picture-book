import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../help_content_data.dart';

final ocrAiSections = <HelpSection>[
  HelpSection(
    title: '选择图片',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpTable(headers: ['按钮', '功能'], rows: [
        ['从相册选择', '打开系统相册，选择已有图片'],
        ['拍照', '打开相机，拍摄绘本页面'],
      ]),
      HelpParagraph('选择图片后可裁剪（支持自由裁剪、正方形、4:3、16:9 等比例）。'),
    ],
  ),
  HelpSection(
    title: '自动 OCR 识别',
    accentColor: AppTheme.softOrange,
    items: [
      HelpBulletList([
        '页面顶部出现提示条："正在识别文字..."',
        '识别完成后图片上显示彩色矩形方块',
        '中文文字方块会被自动过滤，仅保留英文',
      ]),
    ],
  ),
  HelpSection(
    title: '三种操作模式',
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpParagraph('查看模式（默认）：平移图片、缩放、选择文字方块（选中后橙色高亮）。'),
      HelpParagraph('绘制模式：拖动手指绘制矩形区域，手动添加遗漏的文字识别区域。'),
      HelpParagraph('编辑模式：选中文字方块后可调整大小（8 个手柄）、移动位置、试听、编辑内容、删除。'),
    ],
  ),
  HelpSection(
    title: '编辑文字内容',
    accentColor: AppTheme.sweetPink,
    items: [
      HelpBulletList([
        '点击"编辑"按钮或双击文字方块打开编辑对话框',
        '可直接修改文字内容',
        '"识别此区域"可重新对该区域单独运行 OCR',
        '点击"保存"确认修改',
      ]),
    ],
  ),
  HelpSection(
    title: 'AI 强化识别',
    accentColor: AppTheme.lavender,
    items: [
      HelpParagraph('AI 强化使用智谱 AI 视觉大模型，自动清理 OCR 识别结果中的干扰内容。'),
      HelpTable(headers: ['处理项', '示例'], rows: [
        ['去除音标符号', '/ˈpɪkæks/ → 删除'],
        ['去除编号标记', '1. 2. (3) → 删除'],
        ['去除 OCR 噪点', '乱码字符 → 删除'],
        ['去除中文字符', '中文内容 → 删除'],
        ['合并不必要换行', '句中换行 → 连接'],
      ]),
      HelpTip('需要先在「设置 → AI 设置」中配置 API Key。免费模型 GLM-4V-Flash 即可满足需求。'),
    ],
  ),
  HelpSection(
    title: 'OCR 结果表格',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpParagraph('点击导航栏中的表格图标打开，提供所有文字方块的列表视图。'),
      HelpTable(headers: ['功能', '操作'], rows: [
        ['查看原文/AI 结果', '点击"使用原文"或"使用AI结果"切换'],
        ['编辑文字', '点击该行文字区域'],
        ['播放朗读', '点击行内的"播放"按钮'],
        ['删除方块', '向左滑动该行 → 点击"删除"'],
        ['全部 AI 强化', '点击导航栏"AI强化全部"按钮'],
      ]),
    ],
  ),
];
