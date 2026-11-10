import 'dart:math' as math;
import 'dart:typed_data';

import 'model.dart';
import 'vegetation_atlas.dart';

/// Notable terrain features; the names are the `kind` of the
/// `terrainAhead` radio event (rolling hills are never announced).
enum TerrainKind { rolling, ridge, valley, canyon, mesa, forest, crystalField, ruins }

/// One feature per world segment of [TerrainField.segment] texels.
class TerrainFeature {
  const TerrainFeature(this.id, this.kind, this.side, this.w, this.amp, this.s,
      this.len, this.width);
  final int id;
  final TerrainKind kind;

  /// 0 left, 1 right, 2 across the whole field.
  final int side;

  /// Centre along the ground (world texels), height or depth (texels),
  /// lateral centre (world texels from the centre line, signed), half-length
  /// along the ground and half-width across it.
  final double w, amp, s, len, width;

  bool get notable => kind != TerrainKind.rolling;
  String get sideName => side == 0 ? 'left' : side == 1 ? 'right' : 'both';
}

/// Sector identity of the relief: amplitudes, feature mix and sky light.
class TerrainProfile {
  const TerrainProfile({
    required this.roll,
    required this.weights,
    required this.light,
    required this.lightColor,
  });

  /// Rolling-hill amplitude (texels).
  final double roll;

  /// Relative frequency of each feature kind (rolling included).
  final Map<TerrainKind, double> weights;

  /// Unit light direction (lateral s, forward w, up) and its 0-1 colour.
  final (double, double, double) light;
  final (double, double, double) lightColor;

  static const sectors = <TerrainProfile>[
    // Krybor: cold frontier hills, ice ridges, frost-pine stands.
    TerrainProfile(
      roll: 12,
      weights: {
        TerrainKind.rolling: .14,
        TerrainKind.ridge: .26,
        TerrainKind.valley: .16,
        TerrainKind.mesa: .08,
        TerrainKind.forest: .22,
        TerrainKind.crystalField: .14,
      },
      light: (-.5, -.4, .77),
      lightColor: (.84, .93, 1),
    ),
    // Ringfall: cratered ring rock, flat-topped mesas, crystal and wreck fields.
    TerrainProfile(
      roll: 9,
      weights: {
        TerrainKind.rolling: .12,
        TerrainKind.mesa: .26,
        TerrainKind.canyon: .14,
        TerrainKind.crystalField: .26,
        TerrainKind.ruins: .22,
      },
      light: (.45, -.42, .79),
      lightColor: (.93, .86, 1),
    ),
    // Ember: basalt mesas and lava canyons under a warm eclipse.
    TerrainProfile(
      roll: 9,
      weights: {
        TerrainKind.rolling: .1,
        TerrainKind.canyon: .28,
        TerrainKind.mesa: .26,
        TerrainKind.ridge: .16,
        TerrainKind.forest: .2,
      },
      light: (.55, -.38, .74),
      lightColor: (1, .84, .72),
    ),
    // Hollow: sunken valleys between ruins and fungal groves.
    TerrainProfile(
      roll: 11,
      weights: {
        TerrainKind.rolling: .1,
        TerrainKind.valley: .28,
        TerrainKind.ruins: .3,
        TerrainKind.forest: .2,
        TerrainKind.ridge: .12,
      },
      light: (-.45, -.42, .79),
      lightColor: (.84, 1, .9),
    ),
    // Carrier: sinew ridges and torn canyons, thorn thickets.
    TerrainProfile(
      roll: 9,
      weights: {
        TerrainKind.rolling: .1,
        TerrainKind.ridge: .32,
        TerrainKind.canyon: .22,
        TerrainKind.forest: .2,
        TerrainKind.valley: .16,
      },
      light: (.4, -.45, .8),
      lightColor: (1, .78, .78),
    ),
  ];
}

/// Seeded uniform value in [0, 1): Park-Miller steps whose products stay
/// below 2^53, so the VM and the web agree (as `FlyoverBackground`).
double terrainRand(int a, [int b = 0, int c = 0, int d = 0]) {
  const m = 2147483647;
  var h = (a * 73 + 19) % m;
  h = (h * 48271 + b % 100003) % m;
  h = (h * 48271 + c % 100003) % m;
  h = (h * 48271 + d % 100003) % m;
  h = (h * 48271) % m;
  h = (h * 48271) % m;
  return h / m;
}

