import 'dart:math' as math;
import 'dart:ui' as ui;

import 'app_data.dart';
import 'debug_overlay.dart';
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
import 'player_list_renderer.dart';
import 'runtime_transform.dart';
import 'waiting_room_screen.dart';

class PlayScreen extends ScreenAdapter {
  static const double leaderboardWidth = 320;
  static const double leaderboardPadding = 14;
  static const double leaderboardRowHeight = 24;
  static const double leaderboardStartY = 92;
  static const double maxFrameSeconds = 0.25;
  static const double remotePlayerOpacity = 0.5;
  static const double localPlayerRingPadding = 6;
  static const double hudSlotSize = 42;
  static const double hudSlotGap = 8;

  static final ui.Color panelFill = colorValueOf('09140CCC');
  static final ui.Color panelStroke = colorValueOf('35FF74');
  static final ui.Color titleColor = colorValueOf('FFFFFF');
  static final ui.Color textColor = colorValueOf('D8FFE3');
  static final ui.Color dimTextColor = colorValueOf('76A784');
  static final ui.Color localPlayerColor = colorValueOf('FFE07A');
  static final ui.Color winnerOverlayColor = colorValueOf('000000B8');
  static final ui.Color hudPanelColor = colorValueOf('0A0F16CC');
  static final ui.Color hudStrokeColor = colorValueOf('7FA0BF');
  static final ui.Color hpColor = colorValueOf('35FF74');
  static final ui.Color shieldColor = colorValueOf('43B6FF');

  final GameApp game;
  final int levelIndex;
  final OrthographicCamera camera = OrthographicCamera();
  final LevelRenderer levelRenderer = LevelRenderer();
  final DebugOverlay debugOverlay = DebugOverlay();
  final GlyphLayout layout = GlyphLayout();

  late final LevelData levelData;
  late final Viewport viewport;
  late final List<bool> layerVisibilityStates;
  late final Array<SpriteRuntimeState> spriteRuntimeStates;
  late final Array<RuntimeTransform> layerRuntimeStates;
  late final Array<RuntimeTransform> zoneRuntimeStates;
  late final LevelSprite playerTemplate;
  late final Map<String, LevelSprite> gemTemplateByType;

  double elapsedSeconds = 0;
  String _lastSubmittedDirection = 'none';
  bool _showDebugOverlay = false;
  ui.Offset? _localPlayerHighlightCenter;
  double? _localPlayerHighlightRadius;
  ui.Offset _crosshair = const ui.Offset(400, 300);

  PlayScreen(this.game, this.levelIndex) {
    levelData = LevelLoader.loadLevel(levelIndex);
    viewport = _createViewport(levelData, camera);
    layerVisibilityStates = _buildInitialLayerVisibility(levelData);
    spriteRuntimeStates = _createHiddenTemplateRuntimes(levelData);
    layerRuntimeStates = _createLayerRuntimeStates(levelData);
    zoneRuntimeStates = _createZoneRuntimeStates(levelData);
    playerTemplate = _findPlayerTemplate(levelData);
    gemTemplateByType = _buildGemTemplates(levelData);
    _applyInitialCameraFromLevel();
    viewport.update(
      Gdx.graphics.getWidth().toDouble(),
      Gdx.graphics.getHeight().toDouble(),
      false,
    );
  }

  @override
  void render(double delta) {
    elapsedSeconds += math.max(0, math.min(delta, maxFrameSeconds));

    final AppData appData = game.getAppData();
    if (appData.phase == MatchPhase.waiting ||
        appData.phase == MatchPhase.connecting) {
      _submitDirection(appData, 'none');
      game.setScreen(WaitingRoomScreen(game, levelIndex));
      return;
    }

    if (Gdx.input.isKeyJustPressed(Input.keys.f3)) {
      _showDebugOverlay = !_showDebugOverlay;
    }

    _submitDirection(appData, _readCurrentDirection());
    _updateAimAndShoot(appData);
    _applyServerLayerTransforms(appData.layerTransforms);
    _applyServerZoneTransforms(appData.zoneTransforms);
    _updateCameraForGameplay(appData.localPlayer);

    viewport.apply();
    ScreenUtils.clear(levelData.backgroundColor);

    final SpriteBatch batch = game.getBatch();
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
    _renderGems(batch, appData.gems);
    _renderPlayers(batch, appData.sortedPlayers, appData.playerId);
    batch.end();
    if (_showDebugOverlay) {
      debugOverlay.render(
        levelData,
        camera,
        true,
        true,
        zoneRuntimeStates,
        viewport,
      );
    }
    _renderLocalPlayerHighlight();
    _renderCrosshair();
    _renderCombatHud(appData.localPlayer);

    _renderLeaderboard(appData);
    if (appData.phase == MatchPhase.finished) {
      _renderWinnerOverlay(appData);
    }
  }

