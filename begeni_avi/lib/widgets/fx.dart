import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Ekrana ilk girdiğinde yaylanarak büyüyüp beliren widget.
class Pop extends StatelessWidget {
  const Pop({super.key, required this.child, this.delay = Duration.zero, this.from = 0.3});

  final Widget child;
  final Duration delay;
  final double from;

  @override
  Widget build(BuildContext context) {
    final total = delay + const Duration(milliseconds: 650);
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, t, child) {
        final local = t <= start ? 0.0 : (t - start) / (1 - start);
        final scale = from + (1 - from) * Curves.elasticOut.transform(local);
        return Opacity(
          opacity: Curves.easeOut.transform(local.clamp(0, 1)),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: child,
    );
  }
}

/// Aşağıdan kayarak beliren widget (listeler için kademeli giriş).
class SlideIn extends StatelessWidget {
  const SlideIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final total = delay + const Duration(milliseconds: 420);
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, t, child) {
        final local = Curves.easeOutCubic.transform(t <= start ? 0.0 : (t - start) / (1 - start));
        return Opacity(
          opacity: local,
          child: Transform.translate(offset: Offset(0, 24 * (1 - local)), child: child),
        );
      },
      child: child,
    );
  }
}

/// Yanlış cevapta sağa sola sallanır.
class Shake extends StatelessWidget {
  const Shake({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, t, child) {
        final dx = sin(t * pi * 8) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: child,
    );
  }
}

/// Sayıyı eski değerinden yenisine sayarak gösterir.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, this.style, this.prefix = ''});
  final int value;
  final TextStyle? style;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$prefix${v.round()}', style: style),
    );
  }
}

/// "+100" gibi yazıyı büyüterek gösterip yukarı doğru uçurur.
class FloatingGain extends StatelessWidget {
  const FloatingGain({super.key, required this.text, this.color = AppColors.green});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1800),
        builder: (context, t, _) {
          final rise = Curves.easeOutCubic.transform(t);
          final scale = t < 0.2 ? Curves.elasticOut.transform(t / 0.2) * 1.3 : 1.3 - 0.3 * ((t - 0.2) / 0.8);
          final opacity = t < 0.7 ? 1.0 : 1 - (t - 0.7) / 0.3;
          return Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(0, -90 * rise),
              child: Transform.scale(
                scale: scale,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    color: color,
                    shadows: const [Shadow(blurRadius: 18, color: Colors.black)],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tek seferlik konfeti patlaması.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.count = 70});
  final int count;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  late final List<_Particle> _ps;

  @override
  void initState() {
    super.initState();
    final r = Random();
    const colors = [AppColors.pink, AppColors.cyan, AppColors.yellow, AppColors.green, Colors.white];
    _ps = List.generate(widget.count, (_) {
      final angle = -pi / 2 + (r.nextDouble() - 0.5) * pi * 1.2;
      final speed = 500 + r.nextDouble() * 650;
      return _Particle(
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        spin: (r.nextDouble() - 0.5) * 14,
        size: 6 + r.nextDouble() * 7,
        color: colors[r.nextInt(colors.length)],
        round: r.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_ps, _c.value * 2.6), size: Size.infinite),
      ),
    );
  }
}

class _Particle {
  _Particle({required this.vx, required this.vy, required this.spin, required this.size, required this.color, required this.round});
  final double vx, vy, spin, size;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.ps, this.t);
  final List<_Particle> ps;
  final double t; // saniye

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.62);
    const g = 900.0;
    final fade = t < 1.8 ? 1.0 : (1 - (t - 1.8) / 0.8).clamp(0.0, 1.0);
    for (final p in ps) {
      final drag = 1 / (1 + t * 0.9);
      final pos = origin + Offset(p.vx * t * drag, p.vy * t * drag + 0.5 * g * t * t * 0.55);
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.45), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Sona yaklaştıkça rengi değişen, akıcı geri sayım halkası.
class CountdownRing extends StatefulWidget {
  const CountdownRing({super.key, required this.deadline, required this.totalMs, this.size = 54, this.color});

  final int deadline; // ms epoch
  final int totalMs;
  final double size;
  final Color? color;

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final left = (widget.deadline - DateTime.now().millisecondsSinceEpoch).clamp(0, widget.totalMs);
    _c.value = left / widget.totalMs;
    if (left > 0) _c.animateTo(0, duration: Duration(milliseconds: left));
  }

  @override
  void didUpdateWidget(CountdownRing old) {
    super.didUpdateWidget(old);
    if (old.deadline != widget.deadline) _start();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        final secs = (v * widget.totalMs / 1000).ceil();
        final urgent = secs <= 5 && widget.color == null;
        final color = widget.color ?? (urgent ? (secs <= 3 ? AppColors.pink : AppColors.yellow) : AppColors.cyan);
        final pulse = urgent ? 1 + 0.08 * sin(v * widget.totalMs / 1000 * pi * 2).abs() : 1.0;
        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(fit: StackFit.expand, children: [
              CircularProgressIndicator(
                value: v,
                strokeWidth: 5,
                color: color,
                backgroundColor: AppColors.card,
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Text('$secs',
                    style: TextStyle(fontSize: widget.size * 0.38, fontWeight: FontWeight.w900, color: color)),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Basılınca hafifçe küçülen, bırakınca yaylanan dokunma efekti.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
