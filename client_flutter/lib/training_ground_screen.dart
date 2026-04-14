import 'dart:math' as math;
import 'dart:ui' as ui;

import 'game_app.dart';
import 'libgdx_compat/asset_manager.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/gdx.dart';
import 'libgdx_compat/gdx_collections.dart';
import 'libgdx_compat/math_types.dart';
import 'libgdx_compat/viewport.dart';
import 'level_data.dart';
import 'level_loader.dart';
import 'level_renderer.dart';
import 'runtime_transform.dart';

class TrainingGroundScreen extends ScreenAdapter {
  static const double hudMargin = 18;
  static const double hotbarSlotSize = 46;
  static const double hotbarSlotGap = 8;
  static const double playerWidth = 26;
  static const double playerHeight = 30;
  static const double playerSpeed = 170;
  static const double pickupRange = 36;

  static final ui.Color hudPanel = colorValueOf('0A0F16CC');
  static final ui.Color hudStroke = colorValueOf('4A95FF');
  static final ui.Color hpColor = colorValueOf('35FF74');
  static final ui.Color shieldColor = colorValueOf('43B6FF');
  static final ui.Color slotSelected = colorValueOf('FFE07A');
  static final ui.Color slotIdle = colorValueOf('7FA0BF');
  static final ui.Color crosshairColor = colorValueOf('FFFFFF');

  final GameApp game;
  final int levelIndex;
  final OrthographicCamera camera = OrthographicCamera();
  final LevelRenderer renderer = LevelRenderer();

  late final LevelData levelData;
  late final Viewport viewport;
  late final Array<RuntimeTransform> layerRuntimeStates;
  late final Array<SpriteRuntimeState> mapSpriteRuntimeStates;
  late final List<LevelZone> wallZones;

  final List<_GroundWeapon> _groundWeapons = <_GroundWeapon>[];
  final List<_WeaponSlot?> _hotbar = List<_WeaponSlot?>.filled(5, null);
  final List<_Tracer> _tracers = <_Tracer>[];

  double elapsedSeconds = 0;
  double playerX = 64;
  double playerY = 64;
  double health = 100;
  double maxHealth = 100;
  double shield = 50;
  double maxShield = 100;
  int selectedSlot = 0;

  String facing = 'down';
  bool moving = false;
  ui.Offset crosshairScreen = const ui.Offset(400, 320);

  TrainingGroundScreen(this.game, this.levelIndex) {
    levelData = LevelLoader.loadLevel(levelIndex);
    viewport = _createViewport(levelData, camera);
    layerRuntimeStates = _createLayerRuntimeStates(levelData);
    mapSpriteRuntimeStates = _createVisibleSpriteRuntimes(levelData);
    wallZones = levelData.zones
        .iterable()
        .where((LevelZone zone) => normalize(zone.type) == 'wall')
        .toList(growable: false);

    playerX = levelData.viewportX + 38;
    playerY = levelData.viewportY + 38;
    crosshairScreen = ui.Offset(
      Gdx.graphics.getWidth().toDouble() * 0.6,
      Gdx.graphics.getHeight().toDouble() * 0.45,
    );
    _spawnInitialWeapons();
    _updateCamera();
    viewport.update(
      Gdx.graphics.getWidth().toDouble(),
      Gdx.graphics.getHeight().toDouble(),
      false,
    );
  }

  @override
  void render(double delta) {
    final double dt = math.max(0, math.min(0.1, delta));
    elapsedSeconds += dt;

    _handleInput(dt);
    _updateTracers(dt);
    _updateCamera();

    viewport.apply();
    ScreenUtils.clear(levelData.backgroundColor);

    final SpriteBatch batch = game.getBatch();
    batch.begin();
    renderer.render(
      levelData,
      game.getAssetManager(),
      batch,
      camera,
      mapSpriteRuntimeStates,
      List<bool>.generate(
        levelData.layers.size,
        (int index) => levelData.layers.get(index).visible,
      ),
      layerRuntimeStates,
      viewport,
    );
    _drawGroundWeapons(batch);
    _drawPlayer(batch);
    batch.end();

    _drawAimingFx();
    _drawHud();
  }

