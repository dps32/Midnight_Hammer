import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'network_config.dart';
import 'utils_websockets.dart';

enum MatchPhase { connecting, waiting, playing, finished }

class InventorySlotState {
    final int slot;
    final String type;
    final int count;

    const InventorySlotState({
        required this.slot,
        required this.type,
        required this.count,
    });

    factory InventorySlotState.fromJson(Map<String, dynamic> json) {
        return InventorySlotState(
            slot: (json['slot'] as num? ?? 0).toInt(),
            type: (json['type'] as String? ?? '').trim().toLowerCase(),
            count: (json['count'] as num? ?? 0).toInt(),
        );
    }
}

class StormState {
    final String stage;
    final double centerX;
    final double centerY;
    final double radius;
    final double damagePerSecond;
    final int secondsToNextStage;

    const StormState({
        required this.stage,
        required this.centerX,
        required this.centerY,
        required this.radius,
        required this.damagePerSecond,
        required this.secondsToNextStage,
    });

    static const StormState empty = StormState(
        stage: 'waiting',
        centerX: 0,
        centerY: 0,
        radius: 0,
        damagePerSecond: 0,
        secondsToNextStage: 0,
    );

    factory StormState.fromJson(Map<String, dynamic> json) {
        return StormState(
            stage: (json['stage'] as String? ?? 'waiting').trim(),
            centerX: (json['centerX'] as num? ?? 0).toDouble(),
            centerY: (json['centerY'] as num? ?? 0).toDouble(),
            radius: (json['radius'] as num? ?? 0).toDouble(),
            damagePerSecond: (json['damagePerSecond'] as num? ?? 0).toDouble(),
            secondsToNextStage: (json['secondsToNextStage'] as num? ?? 0).toInt(),
        );
    }
}

class WallZoneState {
    final double x;
    final double y;
    final double width;
    final double height;

    const WallZoneState({
        required this.x,
        required this.y,
        required this.width,
        required this.height,
    });

    factory WallZoneState.fromJson(Map<String, dynamic> json) {
        return WallZoneState(
            x: (json['x'] as num? ?? 0).toDouble(),
            y: (json['y'] as num? ?? 0).toDouble(),
            width: (json['width'] as num? ?? 0).toDouble(),
            height: (json['height'] as num? ?? 0).toDouble(),
        );
    }
}

class MultiplayerPlayer {
    final String id;
    final String name;
    final int joinOrder;
    final double x;
    final double y;
    final double width;
    final double height;
    final String move;
    final double aimX;
    final double aimY;
    final bool alive;
    final bool spectator;
    final String spectatingId;
    final double health;
    final double maxHealth;
    final String primaryWeapon;
    final int ammoInMag;
    final int ammoCapacity;
    final bool reloading;
    final int reloadRemainingMs;
    final bool pendingAirstrike;
    final String activeDroneId;
    final int kills;
    final int deaths;
    final List<InventorySlotState> inventorySlots;

    const MultiplayerPlayer({
        required this.id,
        required this.name,
        required this.joinOrder,
        required this.x,
        required this.y,
        required this.width,
        required this.height,
        required this.move,
        required this.aimX,
        required this.aimY,
        required this.alive,
        required this.spectator,
        required this.spectatingId,
        required this.health,
        required this.maxHealth,
        required this.primaryWeapon,
        required this.ammoInMag,
        required this.ammoCapacity,
        required this.reloading,
        required this.reloadRemainingMs,
        required this.pendingAirstrike,
        required this.activeDroneId,
        required this.kills,
        required this.deaths,
        required this.inventorySlots,
    });

