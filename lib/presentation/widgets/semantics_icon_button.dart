import 'package:flutter/material.dart';

class SemanticsIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? hint;
  final double size;
  final Color? color;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry? padding;

  const SemanticsIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.hint,
    this.size = 24,
    this.color,
    this.onPressed,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint ?? '点击执行操作',
      button: true,
      child: IconButton(
        icon: Icon(icon, size: size, color: color),
        onPressed: onPressed,
        tooltip: label,
        padding: padding ?? EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}