  @override
  void resize(int width, int height) {
    viewport.update(width.toDouble(), height.toDouble(), false);
    crosshairScreen = ui.Offset(
      clampDouble(crosshairScreen.dx, 0, width.toDouble()),
      clampDouble(crosshairScreen.dy, 0, height.toDouble()),
    );
    _updateCamera();
  }

  void _handleInput(double dt) {
    crosshairScreen = ui.Offset(
      clampDouble(Gdx.input.getX().toDouble(), 0, Gdx.graphics.getWidth().toDouble()),
      clampDouble(Gdx.input.getY().toDouble(), 0, Gdx.graphics.getHeight().toDouble()),
    );

    for (int i = 0; i < _hotbar.length; i++) {
      if (_isSlotKeyPressed(i)) {
        selectedSlot = i;
      }
    }

    if (Gdx.input.isKeyJustPressed(Input.keys.e)) {
      _tryPickupWeapon();
    }
    if (Gdx.input.isKeyJustPressed(Input.keys.q)) {
      _dropSelectedWeapon();
    }

    if (Gdx.input.justTouched() || Gdx.input.isKeyJustPressed(Input.keys.space)) {
      _fireSelectedWeapon();
    }

    final bool left =
        Gdx.input.isKeyPressed(Input.keys.left) || Gdx.input.isKeyPressed(Input.keys.a);
    final bool right =
        Gdx.input.isKeyPressed(Input.keys.right) || Gdx.input.isKeyPressed(Input.keys.d);
    final bool up = Gdx.input.isKeyPressed(Input.keys.up) || Gdx.input.isKeyPressed(Input.keys.w);
    final bool down =
        Gdx.input.isKeyPressed(Input.keys.down) || Gdx.input.isKeyPressed(Input.keys.s);

    double moveX = 0;
    double moveY = 0;
    if (left) {
      moveX -= 1;
    }
    if (right) {
      moveX += 1;
    }
    if (up) {
      moveY -= 1;
    }
    if (down) {
      moveY += 1;
    }

    moving = moveX != 0 || moveY != 0;
    if (moving) {
      final double length = math.sqrt(moveX * moveX + moveY * moveY);
      moveX /= length;
      moveY /= length;
      _movePlayer(moveX * playerSpeed * dt, moveY * playerSpeed * dt);
      facing = _facingFromVector(moveX, moveY);
    }
  }

  void _movePlayer(double dx, double dy) {
    double nextX = playerX + dx;
    double nextY = playerY;
    final ui.Rect xRect = ui.Rect.fromLTWH(nextX, nextY, playerWidth, playerHeight);
    if (_collidesWithWall(xRect)) {
      nextX = playerX;
    }

    nextY = playerY + dy;
    final ui.Rect yRect = ui.Rect.fromLTWH(nextX, nextY, playerWidth, playerHeight);
    if (_collidesWithWall(yRect)) {
      nextY = playerY;
    }

    playerX = nextX;
    playerY = nextY;
  }

  bool _collidesWithWall(ui.Rect playerRect) {
    for (final LevelZone zone in wallZones) {
      final ui.Rect wallRect = ui.Rect.fromLTWH(zone.x, zone.y, zone.width, zone.height);
      if (playerRect.overlaps(wallRect)) {
        return true;
      }
    }
    return false;
  }

  void _updateCamera() {
    final double worldW = math.max(1, levelData.worldWidth);
    final double worldH = math.max(1, levelData.worldHeight);
    final double viewW = math.max(1, viewport.worldWidth);
    final double viewH = math.max(1, viewport.worldHeight);
    final double halfW = viewW * 0.5;
    final double halfH = viewH * 0.5;
    final double targetX = clampDouble(playerX + playerWidth * 0.5, halfW, worldW - halfW);
    final double targetY = clampDouble(playerY + playerHeight * 0.5, halfH, worldH - halfH);
    camera.setPosition(targetX, targetY);
    camera.update();
  }