  @override
  void resize(int width, int height) {
    viewport.update(width.toDouble(), height.toDouble(), false);
    _updateCameraForGameplay(game.getAppData().localPlayer);
  }

  @override
  void dispose() {
    _submitDirection(game.getAppData(), 'none');
    debugOverlay.dispose();
  }

  void _renderPlayers(
    SpriteBatch batch,
    List<MultiplayerPlayer> players,
    String? localPlayerId,
  ) {
    _localPlayerHighlightCenter = null;
    _localPlayerHighlightRadius = null;
    final ui.Color previousBatchColor = batch.getColor();
    bool usingRemotePlayerOpacity = false;
    final List<MultiplayerPlayer> orderedPlayers =
        List<MultiplayerPlayer>.from(players)
          ..sort((MultiplayerPlayer a, MultiplayerPlayer b) {
            final bool aIsLocal = a.id == localPlayerId;
            final bool bIsLocal = b.id == localPlayerId;
            if (aIsLocal == bIsLocal) {
              return 0;
            }
            return aIsLocal ? 1 : -1;
          });

    for (final MultiplayerPlayer player in orderedPlayers) {
      final _AnimatedSpriteFrame frame = _playerFrameFor(player);
      final bool isLocalPlayer = player.id == localPlayerId;
      if (!isLocalPlayer) {
        if (!usingRemotePlayerOpacity) {
          batch.setColor(1, 1, 1, remotePlayerOpacity);
          usingRemotePlayerOpacity = true;
        }
      } else if (usingRemotePlayerOpacity) {
        batch.setColor(previousBatchColor);
        usingRemotePlayerOpacity = false;
      }
      _drawAnimatedSprite(
        batch,
        frame: frame,
        worldX: player.x,
        worldY: player.y,
        width: player.width,
        height: player.height,
        flipX: frame.flipX,
      );
      if (isLocalPlayer) {
        final ui.Rect dst = viewport.worldToScreenRect(
          player.x,
          player.y,
          player.width,
          player.height,
        );
        _localPlayerHighlightCenter = ui.Offset(
          dst.left + dst.width * frame.anchorX,
          dst.top + dst.height * frame.anchorY,
        );
        _localPlayerHighlightRadius =
            math.max(dst.width, dst.height) * 0.5 + localPlayerRingPadding;
      }
    }
    if (usingRemotePlayerOpacity) {
      batch.setColor(previousBatchColor);
    }
  }

  void _renderGems(SpriteBatch batch, List<MultiplayerGem> gems) {
    for (final MultiplayerGem gem in gems) {
      final LevelSprite template =
          gemTemplateByType[gem.type] ?? gemTemplateByType['green']!;
      final _AnimatedSpriteFrame frame = _frameFromTemplate(template);
      _drawAnimatedSprite(
        batch,
        frame: frame,
        worldX: gem.x,
        worldY: gem.y,
        width: gem.width,
        height: gem.height,
      );
    }
  }

