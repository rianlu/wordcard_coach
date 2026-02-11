import 'dart:async';
import 'dart:math';
import 'dart:ui'; // 逻辑处理
import 'package:flutter/material.dart';

class MeshGradientBackground extends StatefulWidget {
  const MeshGradientBackground({super.key});

  @override
  State<MeshGradientBackground> createState() => _MeshGradientBackgroundState();
}

class _MeshGradientBackgroundState extends State<MeshGradientBackground> {
  // 逻辑处理
  final List<Color> _colors = [
    const Color(0xFFE0F2FE), // 配色
    const Color(0xFFF3E8FF), // 配色
    const Color(0xFFECFCCB), // 配色
    const Color(0xFFFCE7F3), // 配色
  ];

  final Random _random = Random();
  late List<Alignment> _alignments;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 逻辑处理
    _alignments = List.generate(
      _colors.length, 
      (_) => Alignment(
        _random.nextDouble() * 2 - 1, 
        _random.nextDouble() * 2 - 1
      )
    );
    
    // 逻辑处理
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimation();
    });
  }

  void _startAnimation() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
         // 逻辑处理
         for (int i = 0; i < _alignments.length; i++) {
           _alignments[i] = Alignment(
             _random.nextDouble() * 2 - 1, 
             _random.nextDouble() * 2 - 1
           );
         }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // 配色
      child: Stack(
        children: [
          // 逻辑处理
          ...List.generate(_colors.length, (index) {
             return AnimatedAlign(
               duration: const Duration(seconds: 4),
               curve: Curves.easeInOut,
               alignment: _alignments[index],
               child: Container(
                 width: MediaQuery.of(context).size.width * 0.6,
                 height: MediaQuery.of(context).size.width * 0.6,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   color: _colors[index].withValues(alpha: 0.6),
                 ),
               ),
             );
          }),

          // 逻辑处理
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha: 0.3), // 配色
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60.0, sigmaY: 60.0),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
