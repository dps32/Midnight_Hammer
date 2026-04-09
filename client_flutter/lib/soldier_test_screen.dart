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
import 'runtime_transform.dart' as runtime_transform;

class SoldierTestScreen extends ScreenAdapter {
  static const double maxFrameSeconds = 0.25;
  static const double moveSpeed = 120.0;
  static const double playerBoundsPadding = 6.0;
  static const double playerRenderSize = 16.0;
  static const double playerHitboxSize = 12.0;
  static const double pickupRadius = 18.0;
  static const ui.Color testBackgroundColor = ui.Color(0xFFFFFFFF);
  static const String soldierTexturePath = 'levels/media/soldier_2.png';

  static const List<_LootDef> lootDefs = <_LootDef>[
    _LootDef('MP5_2', 'levels/media/MP5_2.png', 512, 512, true),
    _LootDef('assault_rifle_2', 'levels/media/assault_rifle_2.png', 32, 12, true),
    _LootDef('ak47_2', 'levels/media/ak47_2.png', 250, 120, true),
    _LootDef('awp_2', 'levels/media/awp_2.png', 2560, 640, true),
    _LootDef('glock_2', 'levels/media/glock_2.png', 49, 49, true),
    _LootDef('grenade launcher beige_2', 'levels/media/grenade launcher beige_2.png', 42, 19, true),
    _LootDef('smg_2', 'levels/media/smg_2.png', 34, 15, true),
    _LootDef('shotgun_2', 'levels/media/shotgun_2.png', 39, 10, true),
    _LootDef('rpg_2', 'levels/media/rpg_2.png', 39, 16, true),
    _LootDef('grenades_by_mtk_2', 'levels/media/grenades_by_mtk_2.png', 128, 64, false),
    _LootDef('dron2d_2', 'levels/media/dron2d_2.png', 626, 626, false),
  ];

  final GameApp game;
  final int levelIndex;

  final OrthographicCamera camera = OrthographicCamera();
  final LevelRenderer levelRenderer = LevelRenderer();

  late final LevelData levelData;
  late final Viewport viewport;
  late final List<bool> layerVisibilityStates;
  late final Array<SpriteRuntimeState> spriteRuntimeStates;
  late final Array<runtime_transform.RuntimeTransform> layerRuntimeStates;
  late final List<ui.Rect> wallCollisionRects;
  late final List<_GroundLoot> groundLoot;

  late SpriteRuntimeState playerSpriteState;
  int playerSpriteIndex = -1;
  Vector2 playerVelocity = Vector2(0, 0);
  String currentDirection = 'down';
  double animationStateTime = 0;
  double renderAnchorX = 0.5;
  double renderAnchorY = 0.5;

  final List<_LootDef?> hotbar = List<_LootDef?>.filled(9, null, growable: false);
  int selectedHotbarSlot = 0;

  ui.Color backgroundColor = testBackgroundColor;
  double elapsedSeconds = 0;

  SoldierTestScreen(this.game, this.levelIndex) {
    levelData = LevelLoader.loadLevel(levelIndex);
    viewport = _createViewport(levelData, camera);
    layerVisibilityStates = _buildInitialLayerVisibility(levelData);
    spriteRuntimeStates = _createHiddenTemplateRuntimes(levelData);
    layerRuntimeStates = _createLayerRuntimeStates(levelData);
    wallCollisionRects = _buildWallCollisionRects(levelData);
    groundLoot = _spawnBattlefieldLoot();

    _queueRequiredAssets();
    _applyInitialCameraFromLevel();
    viewport.update(
      Gdx.graphics.getWidth().toDouble(),
      Gdx.graphics.getHeight().toDouble(),
      false,
    );

    for (int i = 0; i < levelData.sprites.size; i++) {
      final LevelSprite sprite = levelData.sprites.get(i);
      if (sprite.type == 'Player') {
        playerSpriteIndex = i;
        playerSpriteState = spriteRuntimeStates.get(i);
        playerSpriteState.visible = false;
        break;
      }
    }

    backgroundColor = testBackgroundColor;
    if (playerSpriteIndex >= 0) {
      playerSpriteState.worldX = levelData.worldWidth * 0.5;
      playerSpriteState.worldY = levelData.worldHeight * 0.5;
    }
  }

