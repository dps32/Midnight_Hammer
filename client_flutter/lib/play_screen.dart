import 'dart:math' as math;
import 'dart:ui' as ui;

import 'app_data.dart';
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
import 'waiting_room_screen.dart';

class PlayScreen extends ScreenAdapter {
    static const double maxFrameSeconds = 0.25;
    static const double hudPadding = 14;
    static const double hudPanelWidth = 360;
    static const double grenadeThrowRange = 260;
    static const double grenadeInnerRadius = 28;
    static const double grenadeOuterRadius = 90;

    static final ui.Color playerLocalColor = colorValueOf('4CB1FF');
    static final ui.Color playerEnemyColor = colorValueOf('FF6B6B');
    static final ui.Color droneColor = colorValueOf('5BFF9D');
    static final ui.Color lootWeaponColor = colorValueOf('FFC857');
    static final ui.Color lootConsumableColor = colorValueOf('8A7DFF');
    static final ui.Color projectileColor = colorValueOf('FFF176');
    static final ui.Color rocketColor = colorValueOf('FF9E57');
    static final ui.Color grenadeColor = colorValueOf('A7FF83');
    static final ui.Color stormColor = colorValueOf('45D5FF');
    static final ui.Color warningColor = colorValueOf('FF3434');
    static final ui.Color explosionColor = colorValueOf('FFA24A99');
    static final ui.Color grenadePreviewOuterColor = colorValueOf('A7FF8388');
    static final ui.Color grenadePreviewInnerColor = colorValueOf('EAFFAA');
    static final ui.Color hudPanelColor = colorValueOf('071410D8');
    static final ui.Color hudStrokeColor = colorValueOf('35FF74');
    static final ui.Color hudTextColor = colorValueOf('DFFFF1');
    static final ui.Color hudDimTextColor = colorValueOf('7FB29A');
    static final ui.Color winnerOverlayColor = colorValueOf('000000C0');
    static final ui.Color airstrikeOverlayColor = colorValueOf('000000CF');
    static final ui.Color airstrikeMapFill = colorValueOf('102822');
    static final ui.Color airstrikeMapStroke = colorValueOf('35FF74');
    static final ui.Color airstrikeLocalPoint = colorValueOf('4CB1FF');
    static final ui.Color airstrikeEnemyPoint = colorValueOf('FF4747');

    static const String playerSpritePath = 'levels/media/soldier.png';
    static const String defaultWeaponSpritePath = 'levels/media/glock.png';
    static const String droneSpritePath = 'levels/media/dron.png';
    static const String airstrikeSpritePath = 'levels/media/f15.png';

    static const Map<String, String> weaponSpriteById = <String, String>{
        'pistol': 'levels/media/glock.png',
        'smg': 'levels/media/smg.png',
        'rifle': 'levels/media/rifle_asalto.png',
        'sniper': 'levels/media/awp.png',
        'rocket': 'levels/media/escopeta.png',
    };

    static const Map<String, String> consumableSpriteById = <String, String>{
        'grenade': 'levels/media/glock.png',
        'drone': 'levels/media/dron.png',
        'airstrike': 'levels/media/f15.png',
    };

    final GameApp game;
    final int levelIndex;

    final OrthographicCamera camera = OrthographicCamera();
    final LevelRenderer levelRenderer = LevelRenderer();
    final GlyphLayout layout = GlyphLayout();

    late final LevelData levelData;
    late final Viewport viewport;
    late final List<bool> layerVisibilityStates;
    late final Array<SpriteRuntimeState> spriteRuntimeStates;
    late final Array<RuntimeTransform> layerRuntimeStates;

    ui.Rect? _airstrikeMapRect;
    double elapsedSeconds = 0;
    int? _equippedGrenadeSlot;
    bool _suppressFireUntilPointerUp = false;

    PlayScreen(this.game, this.levelIndex) {
        levelData = LevelLoader.loadLevel(levelIndex);
        viewport = _createViewport(levelData, camera);
        layerVisibilityStates = _buildInitialLayerVisibility(levelData);
        spriteRuntimeStates = _createHiddenTemplateRuntimes(levelData);
        layerRuntimeStates = _createLayerRuntimeStates(levelData);
        _applyInitialCameraFromLevel();
        viewport.update(
            Gdx.graphics.getWidth().toDouble(),
            Gdx.graphics.getHeight().toDouble(),
            false,
        );
        _queueGameplaySpriteAssets();
    }

