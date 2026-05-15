import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../core/theme/app_theme.dart';

class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key});

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  String _markdownData = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    try {
      final data = await rootBundle.loadString('docs/USER_GUIDE.md');
      if (mounted) {
        setState(() {
          _markdownData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('使用教程'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.appBarGradientOf(context),
          ),
        ),
      ),
      body: Container(
        decoration: AppTheme.gradientBoxOf(context),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryOf(context)))
              : _markdownData.isEmpty
                  ? Center(
                      child: Text(
                        '教程加载失败，请稍后重试',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.onSurfaceOf(context)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : Markdown(
                      data: _markdownData,
                      padding: const EdgeInsets.all(16),
                      styleSheet: MarkdownStyleSheet(
                        h1: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurfaceOf(context),
                        ),
                        h2: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryOf(context),
                        ),
                        h3: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurfaceOf(context),
                        ),
                        p: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: AppTheme.onSurfaceOf(context),
                        ),
                        listBullet: TextStyle(
                          fontSize: 15,
                          color: AppTheme.primaryOf(context),
                        ),
                        tableHead: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.onSurfaceOf(context),
                        ),
                        tableBody: TextStyle(
                            fontSize: 14, color: AppTheme.onSurfaceOf(context)),
                        blockquote: TextStyle(
                          fontSize: 14,
                          color: AppTheme.onSurfaceOf(context)
                              .withValues(alpha: 0.6),
                          height: 1.5,
                        ),
                        code: TextStyle(
                          fontSize: 13,
                          backgroundColor: AppTheme.cardOf(context),
                        ),
                        strong: const TextStyle(fontWeight: FontWeight.w700),
                        em: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      builders: {
                        'blockquote': _BlockquoteBuilder(),
                      },
                    ),
        ),
      ),
    );
  }
}

class _BlockquoteBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    _,
    __,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.calmBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.calmBlue.withValues(alpha: 0.25)),
      ),
      child: MarkdownBody(
        data: element.textContent,
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(fontSize: 14, color: AppTheme.mutedOf(context)),
        ),
      ),
    );
  }
}