double _smooth(double t) => t * t * (3 - 2 * t);
double _smoothstep(double a, double b, double x) =>
    _smooth(((x - a) / (b - a)).clamp(0.0, 1.0));

/// The endless relief of one sector and route: a pure, deterministic
/// function of world position.
///
/// World coordinates are ground texels: `s` across (0 on the centre line,
/// negative to the left) and `w` along the ground (the flyover camera sits
/// at `w = distance / 2`). Heights are texels upward. Rolling value-noise
/// hills are composed with one feature per [segment] (ridge, valley,
/// canyon, mesa, or a vegetation-rich forest / crystal field / ruins), chosen
/// from the sector's [TerrainProfile]. Every feature's support stays inside
/// its own segment and its neighbours, so any distance renders seamlessly.
class TerrainField {
  TerrainField(this.sector, this.route)
      : profile = TerrainProfile.sectors[sector.clamp(0, 4)],
        seed = 4099 + sector * 131 + route * 17;
  final int sector, route, seed;
  final TerrainProfile profile;

  static const segment = 300.0;

  final _features = <int, TerrainFeature>{};

  /// The feature of segment [j] (cached; pure).
  TerrainFeature feature(int j) {
    final cached = _features[j];
    if (cached != null) return cached;
    if (_features.length > 256) _features.clear();
    final f = _makeFeature(j);
    _features[j] = f;
    return f;
  }

  TerrainFeature _makeFeature(int j) {
    if (j < 1) {
      // The first stretch of every run is gentle.
      return TerrainFeature(j, TerrainKind.rolling, 2, j * segment, 0, 0, 1, 1);
    }
    final weights = profile.weights;
    final total = weights.values.fold(0.0, (a, b) => a + b);
    var r = terrainRand(seed, j, 1) * total;
    var kind = TerrainKind.rolling;
    for (final e in weights.entries) {
      r -= e.value;
      if (r <= 0) {
        kind = e.key;
        break;
      }
    }
    // No two identical notable features in a row.
    if (j > 1 && kind != TerrainKind.rolling && _makeKindOnly(j - 1) == kind) {
      kind = TerrainKind.rolling;
    }
    final side = terrainRand(seed, j, 2) < .5 ? 0 : 1;
    final sign = side == 0 ? -1.0 : 1.0;
    final w = j * segment + segment * (.3 + .4 * terrainRand(seed, j, 3));
    final q = terrainRand(seed, j, 4);
    return switch (kind) {
      TerrainKind.ridge =>
        TerrainFeature(j, kind, 2, w, 24 + 10 * q, 0, 1, 42 + 14 * q),
      TerrainKind.valley => TerrainFeature(
          j, kind, side, w, 17 + 5 * q, sign * (34 + 30 * q), 125, 15),
      TerrainKind.canyon => TerrainFeature(
          j, kind, side, w, 26 + 8 * q, sign * (36 + 28 * q), 135, 10),
      TerrainKind.mesa => TerrainFeature(
          j, kind, side, w, 30 + 12 * q, sign * (36 + 30 * q), 60 + 20 * q,
          17 + 9 * q),
      TerrainKind.rolling =>
        TerrainFeature(j, kind, 2, w, 0, 0, 1, 1),
      _ => TerrainFeature(j, kind, side, w, 4 + 2 * q, sign * (45 + 25 * q),
          135, 38),
    };
  }

  TerrainKind _makeKindOnly(int j) {
    final weights = profile.weights;
    final total = weights.values.fold(0.0, (a, b) => a + b);
    var r = terrainRand(seed, j, 1) * total;
    for (final e in weights.entries) {
      r -= e.value;
      if (r <= 0) return e.key;
    }
    return TerrainKind.rolling;
  }

  /// Smooth value noise in [-1, 1] on an integer lattice.
  double _noise(double x, double y, int salt) {
    final ix = x.floorToDouble(), iy = y.floorToDouble();
    final fx = _smooth(x - ix), fy = _smooth(y - iy);
    final i = ix.toInt(), k = iy.toInt();
    double v(int a, int b) => terrainRand(seed + salt, a, b) * 2 - 1;
    final a = v(i, k), b = v(i + 1, k), c = v(i, k + 1), d = v(i + 1, k + 1);
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
  }