    factory MultiplayerPlayer.fromJson(Map<String, dynamic> json) {
        final List<dynamic> rawSlots =
                json['inventorySlots'] as List<dynamic>? ?? [];
        return MultiplayerPlayer(
            id: (json['id'] as String? ?? '').trim(),
            name: (json['name'] as String? ?? 'Player').trim(),
            joinOrder: (json['joinOrder'] as num? ?? 0).toInt(),
            x: (json['x'] as num? ?? 0).toDouble(),
            y: (json['y'] as num? ?? 0).toDouble(),
            width: (json['width'] as num? ?? 20).toDouble(),
            height: (json['height'] as num? ?? 20).toDouble(),
            move: (json['move'] as String? ?? 'none').trim(),
            aimX: (json['aimX'] as num? ?? 0).toDouble(),
            aimY: (json['aimY'] as num? ?? 0).toDouble(),
            alive: json['alive'] as bool? ?? false,
            spectator: json['spectator'] as bool? ?? false,
            spectatingId: (json['spectatingId'] as String? ?? '').trim(),
            health: (json['health'] as num? ?? 0).toDouble(),
            maxHealth: (json['maxHealth'] as num? ?? 400).toDouble(),
            primaryWeapon: (json['primaryWeapon'] as String? ?? '').trim(),
            ammoInMag: (json['ammoInMag'] as num? ?? 0).toInt(),
            ammoCapacity: (json['ammoCapacity'] as num? ?? 0).toInt(),
            reloading: json['reloading'] as bool? ?? false,
            reloadRemainingMs: (json['reloadRemainingMs'] as num? ?? 0).toInt(),
            pendingAirstrike: json['pendingAirstrike'] as bool? ?? false,
            activeDroneId: (json['activeDroneId'] as String? ?? '').trim(),
            kills: (json['kills'] as num? ?? 0).toInt(),
            deaths: (json['deaths'] as num? ?? 0).toInt(),
            inventorySlots: rawSlots
                    .whereType<Map>()
                    .map((Map slot) => InventorySlotState.fromJson(_mapFromDynamic(slot)))
                    .where((InventorySlotState slot) => slot.slot >= 2 && slot.slot <= 9)
                    .toList(growable: false),
        );
    }
}

class ProjectileState {
    final String id;
    final String kind;
    final String weaponId;
    final double x;
    final double y;

    const ProjectileState({
        required this.id,
        required this.kind,
        required this.weaponId,
        required this.x,
        required this.y,
    });

    factory ProjectileState.fromJson(Map<String, dynamic> json) {
        return ProjectileState(
            id: (json['id'] as String? ?? '').trim(),
            kind: (json['kind'] as String? ?? 'bullet').trim(),
            weaponId: (json['weaponId'] as String? ?? '').trim(),
            x: (json['x'] as num? ?? 0).toDouble(),
            y: (json['y'] as num? ?? 0).toDouble(),
        );
    }
}

class GrenadeState {
    final String id;
    final double x;
    final double y;
    final String ownerId;
    final double secondsToExplode;

    const GrenadeState({
        required this.id,
        required this.x,
        required this.y,
        required this.ownerId,
        required this.secondsToExplode,
    });

    factory GrenadeState.fromJson(Map<String, dynamic> json) {
        return GrenadeState(
            id: (json['id'] as String? ?? '').trim(),
            x: (json['x'] as num? ?? 0).toDouble(),
            y: (json['y'] as num? ?? 0).toDouble(),
            ownerId: (json['ownerId'] as String? ?? '').trim(),
            secondsToExplode: (json['secondsToExplode'] as num? ?? 0).toDouble(),
        );
    }
}

class DroneState {
    final String id;
    final String ownerId;
    final double x;
    final double y;
    final double width;
    final double height;
    final double secondsRemaining;

    const DroneState({
        required this.id,
        required this.ownerId,
        required this.x,
        required this.y,
        required this.width,
        required this.height,
        required this.secondsRemaining,
    });

    factory DroneState.fromJson(Map<String, dynamic> json) {
        return DroneState(
            id: (json['id'] as String? ?? '').trim(),
            ownerId: (json['ownerId'] as String? ?? '').trim(),
            x: (json['x'] as num? ?? 0).toDouble(),
            y: (json['y'] as num? ?? 0).toDouble(),
            width: (json['width'] as num? ?? 16).toDouble(),
            height: (json['height'] as num? ?? 16).toDouble(),
            secondsRemaining: (json['secondsRemaining'] as num? ?? 0).toDouble(),
        );
    }
}

class LootState {
    final String id;
    final String kind;
    final String weaponId;
    final String consumableType;
    final double x;
    final double y;

