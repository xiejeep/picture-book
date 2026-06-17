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
        '进入页面编辑器后自动运行 OCR，图片上显示彩色矩形方块',
        '页面顶部出现"处理中..."提示条',
        '中文文字方块会被自动过滤，仅保留英文',
      ]),
    ],
  ),
  HelpSection(
    title: '页面编辑操作',
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpParagraph('页面编辑器将查看、选择、编辑、绘制集成在一个画布中：'),
      HelpBulletList([
        '点击文字方块选中（橙色高亮边框），点击空白处取消选中',
        '选中后拖动方块移动位置；拖动 8 个白色手柄调整大小',
        '双指捏合缩放（0.5x~4x），单指拖动平移（缩放状态下）',
        '点击底部工具栏"新建块"进入绘制模式，在画布上拖动绘制新的文字区域',
        '绘制完成后自动弹出编辑对话框，输入文字内容',
      ]),
    ],
  ),
  HelpSection(
    title: '底部工具栏',
    accentColor: AppTheme.honeyYellow,
    items: [
      HelpParagraph('页面底部黑色工具栏，分为两排：'),
      HelpTable(headers: ['区域', '按钮', '功能'], rows: [
        ['上排（始终显示）', '放大/缩小', '缩放画布显示'],
        ['', '适应', '重置缩放，适配屏幕'],
        ['下排（未选中）', '新建块', '进入绘制模式，手动添加文字区域'],
        ['', '重新OCR', '清除所有文字块并重新识别'],
        ['', '全部AI强化', '对所有文字块运行 AI 强化识别'],
        ['下排（已选中）', '编辑', '打开编辑对话框修改文字内容'],
        ['', '试听', '朗读选中文字块的内容'],
        ['', '删除', '删除选中文字块'],
        ['', 'AI强化', '仅对选中文字块运行 AI 强化'],
      ]),
    ],
  ),
  HelpSection(
    title: '编辑文字内容',
    accentColor: AppTheme.sweetPink,
    items: [
      HelpBulletList([
        '选中文字方块后，点击底部工具栏"编辑"按钮打开编辑对话框',
        '可直接修改文字内容',
        '"重新识别此区域"可重新对该区域单独运行 OCR',
        '点击"确定"确认修改',
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
      HelpParagraph('支持全部强化和选中单个强化：'),
      HelpBulletList([
        '全部强化：底部工具栏"全部AI强化"按钮',
        '选中强化：选中文字块后，底部工具栏"AI强化"按钮，或右上角菜单"AI强化此区域"',
      ]),
    ],
  ),
  HelpSection(
    title: 'AppBar 操作菜单',
    accentColor: AppTheme.lavender,
    items: [
      HelpParagraph('页面右上角更多菜单提供以下操作：'),
      HelpBulletList([
        '选择 AI 模型 — 切换 AI 强化使用的模型（免费/付费）',
        '语音设置 — 跳转到语音设置页面，调整朗读引擎和语速',
        'AI强化此区域 — 选中文字块后出现，仅强化当前选中块',
      ]),
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
        ['编辑翻译', '点击该行翻译区域'],
        ['播放朗读', '点击行内的"播放"按钮'],
        ['删除方块', '向左滑动该行 → 点击"删除"'],
        ['全部 AI 强化', '返回编辑器，点击底部工具栏"全部AI强化"'],
        ['全部 AI 翻译', '点击底部"全部AI翻译"按钮'],
      ]),
    ],
  ),
];