  /// Raw world height (texels) at lateral [s] and ground position [w].
  double heightAt(double s, double w) {
    var h = profile.roll *
        (_noise(s / 70, w / 230, 5) + .45 * _noise(s / 32, w / 95, 7));
    final j = (w / segment).floor();
    for (var k = j - 1; k <= j + 1; k++) {
      h += _featureHeight(feature(k), s, w);
    }
    return h;
  }

  double _featureHeight(TerrainFeature f, double s, double w) {
    switch (f.kind) {
      case TerrainKind.rolling:
        return 0;
      case TerrainKind.ridge:
        // A crest crossing the field, slanted and wavering.
        final crest = f.w + .5 * s.abs().clamp(0.0, 150.0) +
            14 * math.sin(s / 25 + f.id);
        final t = (w - crest).abs() / f.width;
        if (t >= 1) return 0;
        final u = 1 - t;
        return f.amp * u * u * (3 - 2 * u) * (.75 + .25 * u);
      case TerrainKind.valley:
      case TerrainKind.canyon:
        final along = (w - f.w).abs() / f.len;
        if (along >= 1) return 0;
        final centre = f.s + 8 * math.sin((w - f.w) / 60 + f.id);
        final t = (s - centre).abs() / f.width;
        final ends = 1 - _smooth(along);
        if (f.kind == TerrainKind.canyon) {
          // Steep walls, a flat floor and a low rim.
          final floor = 1 - _smoothstep(.55, 1, t);
          final rim = t > 1 && t < 1.7 ? math.sin((t - 1) / .7 * math.pi) : 0.0;
          return ends * (-f.amp * floor + 4 * rim);
        }
        final dip = t < 1.6 ? math.exp(-t * t * 1.6) : 0.0;
        final lip = t > .8 && t < 2 ? math.sin((t - .8) / 1.2 * math.pi) : 0.0;
        return ends * (-f.amp * dip + .35 * f.amp * lip);
      case TerrainKind.mesa:
        final ds = (s - f.s) / f.width, dw = (w - f.w) / f.len;
        final r = math.sqrt(math.sqrt(ds * ds * ds * ds + dw * dw * dw * dw));
        if (r >= 1.05) return 0;
        // Flat top, steep stepped edge, a talus skirt.
        final top = 1 - _smoothstep(.78, .9, r);
        final skirt = (1 - _smoothstep(.9, 1.05, r)) * .18;
        return f.amp * math.max(top, skirt);
      case TerrainKind.forest:
      case TerrainKind.crystalField:
      case TerrainKind.ruins:
        // Gentle hummocks: these are carried by their vegetation.
        final along = (w - f.w).abs() / f.len;
        final t = (s - f.s).abs() / f.width;
        if (along >= 1 || t >= 1) return 0;
        return f.amp * (1 - _smooth(along)) * (1 - _smooth(t));
    }
  }

  /// The vegetation theme and its density boost on [side] at [w].
  (TerrainKind, double) vegetationTheme(int side, double w) {
    final j = (w / segment).floor();
    for (var k = j - 1; k <= j + 1; k++) {
      final f = feature(k);
      if (f.kind != TerrainKind.forest &&
          f.kind != TerrainKind.crystalField &&
          f.kind != TerrainKind.ruins) {
        continue;
      }
      if (f.side != side) continue;
      final along = (w - f.w).abs() / f.len;
      if (along < 1) return (f.kind, 1 - along * along);
    }
    return (TerrainKind.rolling, 0);
  }
}

/// What the ground looks like at one screen point.
class TerrainSample {
  const TerrainSample(this.height, this.y, this.slopeS, this.slopeW, this.hidden);

  /// Effective height (texels, after the lane and distance envelopes).
  final double height;

  /// Visible screen y of the surface (a point hidden behind a nearer crest
  /// reports the crest line).
  final double y;

  /// World gradient: dh/ds across and dh/dw along the ground (away from
  /// the camera).
  final double slopeS, slopeW;
  final bool hidden;
}

/// One plant or obstacle on the ground. Its lateral position uses the same
/// band coordinate as the ground units (`across`, 0 at the outer edge, 1 at
/// the lane edge, beyond 1 never), so it hugs the side bands at every depth.
class VegetationInstance {
  VegetationInstance(this.id, this.species, this.side, this.across, this.w,
      this.size);
  final int id;
  final VegetationSpecies species;
  final int side;
  final double across, w, size;