    @override
    void render(double delta) {
        elapsedSeconds += math.max(0, math.min(delta, maxFrameSeconds));
        final AppData appData = game.getAppData();
        game.getAssetManager().update();

        if (appData.phase == MatchPhase.waiting ||
                appData.phase == MatchPhase.connecting) {
            _equippedGrenadeSlot = null;
            _suppressFireUntilPointerUp = false;
            appData.sendInput(move: 'none', aimX: 0, aimY: 0, firing: false);
            game.setScreen(WaitingRoomScreen(game, levelIndex));
            return;
        }

        _handleGameplayInput(appData);
        _updateCameraForGameplay(appData);

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
        batch.end();

        _renderWorldObjects(appData);
        _renderHud(appData);

        if (appData.localPendingAirstrike) {
            _renderAirstrikeMinimap(appData);
        } else {
            _airstrikeMapRect = null;
        }

        if (appData.phase == MatchPhase.finished) {
            _renderWinnerOverlay(appData);
        }
    }

    @override
    void resize(int width, int height) {
        viewport.update(width.toDouble(), height.toDouble(), false);
        _updateCameraForGameplay(game.getAppData());
    }

    void _handleGameplayInput(AppData appData) {
        final Vector3 mouseWorld = _mouseWorldPosition();
        final MultiplayerPlayer? local = appData.localPlayer;

        if (local == null) {
            return;
        }

        if (appData.localPendingAirstrike) {
            appData.sendInput(
                move: 'none',
                aimX: mouseWorld.x,
                aimY: mouseWorld.y,
                firing: false,
            );
            if (Gdx.input.justTouched()) {
                final ui.Offset screenTouch = ui.Offset(
                    Gdx.input.getX().toDouble(),
                    Gdx.input.getY().toDouble(),
                );
                final ui.Offset? world = _airstrikeScreenToWorld(screenTouch);
                if (world != null) {
                    appData.sendAirstrikeTarget(world.dx, world.dy);
                }
            }
            return;
        }

        if (appData.canControlAvatar) {
            final String move = _readCurrentDirection();
            _refreshEquippedGrenade(local);
            final bool grenadeEquipped = _hasEquippedGrenade(local);
            final bool justClicked = Gdx.input.justTouched();

            if (_suppressFireUntilPointerUp && !Gdx.input.isTouchDown()) {
                _suppressFireUntilPointerUp = false;
            }

            final bool firing =
                    !grenadeEquipped &&
                    !_suppressFireUntilPointerUp &&
                    Gdx.input.isTouchDown();
            appData.sendInput(
                move: move,
                aimX: mouseWorld.x,
                aimY: mouseWorld.y,
                firing: firing,
            );

            if (grenadeEquipped && justClicked) {
                final int slot = _equippedGrenadeSlot!;
                appData.sendUseSlotAction(slot);
                _equippedGrenadeSlot = null;
                _suppressFireUntilPointerUp = true;
            }

            if (Gdx.input.isKeyJustPressed(Input.keys.r)) {
                appData.sendReloadAction();
            }
            if (Gdx.input.isKeyJustPressed(Input.keys.digit1)) {
                _equippedGrenadeSlot = null;
                appData.sendSelectPrimaryAction();
            }
            if (Gdx.input.isKeyJustPressed(Input.keys.g)) {
                _equippedGrenadeSlot = null;
                appData.sendDropPrimaryAction();
            }
            if (Gdx.input.isKeyJustPressed(Input.keys.e)) {
                appData.sendDetonateDroneAction();
            }
            for (int slot = 2; slot <= 9; slot++) {
                final int keycode = _digitKeyCode(slot);
                if (keycode > 0 && Gdx.input.isKeyJustPressed(keycode)) {
                    final InventorySlotState? slotState = _findSlot(
                        local.inventorySlots,
                        slot,
                    );
                    if (slotState != null &&
                            slotState.type == 'grenade' &&
                            slotState.count > 0) {
                        _equippedGrenadeSlot = _equippedGrenadeSlot == slot ? null : slot;
                    } else {
                        _equippedGrenadeSlot = null;
                        appData.sendUseSlotAction(slot);
                    }
                }
            }
            return;
        }

        if (local.spectator && Gdx.input.isKeyJustPressed(Input.keys.space)) {
            appData.sendSpectateNextAction();
        }
    }

