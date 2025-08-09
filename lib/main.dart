
import 'dart:ui';
import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(GameWidget(game: AlienJellyBlaster()));
}

class AlienJellyBlaster extends FlameGame
    with HasCollisionDetection, TapDetector, HasGameRef<AlienJellyBlaster> {
  late Player player;
  late SpawnController spawner;
  int score = 0;
  int lives = 3;
  bool paused = false;

  @override
  Color backgroundColor() => const Color(0xFF071018);

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedResolutionViewport(Vector2(1080, 1920));

    player = Player()
      ..position = size / 2
      ..y = size.y - 220;
    add(player);

    spawner = SpawnController(this);
    add(ScreenHud(this));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!paused) {
      spawner.update(dt);
    }
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (paused) return;
    final target = info.eventPosition.game;
    player.shoot(target, this);
  }

  void addScore(int v) {
    score += v;
  }

  void loseLife() {
    lives -= 1;
    if (lives <= 0) {
      paused = true;
    }
  }
}

class ScreenHud extends Component with HasGameRef<AlienJellyBlaster> {
  final AlienJellyBlaster g;
  ScreenHud(this.g);

  TextPaint get tp => TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontFeatures: [FontFeature.enable('smcp')],
        ),
      );

  @override
  void render(Canvas c) {
    tp.render(c, 'Score: ${g.score}', Vector2(32, 32));
    tp.render(c, 'Lives: ${g.lives}', Vector2(game.size.x - 220, 32));
    if (g.paused && g.lives <= 0) {
      final center = game.size / 2;
      final big = TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 96),
      );
      big.render(c, 'GAME OVER', center - Vector2(280, 80));
      tp.render(c, 'Tippe R zum Neustart', center + Vector2(-220, 16));
    }
  }
}

class Player extends PositionComponent with HasGameRef<AlienJellyBlaster> {
  @override
  Future<void> onLoad() async {
    size = Vector2(140, 140);
    anchor = Anchor.center;
    add(RectangleHitbox(size: Vector2(100, 100))
      ..collisionType = CollisionType.passive);
  }

  @override
  void render(Canvas c) {
    final bodyPaint = Paint()..color = const Color(0xFF3DDC84);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(size.x/2, size.y/2), width: 120, height: 60),
        const Radius.circular(16),
      ),
      bodyPaint,
    );
    final barrelPaint = Paint()..color = const Color(0xFF80BB3D);
    c.drawRect(
      Rect.fromCenter(
        center: Offset(size.x/2, size.y/2 - 30),
        width: 20,
        height: 60,
      ),
      barrelPaint,
    );
  }

  void shoot(Vector2 target, AlienJellyBlaster g) {
    final origin = Vector2(x, y - 60);
    final dir = (target - origin).normalized();
    final beam = LaserBeam(origin, dir);
    g.add(beam);
  }
}

class LaserBeam extends PositionComponent
    with CollisionCallbacks, HasGameRef<AlienJellyBlaster> {
  final Vector2 dir;
  final double speed = 1400;
  double life = 0;
  final double maxLife = 1.2;

  LaserBeam(Vector2 origin, this.dir) {
    position = origin.clone();
    size = Vector2(6, 36);
    anchor = Anchor.center;
    add(RectangleHitbox()..collisionType = CollisionType.active);
  }

  @override
  void render(Canvas c) {
    final p = Paint()..color = const Color(0xFF1F3C90);
    c.save();
    c.translate(size.x / 2, size.y / 2);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 6, height: 36),
        const Radius.circular(3),
      ),
      p,
    );
    c.restore();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += dir * speed * dt;
    life += dt;
    if (life > maxLife ||
        position.x < -50 || position.y < -50 ||
        position.x > game.size.x + 50 || position.y > game.size.y + 50) {
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> points, PositionComponent other) {
    if (other is Jellyfish) {
      other.hit();
      removeFromParent();
    }
    super.onCollision(points, other);
  }
}

class Jellyfish extends PositionComponent
    with CollisionCallbacks, HasGameRef<AlienJellyBlaster> {
  double speed = 60;
  int hp = 1;
  Vector2 velocity = Vector2.zero();
  final math.Random rng = math.Random();

  Jellyfish(Vector2 pos, double baseSpeed) {
    position = pos;
    size = Vector2(80, 100);
    anchor = Anchor.center;
    speed = baseSpeed + rng.nextDouble() * 40;
    hp = 1;
    add(CircleHitbox.relative(0.6, parentSize: size)
      ..collisionType = CollisionType.passive);
  }

  @override
  void render(Canvas c) {
    final bell = Paint()..color = const Color(0xFF89E0FF);
    final tentacle = Paint()..color = const Color(0xFF62B8E6);
    final center = Offset(size.x/2, size.y/2);
    c.drawOval(Rect.fromCenter(center: center, width: 70, height: 60), bell);
    for (int i = -3; i <= 3; i++) {
      final x = center.dx + i * 8;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2, center.dy + 10, 4, 40),
          const Radius.circular(2),
        ),
        tentacle,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += Vector2(0, 1) * speed * dt;
    if (position.y > game.size.y + 80) {
      removeFromParent();
      game.loseLife();
    }
  }

  void hit() {
    hp -= 1;
    if (hp <= 0) {
      game.addScore(10);
      removeFromParent();
    }
  }
}

class SpawnController extends Component with HasGameRef<AlienJellyBlaster> {
  final AlienJellyBlaster g;
  double timer = 0;
  double interval = 1.2;
  double difficultyTimer = 0;
  final math.Random rng = math.Random();

  SpawnController(this.g);

  @override
  void update(double dt) {
    super.update(dt);
    timer += dt;
    difficultyTimer += dt;

    if (difficultyTimer > 15) {
      difficultyTimer = 0;
      interval = (interval * 0.9).clamp(0.3, 2.0);
    }

    if (timer > interval && !g.paused) {
      timer = 0;
      final x = rng.nextDouble() * (game.size.x - 160) + 80;
      final base = math.max(60, 110 - interval * 20);
      g.add(Jellyfish(Vector2(x, -40), base.toDouble()));
    }
  }
}
