import 'package:flutter/material.dart';

/// "" 3/实体阴影效果
/// 逻辑处理
class BubblyButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color color;
  final Color shadowColor;
  final double borderRadius;
  final EdgeInsets padding;
  final double shadowHeight;

  const BubblyButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color = Colors.blue,
    this.shadowColor = Colors.blueAccent, // 逻辑处理
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(16),
    this.shadowHeight = 6.0,
  });

  @override
  State<BubblyButton> createState() => _BubblyButtonState();
}

class _BubblyButtonState extends State<BubblyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            // 逻辑处理
            BoxShadow(
              color: widget.shadowColor,
              offset: Offset(0, _isPressed ? 0 : widget.shadowHeight),
              blurRadius: 0,
            ),
          ],
        ),
        transform: Matrix4.translationValues(0, _isPressed ? widget.shadowHeight : 0, 0),
        child: widget.child,
      ),
    );
  }
}
