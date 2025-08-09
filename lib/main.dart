import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // für Ticker

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GamePage(),
    ));

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final Random _rng = Random();

  // Spielzustand
  double _elapsed = 0;
  int _score = 0;
  int _lives = 3;

  // Entities
  final List<_Jelly> _jellies = [];
  final List<_Bullet> _bullets = [];
  final List<_Laser> _lasers = [];

  // Spawning/Schwierigkeit (entschärft)
  double _spawnTimer = 0;
  double _spawnInterval = 1.6; // am Anfang gemütlicher
  int _maxJellies = 5;         // nicht zu viele gleichzeitig

  Size? _lastSize;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration dt) {
    final dtSec = dt.inMicroseconds / 1e6;
    _elapsed += dtSec;
    _spawnTimer += dtSec;

    // Schwierigkeit langsamer anziehen
    if (_elapsed > 20) {
      _spawnInterval = 1.2;
      _maxJellies = 6;
    }
    if (_elapsed > 40) {
      _spawnInterval = 1.0;
      _maxJellies = 7;
    }
    if (_elapsed > 70) {
      _spawnInterval = 0.85;
      _maxJellies = 8;
    }

    // Spawnen (nur bis _maxJellies)
    if (_spawnTimer >= _spawnInterval && _jellies.length < _maxJellies) {
      _spawnTimer = 0;
      final size = _lastSize ?? const Size(400, 800);
      final x = _rng.nextDouble() * (size.width - 60) + 30;
      _jellies.add(
        _Jelly(
          x: x,
          y: -40,
          speed: 28 + _rng.nextDouble() * 22, // VIEL langsamer
        ),
      );
    }

    // Bewegung
    for (final j in _jellies) {
      j.y += j.speed * dtSec;
      j.wave += dtSec * 3.2;
      j.tentacleWiggle += dtSec * 5;
    }
    for (final b in _bullets) {
      b.x += b.vx * b.speed * dtSec;
      b.y += b.vy * b.speed * dtSec;
    }
    for (final l in _lasers) {
      l.timeLeft -= dtSec;
    }

    // Laser-Kollision (breiter Strahl)
    for (final l in _lasers) {
      if (l.timeLeft <= 0) continue;
      for (final j in _jellies) {
        if (j.dead) continue;
        if (_pointToSegmentDistance(
                Offset(j.x, j.y), l.from, l.to) <
            26) {
          j.dead = true;
          _score += 10;
        }
      }
    }

    // Bullet-Kollision
    for (final b in _bullets) {
      for (final j in _jellies) {
        if (!j.dead &&
            (Offset(b.x, b.y) - Offset(j.x, j.y)).distance < 26) {
          j.dead = true;
          b.hit = true;
          _score += 10;
          break;
        }
      }
    }

    // Aufräumen
    _jellies.removeWhere((j) => j.dead);
    _bullets.removeWhere(
        (b) => b.hit || b.y < -60 || b.y > (_lastSize?.height ?? 9999) + 60);
    _lasers.removeWhere((l) => l.timeLeft <= 0);

    // Leben verlieren, wenn Jelly unten ankommt
    final size = _lastSize;
    if (size != null) {
      final escaped = _jellies.where((j) => j.y > size.height + 24).toList();
      if (escaped.isNotEmpty) {
        _jellies.removeWhere((j) => escaped.contains(j));
        _lives -= escaped.length;
        if (_lives <= 0) _gameOver();
      }
    }

    setState(() {});
  }

  void _gameOver() {
    _ticker.stop();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Game Over'),
        content: Text('Score: $_score'),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _restart();
              },
              child: const Text('Restart')),
        ],
      ),
    );
  }

  void _restart() {
    _elapsed = 0;
    _score = 0;
    _lives = 3;
    _spawnTimer = 0;
    _spawnInterval = 1.6;
    _maxJellies = 5;
    _jellies.clear();
    _bullets.clear();
    _lasers.clear();
    _ticker.start();
  }

  void _shoot(Offset tap, Size size) {
    // Laser-Pistole unten Mitte
    final origin = Offset(size.width / 2, size.height - 36);
    final dir = tap - origin;
    final n = dir.distance == 0 ? const Offset(0, -1) : dir / dir.distance;

    // 1) kurzer LASER-Strahl (sichtbar + trifft sofort)
    _lasers.add(_Laser(from: origin, to: tap, timeLeft: 0.12));

    // 2) zusätzlich ein Projektil (fühlt sich „gamey“ an)
    _bullets.add(_Bullet(
      x: origin.dx + n.dx * 28,
      y: origin.dy + n.dy * 28,
      vx: n.dx,
      vy: n.dy,
      speed: 360, // etwas langsamer als vorher
    ));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      _lastSize = size;
      return GestureDetector(
        onTapDown: (d) => _shoot(d.localPosition, size),
        child: CustomPaint(
          size: size,
          painter: _GamePainter(
            jellies: _jellies,
            bullets: _bullets,
            lasers: _lasers,
            score: _score,
            lives: _lives,
          ),
        ),
      );
    });
  }

  // Abstand Punkt -> Liniensegment (für Laser-Hit)
  double _pointToSegmentDistance(Offset p, Offset a, Offset b) {
    final ap = p - a;
    final ab = b - a;
    final t = (ap.dx * ab.dx + ap.dy * ab.dy) /
        (ab.dx * ab.dx + ab.dy * ab.dy);
    final tt = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * tt, a.dy + ab.dy * tt);
    return (p - proj).distance;
  }
}