    void _updateCameraForGameplay(AppData appData) {
        final MultiplayerPlayer? local = appData.localPlayer;
        if (local == null) {
            _applyInitialCameraFromLevel();
            return;
        }

        double targetX;
        double targetY;

        if (local.alive && !local.spectator) {
            if (local.activeDroneId.isNotEmpty) {
                final DroneState? drone = _findDrone(appData, local.activeDroneId);
                if (drone != null) {
                    targetX = drone.x + drone.width * 0.5;
                    targetY = drone.y + drone.height * 0.5;
                } else {
                    targetX = local.x + local.width * 0.5;
                    targetY = local.y + local.height * 0.5;
                }
            } else {
                targetX = local.x + local.width * 0.5;
                targetY = local.y + local.height * 0.5;
            }
        } else {
            final MultiplayerPlayer? spectated = appData.spectatedPlayer;
            if (spectated != null) {
                targetX = spectated.x + spectated.width * 0.5;
                targetY = spectated.y + spectated.height * 0.5;
            } else {
                targetX = levelData.worldWidth * 0.5;
                targetY = levelData.worldHeight * 0.5;
            }
        }

        final double worldW = math.max(1, levelData.worldWidth);
        final double worldH = math.max(1, levelData.worldHeight);
        final double halfW = math.max(1, viewport.worldWidth * camera.zoom * 0.5);
        final double halfH = math.max(1, viewport.worldHeight * camera.zoom * 0.5);

        camera.setPosition(
            _clampCameraAxis(targetX, halfW, worldW),
            _clampCameraAxis(targetY, halfH, worldH),
        );
        camera.update();
    }

    double _clampCameraAxis(double target, double halfView, double worldSize) {
        if (worldSize <= halfView * 2) {
            return worldSize * 0.5;
        }
        return clampDouble(target, halfView, worldSize - halfView);
    }

    void _renderWorldObjects(AppData appData) {
        final SpriteBatch batch = game.getBatch();
        batch.begin();
        _renderLoot(batch, appData.loot);
        _renderProjectiles(batch, appData.projectiles);
        _renderGrenades(batch, appData.grenades);
        _renderDrones(batch, appData.drones);
        _renderPlayers(batch, appData.players, appData.playerId);
        _renderExplosions(batch, appData.explosions);
        _renderAirstrikePlaceholders(batch, appData.airstrikeWarnings);
        batch.end();

        final ShapeRenderer shapes = game.getShapeRenderer();

        shapes.begin(ShapeType.line);
        _renderGrenadePreview(shapes, appData);
        _renderStormCircle(shapes, appData.storm);
        _renderAirstrikeWarnings(shapes, appData.airstrikeWarnings);
        shapes.end();
    }

    void _renderPlayers(
        SpriteBatch batch,
        List<MultiplayerPlayer> players,
        String? localPlayerId,
    ) {
        final TextureRegion? region = _fullTextureRegion(playerSpritePath);
        if (region == null) {
            return;
        }
        for (final MultiplayerPlayer player in players) {
            if (!player.alive) {
                continue;
            }
            batch.setColor(
                player.id == localPlayerId ? playerLocalColor : playerEnemyColor,
            );
            final ui.Rect rect = viewport.worldToScreenRect(
                player.x,
                player.y,
                player.width,
                player.height,
            );
            batch.drawRegion(region.texture, region.srcRect, rect);
            batch.setColor(const ui.Color(0xFFFFFFFF));
            _drawPlayerWeapon(batch, player);
        }
    }

    void _renderLoot(SpriteBatch batch, List<LootState> loot) {
        for (final LootState item in loot) {
            final String spritePath = item.kind == 'weapon'
                    ? (weaponSpriteById[item.weaponId] ?? defaultWeaponSpritePath)
                    : (consumableSpriteById[item.consumableType] ?? defaultWeaponSpritePath);
            final TextureRegion? region = _fullTextureRegion(spritePath);
            if (region == null) {
                continue;
            }
            batch.setColor(
                item.kind == 'weapon' ? lootWeaponColor : lootConsumableColor,
            );
            final ui.Rect rect = viewport.worldToScreenRect(
                item.x - 6,
                item.y - 6,
                12,
                12,
            );
            batch.drawRegion(region.texture, region.srcRect, rect);
            batch.setColor(const ui.Color(0xFFFFFFFF));
        }
    }

