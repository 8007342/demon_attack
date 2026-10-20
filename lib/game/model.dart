import 'dart:math' as math;

enum RunMode {
  title,
  playing,
  paused,
  transition,
  salvage,
  levelClear,
  travel,
  victory,
  gameOver,
}

enum Power { spread, rapid, shield }

class Demon {
  Demon(this.x, this.y, this.kind, this.maxHp, this.seed, {this.elite = false})
    : hp = maxHp,
      homeX = x,
      homeY = y;
  double x, y, homeX, homeY;
  final int kind, maxHp;
  final bool elite;
  int get moltStage => maxHp - hp;
  double attackLeft = 2.4;
  final double seed;
  int hp;
  double dive = 0, targetX = 0, flash = 0, telegraph = 0;
  bool get angry => hp == 1 && maxHp > 1;
}

class Shot {
  Shot(this.x, this.y, this.vx, this.vy, {this.hostile = false});
  double x, y;
  final double vx, vy;
  final bool hostile;
}

class Pickup {
  Pickup(this.x, this.y, this.power);
  double x, y;
  final Power power;
}

class Blast {
  Blast(this.x, this.y, {this.big = false});
  final double x, y;
  final bool big;
  double age = 0;
}

class Carrier {
  Carrier(int cycle)
    : shieldMax = 72 + cycle * 18,
      coreMax = 24 + cycle * 10,
      formCount = math.min(4, 2 + cycle) {
    shield = shieldMax;
    core = coreMax;
  }
  final int shieldMax, coreMax, formCount;
  late int shield, core;
  double x = 180, y = 205;
  int get phase =>
      ((1 - core / coreMax) * formCount).floor().clamp(0, formCount - 1);
  double door = 0;
}

/// Pure fixed-step simulation; renderers and input never change its clock.
class ArcadeModel {
  ArcadeModel({int seed = 1982}) : random = math.Random(seed);
  static const width = 360.0, height = 520.0, shipY = 477.0;
  final math.Random random;
  RunMode mode = RunMode.title;
  RunMode _beforePause = RunMode.playing;
  final List<Demon> demons = [];
  final List<Shot> shots = [];
  final List<Pickup> pickups = [];
  final List<Blast> blasts = [];
  final List<String> events = [];
  Carrier? boss;
  int lives = 3, score = 0, level = 1, cycle = 0, kills = 0, wave = 1;
  int? clearedLevel;
  double shipX = 180, targetX = 180, clock = 0, levelClock = 0;
  double invulnerable = 0, powerLeft = 0, transitionLeft = 0;
  double transitionDuration = 2.3;
  Power? power;
  double _fire = 0, _enemyFire = 1.5, _dive = 3, _flock = 0, _accumulator = 0;
  double get speed => 1 + math.min(cycle, 8) * .1;
  bool get combat => mode == RunMode.playing;
  bool get canPilot =>
      combat ||
      mode == RunMode.salvage ||
      (mode == RunMode.transition && wave > 1);
  bool get isBoss => boss != null;
  int get wavesPerLevel =>
      level == 5 ? 1 : 3 + ((level - 1) ~/ 2) + math.min(cycle, 3);
  int get nextLevel => level == 5 ? 1 : level + 1;
  RunMode get presentationMode => mode == RunMode.paused ? _beforePause : mode;
  bool get cinematic => [
    RunMode.transition,
    RunMode.salvage,
    RunMode.levelClear,
    RunMode.travel,
    RunMode.victory,
  ].contains(presentationMode);
  bool get waveTransition => presentationMode == RunMode.transition && wave > 1;
  double get transitionProgress =>
      (1 - transitionLeft / transitionDuration).clamp(0, 1);
  String get nextLevelName => const [
    'KRYBOR',
    'RINGFALL',
    'EMBER MOON',
    'THE HOLLOW',
    'THE CARRIER',
  ][nextLevel - 1];
  String get levelName => const [
    'KRYBOR',
    'RINGFALL',
    'EMBER MOON',
    'THE HOLLOW',
    'THE CARRIER',
  ][level - 1];
  String get banner => switch (presentationMode) {
    RunMode.victory => 'CARRIER DESTROYED',
    RunMode.salvage => 'COLLECT SALVAGE',
    RunMode.levelClear => '$levelName SECURED',
    RunMode.travel => 'APPROACHING $nextLevelName',
    _ =>
      waveTransition
          ? 'WAVE $wave / $wavesPerLevel'
          : 'LEVEL ${level.toString().padLeft(2, '0')} · $levelName',
  };