  void _drawAnimatedSprite(
    SpriteBatch batch, {
    required _AnimatedSpriteFrame frame,
    required double worldX,
    required double worldY,
    required double width,
    required double height,
    bool flipX = false,
  }) {
    final AssetManager assets = game.getAssetManager();
    if (!assets.isLoaded(frame.texturePath, Texture)) {
      return;
    }

    final ui.Rect dst = viewport.worldToScreenRect(
      worldX,
      worldY,
      width,
      height,
    );
    final Texture texture = assets.get(frame.texturePath, Texture);
    final ui.Rect src = _frameSourceRect(
      texture,
      frame.frameWidth,
      frame.frameHeight,
      frame.frameIndex,
    );
    batch.drawRegion(texture, src, dst, flipX: flipX);
  }

  void _renderLocalPlayerHighlight() {
    final ui.Offset? center = _localPlayerHighlightCenter;
    final double? radius = _localPlayerHighlightRadius;
    if (center == null || radius == null) {
      return;
    }
    final ShapeRenderer shapes = game.getShapeRenderer();
    shapes.begin(ShapeType.line);
    shapes.setColor(localPlayerColor);
    shapes.circle(center.dx, center.dy, radius, 24);
    shapes.setColor(colorValueOf('FFE07A88'));
    shapes.circle(center.dx, center.dy, math.max(4, radius - 3), 24);
    shapes.end();
  }

  void _updateAimAndShoot(AppData appData) {
    _crosshair = ui.Offset(
      clampDouble(
        Gdx.input.getX().toDouble(),
        0,
        Gdx.graphics.getWidth().toDouble(),
      ),
      clampDouble(
        Gdx.input.getY().toDouble(),
        0,
        Gdx.graphics.getHeight().toDouble(),
      ),
    );

    if (!(Gdx.input.justTouched() || Gdx.input.isKeyJustPressed(Input.keys.space))) {
      return;
    }
    final ui.Offset target = _screenToWorld(_crosshair.dx, _crosshair.dy);
    appData.shootAt(target.dx, target.dy);
  }

  ui.Offset _screenToWorld(double sx, double sy) {
    final double viewW = viewport.worldWidth * camera.zoom;
    final double viewH = viewport.worldHeight * camera.zoom;
    final double left = camera.x - viewW * 0.5;
    final double top = camera.y - viewH * 0.5;
    return ui.Offset(
      left + (sx / viewport.screenWidth) * viewW,
      top + (sy / viewport.screenHeight) * viewH,
    );
  }

  void _renderCrosshair() {
    final ShapeRenderer shapes = game.getShapeRenderer();
    shapes.begin(ShapeType.line);
    shapes.setColor(colorValueOf('FFFFFF'));
    shapes.circle(_crosshair.dx, _crosshair.dy, 11, 20);
    shapes.line(_crosshair.dx - 17, _crosshair.dy, _crosshair.dx - 8, _crosshair.dy);
    shapes.line(_crosshair.dx + 8, _crosshair.dy, _crosshair.dx + 17, _crosshair.dy);
    shapes.line(_crosshair.dx, _crosshair.dy - 17, _crosshair.dx, _crosshair.dy - 8);
    shapes.line(_crosshair.dx, _crosshair.dy + 8, _crosshair.dx, _crosshair.dy + 17);
    shapes.end();
  }

  void _renderCombatHud(MultiplayerPlayer? localPlayer) {
    if (localPlayer == null) {
      return;
    }

    final double screenW = Gdx.graphics.getWidth().toDouble();
    final double screenH = Gdx.graphics.getHeight().toDouble();
    final double slotsWidth = hudSlotSize * 5 + hudSlotGap * 4;
    final double x = (screenW - leaderboardWidth - slotsWidth) * 0.5;
    final double y = screenH - 56;

    final ShapeRenderer shapes = game.getShapeRenderer();
    shapes.begin(ShapeType.filled);
    shapes.setColor(hudPanelColor);
    shapes.rect(x - 14, y - 64, slotsWidth + 28, 112);
    shapes.end();

    shapes.begin(ShapeType.line);
    shapes.setColor(hudStrokeColor);
    shapes.rect(x - 14, y - 64, slotsWidth + 28, 112);
    for (int i = 0; i < 5; i++) {
      final double slotX = x + i * (hudSlotSize + hudSlotGap);
      shapes.rect(slotX, y, hudSlotSize, hudSlotSize);
    }

    final double hpRatio = clampDouble(
      localPlayer.maxHealth <= 0 ? 0 : localPlayer.health / localPlayer.maxHealth,
      0,
      1,
    );
    final double shieldRatio = clampDouble(
      localPlayer.maxShield <= 0 ? 0 : localPlayer.shield / localPlayer.maxShield,
      0,
      1,
    );
    const double barW = 220;
    const double barH = 10;
    final double barX = x;
    final double hpY = y - 40;
    final double shY = y - 22;
    shapes.setColor(colorValueOf('0B121A'));
    shapes.rect(barX, hpY, barW, barH);
    shapes.rect(barX, shY, barW, barH);
    shapes.setColor(hpColor);
    shapes.rect(barX, hpY, barW * hpRatio, barH);
    shapes.setColor(shieldColor);
    shapes.rect(barX, shY, barW * shieldRatio, barH);
    shapes.setColor(hudStrokeColor);
    shapes.rect(barX, hpY, barW, barH);
    shapes.rect(barX, shY, barW, barH);
    shapes.end();
  }

