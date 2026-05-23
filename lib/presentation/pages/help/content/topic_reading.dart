import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../help_content_data.dart';

final readingSections = <HelpSection>[
  HelpSection(
    title: '点读操作',
    accentColor: AppTheme.softOrange,
    items: [
      HelpBulletList([
        '点击页面上的绿色边框文字方块，即可听到朗读',
        '正在朗读的文字方块变为黄色高亮，底部显示朗读状态栏',
        '底部状态栏显示当前文字内容，带有停止按钮',
      ]),
    ],
  ),
  HelpSection(
    title: '页面导航',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpParagraph('页面底部显示页码指示器（如"2 / 5"）：'),
      HelpTable(headers: ['操作', '方法'], rows: [
        ['上一页', '点击左侧"◀"箭头'],
        ['下一页', '点击右侧"▶"箭头'],
      ]),
    ],
  ),
  HelpSection(
    title: '缩放与沉浸模式',
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpTable(headers: ['操作', '方法'], rows: [
        ['放大/缩小', '双指捏合缩放（支持 0.5x ~ 4x）'],
        ['拖动平移', '单指拖动（缩放状态下）'],
        ['显示/隐藏导航栏', '双击页面空白区域'],
        ['显示/隐藏文字边框', '点击导航栏中的边框图标'],
      ]),
    ],
  ),
  HelpSection(
    title: '快速语音调节',
    accentColor: AppTheme.sweetPink,
    items: [
      HelpNumberedList([
        '点击导航栏中的麦克风图标',
        '在语速调节面板中拖动滑块调整朗读速度',
        '当前语速以百分比显示（如"50%"）',
        '点击"更多设置"进入完整语音设置页面',
        '调整完毕点击"确定"保存',
      ]),
    ],
  ),
  HelpSection(
    title: 'NFC 标签点读',
    accentColor: AppTheme.honeyYellow,
    items: [
      HelpWarning('iOS 限制：iOS 系统不支持像 Android 那样的后台静默读取，必须手动点击按钮触发扫描。'),
      HelpParagraph('Android：将已绑定的 NFC 标签靠近手机背部，应用会自动打开对应绘本并开始朗读，即使应用未打开也能启动。'),
      HelpParagraph('iOS：进入绘本阅读页面 → 点击导航栏 NFC 图标 → 将标签靠近手机顶部 → 应用自动跳转并朗读。弹窗保持开启可继续扫描下一个标签。'),
    ],
  ),
  HelpSection(
    title: 'NFC 标签绑定',
    accentColor: AppTheme.honeyYellow,
    items: [
      HelpNumberedList([
        '确保 NFC 功能已在设置中开启',
        '在阅读模式下长按某个文字方块',
        '弹出"绑定 NFC 标签"对话框，点击"开始绑定"',
        '将空白 NFC 标签靠近手机背部',
        '绑定成功后显示成功提示',
      ]),
      HelpTip('推荐使用 NTAG215 空白标签（504 字节可用），性价比高。'),
    ],
  ),
];
