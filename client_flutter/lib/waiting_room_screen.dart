import 'dart:math' as math;
import 'dart:ui' as ui;

import 'app_data.dart';
import 'game_app.dart';
import 'libgdx_compat/game_framework.dart';
import 'libgdx_compat/math_types.dart';
import 'libgdx_compat/viewport.dart';
import 'play_screen.dart';

class WaitingRoomScreen extends ScreenAdapter {
    static const double worldWidth = 1280;
    static const double worldHeight = 720;
    static const double panelWidth = 380;
    static const double panelPadding = 18;

    static final ui.Color background = colorValueOf('070E08');
    static final ui.Color panelFill = colorValueOf('09140CCC');
    static final ui.Color panelStroke = colorValueOf('35FF74');
    static final ui.Color titleColor = colorValueOf('FFFFFF');
    static final ui.Color textColor = colorValueOf('D8FFE3');
    static final ui.Color dimTextColor = colorValueOf('7AA689');
    static final ui.Color highlightColor = colorValueOf('35FF74');

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

        _drawCenteredText(
            batch,
            font,
            'Battle Royale Lobby',
            worldHeight * 0.20,
            2.4,
            titleColor,
        );
        _drawCenteredText(
            batch,
            font,
            appData.players.length >= 2
                    ? 'Match starts in ${math.max(0, appData.countdownSeconds)}'
                    : 'Waiting for at least 2 players',
            worldHeight * 0.33,
            1.3,
            appData.players.length >= 2 ? highlightColor : dimTextColor,
        );
        _drawCenteredText(
            batch,
            font,
            'Controls: WASD move, LMB shoot, R reload, G drop, E detonate drone',
            worldHeight * 0.43,
            0.95,
            textColor,
            maxWidth: worldWidth - panelWidth - 80,
        );
        _drawCenteredText(
            batch,
            font,
            'Use slots 2..9. Grenade: equip with number, throw with click',
            worldHeight * 0.49,
            0.95,
            textColor,
            maxWidth: worldWidth - panelWidth - 80,
        );

        _drawLeftText(
            batch,
            font,
            'Connected Players',
            worldWidth - panelWidth + panelPadding,
            36,
            1.3,
            titleColor,
        );
        _drawLeftText(
            batch,
            font,
            '${appData.players.length} connected',
            worldWidth - panelWidth + panelPadding,
            62,
            0.95,
            dimTextColor,
        );

        double rowY = 92;
        int idx = 1;
        for (final MultiplayerPlayer player in appData.sortedPlayers) {
            final String label = player.id == appData.playerId
                    ? '$idx. ${player.name} (you)'
                    : '$idx. ${player.name}';
            _drawLeftText(
                batch,
                font,
                label,
                worldWidth - panelWidth + panelPadding,
                rowY,
                0.95,
                textColor,
            );
            rowY += 22;
            idx++;
            if (rowY > worldHeight - 24) {
                break;
            }
        }

        if (appData.sortedPlayers.isEmpty) {
            _drawLeftText(
                batch,
                font,
                'No players connected',
                worldWidth - panelWidth + panelPadding,
                92,
                0.95,
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
        ui.Color color, {
        double? maxWidth,
    }) {
        font.getData().setScale(scale);
        font.setColor(color);
        layout.setText(font, text);
        final double allowedWidth =
                maxWidth ?? (worldWidth - panelWidth - panelPadding * 2);
        double x = (worldWidth - panelWidth - layout.width) * 0.5;
        if (layout.width > allowedWidth) {
            x = (worldWidth - panelWidth - allowedWidth) * 0.5;
        }
        font.draw(batch, layout, x, y);
        font.getData().setScale(1);
    }

    void _drawLeftText(
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

    @override
    void resize(int width, int height) {
        viewport.update(width.toDouble(), height.toDouble(), true);
    }
}