  void _renderLeaderboard(AppData appData) {
    final double screenWidth = Gdx.graphics.getWidth().toDouble();
    final double screenHeight = Gdx.graphics.getHeight().toDouble();
    final ShapeRenderer shapes = game.getShapeRenderer();
    shapes.begin(ShapeType.filled);
    shapes.setColor(panelFill);
    shapes.rect(
      screenWidth - leaderboardWidth,
      0,
      leaderboardWidth,
      screenHeight,
    );
    shapes.end();

    shapes.begin(ShapeType.line);
    shapes.setColor(panelStroke);
    shapes.rect(
      screenWidth - leaderboardWidth,
      0,
      leaderboardWidth,
      screenHeight,
    );
    shapes.end();

    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();
    batch.begin();

    _drawLeftAlignedText(
      batch,
      font,
      'Leaderboard',
      screenWidth - leaderboardWidth + leaderboardPadding,
      34,
      1.45,
      titleColor,
    );
    _drawLeftAlignedText(
      batch,
      font,
      'Remaining gems: ${appData.remainingGems}',
      screenWidth - leaderboardWidth + leaderboardPadding,
      64,
      1.0,
      dimTextColor,
    );

    PlayerListRenderer.render(
      batch: batch,
      font: font,
      layout: layout,
      players: appData.sortedPlayers,
      localPlayerId: appData.playerId,
      left: screenWidth - leaderboardWidth + leaderboardPadding,
      right: screenWidth - leaderboardPadding,
      startY: leaderboardStartY,
      textColor: textColor,
      localPlayerColor: localPlayerColor,
      drawLeftAlignedText: _drawLeftAlignedText,
      drawRightAlignedText: _drawRightAlignedText,
      style: PlayerListRenderer.gameplayStyle,
    );

    if (appData.sortedPlayers.isEmpty) {
      _drawLeftAlignedText(
        batch,
        font,
        'Waiting for players...',
        screenWidth - leaderboardWidth + leaderboardPadding,
        leaderboardStartY,
        1.0,
        dimTextColor,
      );
    }

    batch.end();
  }

  void _renderWinnerOverlay(AppData appData) {
    final ShapeRenderer shapes = game.getShapeRenderer();
    final double screenWidth = Gdx.graphics.getWidth().toDouble();
    final double screenHeight = Gdx.graphics.getHeight().toDouble();
    shapes.begin(ShapeType.filled);
    shapes.setColor(winnerOverlayColor);
    shapes.rect(0, 0, screenWidth, screenHeight);
    shapes.end();

    final MultiplayerPlayer? winner = appData.sortedPlayers.isEmpty
        ? null
        : appData.sortedPlayers.first;
    final String title = winner == null
        ? 'Match Finished'
        : '${winner.name} wins with ${winner.score}';

    final SpriteBatch batch = game.getBatch();
    final BitmapFont font = game.getFont();
    batch.begin();
    _drawCenteredText(
      batch,
      font,
      title,
      screenHeight * 0.46,
      2.2,
      titleColor,
      maxWidth: screenWidth - leaderboardWidth,
    );
    _drawCenteredText(
      batch,
      font,
      'All gems were collected.',
      screenHeight * 0.53,
      1.15,
      textColor,
      maxWidth: screenWidth - leaderboardWidth,
    );
    batch.end();
  }