    const LootState({
        required this.id,
        required this.kind,
        required this.weaponId,
        required this.consumableType,
        required this.x,
        required this.y,
    });

    factory LootState.fromJson(Map<String, dynamic> json) {
        return LootState(
            id: (json['id'] as String? ?? '').trim(),
            kind: (json['kind'] as String? ?? '').trim(),
            weaponId: (json['weaponId'] as String? ?? '').trim(),
            consumableType: (json['consumableType'] as String? ?? '').trim(),
            x: (json['x'] as num? ?? 0).toDouble(),
            y: (json['y'] as num? ?? 0).toDouble(),
        );
    }
}

class ExplosionState {
    final String id;
    final String type;
    final double x;
    final double y;
    final int ttlMs;

    const ExplosionState({
        required this.id,
        required this.type,
        required this.x,
        required this.y,
        required this.ttlMs,
    });

    factory ExplosionState.fromJson(Map<String, dynamic> json) {
        return ExplosionState(
            id: (json['id'] as String? ?? '').trim(),
            type: (json['type'] as String? ?? '').trim(),
            x: (json['x'] as num? ?? 0).toDouble(),
            y: (json['y'] as num? ?? 0).toDouble(),
            ttlMs: (json['ttlMs'] as num? ?? 0).toInt(),
        );
    }
}

class AirstrikeWarningState {
    final String id;
    final String ownerId;
    final double x;
    final double y;
    final double radius;
    final double secondsToImpact;

    const AirstrikeWarningState({
        required this.id,
        required this.ownerId,
        required this.x,
        required this.y,
        required this.radius,
        required this.secondsToImpact,
    });

    factory AirstrikeWarningState.fromJson(Map<String, dynamic> json) {
        return AirstrikeWarningState(
            id: (json['id'] as String? ?? '').trim(),
            ownerId: (json['ownerId'] as String? ?? '').trim(),
            x: (json['x'] as num? ?? 0).toDouble(),
            y: (json['y'] as num? ?? 0).toDouble(),
            radius: (json['radius'] as num? ?? 0).toDouble(),
            secondsToImpact: (json['secondsToImpact'] as num? ?? 0).toDouble(),
        );
    }
}

class AppData extends ChangeNotifier {
    final WebSocketsHandler _wsHandler = WebSocketsHandler();
    final int _maxReconnectAttempts = 5;
    final Duration _reconnectDelay = const Duration(seconds: 3);
    final Duration _inputKeepAlive = const Duration(milliseconds: 100);
    final Duration _inputMinInterval = const Duration(milliseconds: 50);

    NetworkConfig networkConfig;
    String playerName;

    bool isConnected = false;
    bool isConnecting = false;
    String? playerId;
    MatchPhase phase = MatchPhase.connecting;

    String levelName = 'Battle Royale';
    double worldWidth = 0;
    double worldHeight = 0;
    int countdownSeconds = 60;
    int returnToLobbySeconds = 0;
    String winnerId = '';
    String winnerName = '';
    int aliveCount = 0;
    StormState storm = StormState.empty;

    List<WallZoneState> wallZones = const <WallZoneState>[];
    List<MultiplayerPlayer> players = const <MultiplayerPlayer>[];
    List<ProjectileState> projectiles = const <ProjectileState>[];
    List<GrenadeState> grenades = const <GrenadeState>[];
    List<DroneState> drones = const <DroneState>[];
    List<LootState> loot = const <LootState>[];
    List<ExplosionState> explosions = const <ExplosionState>[];
    List<AirstrikeWarningState> airstrikeWarnings =
            const <AirstrikeWarningState>[];

    int _reconnectAttempts = 0;
    bool _intentionalDisconnect = false;
    bool _disposed = false;

    String _lastMove = 'none';
    double _lastAimX = 0;
    double _lastAimY = 0;
    bool _lastFiring = false;
    DateTime _lastInputSentAt = DateTime.fromMillisecondsSinceEpoch(0);

    AppData({NetworkConfig initialConfig = NetworkConfig.defaults})
        : networkConfig = initialConfig,
            playerName = initialConfig.playerName {
        _connectToWebSocket();
    }

