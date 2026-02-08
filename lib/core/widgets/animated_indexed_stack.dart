import 'package:flutter/material.dart';

/// A replacement for [IndexedStack] that animates transitions between children
/// while preserving their state.
class AnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 250),
  });

  @override
  State<AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.children.length, (i) {
      return AnimationController(
        vsync: this,
        duration: widget.duration,
        value: i == widget.index ? 1.0 : 0.0,
      );
    });
  }

  @override
  void didUpdateWidget(AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _controllers[oldWidget.index].reverse();
      _controllers[widget.index].forward();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(widget.children.length, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (context, child) {
            final value = _controllers[i].value;
            // Use Offstage to hide completely invisible widgets for performance
            return Offstage(
              offstage: value == 0,
              child: Opacity(
                opacity: value,
                // Use IgnorePointer to prevent interaction with fading-out widgets
                child: IgnorePointer(
                  ignoring: i != widget.index,
                  child: child,
                ),
              ),
            );
          },
          child: widget.children[i],
        );
      }),
    );
  }
}