  void _submitDirection(AppData appData, String direction) {
    if (_lastSubmittedDirection == direction) {
      return;
    }
    _lastSubmittedDirection = direction;
    appData.updateMovementDirection(direction);
  }

  String _readCurrentDirection() {
    final bool left =
        Gdx.input.isKeyPressed(Input.keys.left) ||
        Gdx.input.isKeyPressed(Input.keys.a);
    final bool right =
        Gdx.input.isKeyPressed(Input.keys.right) ||
        Gdx.input.isKeyPressed(Input.keys.d);
    final bool up =
        Gdx.input.isKeyPressed(Input.keys.up) ||
        Gdx.input.isKeyPressed(Input.keys.w);
    final bool down =
        Gdx.input.isKeyPressed(Input.keys.down) ||
        Gdx.input.isKeyPressed(Input.keys.s);

    if (up && left) {
      return 'upLeft';
    }
    if (up && right) {
      return 'upRight';
    }
    if (down && left) {
      return 'downLeft';
    }
    if (down && right) {
      return 'downRight';
    }
    if (up) {
      return 'up';
    }
    if (down) {
      return 'down';
    }
    if (left) {
      return 'left';
    }
    if (right) {
      return 'right';
    }
    return 'none';
  }

  void _applyInitialCameraFromLevel() {
    final double centerX = levelData.viewportX + levelData.viewportWidth * 0.5;
    final double centerY = levelData.viewportY + levelData.viewportHeight * 0.5;
    camera.setPosition(centerX, centerY);
    camera.update();
  }

  void _updateCameraForGameplay(MultiplayerPlayer? player) {
    if (player == null) {
      camera.update();
      return;
    }

    final double worldW = math.max(1, levelData.worldWidth);
    final double worldH = math.max(1, levelData.worldHeight);
    final double viewW = math.max(1, viewport.worldWidth);
    final double viewH = math.max(1, viewport.worldHeight);
    final double halfW = viewW * 0.5;
    final double halfH = viewH * 0.5;
    final double targetX = clampDouble(
      player.x + player.width * 0.5,
      halfW,
      worldW - halfW,
    );
    final double targetY = clampDouble(
      player.y + player.height * 0.5,
      halfH,
      worldH - halfH,
    );

    camera.setPosition(targetX, targetY);
    camera.update();
  }

  Viewport _createViewport(LevelData data, OrthographicCamera targetCamera) {
    switch (data.viewportAdaptation) {
      case 'expand':
        return ExtendViewport(
          data.viewportWidth,
          data.viewportHeight,
          targetCamera,
        );
      case 'stretch':
        return StretchViewport(
          data.viewportWidth,
          data.viewportHeight,
          targetCamera,
        );
      case 'letterbox':
      default:
        return FitViewport(
          data.viewportWidth,
          data.viewportHeight,
          targetCamera,
        );
    }
  }

  List<bool> _buildInitialLayerVisibility(LevelData data) {
    return List<bool>.generate(
      data.layers.size,
      (int index) => data.layers.get(index).visible,
    );
  }