  void start() {
    lives = 3;
    score = 0;
    level = 1;
    cycle = 0;
    kills = 0;
    wave = 1;
    clearedLevel = null;
    shipX = targetX = 180;
    clock = 0;
    power = null;
    powerLeft = 0;
    invulnerable = 2;
    _accumulator = 0;
    events.clear();
    _beginLevel();
  }

  void _beginLevel() {
    wave = 1;
    clearedLevel = null;
    boss = level == 5 ? Carrier(cycle) : null;
    levelClock = 0;
    pickups.clear();
    blasts.clear();
    _spawnWave();
    events.add(boss == null ? 'level' : 'boss');
  }

  void _spawnWave() {
    demons.clear();
    shots.clear();
    _fire = 0;
    _enemyFire = 1.7;
    _dive = 3;
    _flock = 2;
    if (boss == null) {
      final count = math.min(
        24,
        6 + level * 2 + (wave - 1) * 2 + math.min(cycle, 4) * 2,
      );
      for (var i = 0; i < count; i++) {
        // Later waves mix previously encountered creatures into the native flock.
        final kind = cycle > 0
            ? (i + wave + level) % 4
            : wave > 1 && i % 4 == 0
            ? math.max(0, level - 2)
            : level - 1;
        final elite = cycle > 0 && (i + wave) % 5 == 0;
        final hp = 1 + (kind ~/ 2) + math.min(cycle, 3) + (elite ? 2 : 0);
        demons.add(
          Demon(
            38 + (i % 6) * 56.0,
            70 + (i ~/ 6) * 48.0,
            kind,
            hp.toInt(),
            i * 1.7 + wave * .6,
            elite: elite,
          ),
        );
      }
    }
    if (boss == null) _updateDemons(0);
    _enterPhase(RunMode.transition, wave > 1 ? 1.4 : 2.3);
  }

  void _enterPhase(RunMode phase, double duration) {
    mode = phase;
    transitionDuration = duration;
    transitionLeft = duration;
  }

  void _completeWave() {
    shots.clear();
    if (wave < wavesPerLevel) {
      wave++;
      _spawnWave();
      events.add('wave');
    } else {
      clearedLevel = level;
      _enterPhase(RunMode.salvage, 2);
      events.add('salvage');
    }
  }

  void moveTo(double x) => targetX = x.clamp(18, width - 18);
  void moveBy(double dx) => moveTo(targetX + dx);
  void pause() {
    if (mode == RunMode.playing || cinematic) {
      _beforePause = mode;
      mode = RunMode.paused;
      events.add('pause');
    }
  }

  void resume() {
    if (mode == RunMode.paused) {
      mode = _beforePause;
      events.add('resume');
    }
  }

  List<String> takeEvents() {
    final result = List<String>.of(events);
    events.clear();
    return result;
  }

  void update(double dt) {
    if (mode == RunMode.paused ||
        mode == RunMode.title ||
        mode == RunMode.gameOver) {
      return;
    }
    _accumulator += dt.clamp(0, .1);
    while (_accumulator >= 1 / 60) {
      _step(1 / 60);
      _accumulator -= 1 / 60;
    }
  }