  @override
  void render(double delta) {
    elapsedSeconds += math.max(0, math.min(delta, maxFrameSeconds));

    game.getAssetManager().update();

    _handleHotbarInput();
    _handlePickupInput();
    _updateMovementFromKeyboard();
    _updatePlayerMovement(delta);
    _updateCameraForPlayer();

    viewport.apply();
    ScreenUtils.clear(backgroundColor);

    final SpriteBatch batch = game.getBatch();
    batch.setProjectionMatrix(camera.combined);
    batch.begin();

    levelRenderer.render(
      levelData,
      game.getAssetManager(),
      batch,
      camera,
      spriteRuntimeStates,
      layerVisibilityStates,
      layerRuntimeStates,
      viewport,
    );

    _drawGroundLoot(batch);
    _drawScaledPlayer(batch);
    _drawEquippedItem(batch);

    batch.end();

    _drawHotbarHud();
  }

  void _queueRequiredAssets() {
    final AssetManager assets = game.getAssetManager();
    if (!assets.isLoaded(soldierTexturePath, Texture)) {
      assets.load(soldierTexturePath, Texture);
    }
    for (final _LootDef def in lootDefs) {
      if (!assets.isLoaded(def.texturePath, Texture)) {
        assets.load(def.texturePath, Texture);
      }
    }
  }

  List<_GroundLoot> _spawnBattlefieldLoot() {
    final List<_GroundLoot> out = <_GroundLoot>[];
    final double centerX = levelData.worldWidth * 0.5;
    final double centerY = levelData.worldHeight * 0.5;

    const int cols = 6;
    const double spacing = 28;
    for (int i = 0; i < lootDefs.length; i++) {
      final int col = i % cols;
      final int row = i ~/ cols;
      final double x = centerX - ((cols - 1) * spacing * 0.5) + col * spacing;
      final double y = centerY - 80 + row * spacing;
      out.add(_GroundLoot(lootDefs[i], x, y, i * 0.47));
    }
    return out;
  }

  void _drawGroundLoot(SpriteBatch batch) {
    for (final _GroundLoot loot in groundLoot) {
      if (loot.picked) {
        continue;
      }
      final TextureRegion? region = _regionForLoot(loot.def);
      if (region == null) {
        continue;
      }

      final double hover = math.sin(elapsedSeconds * 2.4 + loot.phase) * 2.0;
      final double size = loot.def.isWeapon ? 14.0 : 12.0;
      final double left = loot.x - size * 0.5;
      final double top = loot.y - size * 0.5 + hover;
      final ui.Rect dst = viewport.worldToScreenRect(left, top, size, size);

      batch.drawRegion(region.texture, region.srcRect, dst);
    }
  }

  void _drawScaledPlayer(SpriteBatch batch) {
    if (playerSpriteIndex < 0) {
      return;
    }

    final AssetManager assets = game.getAssetManager();
    if (!assets.isLoaded(soldierTexturePath, Texture)) {
      return;
    }

    final Texture texture = assets.get(soldierTexturePath, Texture);
    final List<List<TextureRegion>> regions = splitTexture(texture, 330, 333);
    if (regions.isEmpty || regions.first.isEmpty) {
      return;
    }

    final int rows = regions.length;
    final int cols = regions.first.length;
    final int total = rows * cols;
    final int frame = math.max(0, math.min(total - 1, playerSpriteState.frameIndex));
    final int srcCol = frame % cols;
    final int srcRow = frame ~/ cols;

    final TextureRegion region = regions[srcRow][srcCol];
    final double left = playerSpriteState.worldX - playerRenderSize * renderAnchorX;
    final double top = playerSpriteState.worldY - playerRenderSize * renderAnchorY;
    final ui.Rect dst = viewport.worldToScreenRect(left, top, playerRenderSize, playerRenderSize);

    batch.drawRegion(region.texture, region.srcRect, dst);
  }

  void _drawEquippedItem(SpriteBatch batch) {
    final _LootDef? equipped = hotbar[selectedHotbarSlot];
    if (equipped == null) {
      return;
    }

    final TextureRegion? region = _regionForLoot(equipped);
    if (region == null) {
      return;
    }

    final ui.Offset dir = _directionUnit();
    final double holdDistance = 8.5;
    final double size = equipped.isWeapon ? 10.0 : 8.0;

    final double cx = playerSpriteState.worldX + dir.dx * holdDistance;
    final double cy = playerSpriteState.worldY + dir.dy * holdDistance;
    final ui.Rect dst = viewport.worldToScreenRect(
      cx - size * 0.5,
      cy - size * 0.5,
      size,
      size,
    );

    batch.drawRegion(region.texture, region.srcRect, dst);
  }

  TextureRegion? _regionForLoot(_LootDef def) {
    final AssetManager assets = game.getAssetManager();
    if (!assets.isLoaded(def.texturePath, Texture)) {
      return null;
    }
    final Texture texture = assets.get(def.texturePath, Texture);
    final int w = math.max(1, math.min(def.frameWidth, texture.width));
    final int h = math.max(1, math.min(def.frameHeight, texture.height));
    final List<List<TextureRegion>> regions = splitTexture(texture, w, h);
    if (regions.isEmpty || regions.first.isEmpty) {
      return null;
    }
    return regions.first.first;
  }