  Array<SpriteRuntimeState> _createHiddenTemplateRuntimes(LevelData data) {
    final Array<SpriteRuntimeState> runtimes = Array<SpriteRuntimeState>();
    for (int i = 0; i < data.sprites.size; i++) {
      final LevelSprite sprite = data.sprites.get(i);
      runtimes.add(
        SpriteRuntimeState(
          sprite.frameIndex,
          0,
          0,
          sprite.x,
          sprite.y,
          false,
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

  Array<RuntimeTransform> _createLayerRuntimeStates(LevelData data) {
    final Array<RuntimeTransform> runtimes = Array<RuntimeTransform>();
    for (int i = 0; i < data.layers.size; i++) {
      final LevelLayer layer = data.layers.get(i);
      runtimes.add(RuntimeTransform(layer.x, layer.y));
    }
    return runtimes;
  }

  Array<RuntimeTransform> _createZoneRuntimeStates(LevelData data) {
    final Array<RuntimeTransform> runtimes = Array<RuntimeTransform>();
    for (int i = 0; i < data.zones.size; i++) {
      final LevelZone zone = data.zones.get(i);
      runtimes.add(RuntimeTransform(zone.x, zone.y));
    }
    return runtimes;
  }

  void _applyServerLayerTransforms(List<TransformSnapshot> transforms) {
    for (final TransformSnapshot transform in transforms) {
      if (transform.index < 0 || transform.index >= layerRuntimeStates.size) {
        continue;
      }
      final RuntimeTransform runtime = layerRuntimeStates.get(transform.index);
      runtime.x = transform.x;
      runtime.y = transform.y;
    }
  }

  void _applyServerZoneTransforms(List<TransformSnapshot> transforms) {
    for (final TransformSnapshot transform in transforms) {
      if (transform.index < 0 || transform.index >= zoneRuntimeStates.size) {
        continue;
      }
      final RuntimeTransform runtime = zoneRuntimeStates.get(transform.index);
      runtime.x = transform.x;
      runtime.y = transform.y;
    }
  }

  LevelSprite _findPlayerTemplate(LevelData data) {
    for (final LevelSprite sprite in data.sprites.iterable()) {
      if (normalize(sprite.type).contains('hero')) {
        return sprite;
      }
    }
    return data.sprites.first();
  }

  Map<String, LevelSprite> _buildGemTemplates(LevelData data) {
    final Map<String, LevelSprite> templates = <String, LevelSprite>{};
    for (final LevelSprite sprite in data.sprites.iterable()) {
      final String type = normalize(sprite.type);
      if (type.contains('gem purple')) {
        templates['purple'] = sprite;
      } else if (type.contains('gem yellow')) {
        templates['yellow'] = sprite;
      } else if (type.contains('gem green')) {
        templates['green'] = sprite;
      } else if (type.contains('gem blue')) {
        templates['blue'] = sprite;
      }
    }
    return templates;
  }

  _AnimatedSpriteFrame _playerFrameFor(MultiplayerPlayer player) {
    final String facing = player.facing;
    final bool moving = player.moving;
    final int walkStep = moving ? ((elapsedSeconds * 9).floor() % 2) : 0;
    final String animationName;

    switch (facing) {
      case 'left':
        animationName = walkStep == 0 ? 'soldier left' : 'soldier down-left';
        break;
      case 'upLeft':
        animationName = walkStep == 0 ? 'soldier up' : 'soldier left';
        break;
      case 'upRight':
        animationName = walkStep == 0 ? 'soldier up' : 'soldier right';
        break;
      case 'right':
        animationName = walkStep == 0 ? 'soldier right' : 'soldier down-right';
        break;
      case 'up':
        animationName = 'soldier up';
        break;
      case 'downLeft':
        animationName = 'soldier down-left';
        break;
      case 'downRight':
        animationName = 'soldier down-right';
        break;
      case 'down':
      default:
        animationName = walkStep == 0 ? 'soldier down' : 'soldier down-right';
        break;
    }

    return _frameFromTemplate(
      playerTemplate,
      animationName: animationName,
      flipX: false,
    );
  }

  _AnimatedSpriteFrame _frameFromTemplate(
    LevelSprite template, {
    String? animationName,
    bool flipX = false,
  }) {
    final String? animationId = animationName == null
        ? template.animationId
        : _findAnimationIdByName(animationName);
    if (animationId == null || animationId.isEmpty) {
      return _AnimatedSpriteFrame(
        texturePath: template.texturePath,
        frameWidth: math.max(1, template.width.round()),
        frameHeight: math.max(1, template.height.round()),
        frameIndex: math.max(0, template.frameIndex),
        anchorX: template.anchorX,
        anchorY: template.anchorY,
        flipX: flipX,
      );
    }

    final AnimationClip? clip = levelData.animationClips.get(animationId);
    if (clip == null) {
      return _AnimatedSpriteFrame(
        texturePath: template.texturePath,
        frameWidth: math.max(1, template.width.round()),
        frameHeight: math.max(1, template.height.round()),
        frameIndex: math.max(0, template.frameIndex),
        anchorX: template.anchorX,
        anchorY: template.anchorY,
        flipX: flipX,
      );
    }

    final int start = math.max(0, clip.startFrame);
    final int end = math.max(start, clip.endFrame);
    final int span = math.max(1, end - start + 1);
    final double fps = clip.fps.isFinite && clip.fps > 0 ? clip.fps : 8;
    final int offset = ((elapsedSeconds * fps).floor()) % span;
    final int frameIndex = start + offset;
    final FrameRig? frameRig = clip.frameRigs.get(frameIndex);
    return _AnimatedSpriteFrame(
      texturePath: clip.texturePath ?? template.texturePath,
      frameWidth: clip.frameWidth > 0
          ? clip.frameWidth
          : math.max(1, template.width.round()),
      frameHeight: clip.frameHeight > 0
          ? clip.frameHeight
          : math.max(1, template.height.round()),
      frameIndex: frameIndex,
      anchorX: frameRig?.anchorX ?? clip.anchorX,
      anchorY: frameRig?.anchorY ?? clip.anchorY,
      flipX: flipX,
    );
  }

  String? _findAnimationIdByName(String animationName) {
    final String normalized = normalize(animationName);
    for (final MapEntry<String, AnimationClip> entry
        in levelData.animationClips.entries()) {
      if (normalize(entry.value.name) == normalized) {
        return entry.key;
      }
    }
    return null;
  }

  ui.Rect _frameSourceRect(
    Texture texture,
    int frameWidth,
    int frameHeight,
    int frameIndex,
  ) {
    final int safeWidth = math.max(1, frameWidth);
    final int safeHeight = math.max(1, frameHeight);
    final int cols = math.max(1, texture.width ~/ safeWidth);
    final int rows = math.max(1, texture.height ~/ safeHeight);
    final int total = cols * rows;
    final int safeFrame = clampInt(frameIndex, 0, total - 1);
    final int srcCol = safeFrame % cols;
    final int srcRow = safeFrame ~/ cols;
    return ui.Rect.fromLTWH(
      (srcCol * safeWidth).toDouble(),
      (srcRow * safeHeight).toDouble(),
      safeWidth.toDouble(),
      safeHeight.toDouble(),
    );
  }

  void _drawCenteredText(
    SpriteBatch batch,
    BitmapFont font,
    String text,
    double y,
    double scale,
    ui.Color color, {
    double? maxWidth,
  }) {
    font.getData().setScale(scale);
    font.setColor(color);
    layout.setText(font, text);
    final double width =
        maxWidth ?? Gdx.graphics.getWidth().toDouble() - leaderboardWidth;
    final double x = (width - layout.width) * 0.5;
    font.draw(batch, layout, x, y);
    font.getData().setScale(1);
  }

  void _drawLeftAlignedText(
    SpriteBatch batch,
    BitmapFont font,
    String text,
    double x,
    double y,
    double scale,
    ui.Color color,
  ) {
    font.getData().setScale(scale);
    font.setColor(color);
    font.drawText(text, x, y);
    font.getData().setScale(1);
  }

  void _drawRightAlignedText(
    SpriteBatch batch,
    BitmapFont font,
    String text,
    double right,
    double y,
    double scale,
    ui.Color color,
  ) {
    font.getData().setScale(scale);
    font.setColor(color);
    layout.setText(font, text);
    font.draw(batch, layout, right - layout.width, y);
    font.getData().setScale(1);
  }
}

class _AnimatedSpriteFrame {
  final String texturePath;
  final int frameWidth;
  final int frameHeight;
  final int frameIndex;
  final double anchorX;
  final double anchorY;
  final bool flipX;

  const _AnimatedSpriteFrame({
    required this.texturePath,
    required this.frameWidth,
    required this.frameHeight,
    required this.frameIndex,
    required this.anchorX,
    required this.anchorY,
    required this.flipX,
  });
}
