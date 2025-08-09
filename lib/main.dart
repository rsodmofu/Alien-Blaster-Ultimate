import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: GamePage()));

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  final Random _rng = Random();
  late Ticker _ticker;

  // Game state
  double _elapsed = 0; // seconds
  int _score = 0;
  int _lives = 3;

  // Entities
  final List<_Jelly> _jellies = [];
  final List<_Bullet> _bullets = [];

  // Spawning
  double _spawnTimer = 0;
  double _spawnInterval = 1.2; // seconds; wird mit der Zeit kürzer

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_update)..start();
  }

  void _update(Duration dt) {
    final double dtSec = dt.inMicroseconds / 1e6;
    _elapsed += dtSec;
    _spawnTimer += dtSec;

    // Schwierigkeit langsam erhöhen
    if (_elapsed > 10 && _spawnInterval > 0.5) _spawnInterval = 0.9;
    if (_elapsed > 25 && _spawnInterval > 0.35) _spawnInterval = 0.6;
    if (_elapsed > 45 && _spawnInterval > 0.25) _spawnInterval = 0.45;

    // Spawnen
    if (_spawnTimer >= _spawnInterval) {
      _spawnTimer = 0;
      final size = _lastSize ?? const Size(400, 800);
      final x = _rng.nextDouble() * (size.width - 40) + 20;
      _jellies.add(_Jelly(x: x, y: -30, speed: 60 + _rng.nextDouble() * 70));
    }

    // Bewegen
    for (final j in _jellies) {
      j.y += j.speed * dtSec;
      j.wave += dtSec * 4;
    }
    for (final b in _bullets) {
      b.y -= b.speed * dtSec;
    }

    // Kollisionen
    for (final b in _bullets) {
      for (final j in _jellies) {
        if (!j.dead && (Offset(b.x, b.y) - Offset(j.x, j.y)).distance < 28) {
          j.dead = true;
          b.hit = true;
          _score += 10;
          break;
        }
      }
    }

    // Aufräumen
    _jellies.removeWhere((j) => j.dead);
    _bullets.removeWhere((b) => b.hit || b.y < -40);

    // Check: Jelly unten angekommen?
    final size = _lastSize;
    if (size != null) {
      final reachedBottom = _jellies.where((j) => j.y > size.height + 20).toList();
      if (reachedBottom.isNotEmpty) {
        _jellies.removeWhere((j) => reachedBottom.contains(j));
        _lives -= reachedBottom.length;
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
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  void _restart() {
    _score = 0;
    _lives = 3;
    _elapsed = 0;
    _spawnTimer = 0;
    _spawnInterval = 1.2;
    _jellies.clear();
    _bullets.clear();
    _ticker.start();
  }

  Size? _lastSize;

  void _shoot(Offset tap, Size size) {
    // Schieße von unten Mitte in Richtung Tap
    final origin = Offset(size.width / 2, size.height - 20);
    final dir = (tap - origin);
    final n = dir.distance == 0 ? const Offset(0, -1) : dir / dir.distance;
    _bullets.add(_Bullet(x: origin.dx, y: origin.dy, vx: n.dx, vy: n.dy));
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
        child: Stack(
          children: [
            CustomPaint(size: size, painter: _GamePainter(_jellies, _bullets, _score, _lives)),
            const Positioned(top: 36, left: 16, child: _HudLabel(text: 'Alien Jelly Blaster')),
          ],
        ),
      );
    });
  }
}

class _HudLabel extends StatelessWidget {
  final String text;
  const _HudLabel({required this.text, super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _Jelly {
  double x, y, speed, wave = 0;
  bool dead = false;
  _Jelly({required this.x, required this.y, required this.speed});
}

class _Bullet {
  double x, y;
  final double vx, vy;
  double speed = 420;
  bool hit = false;
  _Bullet({required this.x, required this.y, required this.vx, required this.vy});
}

class _GamePainter extends CustomPainter {
  final List<_Jelly> jellies;
  final List<_Bullet> bullets;
  final int score;
  final int lives;
  _GamePainter(this.jellies, this.bullets, this.score, this.lives);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0B0F16);
    canvas.drawRect(Offset.zero & size, bg);

    // Gun (unten Mitte)
    final gun = Paint()..color = Colors.cyanAccent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(size.width / 2, size.height - 12), width: 60, height: 16), const Radius.circular(8)),
      gun,
    );

    // Jellies: wobbly blobs
    final jellyPaint = Paint()..color = const Color(0xFF80DEEA);
    for (final j in jellies) {
      final wobbleX = sin(j.wave) * 6;
      final wobbleR = 22 + sin(j.wave * 1.3) * 3;
      canvas.drawCircle(Offset(j.x + wobbleX, j.y), wobbleR, jellyPaint);
      // Augen
      final eye = Paint()..color = Colors.black.withOpacity(0.7);
      canvas.drawCircle(Offset(j.x - 6 + wobbleX, j.y - 4), 3, eye);
      canvas.drawCircle(Offset(j.x + 6 + wobbleX, j.y - 4), 3, eye);
    }

    // Bullets
    final bulletPaint = Paint()..color = Colors.pinkAccent;
    for (final b in bullets) {
      canvas.drawCircle(Offset(b.x, b.y), 4, bulletPaint);
      // Bewegung: Richtung beachten
      b.x += b.vx * b.speed / 60;
      b.y += b.vy * b.speed / 60;
    }

    // HUD
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(style: const TextStyle(color: Colors.white, fontSize: 16), text: 'Score: $score   Lives: $lives');
    tp.layout();
    tp.paint(canvas, Offset(size.width - tp.width - 16, 16));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