  /// Clock when a unit first pushed it (null: untouched), push direction
  /// (+1 toward screen right) and the debris shove offset (texels).
  double? hitAt;
  int dir = 1;

  /// Screen centre x of the sprite at depth [z].
  double xAt(double z) {
    final scale = GroundCamera.texel(z) * size;
    final width = species.w * scale;
    return GroundCamera.bandX(side, across, width);
  }
}

/// A burst particle (dust, leaves, shards, splinters, spores, ash).
class VegetationParticle {
  VegetationParticle(this.kind, this.x, this.y, this.vx, this.vy, this.scale,
      this.life, this.phase);
  final int kind;
  double x, y;
  final double vx, vy, scale, life, phase;
  double age = 0;
}

/// The relief under the flyover camera: blends two sector fields during
/// travel, keeps a per-frame screen grid (the mesh the ground is drawn
/// with), and answers surface, navigation and vegetation queries.
///
/// All of it is visual and positional. Gameplay (fire range, breakthroughs,
/// collisions) is decided by logical depth and lane, never by these poses.
class TerrainView implements GroundRelief {
  TerrainView();

  static const horizon = GroundCamera.horizon;
  static const _g = GroundCamera.g, _z0 = GroundCamera.z0;

  /// Columns of the ground mesh (fixed screen x).
  static const columns = 25;
  static const columnStep = 360.0 / (columns - 1);

  /// Mesh rows: flat-ground depths from below the screen to the horizon.
  static final Float64List rowZ = _rows();
  static final Float64List rowFlatY = Float64List.fromList(
      [for (final z in rowZ) horizon + _g * _z0 / z]);
  static int get rows => rowZ.length;

  static Float64List _rows() {
    final out = <double>[];
    var y = 636.0;
    while (y > 176) {
      out.add(_g * _z0 / (y - horizon));
      y -= (.035 * (y - horizon)).clamp(2.5, 7.0);
    }
    for (final top in const [174.6, 173.2, 172.4]) {
      out.add(_g * _z0 / (top - horizon));
    }
    return Float64List.fromList(out);
  }

  /// Depth where relief has faded out completely (toward the horizon).
  static const fadeNear = 6 * _z0, fadeFar = 12 * _z0;

  /// Relief kept in the central firing lane.
  static const laneRelief = .18;

  TerrainField? _a, _b;
  double _mix = 0;
  double cam = 0;
  final _fields = <int, TerrainField>{};

  TerrainField field(int sector, int route) =>
      _fields.putIfAbsent(sector * 16 + route, () => TerrainField(sector, route));

  /// The field the ground units and events follow (the dominant one).
  TerrainField get primary => _b != null && _mix >= .5 ? _b! : _a ?? field(0, 0);

  /// Sets the sector(s) under the camera; [mix] blends toward [far].
  void configure(int sector, int route, {int? far, int? farRoute, double mix = 0}) {
    final a = field(sector, route);
    final b = far == null || far == sector && (farRoute ?? route) == route
        ? null
        : field(far, farRoute ?? route);
    final m = b == null ? 0.0 : mix.clamp(0.0, 1.0);
    if (!identical(a, _a) || !identical(b, _b) || m != _mix) {
      _a = a;
      _b = b;
      _mix = m;
      _gridCam = double.nan;
    }
  }

  double get mix => _mix;

  /// Blended raw world height.
  double worldHeight(double s, double w) {
    final a = _a ?? field(0, 0);
    final b = _b;
    final ha = _mix >= 1 && b != null ? 0.0 : a.heightAt(s, w);
    if (b == null || _mix <= 0) return ha;
    final hb = b.heightAt(s, w);
    return ha + (hb - ha) * _mix;
  }

  /// Lateral world coordinate of screen [x] at depth [z].
  static double lateral(double x, double z) => (x - 180) * z / (2 * _z0);

  /// The relief's lateral frame: texels from the nearer screen edge line
  /// (negative on the left), like the walls, landmarks and props, so
  /// features hug the side bands at every depth while growing as they
  /// approach.
  static double edgeLateral(double x, double z) => x < 180
      ? -x * z / (2 * _z0)
      : (360 - x) * z / (2 * _z0);

  /// Envelope: gentle in the central lane, fading toward the horizon.
  static double envelope(double x, double z) {
    final d = (x - 180).abs();
    // Zero on the centre line (the two side frames meet there), the lane
    // share across the lane, full beyond it.
    final lane = laneRelief * _smoothstep(0, 40, d) +
        (1 - laneRelief) * _smoothstep(56, 100, d);
    final far = ((fadeFar - z) / (fadeFar - fadeNear)).clamp(0.0, 1.0);
    return lane * far;
  }

