import 'dart:math' as math;
import 'dart:ui' as ui;

import 'app_data.dart';
import 'game_app.dart';
import 'libgdx_compat/asset_manager.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/math_types.dart';
import 'libgdx_compat/viewport.dart';
import 'level_data.dart';
import 'level_loader.dart';
import 'play_screen.dart';
import 'player_list_renderer.dart';

class WaitingRoomScreen extends ScreenAdapter {
    static const double worldWidth = 1280;
    static const double worldHeight = 720;
    static const double panelWidth = 320;
    static const double panelPadding = 14;
    static const double leaderboardStartY = 80;

    static final ui.Color background = colorValueOf('070E08');
    static final ui.Color panelFill = colorValueOf('09140CCC');
    static final ui.Color panelStroke = colorValueOf('35FF74');
    static final ui.Color titleColor = colorValueOf('FFFFFF');
    static final ui.Color textColor = colorValueOf('D8FFE3');
    static final ui.Color dimTextColor = colorValueOf('76A784');
    static final ui.Color localPlayerColor = colorValueOf('FFE07A');

    final GameApp game;
    final int levelIndex;
    final Viewport viewport = FitViewport(
      worldWidth,
      worldHeight,
      OrthographicCamera(),
    );
    final GlyphLayout layout = GlyphLayout();

    WaitingRoomScreen(this.game, this.levelIndex);

    @override
    void render(double delta) {
      final AppData appData = game.getAppData();
      if (appData.phase == MatchPhase.playing ||
          appData.phase == MatchPhase.finished) {
        game.setScreen(PlayScreen(game, levelIndex));
        return;
      }

      ScreenUtils.clear(background);
      viewport.apply();

      final ShapeRenderer shapes = game.getShapeRenderer();
      shapes.begin(ShapeType.filled);
      shapes.setColor(panelFill);
      shapes.rect(worldWidth - panelWidth, 0, panelWidth, worldHeight);
      shapes.end();

      shapes.begin(ShapeType.line);
      shapes.setColor(panelStroke);
      shapes.rect(worldWidth - panelWidth, 0, panelWidth, worldHeight);
      shapes.end();

      final SpriteBatch batch = game.getBatch();
      final BitmapFont font = game.getFont();
      batch.begin();

      // Draw title
      _drawCenteredText(
        batch,
        font,
        'Waiting Room',
        worldHeight * 0.18,
        2.8,
        titleColor,
      );

      if (appData.isConnected &&
          appData.phase == MatchPhase.waiting &&
          appData.countdownSeconds > 0) {
        _drawCenteredText(
          batch,
          font,
          'Starts in ${appData.countdownSeconds}s',
          worldHeight * 0.26,
          1.35,
          textColor,
        );
      }

      // Draw players list header
      _drawLeftAlignedText(
        batch,
        font,
        'Players Connected',
        worldWidth - panelWidth + panelPadding,
        34,
        1.45,
        titleColor,
      );

      PlayerListRenderer.render(
        batch: batch,
        font: font,
        layout: layout,
        players: appData.sortedPlayers,
        localPlayerId: appData.playerId,
        left: worldWidth - panelWidth + panelPadding,
        right: worldWidth - panelPadding,
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
          worldWidth - panelWidth + panelPadding,
          leaderboardStartY,
          1.0,
          dimTextColor,
        );
      }

      batch.end();
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
      final double x = (worldWidth - panelWidth - layout.width) * 0.5;
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

    @override
    void resize(int width, int height) {
      viewport.update(width.toDouble(), height.toDouble(), true);
    }
  }