  void _handlePickupInput() {
    if (!Gdx.input.isKeyJustPressed(Input.keys.e)) {
      return;
    }

    int nearestIndex = -1;
    double nearestDist2 = double.infinity;
    for (int i = 0; i < groundLoot.length; i++) {
      final _GroundLoot loot = groundLoot[i];
      if (loot.picked) {
        continue;
      }
      final double dx = loot.x - playerSpriteState.worldX;
      final double dy = loot.y - playerSpriteState.worldY;
      final double dist2 = dx * dx + dy * dy;
      if (dist2 <= pickupRadius * pickupRadius && dist2 < nearestDist2) {
        nearestDist2 = dist2;
        nearestIndex = i;
      }
    }

    if (nearestIndex < 0) {
      return;
    }

    final _GroundLoot loot = groundLoot[nearestIndex];
    final int slot = _findTargetSlotForPickup();
    if (slot < 0) {
      return;
    }

    hotbar[slot] = loot.def;
    loot.picked = true;
  }

  int _findTargetSlotForPickup() {
    if (hotbar[selectedHotbarSlot] == null) {
      return selectedHotbarSlot;
    }
    for (int i = 0; i < hotbar.length; i++) {
      if (hotbar[i] == null) {
        return i;
      }
    }
    return -1;
  }

  void _handleHotbarInput() {
    if (Gdx.input.isKeyJustPressed(Input.keys.digit1)) selectedHotbarSlot = 0;
    if (Gdx.input.isKeyJustPressed(Input.keys.digit2)) selectedHotbarSlot = 1;
    if (Gdx.input.isKeyJustPressed(Input.keys.digit3)) selectedHotbarSlot = 2;
    if (Gdx.input.isKeyJustPressed(Input.keys.digit4)) selectedHotbarSlot = 3;
    if (Gdx.input.isKeyJustPressed(Input.keys.digit5)) selectedHotbarSlot = 4;
    if (Gdx.input.isKeyJustPressed(Input.keys.digit6)) selectedHotbarSlot = 5;
    if (Gdx.input.isKeyJustPressed(Input.keys.digit7)) selectedHotbarSlot = 6;
    if (Gdx.input.isKeyJustPressed(Input.keys.digit8)) selectedHotbarSlot = 7;
    if (Gdx.input.isKeyJustPressed(Input.keys.digit9)) selectedHotbarSlot = 8;
  }

  void _drawHotbarHud() {
    final double totalWidth = 9 * 34.0 + 8 * 4.0;
    final double startX = (viewport.screenWidth - totalWidth) * 0.5;
    final double y = viewport.screenHeight - 52;

    final ShapeRenderer shapes = game.getShapeRenderer();
    shapes.begin(ShapeType.filled);
    for (int i = 0; i < 9; i++) {
      final double x = startX + i * 38.0;
      final bool selected = i == selectedHotbarSlot;
      shapes.setColor(selected ? const ui.Color(0xFFE6B800) : const ui.Color(0xAA1E1E1E));
      shapes.rect(x, y, 34, 34);
    }
    shapes.end();

    shapes.begin(ShapeType.line);
    for (int i = 0; i < 9; i++) {
      final double x = startX + i * 38.0;
      shapes.setColor(const ui.Color(0xFFFFFFFF));
      shapes.rect(x, y, 34, 34);
    }
    shapes.end();

    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();
    batch.begin();

    for (int i = 0; i < 9; i++) {
      final double x = startX + i * 38.0;
      final _LootDef? item = hotbar[i];
      if (item != null) {
        final TextureRegion? region = _regionForLoot(item);
        if (region != null) {
          final ui.Rect dst = ui.Rect.fromLTWH(x + 8, y + 8, 18, 18);
          batch.drawRegion(region.texture, region.srcRect, dst);
        }
      }
      font.setColor(const ui.Color(0xFFFAFAFA));
      font.drawText('${i + 1}', x + 2, y + 11);
    }

    font.setColor(const ui.Color(0xFF0F0F0F));
    font.drawText('E recoger  |  1..9 equipar', 18, viewport.screenHeight - 16);

    batch.end();
  }