    void _renderProjectiles(
        SpriteBatch batch,
        List<ProjectileState> projectiles,
    ) {
        for (final ProjectileState projectile in projectiles) {
            final bool isRocket = projectile.kind == 'rocket';
            final TextureRegion? region = _fullTextureRegion(
                isRocket ? 'levels/media/escopeta.png' : defaultWeaponSpritePath,
            );
            if (region == null) {
                continue;
            }
            final double radiusWorld = projectile.kind == 'rocket' ? 4 : 1.25;
            final ui.Rect rect = viewport.worldToScreenRect(
                projectile.x - radiusWorld,
                projectile.y - radiusWorld,
                radiusWorld * 2,
                radiusWorld * 2,
            );
            batch.setColor(isRocket ? rocketColor : projectileColor);
            batch.drawRegion(region.texture, region.srcRect, rect);
            batch.setColor(const ui.Color(0xFFFFFFFF));
        }
    }

    void _renderGrenades(SpriteBatch batch, List<GrenadeState> grenades) {
        final TextureRegion? region = _fullTextureRegion(defaultWeaponSpritePath);
        if (region == null) {
            return;
        }
        for (final GrenadeState grenade in grenades) {
            final ui.Rect rect = viewport.worldToScreenRect(
                grenade.x - 4,
                grenade.y - 4,
                8,
                8,
            );
            batch.setColor(grenadeColor);
            batch.drawRegion(region.texture, region.srcRect, rect);
            batch.setColor(const ui.Color(0xFFFFFFFF));
        }
    }

    void _renderDrones(SpriteBatch batch, List<DroneState> drones) {
        final TextureRegion? region = _fullTextureRegion(droneSpritePath);
        if (region == null) {
            return;
        }
        for (final DroneState drone in drones) {
            final ui.Rect rect = viewport.worldToScreenRect(
                drone.x,
                drone.y,
                drone.width,
                drone.height,
            );
            batch.setColor(droneColor);
            batch.drawRegion(region.texture, region.srcRect, rect);
            batch.setColor(const ui.Color(0xFFFFFFFF));
        }
    }

    void _renderExplosions(
        SpriteBatch batch,
        List<ExplosionState> explosions,
    ) {
        final TextureRegion? region = _fullTextureRegion(defaultWeaponSpritePath);
        if (region == null) {
            return;
        }
        for (final ExplosionState explosion in explosions) {
            final double radiusWorld = 22;
            final ui.Rect rect = viewport.worldToScreenRect(
                explosion.x - radiusWorld,
                explosion.y - radiusWorld,
                radiusWorld * 2,
                radiusWorld * 2,
            );
            batch.setColor(explosionColor);
            batch.drawRegion(region.texture, region.srcRect, rect);
            batch.setColor(const ui.Color(0xFFFFFFFF));
        }
    }

    void _renderStormCircle(ShapeRenderer shapes, StormState storm) {
        shapes.setColor(stormColor);
        final ui.Offset center = viewport.worldToScreenPoint(
            storm.centerX,
            storm.centerY,
        );
        shapes.circle(center.dx, center.dy, _radiusToScreen(storm.radius), 72);
    }

    void _renderAirstrikeWarnings(
        ShapeRenderer shapes,
        List<AirstrikeWarningState> warnings,
    ) {
        for (final AirstrikeWarningState warning in warnings) {
            shapes.setColor(warningColor);
            final ui.Offset center = viewport.worldToScreenPoint(
                warning.x,
                warning.y,
            );
            shapes.circle(center.dx, center.dy, _radiusToScreen(warning.radius), 60);
        }
    }

