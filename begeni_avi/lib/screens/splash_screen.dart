import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import '../widgets/fx.dart';

/// Açılış animasyonu: ortada yazı belirir, konfeti patlar, sonra uygulama açılır.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});
  final Widget next;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _boom = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _boom = true);
      HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, _, _) => widget.next,
          transitionsBuilder: (_, a, _, child) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
              scale: Tween(begin: 1.06, end: 1.0).animate(a),
              child: child,
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Pop(
                  delay: const Duration(milliseconds: 150),
                  from: 0.1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // TikTok tarzı renk kayması
                      Transform.translate(
                        offset: const Offset(-4, -3),
                        child: const _Title(color: AppColors.cyan),
                      ),
                      Transform.translate(
                        offset: const Offset(4, 3),
                        child: const _Title(color: AppColors.pink),
                      ),
                      const _Title(color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_boom) const Positioned.fill(child: ConfettiBurst(count: 140)),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'DEHŞET VAHŞET\nANADOLU ATEŞİ',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 40,
        height: 1.05,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
        color: color,
      ),
    );
  }
}
