import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'platform_utils.dart';

class ToastUtil {
  static BuildContext? _context;

  static void init(BuildContext context) {
    _context = context;
  }

  static void show(
    String message, {
    Color? backgroundColor,
    Color textColor = Colors.white,
    ToastGravity gravity = ToastGravity.BOTTOM,
    int duration = 4,
    double fontSize = 18.0,
  }) {
    if (PlatformUtils.isDesktop) {
      _showDesktopToast(
        message,
        backgroundColor: backgroundColor ?? Colors.black87,
        textColor: textColor,
        fontSize: fontSize,
        durationSeconds: duration,
      );
    } else {
      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: gravity,
        timeInSecForIosWeb: duration,
        backgroundColor: backgroundColor ?? Colors.black87,
        textColor: textColor,
        fontSize: fontSize,
      );
    }
  }

  static void _showDesktopToast(
    String message, {
    required Color backgroundColor,
    required Color textColor,
    required double fontSize,
    required int durationSeconds,
  }) {
    final ctx = _context;
    if (ctx == null) return;

    final overlay = Overlay.of(ctx, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _DesktopToast(
        message: message,
        backgroundColor: backgroundColor,
        textColor: textColor,
        fontSize: fontSize,
      ),
    );

    overlay.insert(entry);

    Future.delayed(Duration(seconds: durationSeconds), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  static void success(String message) {
    show(message, backgroundColor: Colors.green.shade600);
  }

  static void error(String message) {
    show(message, backgroundColor: const Color(0xFFDC2626));
  }

  static void warning(String message) {
    show(message, backgroundColor: Colors.orange.shade600);
  }

  static void info(String message) {
    show(message, backgroundColor: Colors.blue.shade600);
  }
}

class _DesktopToast extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;

  const _DesktopToast({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.fontSize,
  });

  @override
  State<_DesktopToast> createState() => _DesktopToastState();
}

class _DesktopToastState extends State<_DesktopToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.message,
                style: TextStyle(
                  color: widget.textColor,
                  fontSize: widget.fontSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