  void _drawPlayer(SpriteBatch batch) {
    final _DirectionalClips clips = _resolveSoldierClips();
    final int frameIndex = clips.forFacing(facing);
    final String texturePath = clips.texturePath;

    final AssetManager assets = game.getAssetManager();
    if (!assets.isLoaded(texturePath, Texture)) {
      return;
    }

    final Texture texture = assets.get(texturePath, Texture);
    final int frameW = math.max(1, clips.frameWidth);
    final int frameH = math.max(1, clips.frameHeight);
    final int cols = math.max(1, texture.width ~/ frameW);

    final int animationOffset = moving ? ((elapsedSeconds * 8).floor() % 2) : 0;
    final int animatedFrame = math.max(0, frameIndex + animationOffset);
    final int srcCol = animatedFrame % cols;
    final int srcRow = animatedFrame ~/ cols;

    final double bob = moving ? math.sin(elapsedSeconds * 13) * 1.4 : 0;
    final ui.Rect dst = viewport.worldToScreenRect(playerX, playerY + bob, playerWidth, playerHeight);
    final ui.Rect src = ui.Rect.fromLTWH(
      (srcCol * frameW).toDouble(),
      (srcRow * frameH).toDouble(),
      frameW.toDouble(),
      frameH.toDouble(),
    );
    batch.drawRegion(texture, src, dst);
  }

  void _drawGroundWeapons(SpriteBatch batch) {
    final AssetManager assets = game.getAssetManager();
    for (final _GroundWeapon weapon in _groundWeapons) {
      if (!assets.isLoaded(weapon.texturePath, Texture)) {
        continue;
      }
      final Texture texture = assets.get(weapon.texturePath, Texture);
      final double floatOffset = math.sin(elapsedSeconds * 2.3 + weapon.phase) * 3.8;
      final ui.Rect dst = viewport.worldToScreenRect(
        weapon.x - 15,
        weapon.y - 11 + floatOffset,
        30,
        30,
      );
      final ui.Rect src = ui.Rect.fromLTWH(0, 0, texture.width.toDouble(), texture.height.toDouble());
      batch.drawRegion(texture, src, dst);
    }
  }

  void _drawAimingFx() {
    final ShapeRenderer shapes = game.getShapeRenderer();
    final ui.Offset playerScreen = viewport.worldToScreenPoint(
      playerX + playerWidth * 0.5,
      playerY + playerHeight * 0.35,
    );

    shapes.begin(ShapeType.line);
    shapes.setColor(colorValueOf('FFFFFF4A'));
    shapes.line(playerScreen.dx, playerScreen.dy, crosshairScreen.dx, crosshairScreen.dy);

    for (final _Tracer tracer in _tracers) {
      final int alpha = (255 * tracer.life).clamp(0, 255).toInt();
      final String alphaHex = alpha.toRadixString(16).padLeft(2, '0').toUpperCase();
      shapes.setColor(colorValueOf('FFE07A$alphaHex'));
      shapes.line(tracer.from.dx, tracer.from.dy, tracer.to.dx, tracer.to.dy);
    }

    shapes.setColor(crosshairColor);
    shapes.circle(crosshairScreen.dx, crosshairScreen.dy, 12, 24);
    shapes.line(crosshairScreen.dx - 17, crosshairScreen.dy, crosshairScreen.dx - 8, crosshairScreen.dy);
    shapes.line(crosshairScreen.dx + 8, crosshairScreen.dy, crosshairScreen.dx + 17, crosshairScreen.dy);
    shapes.line(crosshairScreen.dx, crosshairScreen.dy - 17, crosshairScreen.dx, crosshairScreen.dy - 8);
    shapes.line(crosshairScreen.dx, crosshairScreen.dy + 8, crosshairScreen.dx, crosshairScreen.dy + 17);
    shapes.end();
  }

