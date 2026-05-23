import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'content/topic_getting_started.dart';
import 'content/topic_reading.dart';
import 'content/topic_nfc.dart';
import 'content/topic_ocr_ai.dart';
import 'content/topic_voice.dart';
import 'content/topic_appearance.dart';
import 'content/topic_import_export.dart';
import 'content/topic_privacy.dart';
import 'content/topic_faq.dart';

class HelpTopic {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<HelpSection> sections;

  const HelpTopic({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.sections,
  });
}

class HelpSection {
  final String? title;
  final IconData? icon;
  final Color? accentColor;
  final List<HelpItem> items;

  const HelpSection({
    this.title,
    this.icon,
    this.accentColor,
    this.items = const [],
  });
}

sealed class HelpItem {
  const HelpItem();
}

class HelpParagraph extends HelpItem {
  final String text;
  const HelpParagraph(this.text);
}

class HelpBulletList extends HelpItem {
  final List<String> items;
  const HelpBulletList(this.items);
}

class HelpNumberedList extends HelpItem {
  final List<String> items;
  const HelpNumberedList(this.items);
}

class HelpTable extends HelpItem {
  final List<String> headers;
  final List<List<String>> rows;
  const HelpTable({required this.headers, required this.rows});
}

class HelpWarning extends HelpItem {
  final String text;
  const HelpWarning(this.text);
}

class HelpTip extends HelpItem {
  final String text;
  const HelpTip(this.text);
}

class HelpImagePlaceholder extends HelpItem {
  final String description;
  const HelpImagePlaceholder(this.description);
}

final List<HelpTopic> helpTopics = [
  HelpTopic(
    id: 'getting-started',
    title: '快速开始',
    subtitle: '首次使用、创建读本',
    icon: Icons.rocket_launch_rounded,
    color: AppTheme.gentleGreen,
    sections: gettingStartedSections,
  ),
  HelpTopic(
    id: 'reading',
    title: '阅读模式',
    subtitle: '点读文字、页面导航、NFC 快捷播放',
    icon: Icons.menu_book_rounded,
    color: AppTheme.softOrange,
    sections: readingSections,
  ),
  HelpTopic(
    id: 'nfc',
    title: 'NFC 功能',
    subtitle: '标签绑定、读取、iOS 与 Android 对比',
    icon: Icons.nfc_rounded,
    color: AppTheme.honeyYellow,
    sections: nfcSections,
  ),
  HelpTopic(
    id: 'ocr-ai',
    title: '文字识别与 AI',
    subtitle: 'OCR 识别、AI 强化、结果表格',
    icon: Icons.document_scanner_rounded,
    color: AppTheme.calmBlue,
    sections: ocrAiSections,
  ),
  HelpTopic(
    id: 'voice',
    title: '语音设置',
    subtitle: '三引擎对比、音色选择、语速调节',
    icon: Icons.record_voice_over_rounded,
    color: AppTheme.sweetPink,
    sections: voiceSections,
  ),
  HelpTopic(
    id: 'appearance',
    title: '外观设置',
    subtitle: '亮色、暗色、跟随系统主题',
    icon: Icons.palette_rounded,
    color: AppTheme.lavender,
    sections: appearanceSections,
  ),
  HelpTopic(
    id: 'import-export',
    title: '绘本导入/导出',
    subtitle: 'ddb 格式跨设备分享',
    icon: Icons.import_export_rounded,
    color: AppTheme.gentleGreen,
    sections: importExportSections,
  ),
  HelpTopic(
    id: 'privacy',
    title: '费用、隐私与平台',
    subtitle: 'AI 费用说明、网络隐私',
    icon: Icons.shield_rounded,
    color: AppTheme.calmBlue,
    sections: privacySections,
  ),
  HelpTopic(
    id: 'faq',
    title: '常见问题',
    subtitle: '16 个常见问题解答',
    icon: Icons.help_outline_rounded,
    color: AppTheme.softOrange,
    sections: faqSections,
  ),
];