    void _renderGrenadePreview(ShapeRenderer shapes, AppData appData) {
        if (appData.localPendingAirstrike) {
            return;
        }
        if (!appData.canControlAvatar) {
            return;
        }
        final MultiplayerPlayer? local = appData.localPlayer;
        if (local == null || !_hasEquippedGrenade(local)) {
            return;
        }

        final Vector3 mouseWorld = _mouseWorldPosition();
        final ui.Offset target = _clampedGrenadeTargetWorld(
            local,
            mouseWorld.x,
            mouseWorld.y,
        );
        final ui.Offset center = viewport.worldToScreenPoint(target.dx, target.dy);
        shapes.setColor(grenadePreviewOuterColor);
        shapes.circle(
            center.dx,
            center.dy,
            _radiusToScreen(grenadeOuterRadius),
            42,
        );
        shapes.setColor(grenadePreviewInnerColor);
        shapes.circle(
            center.dx,
            center.dy,
            _radiusToScreen(grenadeInnerRadius),
            26,
        );
    }

    void _renderAirstrikePlaceholders(
        SpriteBatch batch,
        List<AirstrikeWarningState> warnings,
    ) {
        final TextureRegion? plane = _fullTextureRegion(airstrikeSpritePath);
        final TextureRegion? bomb = _fullTextureRegion(defaultWeaponSpritePath);
        if (plane == null || bomb == null) {
            return;
        }
        for (final AirstrikeWarningState warning in warnings) {
            final ui.Offset center = viewport.worldToScreenPoint(
                warning.x,
                warning.y,
            );
            final double radius = _radiusToScreen(warning.radius);
            final double progress = clampDouble(
                1 - (warning.secondsToImpact / 5.0),
                0,
                1,
            );
            final double planeX = center.dx - radius + (radius * 2 * progress);
            final double planeY = center.dy - radius - 18;
            final double bombY = planeY + (radius + 18) * progress;

            batch.setColor(warningColor);
            batch.drawRegion(
                plane.texture,
                plane.srcRect,
                ui.Rect.fromLTWH(planeX - 10, planeY - 4, 20, 8),
            );
            batch.drawRegion(
                bomb.texture,
                bomb.srcRect,
                ui.Rect.fromLTWH(planeX - 2, bombY - 2, 4, 4),
            );
            batch.setColor(const ui.Color(0xFFFFFFFF));
        }
    }

    void _drawPlayerWeapon(SpriteBatch batch, MultiplayerPlayer player) {
        final String weaponId = player.primaryWeapon.trim();
        if (weaponId.isEmpty) {
            return;
        }
        final String weaponPath =
                weaponSpriteById[weaponId] ?? defaultWeaponSpritePath;
        final TextureRegion? region = _fullTextureRegion(weaponPath);
        if (region == null) {
            return;
        }

        final double cx = player.x + player.width * 0.5;
        final double cy = player.y + player.height * 0.5;
        final double dx = player.aimX - cx;
        final double dy = player.aimY - cy;
        final double len = math.sqrt(dx * dx + dy * dy);
        final double ux = len > 0.0001 ? dx / len : 1;
        final double uy = len > 0.0001 ? dy / len : 0;

        const double holdDistance = 8;
        const double weaponWidth = 12;
        const double weaponHeight = 6;

        final double wx = cx + ux * holdDistance;
        final double wy = cy + uy * holdDistance;
        final ui.Rect weaponRect = viewport.worldToScreenRect(
            wx - weaponWidth * 0.5,
            wy - weaponHeight * 0.5,
            weaponWidth,
            weaponHeight,
        );
        batch.drawRegion(region.texture, region.srcRect, weaponRect);
    }

    TextureRegion? _fullTextureRegion(String texturePath) {
        final AssetManager assets = game.getAssetManager();
        if (!assets.isLoaded(texturePath, Texture)) {
            assets.load(texturePath, Texture);
            return null;
        }
        final Texture texture = assets.get(texturePath, Texture);
        return TextureRegion(
            texture,
            ui.Rect.fromLTWH(
                0,
                0,
                texture.width.toDouble(),
                texture.height.toDouble(),
            ),
        );
    }

    void _queueGameplaySpriteAssets() {
        final AssetManager assets = game.getAssetManager();
        final Set<String> paths = <String>{
            playerSpritePath,
            defaultWeaponSpritePath,
            droneSpritePath,
            airstrikeSpritePath,
            ...weaponSpriteById.values,
            ...consumableSpriteById.values,
        };
        for (final String path in paths) {
            if (!assets.isLoaded(path, Texture)) {
                assets.load(path, Texture);
            }
        }
    }