class _Jelly {
  double x, y, speed, wave, tentacleWiggle;
  bool dead = false;
  _Jelly({required this.x, required this.y, required this.speed})
      : wave = 0,
        tentacleWiggle = 0;
}

class _Bullet {
  double x, y, vx, vy, speed;
  bool hit = false;
  _Bullet(
      {required this.x,
      required this.y,
      required this.vx,
      required this.vy,
      required this.speed});
}

class _Laser {
  Offset from, to;
  double timeLeft; // Sekunden
  _Laser({required this.from, required this.to, required this.timeLeft});
}

class _GamePainter extends CustomPainter {
  final List<_Jelly> jellies;
  final List<_Bullet> bullets;
  final List<_Laser> lasers;
  final int score;
  final int lives;

  _GamePainter(
      {required this.jellies,
      required this.bullets,
      required this.lasers,
      required this.score,
      required this.lives});

  @override
  void paint(Canvas canvas, Size size) {
    // Hintergrund
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF07121B));

    // Laser-Pistole (sichtbar & nicer)
    _drawGun(canvas, size);

    // Laserstrahlen
    for (final l in lasers) {
      final alpha = (l.timeLeft / 0.12).clamp(0.0, 1.0);
      final laserPaint = Paint()
        ..shader = const LinearGradient(colors: [
          Color(0xFF00FFFF),
          Color(0xFFFF2E80),
        ]).createShader(Rect.fromPoints(l.from, l.to))
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withOpacity(0.6 * alpha);
      canvas.drawLine(l.from, l.to, laserPaint);
      // heller Kern
      final core = Paint()
        ..color = Colors.white.withOpacity(0.8 * alpha)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(l.from, l.to, core);
    }

    // Jellies (mit Schirm + Tentakeln)
    for (final j in jellies) {
      _drawJelly(canvas, j);
    }

    // Bullets
    final bulletPaint = Paint()..color = const Color(0xFFFF2E80);
    for (final b in bullets) {
      canvas.drawCircle(Offset(b.x, b.y), 4, bulletPaint);
      // kleines Mündungs-Glow
      canvas.drawCircle(Offset(b.x, b.y), 8,
          Paint()..color = const Color(0xFFFF2E80).withOpacity(0.25));
    }

    // HUD
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 16),
        text: 'Score: $score   Lives: $lives');
    tp.layout();
    tp.paint(canvas, Offset(size.width - tp.width - 16, 16));
  }

  void _drawGun(Canvas canvas, Size size) {
    final baseY = size.height - 36;
    final gunBody = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width / 2, baseY), width: 80, height: 24),
        const Radius.circular(10));
    final barrel = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.width / 2, baseY - 12), width: 46, height: 12),
        const Radius.circular(6));
    final grip = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width / 2 - 10, baseY + 6, 20, 22),
        const Radius.circular(6));

    final paintBody = Paint()..color = const Color(0xFF0BD3D3);
    final paintDark = Paint()..color = const Color(0xFF067A7A);

    canvas.drawRRect(gunBody, paintBody);
    canvas.drawRRect(barrel, paintDark);
    canvas.drawRRect(grip, paintDark);
    // kleines Leuchten vorne
    canvas.drawCircle(Offset(size.width / 2, baseY - 18),
        5, Paint()..color = const Color(0xFF00FFFF).withOpacity(0.7));
  }

  void _drawJelly(Canvas canvas, _Jelly j) {
    final bodyColor = const Color(0xFF7CE2FF);
    final body = Paint()..color = bodyColor.withOpacity(0.95);
    final shine = Paint()..color = Colors.white.withOpacity(0.25);

    // Glocke (Schirm)
    final wobbleX = sin(j.wave) * 5;
    final center = Offset(j.x + wobbleX, j.y);
    final r = 24 + sin(j.wave * 1.4) * 2.5;

    final path = Path()
      ..moveTo(center.dx - r, center.dy)
      ..quadraticBezierTo(center.dx, center.dy - r * 0.9,
          center.dx + r, center.dy)
      ..arcToPoint(Offset(center.dx - r, center.dy),
          clockwise: false, radius: Radius.circular(r));
    canvas.drawPath(path, body);

    // Highlights
    canvas.drawCircle(Offset(center.dx - r * 0.35, center.dy - r * 0.45),
        r * 0.22, shine);

    // Augen
    final eye = Paint()..color = Colors.black.withOpacity(0.75);
    canvas.drawCircle(Offset(center.dx - 7, center.dy - 4), 3, eye);
    canvas.drawCircle(Offset(center.dx + 7, center.dy - 4), 3, eye);

    // Tentakel (schwingend)
    final tPaint = Paint()
      ..color = bodyColor.withOpacity(0.85)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    for (int i = -2; i <= 2; i++) {
      final base = Offset(center.dx + i * 6, center.dy + 2);
      final len = 26 + (i.abs() * 3);
      final sway = sin(j.tentacleWiggle + i) * 6;
      final ctrl = Offset(base.dx + sway, base.dy + len * 0.5);
      final end = Offset(base.dx + sway * 0.7, base.dy + len);
      final p = Path()..moveTo(base.dx, base.dy);
      p.quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
      canvas.drawPath(p, tPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}