  ui.Offset _directionUnit() {
    switch (currentDirection) {
      case 'up':
        return const ui.Offset(0, -1);
      case 'down':
        return const ui.Offset(0, 1);
      case 'left':
        return const ui.Offset(-1, 0);
      case 'right':
        return const ui.Offset(1, 0);
      case 'up-left':
        return const ui.Offset(-0.707, -0.707);
      case 'up-right':
        return const ui.Offset(0.707, -0.707);
      case 'down-left':
        return const ui.Offset(-0.707, 0.707);
      case 'down-right':
        return const ui.Offset(0.707, 0.707);
      default:
        return const ui.Offset(0, 1);
    }
  }

  void _updateMovementFromKeyboard() {
    playerVelocity.x = 0;
    playerVelocity.y = 0;

    final bool up = Gdx.input.isKeyPressed(Input.keys.up) || Gdx.input.isKeyPressed(Input.keys.w);
    final bool down = Gdx.input.isKeyPressed(Input.keys.down) || Gdx.input.isKeyPressed(Input.keys.s);
    final bool left = Gdx.input.isKeyPressed(Input.keys.left) || Gdx.input.isKeyPressed(Input.keys.a);
    final bool right = Gdx.input.isKeyPressed(Input.keys.right) || Gdx.input.isKeyPressed(Input.keys.d);

    if (up) playerVelocity.y = -moveSpeed;
    if (down) playerVelocity.y = moveSpeed;
    if (left) playerVelocity.x = -moveSpeed;
    if (right) playerVelocity.x = moveSpeed;

    _updateDirectionAnimation(up, down, left, right);
  }

  void _updateDirectionAnimation(bool up, bool down, bool left, bool right) {
    String newDirection = currentDirection;

    if (up && left) {
      newDirection = 'up-left';
    } else if (up && right) {
      newDirection = 'up-right';
    } else if (down && left) {
      newDirection = 'down-left';
    } else if (down && right) {
      newDirection = 'down-right';
    } else if (up) {
      newDirection = 'up';
    } else if (down) {
      newDirection = 'down';
    } else if (left) {
      newDirection = 'left';
    } else if (right) {
      newDirection = 'right';
    }

    if (newDirection != currentDirection) {
      currentDirection = newDirection;
      _changeSoldierAnimationForDirection(newDirection);
    }
  }

  void _changeSoldierAnimationForDirection(String direction) {
    final Map<String, String> animationMap = <String, String>{
      'up': 'anim_1773416849964663',
      'down': 'anim_1773416599518464',
      'left': 'anim_4',
      'right': 'anim_5',
      'up-left': 'anim_1773416849964663',
      'up-right': 'anim_1773416849964663',
      'down-left': 'anim_6',
      'down-right': 'anim_7',
    };

    final String? animationId = animationMap[direction];
    if (animationId != null && playerSpriteIndex >= 0) {
      playerSpriteState.animationId = animationId;
      playerSpriteState.frameIndex = 0;
      animationStateTime = 0;
    }
  }

  void _updatePlayerMovement(double delta) {
    if (playerSpriteIndex < 0) {
      return;
    }

    final double halfHitbox = playerHitboxSize * 0.5;
    final double minX = playerBoundsPadding + halfHitbox;
    final double minY = playerBoundsPadding + halfHitbox;
    final double maxX = math.max(minX, levelData.worldWidth - playerBoundsPadding - halfHitbox);
    final double maxY = math.max(minY, levelData.worldHeight - playerBoundsPadding - halfHitbox);

    final double currentX = playerSpriteState.worldX;
    final double currentY = playerSpriteState.worldY;

    final double proposedX = (currentX + playerVelocity.x * delta).clamp(minX, maxX);
    final ui.Rect rectAfterX = ui.Rect.fromLTWH(
      proposedX - halfHitbox,
      currentY - halfHitbox,
      playerHitboxSize,
      playerHitboxSize,
    );
    if (!_collidesWall(rectAfterX)) {
      playerSpriteState.worldX = proposedX;
    }

    final double proposedY = (playerSpriteState.worldY + playerVelocity.y * delta).clamp(minY, maxY);
    final ui.Rect rectAfterY = ui.Rect.fromLTWH(
      playerSpriteState.worldX - halfHitbox,
      proposedY - halfHitbox,
      playerHitboxSize,
      playerHitboxSize,
    );
    if (!_collidesWall(rectAfterY)) {
      playerSpriteState.worldY = proposedY;
    }

    _updateAnimationFrame(delta);
  }