  /// Effective (displayed) height at screen [x] and depth [z], before
  /// occlusion: what `terrainHeight` is made of.
  double rawHeight(double x, double z) {
    final e = envelope(x, z);
    if (e <= 0) return 0;
    return worldHeight(edgeLateral(x, z), cam + z) * e;
  }

  // ---------------------------------------------------------------------
  // Grid
  // ---------------------------------------------------------------------

  double _gridCam = double.nan;
  final Float64List gridHeight = Float64List(columns * 160);
  final Float64List gridY = Float64List(columns * 160);
  final Float64List gridShade = Float64List(columns * 160);
  final Uint8List _hidden = Uint8List(columns * 160);

  /// Per-vertex light (1 = flat ground; lit slopes above, shadowed below)
  /// for the light of [profile].
  void _ensure() {
    if (_gridCam == cam) return;
    _gridCam = cam;
    final n = rows;
    for (var i = 0; i < n; i++) {
      final z = rowZ[i];
      final flat = rowFlatY[i];
      final k = 2 * _z0 / z;
      for (var j = 0; j < columns; j++) {
        final idx = i * columns + j;
        final h = rawHeight(j * columnStep, z);
        gridHeight[idx] = h;
        var y = flat - h * k;
        if (i > 0) {
          final nearer = gridY[idx - columns];
          if (y > nearer) {
            y = nearer;
            _hidden[idx] = 1;
          } else {
            _hidden[idx] = 0;
          }
        } else {
          _hidden[idx] = 0;
        }
        gridY[idx] = y;
      }
    }
    final light = primary.profile.light;
    for (var i = 0; i < n; i++) {
      final i0 = math.max(0, i - 1), i1 = math.min(n - 1, i + 1);
      final dw = rowZ[i1] - rowZ[i0];
      final ds = 2 * columnStep * rowZ[i] / (2 * _z0);
      for (var j = 0; j < columns; j++) {
        final j0 = math.max(0, j - 1), j1 = math.min(columns - 1, j + 1);
        final hs = (gridHeight[i * columns + j1] - gridHeight[i * columns + j0]) /
            (ds * (j1 - j0) / 2);
        final hw = (gridHeight[i1 * columns + j] - gridHeight[i0 * columns + j]) / dw;
        final norm = math.sqrt(hs * hs + hw * hw + 1);
        final dot = (-hs * light.$1 - hw * light.$2 + light.$3) / norm;
        final idx = i * columns + j;
        // Slope light, a little lift on high ground and depth in hollows,
        // and a dark band where ground disappears behind a crest.
        var shade = 1 + 3.0 * (dot - light.$3) + .016 * gridHeight[idx];
        if (_hidden[idx] == 1) shade *= .55;
        gridShade[idx] = shade.clamp(.3, 1.9);
      }
    }
  }

  /// Visible y of mesh vertex ([row], [col]) (fresh for [cam]).
  double vertexY(int row, int col) {
    _ensure();
    return gridY[row * columns + col];
  }

  double vertexShade(int row, int col) {
    _ensure();
    return gridShade[row * columns + col];
  }

  /// Makes sure the grid matches [cam] (painters read the arrays directly).
  void prepare() => _ensure();