    MultiplayerPlayer? get localPlayer {
        final String? id = playerId;
        if (id == null || id.isEmpty) {
            return null;
        }
        for (final MultiplayerPlayer player in players) {
            if (player.id == id) {
                return player;
            }
        }
        return null;
    }

    MultiplayerPlayer? get spectatedPlayer {
        final MultiplayerPlayer? local = localPlayer;
        if (local == null || local.spectatingId.isEmpty) {
            return null;
        }
        for (final MultiplayerPlayer player in players) {
            if (player.id == local.spectatingId) {
                return player;
            }
        }
        return null;
    }

    List<MultiplayerPlayer> get sortedPlayers {
        final List<MultiplayerPlayer> sorted = List<MultiplayerPlayer>.from(
            players,
        );
        sorted.sort((MultiplayerPlayer a, MultiplayerPlayer b) {
            if (a.alive != b.alive) {
                return a.alive ? -1 : 1;
            }
            final int byKills = b.kills.compareTo(a.kills);
            if (byKills != 0) {
                return byKills;
            }
            final int byJoinOrder = a.joinOrder.compareTo(b.joinOrder);
            if (byJoinOrder != 0) {
                return byJoinOrder;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        return sorted;
    }

    bool get canControlAvatar {
        final MultiplayerPlayer? local = localPlayer;
        return isConnected &&
                phase == MatchPhase.playing &&
                local != null &&
                local.alive &&
                !local.spectator;
    }

    bool get canCycleSpectator {
        final MultiplayerPlayer? local = localPlayer;
        return isConnected &&
                phase == MatchPhase.playing &&
                local != null &&
                local.spectator;
    }

    bool get localPendingAirstrike => localPlayer?.pendingAirstrike ?? false;

    void updateNetworkConfig(NetworkConfig nextConfig) {
        networkConfig = nextConfig;
        playerName = nextConfig.playerName;
        _reconnectAttempts = 0;
        playerId = null;
        disconnect();
        _connectToWebSocket();
    }

    void sendInput({
        required String move,
        required double aimX,
        required double aimY,
        required bool firing,
    }) {
        if (_intentionalDisconnect ||
                _wsHandler.connectionStatus != ConnectionStatus.connected) {
            return;
        }

        final String normalizedMove = _normalizeDirection(move);
        final bool changed =
                normalizedMove != _lastMove ||
                (aimX - _lastAimX).abs() > 0.25 ||
                (aimY - _lastAimY).abs() > 0.25 ||
                firing != _lastFiring;

        final DateTime now = DateTime.now();
        final Duration elapsed = now.difference(_lastInputSentAt);
        if (!changed && elapsed < _inputKeepAlive) {
            return;
        }

        final bool criticalChange =
                normalizedMove != _lastMove || firing != _lastFiring;
        if (changed && !criticalChange && elapsed < _inputMinInterval) {
            return;
        }

        _lastMove = normalizedMove;
        _lastAimX = aimX;
        _lastAimY = aimY;
        _lastFiring = firing;
        _lastInputSentAt = now;

        _sendMessage(<String, dynamic>{
            'type': 'input',
            'move': normalizedMove,
            'aimX': aimX,
            'aimY': aimY,
            'firing': firing,
        });
    }

    void sendReloadAction() => _sendAction('reload');

    void sendSelectPrimaryAction() => _sendAction('selectPrimary');

    void sendDropPrimaryAction() => _sendAction('dropPrimary');

    void sendDetonateDroneAction() => _sendAction('detonateDrone');

    void sendSpectateNextAction() => _sendAction('spectateNext');

    void sendUseSlotAction(int slot) =>
            _sendAction('useSlot', extra: <String, dynamic>{'slot': slot});

    void sendAirstrikeTarget(double worldX, double worldY) {
        _sendMessage(<String, dynamic>{
            'type': 'airstrikeTarget',
            'x': worldX,
            'y': worldY,
        });
    }

    void disconnect() {
        _intentionalDisconnect = true;
        _wsHandler.disconnectFromServer();
        isConnected = false;
        isConnecting = false;
        players = const <MultiplayerPlayer>[];
        projectiles = const <ProjectileState>[];
        grenades = const <GrenadeState>[];
        drones = const <DroneState>[];
        loot = const <LootState>[];
        explosions = const <ExplosionState>[];
        airstrikeWarnings = const <AirstrikeWarningState>[];
        notifyListeners();
    }

    @override
    void dispose() {
        _disposed = true;
        disconnect();
        super.dispose();
    }

    void _connectToWebSocket() {
        if (_disposed) {
            return;
        }
        if (_reconnectAttempts >= _maxReconnectAttempts) {
            return;
        }

        _intentionalDisconnect = false;
        isConnecting = true;
        isConnected = false;
        phase = MatchPhase.connecting;
        notifyListeners();

        _wsHandler.connectToServer(
            networkConfig.serverHost,
            networkConfig.serverPort,
            _onWebSocketMessage,
            useSecureSocket: networkConfig.useSecureWebSocket,
            onError: _onWebSocketError,
            onDone: _onWebSocketClosed,
        );
    }

    void _onWebSocketMessage(String message) {
        try {
            final Object? decoded = jsonDecode(message);
            if (decoded is! Map) {
                return;
            }
            final Map<String, dynamic> data = _mapFromDynamic(decoded);
            final String type = (data['type'] as String? ?? '').trim();

            if (type == 'welcome') {
                playerId = data['id'] as String? ?? _wsHandler.socketId;
                isConnected = true;
                isConnecting = false;
                _reconnectAttempts = 0;
                _registerPlayer();
                notifyListeners();
                return;
            }

            if (type == 'initial') {
                isConnected = true;
                isConnecting = false;
                _reconnectAttempts = 0;
                final Object? rawInitialState = data['initialState'];
                _applyInitialState(
                    rawInitialState is Map ? _mapFromDynamic(rawInitialState) : {},
                );
                notifyListeners();
                return;
            }

            if (type == 'gameplay') {
                isConnected = true;
                isConnecting = false;
                _reconnectAttempts = 0;
                final Object? rawState = data['gameState'];
                _applyGameplayState(rawState is Map ? _mapFromDynamic(rawState) : {});
                notifyListeners();
            }
        } catch (error) {
            if (kDebugMode) {
                print('Error processant missatge WebSocket: $error');
            }
        }
    }

    void _applyInitialState(Map<String, dynamic> state) {
        levelName = (state['level'] as String? ?? levelName).trim();
        worldWidth = (state['worldWidth'] as num? ?? worldWidth).toDouble();
        worldHeight = (state['worldHeight'] as num? ?? worldHeight).toDouble();

        final List<dynamic> rawWalls = state['wallZones'] as List<dynamic>? ?? [];
        wallZones = rawWalls
                .whereType<Map>()
                .map((Map wall) => WallZoneState.fromJson(_mapFromDynamic(wall)))
                .toList(growable: false);
    }

    void _applyGameplayState(Map<String, dynamic> state) {
        levelName = (state['level'] as String? ?? levelName).trim();
        worldWidth = (state['worldWidth'] as num? ?? worldWidth).toDouble();
        worldHeight = (state['worldHeight'] as num? ?? worldHeight).toDouble();
        phase = _parsePhase(state['phase'] as String?);
        countdownSeconds = (state['countdownSeconds'] as num? ?? 0).toInt();
        returnToLobbySeconds = (state['returnToLobbySeconds'] as num? ?? 0).toInt();
        winnerId = (state['winnerId'] as String? ?? '').trim();
        winnerName = (state['winnerName'] as String? ?? '').trim();
        aliveCount = (state['aliveCount'] as num? ?? 0).toInt();

        final Object? rawStorm = state['storm'];
        storm = rawStorm is Map
                ? StormState.fromJson(_mapFromDynamic(rawStorm))
                : StormState.empty;

        final List<dynamic> rawPlayers = state['players'] as List<dynamic>? ?? [];
        players = rawPlayers
                .whereType<Map>()
                .map(
                    (Map player) => MultiplayerPlayer.fromJson(_mapFromDynamic(player)),
                )
                .toList(growable: false);

        final List<dynamic> rawProjectiles =
                state['projectiles'] as List<dynamic>? ?? [];
        projectiles = rawProjectiles
                .whereType<Map>()
                .map((Map p) => ProjectileState.fromJson(_mapFromDynamic(p)))
                .toList(growable: false);

        final List<dynamic> rawGrenades = state['grenades'] as List<dynamic>? ?? [];
        grenades = rawGrenades
                .whereType<Map>()
                .map((Map g) => GrenadeState.fromJson(_mapFromDynamic(g)))
                .toList(growable: false);

        final List<dynamic> rawDrones = state['drones'] as List<dynamic>? ?? [];
        drones = rawDrones
                .whereType<Map>()
                .map((Map d) => DroneState.fromJson(_mapFromDynamic(d)))
                .toList(growable: false);

        final List<dynamic> rawLoot = state['loot'] as List<dynamic>? ?? [];
        loot = rawLoot
                .whereType<Map>()
                .map((Map item) => LootState.fromJson(_mapFromDynamic(item)))
                .toList(growable: false);

        final List<dynamic> rawExplosions =
                state['explosions'] as List<dynamic>? ?? [];
        explosions = rawExplosions
                .whereType<Map>()
                .map((Map ex) => ExplosionState.fromJson(_mapFromDynamic(ex)))
                .toList(growable: false);

        final List<dynamic> rawWarnings =
                state['airstrikeWarnings'] as List<dynamic>? ?? [];
        airstrikeWarnings = rawWarnings
                .whereType<Map>()
                .map(
                    (Map warning) =>
                            AirstrikeWarningState.fromJson(_mapFromDynamic(warning)),
                )
                .toList(growable: false);
    }

    void _registerPlayer() {
        _sendMessage(<String, dynamic>{
            'type': 'register',
            'playerName': playerName,
        });
    }

    void _sendAction(String name, {Map<String, dynamic>? extra}) {
        final Map<String, dynamic> payload = <String, dynamic>{
            'type': 'action',
            'name': name,
        };
        if (extra != null) {
            payload.addAll(extra);
        }
        _sendMessage(payload);
    }

    void _onWebSocketError(dynamic error) {
        if (kDebugMode) {
            print('Error de WebSocket: $error');
        }
        isConnected = false;
        isConnecting = false;
        notifyListeners();
        _scheduleReconnect();
    }

    void _onWebSocketClosed() {
        isConnected = false;
        isConnecting = false;
        notifyListeners();
        _scheduleReconnect();
    }

    void _scheduleReconnect() {
        if (_intentionalDisconnect || _disposed) {
            return;
        }
        if (_reconnectAttempts >= _maxReconnectAttempts) {
            return;
        }

        _reconnectAttempts++;
        Future<void>.delayed(_reconnectDelay, () {
            if (_intentionalDisconnect || _disposed) {
                return;
            }
            _connectToWebSocket();
        });
    }

    void _sendMessage(Map<String, dynamic> payload) {
        if (_intentionalDisconnect ||
                _wsHandler.connectionStatus != ConnectionStatus.connected) {
            return;
        }
        _wsHandler.sendMessage(jsonEncode(payload));
    }

    MatchPhase _parsePhase(String? rawPhase) {
        switch ((rawPhase ?? '').trim().toLowerCase()) {
            case 'waiting':
                return MatchPhase.waiting;
            case 'playing':
                return MatchPhase.playing;
            case 'finished':
                return MatchPhase.finished;
            case 'connecting':
            default:
                return MatchPhase.connecting;
        }
    }

    String _normalizeDirection(String rawDirection) {
        switch (rawDirection.trim()) {
            case 'up':
            case 'upLeft':
            case 'left':
            case 'downLeft':
            case 'down':
            case 'downRight':
            case 'right':
            case 'upRight':
            case 'none':
                return rawDirection.trim();
            default:
                return 'none';
        }
    }
}

Map<String, dynamic> _mapFromDynamic(Map<dynamic, dynamic> raw) {
    return raw.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
}