  void _drawHud() {
    final double screenW = Gdx.graphics.getWidth().toDouble();
    final double screenH = Gdx.graphics.getHeight().toDouble();
    final double hotbarWidth = _hotbar.length * hotbarSlotSize + (_hotbar.length - 1) * hotbarSlotGap;
    final double hotbarX = (screenW - hotbarWidth) * 0.5;
    final double hotbarY = screenH - hudMargin - hotbarSlotSize;

    final ShapeRenderer shapes = game.getShapeRenderer();
    shapes.begin(ShapeType.filled);
    shapes.setColor(hudPanel);
    shapes.rect(hotbarX - 14, hotbarY - 62, hotbarWidth + 28, hotbarSlotSize + 74);
    shapes.end();

    shapes.begin(ShapeType.line);
    shapes.setColor(hudStroke);
    shapes.rect(hotbarX - 14, hotbarY - 62, hotbarWidth + 28, hotbarSlotSize + 74);

    for (int i = 0; i < _hotbar.length; i++) {
      final double x = hotbarX + i * (hotbarSlotSize + hotbarSlotGap);
      shapes.setColor(i == selectedSlot ? slotSelected : slotIdle);
      shapes.rect(x, hotbarY, hotbarSlotSize, hotbarSlotSize);
    }

    final double hpRatio = clampDouble(maxHealth <= 0 ? 0 : health / maxHealth, 0, 1);
    final double shRatio = clampDouble(maxShield <= 0 ? 0 : shield / maxShield, 0, 1);
    final double barX = hotbarX;
    const double barW = 260;
    const double barH = 12;
    final double hpY = hotbarY - 40;
    final double shieldY = hotbarY - 22;

    shapes.setColor(colorValueOf('0B121A'));
    shapes.rect(barX, hpY, barW, barH);
    shapes.rect(barX, shieldY, barW, barH);
    shapes.setColor(hpColor);
    shapes.rect(barX, hpY, barW * hpRatio, barH);
    shapes.setColor(shieldColor);
    shapes.rect(barX, shieldY, barW * shRatio, barH);

    shapes.setColor(slotIdle);
    shapes.rect(barX, hpY, barW, barH);
    shapes.rect(barX, shieldY, barW, barH);
    shapes.end();

    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();
    final AssetManager assets = game.getAssetManager();

    batch.begin();
    font.setColor(colorValueOf('DDEEFF'));
    font.getData().setScale(0.9);
    font.drawText('HP ${health.round()} / ${maxHealth.round()}', barX + 6, hpY - 4);
    font.drawText('ESCUT ${shield.round()} / ${maxShield.round()}', barX + 6, shieldY - 4);
    font.drawText('E: recollir   Q: deixar   1-5: seleccionar', hotbarX, hotbarY + hotbarSlotSize + 28);
    font.getData().setScale(1);

    for (int i = 0; i < _hotbar.length; i++) {
      final _WeaponSlot? slot = _hotbar[i];
      if (slot == null || !assets.isLoaded(slot.texturePath, Texture)) {
        continue;
      }
      final Texture texture = assets.get(slot.texturePath, Texture);
      final double x = hotbarX + i * (hotbarSlotSize + hotbarSlotGap);
      final ui.Rect src = ui.Rect.fromLTWH(0, 0, texture.width.toDouble(), texture.height.toDouble());
      final ui.Rect dst = ui.Rect.fromLTWH(x + 5, hotbarY + 5, hotbarSlotSize - 10, hotbarSlotSize - 10);
      batch.drawRegion(texture, src, dst);
    }

    batch.end();
  }

  void _spawnInitialWeapons() {
    const List<String> weaponFiles = <String>[
      'levels/media/ak47_2.png',
      'levels/media/awp_2.png',
      'levels/media/escopeta_2.png',
      'levels/media/glock_2.png',
      'levels/media/rifle_asalto_2.png',
      'levels/media/smg_2.png',
    ];

    final double centerX = levelData.viewportX + levelData.viewportWidth * 0.5;
    final double centerY = levelData.viewportY + levelData.viewportHeight * 0.6;

    int index = 0;
    for (final String texturePath in weaponFiles) {
      _groundWeapons.add(
        _GroundWeapon(
          id: 'weapon_$index',
          name: texturePath.split('/').last,
          texturePath: texturePath,
          x: centerX + (index % 3) * 44,
          y: centerY + (index ~/ 3) * 38,
          phase: index * 0.8,
        ),
      );
      index++;
    }
  }