    void _renderHud(AppData appData) {
        final MultiplayerPlayer? local = appData.localPlayer;
        final double screenH = Gdx.graphics.getHeight().toDouble();

        final ShapeRenderer shapes = game.getShapeRenderer();
        shapes.begin(ShapeType.filled);
        shapes.setColor(hudPanelColor);
        shapes.rect(0, 0, hudPanelWidth, screenH);
        shapes.end();

        shapes.begin(ShapeType.line);
        shapes.setColor(hudStrokeColor);
        shapes.rect(0, 0, hudPanelWidth, screenH);
        shapes.end();

        final SpriteBatch batch = game.getBatch();
        final BitmapFont font = game.getFont();
        batch.begin();

        _drawText(batch, font, 'Battle Royale', hudPadding, 32, 1.35, hudTextColor);
        _drawText(
            batch,
            font,
            'Phase: ${_phaseLabel(appData.phase)}',
            hudPadding,
            60,
            1.0,
            hudDimTextColor,
        );
        _drawText(
            batch,
            font,
            'Alive: ${appData.aliveCount}/${appData.players.length}',
            hudPadding,
            84,
            1.0,
            hudTextColor,
        );

        if (local != null) {
            _drawText(
                batch,
                font,
                'HP: ${local.health.round()}/${local.maxHealth.round()}',
                hudPadding,
                118,
                1.0,
                hudTextColor,
            );
            _drawText(
                batch,
                font,
                'Weapon: ${local.primaryWeapon.isEmpty ? 'None' : local.primaryWeapon}',
                hudPadding,
                142,
                1.0,
                hudTextColor,
            );
            _drawText(
                batch,
                font,
                'Ammo: ${local.ammoInMag}/${local.ammoCapacity}',
                hudPadding,
                166,
                1.0,
                hudTextColor,
            );
            if (local.reloading) {
                _drawText(
                    batch,
                    font,
                    'Reloading ${_msToSec(local.reloadRemainingMs)}s',
                    hudPadding,
                    188,
                    0.95,
                    hudDimTextColor,
                );
            }
            if (local.activeDroneId.isNotEmpty) {
                _drawText(
                    batch,
                    font,
                    'Drone active',
                    hudPadding,
                    210,
                    0.95,
                    droneColor,
                );
            }
            if (local.pendingAirstrike) {
                _drawText(
                    batch,
                    font,
                    'Airstrike: choose target',
                    hudPadding,
                    232,
                    0.95,
                    warningColor,
                );
            }

            _drawText(batch, font, 'Consumables', hudPadding, 266, 1.0, hudTextColor);
            double slotY = 290;
            for (int slot = 2; slot <= 9; slot++) {
                final InventorySlotState? state = _findSlot(local.inventorySlots, slot);
                final String text = state == null
                        ? '$slot: -'
                        : '$slot: ${state.type} x${state.count}${_equippedGrenadeSlot == slot ? ' [equipped]' : ''}';
                _drawText(batch, font, text, hudPadding, slotY, 0.9, hudDimTextColor);
                slotY += 22;
            }
        }

        _drawText(
            batch,
            font,
            'Storm: ${appData.storm.stage}',
            hudPadding,
            screenH - 78,
            0.95,
            hudTextColor,
        );
        _drawText(
            batch,
            font,
            'Radius: ${appData.storm.radius.toStringAsFixed(1)}',
            hudPadding,
            screenH - 56,
            0.95,
            hudTextColor,
        );
        _drawText(
            batch,
            font,
            'Damage/s: ${appData.storm.damagePerSecond.toStringAsFixed(1)}',
            hudPadding,
            screenH - 34,
            0.95,
            hudTextColor,
        );

        batch.end();
    }

    void _renderWinnerOverlay(AppData appData) {
        final ShapeRenderer shapes = game.getShapeRenderer();
        final double screenW = Gdx.graphics.getWidth().toDouble();
        final double screenH = Gdx.graphics.getHeight().toDouble();

        shapes.begin(ShapeType.filled);
        shapes.setColor(winnerOverlayColor);
        shapes.rect(0, 0, screenW, screenH);
        shapes.end();

        final SpriteBatch batch = game.getBatch();
        final BitmapFont font = game.getFont();
        batch.begin();
        _drawCenteredText(
            batch,
            font,
            appData.winnerName.isEmpty
                    ? 'No winner'
                    : 'Winner: ${appData.winnerName}',
            screenH * 0.45,
            2.0,
            hudTextColor,
        );
        _drawCenteredText(
            batch,
            font,
            'Back to lobby in ${appData.returnToLobbySeconds}s',
            screenH * 0.53,
            1.1,
            hudDimTextColor,
        );
        batch.end();
    }