  int _rowOf(double flatY) {
    // rowFlatY decreases with the index.
    var lo = 0, hi = rows - 1;
    if (flatY >= rowFlatY[0]) return 0;
    if (flatY <= rowFlatY[hi]) return hi - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (rowFlatY[mid] >= flatY) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  double _interp(Float64List g, int i, int j, double u, double t) {
    final v00 = g[i * columns + j], v01 = g[i * columns + j + 1];
    final v10 = g[(i + 1) * columns + j], v11 = g[(i + 1) * columns + j + 1];
    // The mesh splits each cell along (i, j+1)-(i+1, j).
    if (u + t <= 1) return v00 + u * (v01 - v00) + t * (v10 - v00);
    return v11 + (1 - u) * (v10 - v11) + (1 - t) * (v01 - v11);
  }

  /// The ground surface at screen [x] and depth [z]: height, visible y and
  /// world slope. Exactly where the ground mesh draws that ground point.
  TerrainSample surfaceAt(double x, double z) {
    _ensure();
    final flat = horizon + _g * _z0 / z;
    final i = _rowOf(flat);
    final t = ((rowFlatY[i] - flat) / (rowFlatY[i] - rowFlatY[i + 1]))
        .clamp(0.0, 1.0);
    final cx = (x / columnStep).clamp(0.0, columns - 1.0001);
    final j = cx.floor();
    final u = cx - j;
    final h = _interp(gridHeight, i, j, u, t);
    final y = _interp(gridY, i, j, u, t);
    final k = 2 * _z0 / z;
    final hidden = y < flat - h * k - .5;
    // World gradient by central differences of the effective height.
    final ds = 6.0 * z / (2 * _z0);
    final hs = (rawHeight(x + 6, z) - rawHeight(x - 6, z)) / (2 * ds);
    final dz = math.max(2.0, z * .02);
    final hw = (rawHeight(x, z + dz) - rawHeight(x, z - dz)) / (2 * dz);
    return TerrainSample(h, y, hs, hw, hidden);
  }

  /// Effective terrain height (texels) at screen [x] and depth [z].
  double terrainHeight(double x, double z) => surfaceAt(x, z).height;

  /// Visible screen y of the ground at [x], [z] (`GroundCamera.yOf(z)` on
  /// flat ground).
  double yOf(double x, double z) {
    _ensure();
    final flat = horizon + _g * _z0 / z;
    final i = _rowOf(flat);
    final t = ((rowFlatY[i] - flat) / (rowFlatY[i] - rowFlatY[i + 1]))
        .clamp(0.0, 1.0);
    final cx = (x / columnStep).clamp(0.0, columns - 1.0001);
    final j = cx.floor();
    return _interp(gridY, i, j, cx - j, t);
  }

  double _heightFast(double x, double z) {
    final flat = horizon + _g * _z0 / z;
    final i = _rowOf(flat);
    final t = ((rowFlatY[i] - flat) / (rowFlatY[i] - rowFlatY[i + 1]))
        .clamp(0.0, 1.0);
    final cx = (x / columnStep).clamp(0.0, columns - 1.0001);
    final j = cx.floor();
    return _interp(gridHeight, i, j, cx - j, t);
  }

  // ---------------------------------------------------------------------
  // Navigation (GroundRelief)
  // ---------------------------------------------------------------------

  static const _probe = [-1.0, -.5, 0.0, .5, 1.0];

  /// Where a ground unit drives: it keeps its logical depth [z], side and
  /// band, but winds toward lower, gentler ground inside its band (valley
  /// floors, around mesas), stands on the visible surface, and reports the
  /// slope along its travel (`climb` > 0 uphill toward the camera) and a
  /// visual `pace` (slower uphill). Never enters the central lane.
  @override
  GroundPose place(int side, double across, double width, double z,
      {bool ally = false}) {
    _ensure();
    final base = GroundCamera.bandX(side, across, width);
    final innerLimit = side == 0
        ? GroundCamera.laneLeft - width / 2
        : GroundCamera.laneRight + width / 2;
    final room = math.max(0.0, GroundCamera.laneLeft - 6 - width);
    final reach = .32 * room;
    var x = base;
    if (reach > 1 && z < fadeFar) {
      var sumW = 0.0, sumX = 0.0;
      var best = double.infinity;
      final costs = List<double>.filled(_probe.length, 0);
      for (var k = 0; k < _probe.length; k++) {
        final px = base + _probe[k] * reach;
        final h = _heightFast(px.clamp(0.0, 360.0), z);
        final c = h / 9 + .5 * _probe[k] * _probe[k];
        costs[k] = c;
        if (c < best) best = c;
      }
      for (var k = 0; k < _probe.length; k++) {
        final wgt = math.exp(-(costs[k] - best) / .35);
        sumW += wgt;
        sumX += wgt * (base + _probe[k] * reach);
      }
      x = sumX / sumW;
    }
    x = side == 0 ? math.min(x, innerLimit) : math.max(x, innerLimit);
    final px = x.clamp(0.0, 360.0);
    final y = yOf(px, z);
    final dz = 10.0;
    final ahead = _heightFast(px, math.max(GroundTuning.leaveZ * .8, z - dz));
    final behind = _heightFast(px, z + dz);
    final climb = (ahead - behind) / (2 * dz);
    final pace = (1 - 2.4 * climb).clamp(.5, 1.25);
    return GroundPose(x, y, climb: climb, pace: pace);
  }

  // ---------------------------------------------------------------------
  // Vegetation
  // ---------------------------------------------------------------------

  static const vegetationCell = 24.0;
  static const vegetationNear = .55 * _z0, vegetationFar = 7 * _z0;

  final _vegetation = <int, VegetationInstance>{};

  static final _speciesBySector = [
    for (var s = 0; s < 5; s++)
      [for (final v in VegetationAtlas.species) if (v.sector == s) v],
  ];

  VegetationInstance? _plant(TerrainField f, int side, int cell, int slot) {
    final species = _speciesBySector[f.sector.clamp(0, 4)];
    if (species.isEmpty) return null;
    final w = (cell + terrainRand(f.seed, side * 7 + slot, cell, 41)) *
        vegetationCell;
    final (theme, boost) = f.vegetationTheme(side, w);
    final density = (slot == 0 ? .2 : .04) + boost * (slot == 0 ? .75 : .6);
    if (terrainRand(f.seed, side * 7 + slot, cell, 42) > density) return null;
    VegetationSpecies pick;
    final r = terrainRand(f.seed, side * 7 + slot, cell, 43);
    final themed = [
      for (final v in species)
        if (switch (theme) {
          TerrainKind.forest => v.kind == 'tree' || v.kind == 'stalk' || v.kind == 'brush',
          TerrainKind.crystalField => v.kind == 'crystal',
          TerrainKind.ruins => v.kind == 'debris',
          _ => false,
        })
          v,
    ];
    final pool = themed.isNotEmpty && r < .85 ? themed : species;
    pick = pool[(terrainRand(f.seed, side, cell * 3 + slot, 44) * pool.length)
            .floor() %
        pool.length];
    final across = -.05 + terrainRand(f.seed, side, cell * 3 + slot, 45) * 1.0;
    final size = .8 + terrainRand(f.seed, side, cell * 3 + slot, 46) * .45;
    final id = ((f.sector * 32 + f.route) * 2 + side) * 4000000 + cell * 4 + slot;
    return VegetationInstance(id, pick, side, across, w, size);
  }

  /// Vegetation of the dominant field between depths [zNear] and [zFar],
  /// far to near (stateful instances: their push state persists).
  List<VegetationInstance> vegetation(
          [double zNear = vegetationNear, double zFar = vegetationFar]) =>
      vegetationOf(primary, zNear, zFar);

  /// Vegetation of [f] between [zNear] and [zFar], far to near.
  List<VegetationInstance> vegetationOf(TerrainField f,
      [double zNear = vegetationNear, double zFar = vegetationFar]) {
    final out = <VegetationInstance>[];
    final first = ((cam + zNear) / vegetationCell).floor() - 1;
    final last = ((cam + zFar) / vegetationCell).ceil();
    for (var cell = last; cell >= first; cell--) {
      if (cell < 2) continue;
      for (var side = 0; side < 2; side++) {
        for (var slot = 0; slot < 2; slot++) {
          final key = ((f.sector * 32 + f.route) * 2 + side) * 4000000 +
              cell * 4 + slot;
          var v = _vegetation[key];
          if (v == null) {
            if (_vegetation.containsKey(-key - 1)) continue;
            v = _plant(f, side, cell, slot);
            if (v == null) {
              _vegetation[-key - 1] = _none;
              continue;
            }
            _vegetation[key] = v;
          }
          final z = v.w - cam;
          if (z >= zNear && z <= zFar) out.add(v);
        }
      }
    }
    if (_vegetation.length > 3000) {
      _vegetation.removeWhere((k, v) => v.w < cam + vegetationNear * .5);
      if (_vegetation.length > 3000) _vegetation.clear();
    }
    return out;
  }

  static final _none = VegetationInstance(
      -1, VegetationAtlas.species.first, 0, 0, -1e9, 1);

  /// The plant nearest screen [x] at depth [z] within [radius] arena units
  /// (and a matching depth window), or null.
  VegetationInstance? vegetationAt(double x, double z, {double radius = 14}) {
    VegetationInstance? best;
    var bestD = double.infinity;
    final window = math.max(10.0, z * .05);
    for (final v in vegetation(math.max(vegetationNear, z - window), z + window)) {
      final d = (v.xAt(v.w - cam) - x).abs();
      if (d < radius && d < bestD) {
        best = v;
        bestD = d;
      }
    }
    return best;
  }

  /// Forget push states (a new run, a new sector).
  void resetVegetation() => _vegetation.clear();
}

/// Turns what the flyover shows into rate-limited radio events
/// ([GameEventNames.terrain]) for the comms. Visual only: it reads the
/// relief and the ground units, never the gameplay rules.
class TerrainRadio {
  TerrainRadio({void Function(GameEvent event)? emit})
      : emit = emit ?? dispatchGameEvent;
  void Function(GameEvent event) emit;