  void _step(double dt) {
    clock += dt;
    for (final b in blasts) {
      b.age += dt;
    }
    blasts.removeWhere((b) => b.age > .55);
    if (canPilot) {
      final delta = targetX - shipX;
      shipX += delta.clamp(-330 * dt, 330 * dt);
      _updatePickups(dt, mode == RunMode.salvage ? 144 : 64);
    }
    if (cinematic) {
      transitionLeft = math.max(0, transitionLeft - dt);
      if (transitionLeft <= 0) {
        if (mode == RunMode.salvage) {
          pickups.clear();
          _enterPhase(RunMode.levelClear, 4);
          events.add('levelclear');
        } else if (mode == RunMode.levelClear || mode == RunMode.victory) {
          _enterPhase(RunMode.travel, 4);
          events.add('travel');
        } else if (mode == RunMode.travel) {
          if (level == 5) cycle++;
          level = nextLevel;
          shipX = targetX = 180;
          _beginLevel();
        } else {
          mode = RunMode.playing;
        }
      }
      return;
    }
    if (!combat) return;
    levelClock += dt;
    invulnerable = math.max(0, invulnerable - dt);
    powerLeft = math.max(0, powerLeft - dt);
    if (powerLeft == 0) power = null;
    _fire -= dt;
    if (_fire <= 0) {
      _fire += power == Power.rapid ? .105 : .23;
      shots.add(Shot(shipX, shipY - 13, 0, -390));
      if (power == Power.spread) {
        shots.addAll([
          Shot(shipX - 5, shipY - 8, -90, -370),
          Shot(shipX + 5, shipY - 8, 90, -370),
        ]);
      }
      events.add('shot');
    }
    _updateDemons(dt);
    _updateBoss(dt);
    for (final s in shots) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
    }
    _collisions();
    shots.removeWhere(
      (s) => s.y < -10 || s.y > height + 10 || s.x < -10 || s.x > width + 10,
    );
    if (combat && demons.isEmpty && boss == null) {
      _completeWave();
    }
  }

  void _updatePickups(double dt, double fallSpeed) {
    for (final p in pickups) {
      p.y += fallSpeed * dt;
      if ((p.x - shipX).abs() < 22 && (p.y - shipY).abs() < 23) {
        collect(p.power);
        p.y = height + 20;
      }
    }
    pickups.removeWhere((p) => p.y > height + 10);
  }

  void _hostile(Shot shot) {
    if (shots.where((s) => s.hostile).length < 120) shots.add(shot);
  }

  void _updateDemons(double dt) {
    _dive -= dt;
    final readyDivers = demons
        .where((d) => d.dive == 0 && d.telegraph <= 0)
        .toList();
    if (_dive <= 0 && readyDivers.isNotEmpty) {
      final d = readyDivers[random.nextInt(readyDivers.length)];
      if (level >= 2 || cycle > 0) {
        d.telegraph = d.elite ? .55 : .7;
        d.targetX = shipX;
      }
      _dive = math.max(
        .8,
        (4.2 - level * .45 - math.min(cycle, 5) * .22) / speed,
      );
    }
    for (final d in demons) {
      d.flash = math.max(0, d.flash - dt);
      if (d.elite && dt > 0) {
        d.attackLeft -= dt;
        if (d.attackLeft <= 0) {
          final aim = ((shipX - d.x) * .3).clamp(-70.0, 70.0);
          for (final offset in [-32.0, 0.0, 32.0]) {
            _hostile(
              Shot(d.x, d.y + 12, aim + offset, 130 * speed, hostile: true),
            );
          }
          if (d.dive == 0 && d.telegraph <= 0) {
            d.telegraph = .55;
            d.targetX = shipX;
          }
          d.attackLeft = math.max(2.0, 4 - math.min(cycle, 5) * .3);
        }
      }
      if (d.telegraph > 0) {
        d.telegraph -= dt;
        if (d.telegraph <= 0) d.dive = .001;
      }
      if (d.dive > 0) {
        d.dive += dt * speed * (d.angry ? 1.3 : 1) * (d.elite ? 1.15 : 1);
        d.x += (d.targetX - d.x) * dt * (d.elite ? 2.1 : 1.8);
        d.y +=
            (115 + d.kind * 16) *
            dt *
            speed *
            (d.angry ? 1.3 : 1) *
            (d.elite ? 1.15 : 1);
        if (d.y > height + 20) {
          d.dive = 0;
          d.y = d.homeY;
          d.x = d.homeX;
        }
      } else {
        d.x =
            (d.homeX +
                    math.sin(
                          levelClock * (.9 + d.kind * .12) * speed + d.seed,
                        ) *
                        29 +
                    math.sin(levelClock * .44) * 13)
                .clamp(20, width - 20);
        d.y = d.homeY + math.sin(levelClock * 1.7 * speed + d.seed) * 14;
      }
    }
    _enemyFire -= dt;
    if (_enemyFire <= 0 && demons.isNotEmpty) {
      final d = demons[random.nextInt(demons.length)];
      final aim = ((shipX - d.x) * .22).clamp(-65.0, 65.0);
      _hostile(
        Shot(d.x, d.y + 12, aim, (100 + level * 13) * speed, hostile: true),
      );
      _enemyFire = math.max(.45, 1.8 - level * .18 - cycle * .05);
    }
  }

  void _updateBoss(double dt) {
    final b = boss;
    if (b == null) return;
    b.x = 180 + math.sin(levelClock * .7 * speed) * 80;
    b.y = 205 + math.sin(levelClock * .9) * 12;
    b.door = ((math.sin(levelClock * (1.8 + b.phase * .25)) - .1) * 2).clamp(
      0,
      1,
    );
    _flock -= dt;
    if (_flock <= 0 && demons.length < 10) {
      final flockSize = math.min(3, 10 - demons.length);
      for (var i = 0; i < flockSize; i++) {
        final d = Demon(
          (b.x + (i - 1) * 35).clamp(30, 330),
          b.y + 52,
          math.min(3, cycle + 1),
          1 + math.min(cycle, 2),
          random.nextDouble() * 8,
        );
        d.homeY = b.y + 70;
        demons.add(d);
      }
      _flock = math.max(2.2, 5 - b.phase * .5 - cycle * .2);
    }
    // Fan attacks force positioning without tracking a player after launch.
    if ((levelClock * 1.1).floor() != ((levelClock - dt) * 1.1).floor()) {
      for (var i = -1; i <= 1; i++) {
        _hostile(
          Shot(
            b.x,
            b.y + 42,
            i * (40.0 + b.phase * 10),
            120 * speed,
            hostile: true,
          ),
        );
      }
    }
  }

  void _collisions() {
    for (final s in List<Shot>.of(shots)) {
      if (!combat) break;
      if (s.y > height + 2) continue;
      if (s.hostile) {
        if ((s.x - shipX).abs() < 10 && (s.y - shipY).abs() < 12) {
          hitPlayer();
          s.y = height + 20;
        }
        continue;
      }
      var hit = false;
      for (final d in List<Demon>.of(demons)) {
        if ((s.x - d.x).abs() < 16 && (s.y - d.y).abs() < 14) {
          hitDemon(d);
          hit = true;
          break;
        }
      }
      final b = boss;
      if (!hit &&
          b != null &&
          (s.x - b.x).abs() < 78 &&
          s.y < b.y + 43 &&
          s.y > b.y - 25) {
        hitBoss(s.x);
        hit = true;
      }
      if (hit) s.y = height + 20;
    }
    for (final d in demons) {
      if ((d.x - shipX).abs() < 21 && (d.y - shipY).abs() < 21) hitPlayer();
    }
  }

  void hitDemon(Demon d) {
    if (!combat || !demons.contains(d)) return;
    d.hp--;
    d.flash = .12;
    if (d.hp <= 0) {
      demons.remove(d);
      kills++;
      score += (100 + d.kind * 75 + (d.maxHp - 1) * 50) * (cycle + 1);
      blasts.add(Blast(d.x, d.y));
      events.add('explosion');
      if (kills % 5 == 0) {
        pickups.add(Pickup(d.x, d.y, Power.values[(kills ~/ 5 - 1) % 3]));
      }
    } else {
      events.add('hit');
      if (d.angry && d.dive == 0 && d.telegraph <= 0) {
        d.telegraph = d.elite ? .55 : .7;
        d.targetX = shipX;
      }
    }
  }

  /// Shield can be hit across its width. Core needs the exposed central door.
  bool hitBoss(double shotX) {
    final b = boss;
    if (b == null || !combat) return false;
    if (b.shield > 0) {
      b.shield--;
      events.add('hit');
      blasts.add(Blast(shotX, b.y + 39));
      if (b.shield == 0) events.add('boss');
      return true;
    }
    if (b.door < .65 || (shotX - b.x).abs() > 12 * b.door) return false;
    final old = b.phase;
    b.core--;
    events.add('hit');
    blasts.add(Blast(b.x, b.y + 18));
    if (b.phase != old) events.add('boss');
    if (b.core <= 0) {
      score += 5000 * (cycle + 1);
      blasts.add(Blast(b.x, b.y, big: true));
      boss = null;
      demons.clear();
      shots.clear();
      pickups.clear();
      clearedLevel = level;
      _enterPhase(RunMode.victory, 5.5);
      events.add('victory');
    }
    return true;
  }

  void collect(Power value) {
    power = value;
    powerLeft = 9;
    events.add('powerup');
  }

  void hitPlayer() {
    if (!combat || invulnerable > 0) return;
    if (power == Power.shield) {
      power = null;
      powerLeft = 0;
      invulnerable = 1;
      events.add('hit');
      return;
    }
    lives--;
    invulnerable = 2.5;
    blasts.add(Blast(shipX, shipY));
    events.add('life');
    if (lives <= 0) {
      mode = RunMode.gameOver;
      events.add('gameover');
    }
  }
}