    void _renderAirstrikeMinimap(AppData appData) {
        final double screenW = Gdx.graphics.getWidth().toDouble();
        final double screenH = Gdx.graphics.getHeight().toDouble();

        final ui.Rect mapRect = _computeAirstrikeMapRect(screenW, screenH, appData);
        _airstrikeMapRect = mapRect;

        final ShapeRenderer shapes = game.getShapeRenderer();
        shapes.begin(ShapeType.filled);
        shapes.setColor(airstrikeOverlayColor);
        shapes.rect(0, 0, screenW, screenH);
        shapes.setColor(airstrikeMapFill);
        shapes.rect(mapRect.left, mapRect.top, mapRect.width, mapRect.height);

        for (final MultiplayerPlayer player in appData.players) {
            if (!player.alive) {
                continue;
            }
            final ui.Offset p = _worldToAirstrikePoint(
                appData,
                mapRect,
                player.x + player.width * 0.5,
                player.y + player.height * 0.5,
            );
            shapes.setColor(
                player.id == appData.playerId
                        ? airstrikeLocalPoint
                        : airstrikeEnemyPoint,
            );
            shapes.rect(p.dx - 3, p.dy - 3, 6, 6);
        }
        shapes.end();

        shapes.begin(ShapeType.line);
        shapes.setColor(airstrikeMapStroke);
        shapes.rect(mapRect.left, mapRect.top, mapRect.width, mapRect.height);
        shapes.end();

        final SpriteBatch batch = game.getBatch();
        final BitmapFont font = game.getFont();
        batch.begin();
        _drawCenteredText(
            batch,
            font,
            'AIRSTRIKE TARGET',
            mapRect.top - 20,
            1.25,
            hudTextColor,
        );
        _drawCenteredText(
            batch,
            font,
            'Click on the map to confirm',
            mapRect.bottom + 26,
            1.0,
            hudDimTextColor,
        );
        batch.end();
    }

    ui.Rect _computeAirstrikeMapRect(
        double screenW,
        double screenH,
        AppData appData,
    ) {
        final double worldW = math.max(
            1,
            appData.worldWidth > 0 ? appData.worldWidth : levelData.worldWidth,
        );
        final double worldH = math.max(
            1,
            appData.worldHeight > 0 ? appData.worldHeight : levelData.worldHeight,
        );
        final double maxW = screenW * 0.82;
        final double maxH = screenH * 0.76;
        final double worldAspect = worldW / worldH;
        double mapW = maxW;
        double mapH = mapW / worldAspect;
        if (mapH > maxH) {
            mapH = maxH;
            mapW = mapH * worldAspect;
        }
        return ui.Rect.fromLTWH(
            (screenW - mapW) * 0.5,
            (screenH - mapH) * 0.5,
            mapW,
            mapH,
        );
    }

    ui.Offset? _airstrikeScreenToWorld(ui.Offset screenPoint) {
        final ui.Rect? mapRect = _airstrikeMapRect;
        if (mapRect == null || !mapRect.contains(screenPoint)) {
            return null;
        }
        final AppData appData = game.getAppData();
        final double worldW = math.max(
            1,
            appData.worldWidth > 0 ? appData.worldWidth : levelData.worldWidth,
        );
        final double worldH = math.max(
            1,
            appData.worldHeight > 0 ? appData.worldHeight : levelData.worldHeight,
        );
        final double nx = (screenPoint.dx - mapRect.left) / mapRect.width;
        final double ny = (screenPoint.dy - mapRect.top) / mapRect.height;
        return ui.Offset(nx * worldW, ny * worldH);
    }

    ui.Offset _worldToAirstrikePoint(
        AppData appData,
        ui.Rect mapRect,
        double worldX,
        double worldY,
    ) {
        final double worldW = math.max(
            1,
            appData.worldWidth > 0 ? appData.worldWidth : levelData.worldWidth,
        );
        final double worldH = math.max(
            1,
            appData.worldHeight > 0 ? appData.worldHeight : levelData.worldHeight,
        );
        return ui.Offset(
            mapRect.left + (worldX / worldW) * mapRect.width,
            mapRect.top + (worldY / worldH) * mapRect.height,
        );
    }