  static const aheadGap = 12.0, aheadKindGap = 30.0;
  static const climbGap = 15.0, clearGap = 12.0, stuckGap = 45.0;

  /// Feature window ahead (depth texels): about 25-35 s out at base speed.
  static const aheadNear = 3.2 * GroundCamera.z0,
      aheadFar = 4.2 * GroundCamera.z0;
  static const climbSlope = .18, stuckSlope = .4;
  static const climbHold = .4, stuckHold = 1.0;

  double clock = 0;
  double _ahead = -1e9, _climb = -1e9, _clear = -1e9, _stuck = -1e9;
  final _kindAt = <TerrainKind, double>{};
  final _announced = <int>{};
  final _climbT = <int, double>{};
  final _stuckT = <int, double>{};

  /// The last events sent (tests, diagnostics).
  final List<GameEvent> log = [];

  void reset() {
    clock = 0;
    _ahead = _climb = _clear = _stuck = -1e9;
    _kindAt.clear();
    _announced.clear();
    _climbT.clear();
    _stuckT.clear();
  }

  void _send(String name, Map<String, Object?> data) {
    final e = GameEvent(name, data);
    log.add(e);
    if (log.length > 64) log.removeAt(0);
    emit(e);
  }

  /// Announces the next notable feature of [field] entering the window.
  void lookAhead(TerrainField field, double cam, int sector) {
    final first = ((cam + aheadNear) / TerrainField.segment).floor() - 1;
    final last = ((cam + aheadFar) / TerrainField.segment).floor() + 1;
    for (var j = first; j <= last; j++) {
      final f = field.feature(j);
      if (!f.notable) continue;
      final z = f.w - cam;
      if (z < aheadNear || z > aheadFar) continue;
      final key = field.seed * 100000 + j;
      if (!_announced.add(key)) continue;
      if (_announced.length > 200) _announced.remove(_announced.first);
      if (clock - _ahead < aheadGap) continue;
      if (clock - (_kindAt[f.kind] ?? -1e9) < aheadKindGap) continue;
      _ahead = clock;
      _kindAt[f.kind] = clock;
      _send(GameEventNames.terrainAhead, {
        'sector': sector,
        'kind': f.kind.name,
        'side': f.sideName,
      });
    }
  }