  void _updateAnimationFrame(double delta) {
    if (playerSpriteState.animationId == null) {
      return;
    }

    final AnimationClip? clip = levelData.animationClips.get(playerSpriteState.animationId!);
    if (clip == null) {
      return;
    }

    animationStateTime += delta;
    final double frameDuration = 1.0 / clip.fps;
    final int frameCount = clip.endFrame - clip.startFrame + 1;

    int frameOffset = (animationStateTime / frameDuration).toInt();
    if (clip.loop && frameCount > 0) {
      frameOffset = frameOffset % frameCount;
    } else {
      frameOffset = frameOffset.clamp(0, frameCount - 1);
    }

    playerSpriteState.frameIndex = clip.startFrame + frameOffset;

    final FrameRig? frameRig = clip.frameRigs.get(playerSpriteState.frameIndex);
    renderAnchorX = frameRig?.anchorX ?? clip.anchorX;
    renderAnchorY = frameRig?.anchorY ?? clip.anchorY;
  }

  void _updateCameraForPlayer() {
    final double worldW = math.max(1, levelData.worldWidth);
    final double worldH = math.max(1, levelData.worldHeight);
    final double halfW = math.max(1, viewport.worldWidth * camera.zoom * 0.5);
    final double halfH = math.max(1, viewport.worldHeight * camera.zoom * 0.5);

    final double minCamX = halfW;
    final double maxCamX = math.max(halfW, worldW - halfW);
    final double minCamY = halfH;
    final double maxCamY = math.max(halfH, worldH - halfH);

    final double targetX = playerSpriteState.worldX.clamp(minCamX, maxCamX);
    final double targetY = playerSpriteState.worldY.clamp(minCamY, maxCamY);

    camera.setPosition(targetX, targetY);
    camera.update();
  }

  Viewport _createViewport(LevelData level, OrthographicCamera cam) {
    return FitViewport(level.viewportWidth, level.viewportHeight, cam);
  }

  List<bool> _buildInitialLayerVisibility(LevelData level) {
    final List<bool> visibilities = <bool>[];
    for (int i = 0; i < level.layers.size; i++) {
      visibilities.add(level.layers.get(i).visible);
    }
    return visibilities;
  }

  Array<SpriteRuntimeState> _createHiddenTemplateRuntimes(LevelData level) {
    final Array<SpriteRuntimeState> runtimes = Array<SpriteRuntimeState>();
    for (int i = 0; i < level.sprites.size; i++) {
      final LevelSprite sprite = level.sprites.get(i);
      runtimes.add(
        SpriteRuntimeState(
          sprite.frameIndex,
          sprite.anchorX,
          sprite.anchorY,
          sprite.x,
          sprite.y,
          false,
          sprite.flipX,
          sprite.flipY,
          sprite.width.round(),
          sprite.height.round(),
          sprite.texturePath,
          sprite.animationId,
        ),
      );
    }
    return runtimes;
  }

  Array<runtime_transform.RuntimeTransform> _createLayerRuntimeStates(LevelData level) {
    final Array<runtime_transform.RuntimeTransform> states = Array<runtime_transform.RuntimeTransform>();
    for (int i = 0; i < level.layers.size; i++) {
      final LevelLayer layer = level.layers.get(i);
      states.add(runtime_transform.RuntimeTransform(layer.x, layer.y));
    }
    return states;
  }

  List<ui.Rect> _buildWallCollisionRects(LevelData level) {
    final List<ui.Rect> out = <ui.Rect>[];
    for (final LevelZone zone in level.zones.iterable()) {
      final String name = zone.name.trim().toLowerCase();
      final String type = zone.type.trim().toLowerCase();
      final bool isWall = type.contains('wall') || name.contains('wall') || type.contains('mur') || name.contains('mur');
      if (isWall) {
        out.add(ui.Rect.fromLTWH(zone.x, zone.y, zone.width, zone.height));
      }
    }
    return out;
  }

  bool _collidesWall(ui.Rect rect) {
    for (final ui.Rect wall in wallCollisionRects) {
      if (rect.overlaps(wall)) {
        return true;
      }
    }
    return false;
  }

  void _applyInitialCameraFromLevel() {
    camera.setPosition(
      levelData.viewportX + levelData.viewportWidth / 2,
      levelData.viewportY + levelData.viewportHeight / 2,
    );
  }

  @override
  void resize(int width, int height) {
    viewport.update(width.toDouble(), height.toDouble(), false);
  }

  @override
  void show() {}

  @override
  void dispose() {}
}

class _LootDef {
  final String id;
  final String texturePath;
  final int frameWidth;
  final int frameHeight;
  final bool isWeapon;

  const _LootDef(this.id, this.texturePath, this.frameWidth, this.frameHeight, this.isWeapon);
}

class _GroundLoot {
  final _LootDef def;
  final double x;
  final double y;
  final double phase;
  bool picked = false;

  _GroundLoot(this.def, this.x, this.y, this.phase);
}
