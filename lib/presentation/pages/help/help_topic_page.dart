import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'help_content_data.dart';

class HelpTopicPage extends StatelessWidget {
  final String topicId;

  const HelpTopicPage({super.key, required this.topicId});

  @override
  Widget build(BuildContext context) {
    final topic = helpTopics.firstWhere(
      (t) => t.id == topicId,
      orElse: () => helpTopics.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(topic.title),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.appBarGradientOf(context),
          ),
        ),
      ),
      body: Container(
        decoration: AppTheme.gradientBoxOf(context),
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: topic.sections.length,
            itemBuilder: (context, index) {
              return _buildSection(context, topic.sections[index]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, HelpSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: AppTheme.playfulCardDecorationOf(context),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (section.title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: (section.accentColor ?? AppTheme.primaryOf(context))
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        section.icon ?? Icons.circle_rounded,
                        size: 16,
                        color: section.accentColor ?? AppTheme.primaryOf(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        section.title!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurfaceOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ...section.items.map((item) => _buildItem(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, HelpItem item) {
    switch (item) {
      case HelpParagraph(text: final text):
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.85),
            ),
          ),
        );
      case HelpBulletList(items: final items):
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AppTheme.primaryOf(context).withValues(alpha: 0.6),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        );
      case HelpNumberedList(items: final items):
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${entry.key + 1}.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryOf(context),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        );
      case HelpTable(headers: final headers, rows: final rows):
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Table(
              border: TableBorder.all(
                color: AppTheme.isDarkMode(context)
                    ? AppTheme.darkCard
                    : AppTheme.softGray.withValues(alpha: 0.3),
              ),
              columnWidths: headers.asMap().map((i, _) {
                final widths = headers.length == 2
                    ? const {0: FlexColumnWidth(2), 1: FlexColumnWidth(3)}
                    : headers.length == 3
                        ? const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2.5), 2: FlexColumnWidth(2.5)}
                        : headers.length == 4
                            ? const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(2.5)}
                            : <int, FlexColumnWidth>{};
                return MapEntry(i, widths[i] ?? const FlexColumnWidth(1));
              }),
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOf(context).withValues(alpha: 0.08),
                  ),
                  children: headers.map((h) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Text(
                      h,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurfaceOf(context),
                      ),
                    ),
                  )).toList(),
                ),
                ...rows.map((row) => TableRow(
                  children: row.map((cell) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(
                      cell,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.onSurfaceOf(context).withValues(alpha: 0.85),
                      ),
                    ),
                  )).toList(),
                )),
              ],
            ),
          ),
        );
      case HelpWarning(text: final text):
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.errorOf(context).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 18,
                    color: AppTheme.errorOf(context).withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.errorOf(context).withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case HelpTip(text: final text):
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.calmBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_rounded, size: 18,
                    color: AppTheme.calmBlue.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.calmBlue.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case HelpImagePlaceholder(description: final desc):
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '📸 $desc',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.mutedOf(context),
                ),
              ),
            ),
          ),
        );
    }
  }
}