  bool _isSlotKeyPressed(int index) {
    switch (index) {
      case 0:
        return Gdx.input.isKeyJustPressed(Input.keys.num1);
      case 1:
        return Gdx.input.isKeyJustPressed(Input.keys.num2);
      case 2:
        return Gdx.input.isKeyJustPressed(Input.keys.num3);
      case 3:
        return Gdx.input.isKeyJustPressed(Input.keys.num4);
      case 4:
        return Gdx.input.isKeyJustPressed(Input.keys.num5);
      default:
        return false;
    }
  }

  void _tryPickupWeapon() {
    if (_groundWeapons.isEmpty) {
      return;
    }

    int nearestIndex = -1;
    double nearestDistance = double.infinity;
    final double cx = playerX + playerWidth * 0.5;
    final double cy = playerY + playerHeight * 0.5;

    for (int i = 0; i < _groundWeapons.length; i++) {
      final _GroundWeapon weapon = _groundWeapons[i];
      final double dx = weapon.x - cx;
      final double dy = weapon.y - cy;
      final double d = math.sqrt(dx * dx + dy * dy);
      if (d < nearestDistance) {
        nearestDistance = d;
        nearestIndex = i;
      }
    }

    if (nearestIndex < 0 || nearestDistance > pickupRange) {
      return;
    }

    final _GroundWeapon weapon = _groundWeapons.removeAt(nearestIndex);
    final _WeaponSlot? current = _hotbar[selectedSlot];
    _hotbar[selectedSlot] = _WeaponSlot(weapon.name, weapon.texturePath);
    if (current != null) {
      _groundWeapons.add(
        _GroundWeapon(
          id: 'drop_${elapsedSeconds}_$selectedSlot',
          name: current.name,
          texturePath: current.texturePath,
          x: cx + 12,
          y: cy + 4,
          phase: elapsedSeconds,
        ),
      );
    }
  }

  void _dropSelectedWeapon() {
    final _WeaponSlot? slot = _hotbar[selectedSlot];
    if (slot == null) {
      return;
    }

    final ui.Offset playerScreen = viewport.worldToScreenPoint(
      playerX + playerWidth * 0.5,
      playerY + playerHeight * 0.4,
    );
    final double aimDx = crosshairScreen.dx - playerScreen.dx;
    final double aimDy = crosshairScreen.dy - playerScreen.dy;
    final double length = math.max(1, math.sqrt(aimDx * aimDx + aimDy * aimDy));
    final double nx = aimDx / length;
    final double ny = aimDy / length;

    _groundWeapons.add(
      _GroundWeapon(
        id: 'drop_${elapsedSeconds}_$selectedSlot',
        name: slot.name,
        texturePath: slot.texturePath,
        x: playerX + playerWidth * 0.5 + nx * 28,
        y: playerY + playerHeight * 0.5 + ny * 28,
        phase: elapsedSeconds,
      ),
    );
    _hotbar[selectedSlot] = null;
  }

  void _fireSelectedWeapon() {
    final _WeaponSlot? slot = _hotbar[selectedSlot];
    if (slot == null) {
      return;
    }
    final ui.Offset playerScreen = viewport.worldToScreenPoint(
      playerX + playerWidth * 0.5,
      playerY + playerHeight * 0.35,
    );
    _tracers.add(_Tracer(from: playerScreen, to: crosshairScreen, life: 1));
  }

  void _updateTracers(double dt) {
    for (int i = _tracers.length - 1; i >= 0; i--) {
      final _Tracer tracer = _tracers[i];
      final double nextLife = tracer.life - dt * 5;
      if (nextLife <= 0) {
        _tracers.removeAt(i);
      } else {
        _tracers[i] = _Tracer(from: tracer.from, to: tracer.to, life: nextLife);
      }
    }
  }

  String _facingFromVector(double moveX, double moveY) {
    if (moveY < -0.2 && moveX > 0.2) {
      return 'upRight';
    }
    if (moveY < -0.2 && moveX < -0.2) {
      return 'upLeft';
    }
    if (moveY > 0.2 && moveX > 0.2) {
      return 'downRight';
    }
    if (moveY > 0.2 && moveX < -0.2) {
      return 'downLeft';
    }
    if (moveY < -0.2) {
      return 'up';
    }
    if (moveY > 0.2) {
      return 'down';
    }
    if (moveX < 0) {
      return 'left';
    }
    return 'right';
  }