    double _radiusToScreen(double worldRadius) {
        final double sx =
                viewport.screenWidth / (viewport.worldWidth * camera.zoom);
        final double sy =
                viewport.screenHeight / (viewport.worldHeight * camera.zoom);
        return worldRadius * ((sx + sy) * 0.5);
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

    int _digitKeyCode(int digit) {
        switch (digit) {
            case 1:
                return Input.keys.digit1;
            case 2:
                return Input.keys.digit2;
            case 3:
                return Input.keys.digit3;
            case 4:
                return Input.keys.digit4;
            case 5:
                return Input.keys.digit5;
            case 6:
                return Input.keys.digit6;
            case 7:
                return Input.keys.digit7;
            case 8:
                return Input.keys.digit8;
            case 9:
                return Input.keys.digit9;
            default:
                return -1;
        }
    }

    void _applyInitialCameraFromLevel() {
        final double centerX = levelData.viewportX + levelData.viewportWidth * 0.5;
        final double centerY = levelData.viewportY + levelData.viewportHeight * 0.5;
        camera.setPosition(centerX, centerY);
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
            final bool isTemplatePlayer =
                    sprite.type.trim().toLowerCase() == 'player';
            runtimes.add(
                SpriteRuntimeState(
                    sprite.frameIndex,
                    0,
                    0,
                    sprite.x,
                    sprite.y,
                    !isTemplatePlayer,
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

    DroneState? _findDrone(AppData appData, String id) {
        for (final DroneState drone in appData.drones) {
            if (drone.id == id) {
                return drone;
            }
        }
        return null;
    }

    InventorySlotState? _findSlot(List<InventorySlotState> slots, int slot) {
        for (final InventorySlotState state in slots) {
            if (state.slot == slot) {
                return state;
            }
        }
        return null;
    }

    void _refreshEquippedGrenade(MultiplayerPlayer local) {
        final int? slot = _equippedGrenadeSlot;
        if (slot == null) {
            return;
        }
        final InventorySlotState? state = _findSlot(local.inventorySlots, slot);
        if (state == null || state.type != 'grenade' || state.count <= 0) {
            _equippedGrenadeSlot = null;
        }
    }

    bool _hasEquippedGrenade(MultiplayerPlayer local) {
        final int? slot = _equippedGrenadeSlot;
        if (slot == null) {
            return false;
        }
        final InventorySlotState? state = _findSlot(local.inventorySlots, slot);
        return state != null && state.type == 'grenade' && state.count > 0;
    }

    ui.Offset _clampedGrenadeTargetWorld(
        MultiplayerPlayer local,
        double aimX,
        double aimY,
    ) {
        final double ox = local.x + local.width * 0.5;
        final double oy = local.y + local.height * 0.5;
        final double dx = aimX - ox;
        final double dy = aimY - oy;
        final double dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= 0.00001) {
            return ui.Offset(ox, oy);
        }
        final double scale = math.min(1, grenadeThrowRange / dist);
        return ui.Offset(ox + dx * scale, oy + dy * scale);
    }

    Vector3 _mouseWorldPosition() {
        final Vector3 v = Vector3(
            Gdx.input.getX().toDouble(),
            Gdx.input.getY().toDouble(),
            0,
        );
        viewport.unproject(v);
        return v;
    }

    String _phaseLabel(MatchPhase phase) {
        switch (phase) {
            case MatchPhase.connecting:
                return 'Connecting';
            case MatchPhase.waiting:
                return 'Waiting';
            case MatchPhase.playing:
                return 'Playing';
            case MatchPhase.finished:
                return 'Finished';
        }
    }

    String _msToSec(int ms) {
        return (math.max(0, ms) / 1000).toStringAsFixed(1);
    }

    void _drawText(
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

    void _drawCenteredText(
        SpriteBatch batch,
        BitmapFont font,
        String text,
        double y,
        double scale,
        ui.Color color,
    ) {
        font.getData().setScale(scale);
        font.setColor(color);
        layout.setText(font, text);
        final double x = (Gdx.graphics.getWidth().toDouble() - layout.width) * 0.5;
        font.draw(batch, layout, x, y);
        font.getData().setScale(1);
    }
}
