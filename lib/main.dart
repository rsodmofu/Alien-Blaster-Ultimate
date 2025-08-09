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

  // Spawning/Schwierigkeit
  double _spawnTimer = 0;
  double _spawnInterval = 1.2;

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

    // Schwierigkeit anziehen
    if (_elapsed > 10) _spawnInterval = 0.9;
    if (_elapsed > 25) _spawnInterval = 0.6;
    if (_elapsed > 45) _spawnInterval = 0.45;

    // Spawnen
    if (_spawnTimer >= _spawnInterval) {
      _spawnTimer = 0;
      final size = _lastSize ?? const Size(400, 800);
      final x = _rng.nextDouble() * (size.width - 40) + 20;
      _jellies.add(_Jelly(x: x, y: -30, speed: 60 + _rng.nextDouble() * 70));
    }

    // Bewegung
    for (final j in _jellies) {
      j.y += j.speed * dtSec;
      j.wave += dtSec * 4;
    }
    for (final b in _bullets) {
      b.x += b.vx * b.speed * dtSec;
      b.y += b.vy * b.speed * dtSec;
    }

    // Kollisionen
    for (final b in _bullets) {
      for (final j in _jellies) {
        if (!j.dead &&
            (Offset(b.x, b.y) - Offset(j.x, j.y)).distance < 28) {
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
        (b) => b.hit || b.y < -50 || b.y > (_lastSize?.height ?? 9999) + 50);

    // Leben verlieren, wenn Jelly unten ankommt
    final size = _lastSize;
    if (size != null) {
      final escaped = _jellies.where((j) => j.y > size.height + 20).toList();
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
    _spawnInterval = 1.2;
    _jellies.clear();
    _bullets.clear();
    _ticker.start();
  }

  void _shoot(Offset tap, Size size) {
    final origin = Offset(size.width / 2, size.height - 20);
    final dir = tap - origin;
    final n = dir.distance == 0 ? const Offset(0, -1) : dir / dir.distance;
    _bullets.add(_Bullet(
      x: origin.dx,
      y: origin.dy,
      vx: n.dx,
      vy: n.dy,
      speed: 420,
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
            score: _score,
            lives: _lives,
          ),
        ),
      );
    });
  }
}

class _Jelly {
  double x, y, speed, wave;
  bool dead = false;
  _Jelly({required this.x, required this.y, required this.speed})
      : wave = 0;
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

class _GamePainter extends CustomPainter {
  final List<_Jelly> jellies;
  final List<_Bullet> bullets;
  final int score;
  final int lives;

  _GamePainter(
      {required this.jellies,
      required this.bullets,
      required this.score,
      required this.lives});

  @override
  void paint(Canvas canvas, Size size) {
    // Hintergrund
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF0B0F16));

    // Gun (unten Mitte)
    final gun = Paint()..color = Colors.cyanAccent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(size.width / 2, size.height - 12),
              width: 60,
              height: 16),
          const Radius.circular(8)),
      gun,
    );

    // Jellies
    final jellyPaint = Paint()..color = const Color(0xFF80DEEA);
    for (final j in jellies) {
      final wobbleX = sin(j.wave) * 6;
      final r = 22 + sin(j.wave * 1.3) * 3;
      final center = Offset(j.x + wobbleX, j.y);
      canvas.drawCircle(center, r, jellyPaint);

      final eye = Paint()..color = Colors.black.withOpacity(0.7);
      canvas.drawCircle(Offset(center.dx - 6, center.dy - 4), 3, eye);
      canvas.drawCircle(Offset(center.dx + 6, center.dy - 4), 3, eye);
    }

    // Bullets
    final bulletPaint = Paint()..color = Colors.pinkAccent;
    for (final b in bullets) {
      canvas.drawCircle(Offset(b.x, b.y), 4, bulletPaint);
    }

    // HUD
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 16),
        text: 'Score: $score   Lives: $lives');
    tp.layout();
    tp.paint(canvas, Offset(size.width - tp.width - 16, 16));
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => true;
}
