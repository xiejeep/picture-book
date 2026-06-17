import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../help_content_data.dart';

final readingSections = <HelpSection>[
  HelpSection(
    title: '点读操作',
    accentColor: AppTheme.softOrange,
    items: [
      HelpBulletList([
        '点击页面上的橙色半透明文字方块，即可听到朗读',
        '正在朗读的文字方块显示红色焦点动画边框并带有弹跳效果',
        '加载中文字方块上显示旋转加载指示器',
        '底部朗读栏显示当前文字内容，带有停止/重播按钮和关闭按钮',
        '朗读时自动翻译当前文字（需 ML Kit 支持），翻译结果显示在朗读栏下方',
      ]),
    ],
  ),
  HelpSection(
    title: '页面导航',
    accentColor: AppTheme.calmBlue,
    items: [
      HelpParagraph('页面底部显示页码指示器（如"2 / 5"）。左右滑动切换页面，平滑翻页动画。'),
      HelpTable(headers: ['操作', '方法'], rows: [
        ['上一页/下一页', '左右滑动切换'],
        ['放大/缩小', '双指捏合缩放（适配屏幕到图片填满）'],
        ['拖动平移', '单指拖动（缩放状态下）'],
        ['适应屏幕', '双击图片恢复适应屏幕比例'],
      ]),
    ],
  ),
  HelpSection(
    title: '导航栏操作',
    accentColor: AppTheme.gentleGreen,
    items: [
      HelpTable(headers: ['操作', '方法'], rows: [
        ['显示/隐藏导航栏', '点击页面空白区域或双击页面'],
        ['语音设置', '点击导航栏中的语音图标，调整朗读语速'],
        ['显示/隐藏文字边框', '点击导航栏中的边框图标'],
        ['显示/隐藏翻译', '点击导航栏中的翻译图标（ML Kit 可用时）'],
        ['扫描 NFC 标签（iOS）', '点击导航栏中的 NFC 图标，靠近标签自动播放'],
      ]),
    ],
  ),
  HelpSection(
    title: '快速语音调节',
    accentColor: AppTheme.sweetPink,
    items: [
      HelpNumberedList([
        '点击导航栏中的语音图标',
        '弹窗顶部显示当前 TTS 引擎名称（系统 TTS / Supertonic）',
        '拖动滑块调整朗读速度，百分比即时显示',
        '不同引擎语速范围不同（系统 TTS：10%~100%，Supertonic：50%~200%）',
        '点击"更多设置"跳转到语音设置页面进行详细配置',
        '点击"确定"保存语速调整',
      ]),
    ],
  ),
  HelpSection(
    title: '长按菜单',
    accentColor: AppTheme.honeyYellow,
    items: [
      HelpParagraph('在阅读页面长按文字方块弹出操作菜单：'),
      HelpBulletList([
        '编辑文字 — 打开底部弹窗修改文字内容，支持 AI 自动纠正',
        '编辑翻译 — 打开底部弹窗修改翻译文本，支持 AI 自动翻译（需联网）',
        '绑定 NFC — 将当前文字块绑定到 NFC 标签（需开启 NFC 功能）',
      ]),
    ],
  ),
];