  /// Climb tracking for one live allied unit (call every frame).
  void ally(int id, int side, double climb, double dt, double x, double y,
      int sector) {
    final t = climb > climbSlope ? (_climbT[id] ?? 0) + dt : 0.0;
    _climbT[id] = t;
    if (t >= climbHold && clock - _climb >= climbGap) {
      _climb = clock;
      _send(GameEventNames.convoyClimbing, {
        'sector': sector,
        'side': side == 0 ? 'left' : 'right',
        'x': x,
        'y': y,
      });
    }
    final st = climb > stuckSlope ? (_stuckT[id] ?? 0) + dt : 0.0;
    _stuckT[id] = st;
    if (st >= stuckHold && clock - _stuck >= stuckGap) {
      _stuck = clock;
      _stuckT[id] = -1e9; // once per wall
      _send(GameEventNames.convoyStuck, {
        'sector': sector,
        'side': side == 0 ? 'left' : 'right',
        'x': x,
        'y': y,
      });
    }
    if (_climbT.length > 64) {
      _climbT.clear();
      _stuckT.clear();
    }
  }

  /// An allied unit pushed through [v].
  void cleared(VegetationInstance v, double x, double y, int sector) {
    if (clock - _clear < clearGap) return;
    _clear = clock;
    _send(GameEventNames.convoyClearingVegetation, {
      'sector': sector,
      'side': v.side == 0 ? 'left' : 'right',
      'kind': v.species.kind,
      'species': v.species.id,
      'x': x,
      'y': y,
    });
  }
}