  _DirectionalClips _resolveSoldierClips() {
    int frame(String name, int fallback) {
      for (final MapEntry<String, AnimationClip> entry in levelData.animationClips.entries()) {
        if (normalize(entry.value.name) == normalize(name)) {
          return entry.value.startFrame;
        }
      }
      return fallback;
    }

    String texturePath = 'levels/media/soldier_2.png';
    int frameWidth = 333;
    int frameHeight = 333;
    for (final MapEntry<String, AnimationClip> entry in levelData.animationClips.entries()) {
      final AnimationClip clip = entry.value;
      if (normalize(clip.name).contains('soldier') && clip.texturePath != null) {
        texturePath = clip.texturePath!;
        frameWidth = clip.frameWidth > 0 ? clip.frameWidth : frameWidth;
        frameHeight = clip.frameHeight > 0 ? clip.frameHeight : frameHeight;
        break;
      }
    }

    return _DirectionalClips(
      texturePath: texturePath,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      down: frame('soldier down', 0),
      up: frame('soldier up', 1),
      right: frame('soldier right', 4),
      left: frame('soldier left', 6),
      downRight: frame('soldier down-right', 3),
      downLeft: frame('soldier down-left', 5),
    );
  }

  Viewport _createViewport(LevelData data, OrthographicCamera targetCamera) {
    switch (data.viewportAdaptation) {
      case 'expand':
        return ExtendViewport(data.viewportWidth, data.viewportHeight, targetCamera);
      case 'stretch':
        return StretchViewport(data.viewportWidth, data.viewportHeight, targetCamera);
      case 'letterbox':
      default:
        return FitViewport(data.viewportWidth, data.viewportHeight, targetCamera);
    }
  }

  Array<RuntimeTransform> _createLayerRuntimeStates(LevelData data) {
    final Array<RuntimeTransform> runtimes = Array<RuntimeTransform>();
    for (int i = 0; i < data.layers.size; i++) {
      final LevelLayer layer = data.layers.get(i);
      runtimes.add(RuntimeTransform(layer.x, layer.y));
    }
    return runtimes;
  }

  Array<SpriteRuntimeState> _createVisibleSpriteRuntimes(LevelData data) {
    final Array<SpriteRuntimeState> runtimes = Array<SpriteRuntimeState>();
    for (int i = 0; i < data.sprites.size; i++) {
      final LevelSprite sprite = data.sprites.get(i);
      runtimes.add(
        SpriteRuntimeState(
          sprite.frameIndex,
          sprite.anchorX,
          sprite.anchorY,
          sprite.x,
          sprite.y,
          true,
          sprite.flipX,
          sprite.flipY,
          math.max(1, sprite.width.round()),
          math.max(1, sprite.height.round()),
          sprite.texturePath,
          sprite.animationId,
        ),
      );
    }
    return runtimes;
  }
}

class _DirectionalClips {
  final String texturePath;
  final int frameWidth;
  final int frameHeight;
  final int down;
  final int up;
  final int right;
  final int left;
  final int downRight;
  final int downLeft;

  const _DirectionalClips({
    required this.texturePath,
    required this.frameWidth,
    required this.frameHeight,
    required this.down,
    required this.up,
    required this.right,
    required this.left,
    required this.downRight,
    required this.downLeft,
  });

  int forFacing(String facing) {
    switch (facing) {
      case 'up':
      case 'upRight':
      case 'upLeft':
        return up;
      case 'left':
        return left;
      case 'right':
        return right;
      case 'downRight':
        return downRight;
      case 'downLeft':
        return downLeft;
      case 'down':
      default:
        return down;
    }
  }
}

class _GroundWeapon {
  final String id;
  final String name;
  final String texturePath;
  final double x;
  final double y;
  final double phase;

  const _GroundWeapon({
    required this.id,
    required this.name,
    required this.texturePath,
    required this.x,
    required this.y,
    required this.phase,
  });
}

class _WeaponSlot {
  final String name;
  final String texturePath;

  const _WeaponSlot(this.name, this.texturePath);
}

class _Tracer {
  final ui.Offset from;
  final ui.Offset to;
  final double life;

  const _Tracer({required this.from, required this.to, required this.life});
}
