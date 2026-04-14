import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'network_config.dart';
import 'utils_websockets.dart';

enum MatchPhase { connecting, waiting, playing, finished }

class MultiplayerPlayer {
  final String id;
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final int score;
  final int gemsCollected;
  final int kills;
  final int deaths;
  final int placement;
  final bool alive;
  final double health;
  final double shield;
  final double maxHealth;
  final double maxShield;
  final bool recentlyHit;
  final double aimX;
  final double aimY;
  final int equippedSlot;
  final List<InventoryWeaponSlot?> inventory;
  final EquippedWeapon? equippedWeapon;
  final String direction;
  final String facing;
  final bool moving;
  final bool reloading;
  final int joinOrder;

  const MultiplayerPlayer({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.score,
    required this.gemsCollected,
    required this.kills,
    required this.deaths,
    required this.placement,
    required this.alive,
    required this.health,
    required this.shield,
    required this.maxHealth,
    required this.maxShield,
    required this.recentlyHit,
    required this.aimX,
    required this.aimY,
    required this.equippedSlot,
    required this.inventory,
    required this.equippedWeapon,
    required this.direction,
    required this.facing,
    required this.moving,
    required this.reloading,
    required this.joinOrder,
  });

  factory MultiplayerPlayer.fromJson(Map<String, dynamic> json) {
    return MultiplayerPlayer(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? 'Player').trim(),
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      width: (json['width'] as num? ?? 20).toDouble(),
      height: (json['height'] as num? ?? 20).toDouble(),
      score: (json['score'] as num? ?? 0).toInt(),
      gemsCollected: (json['gemsCollected'] as num? ?? 0).toInt(),
      kills: (json['kills'] as num? ?? 0).toInt(),
      deaths: (json['deaths'] as num? ?? 0).toInt(),
      placement: (json['placement'] as num? ?? 0).toInt(),
      alive: json['alive'] as bool? ?? true,
      health: (json['health'] as num? ?? 100).toDouble(),
      shield: (json['shield'] as num? ?? 0).toDouble(),
      maxHealth: (json['maxHealth'] as num? ?? 100).toDouble(),
      maxShield: (json['maxShield'] as num? ?? 100).toDouble(),
      recentlyHit: json['recentlyHit'] as bool? ?? false,
      aimX: (json['aimX'] as num? ?? 0).toDouble(),
      aimY: (json['aimY'] as num? ?? 0).toDouble(),
      equippedSlot: (json['equippedSlot'] as num? ?? 0).toInt(),
      inventory: ((json['inventory'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic value) {
            if (value is! Map) {
              return null;
            }
            return InventoryWeaponSlot.fromJson(
              value.map(
                (dynamic key, dynamic data) => MapEntry(key.toString(), data),
              ),
            );
          })
          .toList(growable: false)),
      equippedWeapon: json['equippedWeapon'] is Map
          ? EquippedWeapon.fromJson(
              (json['equippedWeapon'] as Map).map(
                (dynamic key, dynamic value) => MapEntry(key.toString(), value),
              ),
            )
          : null,
      direction: (json['direction'] as String? ?? 'none').trim(),
      facing: (json['facing'] as String? ?? 'down').trim(),
      moving: json['moving'] as bool? ?? false,
      reloading: json['reloading'] as bool? ?? false,
      joinOrder: (json['joinOrder'] as num? ?? 0).toInt(),
    );
  }
}

class InventoryWeaponSlot {
  final String kind;
  final String weaponType;
  final String label;
  final String texturePath;
  final int clipAmmo;
  final int reserveAmmo;
  final int maxClipAmmo;

  const InventoryWeaponSlot({
    required this.kind,
    required this.weaponType,
    required this.label,
    required this.texturePath,
    required this.clipAmmo,
    required this.reserveAmmo,
    required this.maxClipAmmo,
  });

  factory InventoryWeaponSlot.fromJson(Map<String, dynamic> json) {
    return InventoryWeaponSlot(
      kind: (json['kind'] as String? ?? '').trim(),
      weaponType: (json['weaponType'] as String? ?? '').trim(),
      label: (json['label'] as String? ?? '').trim(),
      texturePath: (json['texturePath'] as String? ?? '').trim(),
      clipAmmo: (json['clipAmmo'] as num? ?? 0).toInt(),
      reserveAmmo: (json['reserveAmmo'] as num? ?? 0).toInt(),
      maxClipAmmo: (json['maxClipAmmo'] as num? ?? 0).toInt(),
    );
  }
}

class EquippedWeapon {
  final String type;
  final String label;
  final String texturePath;
  final int clipAmmo;
  final int reserveAmmo;

  const EquippedWeapon({
    required this.type,
    required this.label,
    required this.texturePath,
    required this.clipAmmo,
    required this.reserveAmmo,
  });

  factory EquippedWeapon.fromJson(Map<String, dynamic> json) {
    return EquippedWeapon(
      type: (json['type'] as String? ?? '').trim(),
      label: (json['label'] as String? ?? '').trim(),
      texturePath: (json['texturePath'] as String? ?? '').trim(),
      clipAmmo: (json['clipAmmo'] as num? ?? 0).toInt(),
      reserveAmmo: (json['reserveAmmo'] as num? ?? 0).toInt(),
    );
  }
}

class GroundItem {
  final String id;
  final String kind;
  final String weaponType;
  final String texturePath;
  final double x;
  final double y;
  final double width;
  final double height;
  final int amount;
  final double floatPhase;

  const GroundItem({
    required this.id,
    required this.kind,
    required this.weaponType,
    required this.texturePath,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.amount,
    required this.floatPhase,
  });

  factory GroundItem.fromJson(Map<String, dynamic> json) {
    return GroundItem(
      id: (json['id'] as String? ?? '').trim(),
      kind: (json['kind'] as String? ?? '').trim(),
      weaponType: (json['weaponType'] as String? ?? '').trim(),
      texturePath: (json['texturePath'] as String? ?? '').trim(),
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      width: (json['width'] as num? ?? 16).toDouble(),
      height: (json['height'] as num? ?? 16).toDouble(),
      amount: (json['amount'] as num? ?? 0).toInt(),
      floatPhase: (json['floatPhase'] as num? ?? 0).toDouble(),
    );
  }
}

class ProjectileSnapshot {
  final String id;
  final String ownerId;
  final double x;
  final double y;
  final double radius;

  const ProjectileSnapshot({
    required this.id,
    required this.ownerId,
    required this.x,
    required this.y,
    required this.radius,
  });

  factory ProjectileSnapshot.fromJson(Map<String, dynamic> json) {
    return ProjectileSnapshot(
      id: (json['id'] as String? ?? '').trim(),
      ownerId: (json['ownerId'] as String? ?? '').trim(),
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      radius: (json['radius'] as num? ?? 2).toDouble(),
    );
  }
}

class RankingEntry {
  final String id;
  final String name;
  final bool alive;
  final int placement;
  final int kills;
  final int score;

  const RankingEntry({
    required this.id,
    required this.name,
    required this.alive,
    required this.placement,
    required this.kills,
    required this.score,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    return RankingEntry(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? 'Player').trim(),
      alive: json['alive'] as bool? ?? false,
      placement: (json['placement'] as num? ?? 0).toInt(),
      kills: (json['kills'] as num? ?? 0).toInt(),
      score: (json['score'] as num? ?? 0).toInt(),
    );
  }
}

class MultiplayerGem {
  final String id;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final int value;

  const MultiplayerGem({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.value,
  });

  factory MultiplayerGem.fromJson(Map<String, dynamic> json) {
    return MultiplayerGem(
      id: (json['id'] as String? ?? '').trim(),
      type: (json['type'] as String? ?? 'green').trim().toLowerCase(),
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      width: (json['width'] as num? ?? 15).toDouble(),
      height: (json['height'] as num? ?? 15).toDouble(),
      value: (json['value'] as num? ?? 1).toInt(),
    );
  }
}

class TransformSnapshot {
  final int index;
  final double x;
  final double y;

  const TransformSnapshot({
    required this.index,
    required this.x,
    required this.y,
  });

  factory TransformSnapshot.fromJson(Map<String, dynamic> json) {
    return TransformSnapshot(
      index: (json['index'] as num? ?? -1).toInt(),
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
    );
  }
}

class _PlayerStaticData {
  final String id;
  final String name;
  final double width;
  final double height;
  final int joinOrder;

  const _PlayerStaticData({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.joinOrder,
  });
}

class _PlayerDynamicData {
  final String id;
  final double x;
  final double y;
  final int score;
  final int gemsCollected;
  final int kills;
  final int deaths;
  final int placement;
  final bool alive;
  final double health;
  final double shield;
  final double maxHealth;
  final double maxShield;
  final bool recentlyHit;
  final double aimX;
  final double aimY;
  final int equippedSlot;
  final List<InventoryWeaponSlot?> inventory;
  final EquippedWeapon? equippedWeapon;
  final String direction;
  final String facing;
  final bool moving;
  final bool reloading;

  const _PlayerDynamicData({
    required this.id,
    required this.x,
    required this.y,
    required this.score,
    required this.gemsCollected,
    required this.kills,
    required this.deaths,
    required this.placement,
    required this.alive,
    required this.health,
    required this.shield,
    required this.maxHealth,
    required this.maxShield,
    required this.recentlyHit,
    required this.aimX,
    required this.aimY,
    required this.equippedSlot,
    required this.inventory,
    required this.equippedWeapon,
    required this.direction,
    required this.facing,
    required this.moving,
    required this.reloading,
  });
}

class _DirectionVector {
  final double dx;
  final double dy;
  final String facing;

  const _DirectionVector(this.dx, this.dy, this.facing);
}

class _TrainingWeaponStats {
  final double projectileSpeed;
  final double range;
  final double fireInterval;
  final int pellets;
  final double spreadRadians;
  final double reloadSeconds;

  const _TrainingWeaponStats({
    required this.projectileSpeed,
    required this.range,
    required this.fireInterval,
    this.pellets = 1,
    this.spreadRadians = 0,
    required this.reloadSeconds,
  });
}

class TrainingWorldRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const TrainingWorldRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

class TrainingSlowZone {
  final double x;
  final double y;
  final double width;
  final double height;
  final double speedMultiplier;

  const TrainingSlowZone({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speedMultiplier,
  });
}

class _TrainingProjectileState {
  final String id;
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double remainingDistance;

  const _TrainingProjectileState({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.remainingDistance,
  });
}

class AppData extends ChangeNotifier {
  static const String _trainingPlayerId = 'LOCAL_TRAINING';
  static const double _trainingMoveSpeed = 95;
  static const double _trainingPickupRadius = 42;

  final WebSocketsHandler _wsHandler = WebSocketsHandler();
  final int _maxReconnectAttempts = 5;
  final Duration _reconnectDelay = const Duration(seconds: 3);

  NetworkConfig networkConfig;
  String playerName;

  bool isConnected = false;
  bool isConnecting = false;
  String? playerId;
  MatchPhase phase = MatchPhase.connecting;
  String levelName = 'All together now';
  int countdownSeconds = 60;
  int remainingGems = 0;
  int alivePlayers = 0;
  String? winnerId;
  List<MultiplayerPlayer> players = const <MultiplayerPlayer>[];
  List<MultiplayerGem> gems = const <MultiplayerGem>[];
  List<GroundItem> items = const <GroundItem>[];
  List<ProjectileSnapshot> projectiles = const <ProjectileSnapshot>[];
  List<RankingEntry> ranking = const <RankingEntry>[];
  List<TransformSnapshot> layerTransforms = const <TransformSnapshot>[];
  List<TransformSnapshot> zoneTransforms = const <TransformSnapshot>[];

  int _reconnectAttempts = 0;
  bool _intentionalDisconnect = false;
  bool _disposed = false;
  String _lastDirection = 'none';
  Map<String, _PlayerStaticData> _playerStaticById =
      const <String, _PlayerStaticData>{};
  Map<String, _PlayerDynamicData> _playerDynamicById =
      const <String, _PlayerDynamicData>{};
  int _trainingProjectileSeq = 0;
  int _trainingItemSeq = 0;
  final List<_TrainingProjectileState> _trainingProjectiles =
      <_TrainingProjectileState>[];
  double _trainingElapsedSeconds = 0;
  double _trainingNextShotSeconds = 0;
  double? _trainingReloadUntilSeconds;

  AppData({NetworkConfig initialConfig = NetworkConfig.defaults})
    : networkConfig = initialConfig,
      playerName = initialConfig.playerName {
    if (networkConfig.trainingMode) {
      _initializeTrainingSandbox();
    } else {
      _connectToWebSocket();
    }
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

  List<MultiplayerPlayer> get sortedPlayers {
    final List<MultiplayerPlayer> sorted = List<MultiplayerPlayer>.from(
      players,
    );
    sorted.sort((MultiplayerPlayer a, MultiplayerPlayer b) {
      if (a.alive != b.alive) {
        return a.alive ? -1 : 1;
      }
      if (a.alive && b.alive) {
        final int byKills = b.kills.compareTo(a.kills);
        if (byKills != 0) {
          return byKills;
        }
      } else {
        final int byPlacement = a.placement.compareTo(b.placement);
        if (byPlacement != 0) {
          return byPlacement;
        }
      }
      final int byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      final int byGems = b.gemsCollected.compareTo(a.gemsCollected);
      if (byGems != 0) {
        return byGems;
      }
      final int byJoinOrder = a.joinOrder.compareTo(b.joinOrder);
      if (byJoinOrder != 0) {
        return byJoinOrder;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  bool get canMove => isConnected && phase == MatchPhase.playing;

  bool get canRequestMatchRestart =>
      isConnected && phase == MatchPhase.finished;

  MultiplayerPlayer? playerById(String playerId) {
    for (final MultiplayerPlayer player in players) {
      if (player.id == playerId) {
        return player;
      }
    }
    return null;
  }

  void updateNetworkConfig(NetworkConfig nextConfig) {
    networkConfig = nextConfig;
    playerName = nextConfig.playerName;
    _reconnectAttempts = 0;
    playerId = null;
    _lastDirection = 'none';
    disconnect();
    if (networkConfig.trainingMode) {
      _initializeTrainingSandbox();
    } else {
      _connectToWebSocket();
    }
  }

  void updateMovementDirection(String direction) {
    final String normalized = _normalizeDirection(direction);
    if (_lastDirection == normalized) {
      return;
    }
    _lastDirection = normalized;
    if (networkConfig.trainingMode) {
      _applyTrainingDirection(normalized);
      return;
    }
    _sendMessage(<String, dynamic>{'type': 'direction', 'value': normalized});
  }

  void requestMatchRestart() {
    if (!canRequestMatchRestart) {
      return;
    }
    _sendMessage(<String, dynamic>{'type': 'restartMatch'});
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _lastDirection = 'none';
    _wsHandler.disconnectFromServer();
    isConnected = false;
    isConnecting = false;
    players = const <MultiplayerPlayer>[];
    gems = const <MultiplayerGem>[];
    items = const <GroundItem>[];
    projectiles = const <ProjectileSnapshot>[];
    ranking = const <RankingEntry>[];
    _playerStaticById = const <String, _PlayerStaticData>{};
    _playerDynamicById = const <String, _PlayerDynamicData>{};
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
    if (networkConfig.trainingMode) {
      _initializeTrainingSandbox();
      return;
    }
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        print("S'ha assolit el màxim d'intents de reconnexió.");
      }
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
        playerId = _wsHandler.socketId;
        isConnected = true;
        isConnecting = false;
        _reconnectAttempts = 0;
        _registerPlayer();
        notifyListeners();
        return;
      }

      if (type == 'snapshot' || type == 'initial') {
        isConnected = true;
        isConnecting = false;
        _reconnectAttempts = 0;
        final Object? rawSnapshot = data['snapshot'] ?? data['initialState'];
        _applySnapshotState(
          rawSnapshot is Map ? _mapFromDynamic(rawSnapshot) : {},
        );
        notifyListeners();
        return;
      }

      if (type == 'gameplay') {
        isConnected = true;
        isConnecting = false;
        _reconnectAttempts = 0;
        final Object? rawGameState = data['gameState'];
        _applyGameplayState(
          rawGameState is Map ? _mapFromDynamic(rawGameState) : {},
        );
        notifyListeners();
        return;
      }

      if (type == 'update') {
        isConnected = true;
        isConnecting = false;
        _reconnectAttempts = 0;
        final Object? rawGameState = data['gameState'];
        final Map<String, dynamic> gameState = rawGameState is Map
            ? _mapFromDynamic(rawGameState)
            : {};
        _applySnapshotState(gameState);
        _applyGameplayState(gameState);
        notifyListeners();
      }
    } catch (error) {
      if (kDebugMode) {
        print('Error processant missatge WebSocket: $error');
      }
    }
  }

  void _applySnapshotState(Map<String, dynamic> state) {
    levelName = (state['level'] as String? ?? levelName).trim();

    if (state.containsKey('players')) {
      final List<dynamic> rawPlayers = state['players'] as List<dynamic>? ?? [];
      _playerStaticById = <String, _PlayerStaticData>{
        for (final Map rawPlayer in rawPlayers.whereType<Map>())
          (_mapFromDynamic(rawPlayer)['id'] as String? ?? '').trim():
              _staticPlayerFromJson(_mapFromDynamic(rawPlayer)),
      }..remove('');
      _playerDynamicById = Map<String, _PlayerDynamicData>.fromEntries(
        _playerDynamicById.entries.where(
          (MapEntry<String, _PlayerDynamicData> entry) =>
              _playerStaticById.containsKey(entry.key),
        ),
      );
    }

    if (state.containsKey('gems')) {
      gems = _parseGems(state['gems'] as List<dynamic>?);
    }

    _rebuildPlayers();
  }

  void _applyGameplayState(Map<String, dynamic> state) {
    levelName = (state['level'] as String? ?? levelName).trim();
    phase = _parsePhase(state['phase'] as String?);
    countdownSeconds = (state['countdownSeconds'] as num? ?? 0).toInt();
    alivePlayers = (state['alivePlayers'] as num? ?? 0).toInt();
    remainingGems =
        (state['remainingGems'] as num? ?? state['gems']?.length ?? 0).toInt();
    winnerId = state['winnerId'] as String?;

    final Map<String, _PlayerDynamicData> nextDynamicById =
        Map<String, _PlayerDynamicData>.from(_playerDynamicById);

    final Object? rawSelfPlayer = state['selfPlayer'];
    if (rawSelfPlayer is Map) {
      final Map<String, dynamic> selfPlayer = _mapFromDynamic(rawSelfPlayer);
      final String selfId = (selfPlayer['id'] as String? ?? '').trim();
      if (selfId.isNotEmpty) {
        nextDynamicById[selfId] = _dynamicPlayerFromJson(selfPlayer);
      }
    }

    if (state.containsKey('otherPlayers')) {
      final String currentPlayerId = (playerId ?? '').trim();
      nextDynamicById.removeWhere(
        (String id, _PlayerDynamicData _) => id != currentPlayerId,
      );

      final List<dynamic> rawOtherPlayers =
          state['otherPlayers'] as List<dynamic>? ?? [];
      for (final Map rawPlayer in rawOtherPlayers.whereType<Map>()) {
        final Map<String, dynamic> parsedPlayer = _mapFromDynamic(rawPlayer);
        final String id = (parsedPlayer['id'] as String? ?? '').trim();
        if (id.isEmpty) {
          continue;
        }
        nextDynamicById[id] = _dynamicPlayerFromJson(parsedPlayer);
      }
    } else if (state.containsKey('players')) {
      nextDynamicById
        ..clear()
        ..addAll(
          <String, _PlayerDynamicData>{
            for (final Map rawPlayer
                in (state['players'] as List<dynamic>? ?? const <dynamic>[])
                    .whereType<Map>())
              (_mapFromDynamic(rawPlayer)['id'] as String? ?? '').trim():
                  _dynamicPlayerFromJson(_mapFromDynamic(rawPlayer)),
          }..remove(''),
        );
    }

    _playerDynamicById = nextDynamicById;

    if (state.containsKey('gems')) {
      gems = _parseGems(state['gems'] as List<dynamic>?);
    }
    if (state.containsKey('items')) {
      items = _parseItems(state['items'] as List<dynamic>?);
    }
    if (state.containsKey('projectiles')) {
      projectiles = _parseProjectiles(state['projectiles'] as List<dynamic>?);
    }
    if (state.containsKey('ranking')) {
      ranking = _parseRanking(state['ranking'] as List<dynamic>?);
    }

    _rebuildPlayers();

    final List<dynamic> rawLayerTransforms =
        state['layerTransforms'] as List<dynamic>? ?? [];
    layerTransforms = rawLayerTransforms
        .whereType<Map>()
        .map(
          (Map transform) =>
              TransformSnapshot.fromJson(_mapFromDynamic(transform)),
        )
        .toList(growable: false);

    final List<dynamic> rawZoneTransforms =
        state['zoneTransforms'] as List<dynamic>? ?? [];
    zoneTransforms = rawZoneTransforms
        .whereType<Map>()
        .map(
          (Map transform) =>
              TransformSnapshot.fromJson(_mapFromDynamic(transform)),
        )
        .toList(growable: false);
  }

  _PlayerStaticData _staticPlayerFromJson(Map<String, dynamic> json) {
    return _PlayerStaticData(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? 'Player').trim(),
      width: (json['width'] as num? ?? 20).toDouble(),
      height: (json['height'] as num? ?? 20).toDouble(),
      joinOrder: (json['joinOrder'] as num? ?? 0).toInt(),
    );
  }

  _PlayerDynamicData _dynamicPlayerFromJson(Map<String, dynamic> json) {
    return _PlayerDynamicData(
      id: (json['id'] as String? ?? '').trim(),
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      score: (json['score'] as num? ?? 0).toInt(),
      gemsCollected: (json['gemsCollected'] as num? ?? 0).toInt(),
      kills: (json['kills'] as num? ?? 0).toInt(),
      deaths: (json['deaths'] as num? ?? 0).toInt(),
      placement: (json['placement'] as num? ?? 0).toInt(),
      alive: json['alive'] as bool? ?? true,
      health: (json['health'] as num? ?? 100).toDouble(),
      shield: (json['shield'] as num? ?? 0).toDouble(),
      maxHealth: (json['maxHealth'] as num? ?? 100).toDouble(),
      maxShield: (json['maxShield'] as num? ?? 100).toDouble(),
      recentlyHit: json['recentlyHit'] as bool? ?? false,
      aimX: (json['aimX'] as num? ?? 0).toDouble(),
      aimY: (json['aimY'] as num? ?? 0).toDouble(),
      equippedSlot: (json['equippedSlot'] as num? ?? 0).toInt(),
      inventory: ((json['inventory'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic value) {
            if (value is! Map) {
              return null;
            }
            return InventoryWeaponSlot.fromJson(_mapFromDynamic(value));
          })
          .toList(growable: false)),
      equippedWeapon: json['equippedWeapon'] is Map
          ? EquippedWeapon.fromJson(
              _mapFromDynamic(json['equippedWeapon'] as Map),
            )
          : null,
      direction: (json['direction'] as String? ?? 'none').trim(),
      facing: (json['facing'] as String? ?? 'down').trim(),
      moving: json['moving'] as bool? ?? false,
      reloading: json['reloading'] as bool? ?? false,
    );
  }

  void _rebuildPlayers() {
    final Set<String> ids = <String>{
      ..._playerStaticById.keys,
      ..._playerDynamicById.keys,
    };
    players = ids
        .map((String id) {
          final _PlayerStaticData? staticData = _playerStaticById[id];
          final _PlayerDynamicData? dynamicData = _playerDynamicById[id];
          return MultiplayerPlayer(
            id: id,
            name: staticData?.name ?? 'Player',
            x: dynamicData?.x ?? 0,
            y: dynamicData?.y ?? 0,
            width: staticData?.width ?? 20,
            height: staticData?.height ?? 20,
            score: dynamicData?.score ?? 0,
            gemsCollected: dynamicData?.gemsCollected ?? 0,
            kills: dynamicData?.kills ?? 0,
            deaths: dynamicData?.deaths ?? 0,
            placement: dynamicData?.placement ?? 0,
            alive: dynamicData?.alive ?? true,
            health: dynamicData?.health ?? 100,
            shield: dynamicData?.shield ?? 0,
            maxHealth: dynamicData?.maxHealth ?? 100,
            maxShield: dynamicData?.maxShield ?? 100,
            recentlyHit: dynamicData?.recentlyHit ?? false,
            aimX: dynamicData?.aimX ?? 0,
            aimY: dynamicData?.aimY ?? 0,
            equippedSlot: dynamicData?.equippedSlot ?? 0,
            inventory: dynamicData?.inventory ?? const <InventoryWeaponSlot?>[],
            equippedWeapon: dynamicData?.equippedWeapon,
            direction: dynamicData?.direction ?? 'none',
            facing: dynamicData?.facing ?? 'down',
            moving: dynamicData?.moving ?? false,
            reloading: dynamicData?.reloading ?? false,
            joinOrder: staticData?.joinOrder ?? 0,
          );
        })
        .toList(growable: false);
  }

  List<MultiplayerGem> _parseGems(List<dynamic>? rawGems) {
    return (rawGems ?? const <dynamic>[])
        .whereType<Map>()
        .map((Map gem) => MultiplayerGem.fromJson(_mapFromDynamic(gem)))
        .toList(growable: false);
  }

  List<GroundItem> _parseItems(List<dynamic>? rawItems) {
    return (rawItems ?? const <dynamic>[])
        .whereType<Map>()
        .map((Map item) => GroundItem.fromJson(_mapFromDynamic(item)))
        .toList(growable: false);
  }

  List<ProjectileSnapshot> _parseProjectiles(List<dynamic>? rawProjectiles) {
    return (rawProjectiles ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (Map projectile) =>
              ProjectileSnapshot.fromJson(_mapFromDynamic(projectile)),
        )
        .toList(growable: false);
  }

  List<RankingEntry> _parseRanking(List<dynamic>? rawRanking) {
    return (rawRanking ?? const <dynamic>[])
        .whereType<Map>()
        .map((Map entry) => RankingEntry.fromJson(_mapFromDynamic(entry)))
        .toList(growable: false);
  }

  void updateAim(double worldX, double worldY) {
    if (networkConfig.trainingMode) {
      _applyTrainingAim(worldX, worldY);
      return;
    }
    _sendMessage(<String, dynamic>{'type': 'aim', 'x': worldX, 'y': worldY});
  }

  void shootAt(double worldX, double worldY) {
    if (networkConfig.trainingMode) {
      _applyTrainingShootAt(worldX, worldY);
      return;
    }
    _sendMessage(<String, dynamic>{'type': 'shoot', 'x': worldX, 'y': worldY});
  }

  void pickupNearestItem() {
    if (networkConfig.trainingMode) {
      _applyTrainingPickupNearest();
      return;
    }
    _sendMessage(<String, dynamic>{'type': 'pickup'});
  }

  void dropWeapon({int? slot}) {
    if (networkConfig.trainingMode) {
      _applyTrainingDropWeapon(slot: slot);
      return;
    }
    final Map<String, dynamic> payload = <String, dynamic>{
      'type': 'dropWeapon',
    };
    if (slot != null) {
      payload['slot'] = slot;
    }
    _sendMessage(payload);
  }

  void reloadWeapon() {
    if (networkConfig.trainingMode) {
      _applyTrainingReload();
      return;
    }
    _sendMessage(<String, dynamic>{'type': 'reload'});
  }

  void selectSlot(int slot) {
    if (networkConfig.trainingMode) {
      _applyTrainingSelectSlot(slot);
      return;
    }
    _sendMessage(<String, dynamic>{'type': 'selectSlot', 'slot': slot});
  }

  void _registerPlayer() {
    _sendMessage(<String, dynamic>{
      'type': 'register',
      'playerName': playerName,
      'trainingMode': networkConfig.trainingMode,
    });
  }

  void tickTraining(
    double delta, {
    double worldWidth = 2000,
    double worldHeight = 2000,
    List<TrainingWorldRect> blockingRects = const <TrainingWorldRect>[],
    List<TrainingSlowZone> slowZones = const <TrainingSlowZone>[],
  }) {
    if (!networkConfig.trainingMode) {
      return;
    }
    _trainingElapsedSeconds += math.max(0, delta);
    final _PlayerDynamicData? current = _playerDynamicById[_trainingPlayerId];
    final _PlayerStaticData? staticData = _playerStaticById[_trainingPlayerId];
    if (current == null || staticData == null) {
      return;
    }

    _completeTrainingReloadIfNeeded(current);
    final _PlayerDynamicData? afterReload = _playerDynamicById[_trainingPlayerId];
    final _PlayerDynamicData playerState = afterReload ?? current;

    final _DirectionVector vector = _directionVectorFor(playerState.direction);
    final double speedMultiplier = _speedMultiplierForPosition(
      playerState.x,
      playerState.y,
      staticData.width,
      staticData.height,
      slowZones,
    );
    final double step = _trainingMoveSpeed * speedMultiplier * delta;
    final double maxX = (worldWidth - staticData.width).clamp(0, double.infinity);
    final double maxY = (worldHeight - staticData.height).clamp(0, double.infinity);
    double nextX = (playerState.x + vector.dx * step).clamp(0, maxX);
    double nextY = (playerState.y + vector.dy * step).clamp(0, maxY);

    if (_intersectsAnyBlockingRect(
      nextX,
      playerState.y,
      staticData.width,
      staticData.height,
      blockingRects,
    )) {
      nextX = playerState.x;
    }
    if (_intersectsAnyBlockingRect(
      nextX,
      nextY,
      staticData.width,
      staticData.height,
      blockingRects,
    )) {
      nextY = playerState.y;
      if (_intersectsAnyBlockingRect(
        nextX,
        nextY,
        staticData.width,
        staticData.height,
        blockingRects,
      )) {
        nextX = playerState.x;
      }
    }

    final bool moving = playerState.direction != 'none';

    _playerDynamicById = <String, _PlayerDynamicData>{
      ..._playerDynamicById,
      _trainingPlayerId: _copyDynamic(
        playerState,
        x: nextX,
        y: nextY,
        moving: moving,
      ),
    };
    _updateTrainingProjectiles(delta, worldWidth: worldWidth, worldHeight: worldHeight);
    _rebuildPlayers();
    notifyListeners();
  }

  void _initializeTrainingSandbox() {
    _intentionalDisconnect = true;
    _wsHandler.disconnectFromServer();
    _reconnectAttempts = 0;
    isConnected = true;
    isConnecting = false;
    phase = MatchPhase.playing;
    levelName = 'Camp de proves';
    playerId = _trainingPlayerId;
    alivePlayers = 1;
    winnerId = null;
    remainingGems = 0;
    _trainingProjectileSeq = 0;
    _trainingItemSeq = 0;
    _trainingElapsedSeconds = 0;
    _trainingNextShotSeconds = 0;
    _trainingReloadUntilSeconds = null;
    _trainingProjectiles.clear();

    _playerStaticById = <String, _PlayerStaticData>{
      _trainingPlayerId: _PlayerStaticData(
        id: _trainingPlayerId,
        name: playerName,
        width: 20,
        height: 20,
        joinOrder: 0,
      ),
    };

    final List<InventoryWeaponSlot?> inventory = <InventoryWeaponSlot?>[
      null,
      null,
      null,
      null,
      null,
    ];

    _playerDynamicById = <String, _PlayerDynamicData>{
      _trainingPlayerId: _PlayerDynamicData(
        id: _trainingPlayerId,
        x: 64,
        y: 64,
        score: 0,
        gemsCollected: 0,
        kills: 0,
        deaths: 0,
        placement: 1,
        alive: true,
        health: 100,
        shield: 100,
        maxHealth: 100,
        maxShield: 100,
        recentlyHit: false,
        aimX: 140,
        aimY: 140,
        equippedSlot: 0,
        inventory: inventory,
        equippedWeapon: null,
        direction: 'none',
        facing: 'down',
        moving: false,
        reloading: false,
      ),
    };

    gems = const <MultiplayerGem>[];
    items = <GroundItem>[
      _trainingGroundWeapon('glock', 120, 80, 0.1),
      _trainingGroundWeapon('smg', 160, 92, 1.2),
      _trainingGroundWeapon('rifle_asalto', 200, 105, 2.1),
      _trainingGroundWeapon('escopeta', 240, 118, 2.9),
      _trainingGroundWeapon('awp', 280, 130, 3.7),
    ];
    projectiles = const <ProjectileSnapshot>[];
    layerTransforms = const <TransformSnapshot>[];
    zoneTransforms = const <TransformSnapshot>[];
    ranking = <RankingEntry>[
      RankingEntry(
        id: _trainingPlayerId,
        name: playerName,
        alive: true,
        placement: 1,
        kills: 0,
        score: 0,
      ),
    ];
    _rebuildPlayers();
    notifyListeners();
  }

  void _applyTrainingDirection(String direction) {
    final _PlayerDynamicData? current = _playerDynamicById[_trainingPlayerId];
    if (current == null) {
      return;
    }
    final String facing = direction == 'none'
        ? current.facing
        : _directionVectorFor(direction).facing;
    _playerDynamicById = <String, _PlayerDynamicData>{
      ..._playerDynamicById,
      _trainingPlayerId: _copyDynamic(
        current,
        direction: direction,
        facing: facing,
        moving: direction != 'none',
      ),
    };
    _rebuildPlayers();
    notifyListeners();
  }

  void _applyTrainingAim(double worldX, double worldY) {
    final _PlayerDynamicData? current = _playerDynamicById[_trainingPlayerId];
    if (current == null) {
      return;
    }
    _playerDynamicById = <String, _PlayerDynamicData>{
      ..._playerDynamicById,
      _trainingPlayerId: _copyDynamic(current, aimX: worldX, aimY: worldY),
    };
    _rebuildPlayers();
    notifyListeners();
  }

  void _applyTrainingPickupNearest() {
    final _PlayerDynamicData? current = _playerDynamicById[_trainingPlayerId];
    final _PlayerStaticData? staticData = _playerStaticById[_trainingPlayerId];
    if (current == null || staticData == null) {
      return;
    }
    int nearestIndex = -1;
    double nearestDistSq = double.infinity;
    final double centerX = current.x + staticData.width * 0.5;
    final double centerY = current.y + staticData.height * 0.5;
    for (int i = 0; i < items.length; i++) {
      final GroundItem item = items[i];
      if (item.kind != 'weapon') {
        continue;
      }
      final double ix = item.x + item.width * 0.5;
      final double iy = item.y + item.height * 0.5;
      final double dx = ix - centerX;
      final double dy = iy - centerY;
      final double distSq = dx * dx + dy * dy;
      if (distSq > _trainingPickupRadius * _trainingPickupRadius) {
        continue;
      }
      if (distSq < nearestDistSq) {
        nearestDistSq = distSq;
        nearestIndex = i;
      }
    }
    if (nearestIndex < 0) {
      return;
    }

    final GroundItem item = items[nearestIndex];
    final InventoryWeaponSlot? slotData = _trainingWeaponSlotForType(
      item.weaponType,
      reserveAmmo: item.amount,
    );
    if (slotData == null) {
      return;
    }

    final List<InventoryWeaponSlot?> nextInventory =
        List<InventoryWeaponSlot?>.from(current.inventory);
    int targetSlot = nextInventory.indexWhere((InventoryWeaponSlot? value) => value == null);
    if (targetSlot < 0) {
      targetSlot = current.equippedSlot;
    }
    nextInventory[targetSlot] = slotData;

    final List<GroundItem> nextItems = List<GroundItem>.from(items)
      ..removeAt(nearestIndex);
    items = nextItems;
    _playerDynamicById = <String, _PlayerDynamicData>{
      ..._playerDynamicById,
      _trainingPlayerId: _copyDynamic(
        current,
        inventory: nextInventory,
        equippedSlot: targetSlot,
        equippedWeapon: EquippedWeapon(
          type: slotData.weaponType,
          label: slotData.label,
          texturePath: slotData.texturePath,
          clipAmmo: slotData.clipAmmo,
          reserveAmmo: slotData.reserveAmmo,
        ),
      ),
    };
    _rebuildPlayers();
    notifyListeners();
  }

  void _applyTrainingDropWeapon({int? slot}) {
    final _PlayerDynamicData? current = _playerDynamicById[_trainingPlayerId];
    final _PlayerStaticData? staticData = _playerStaticById[_trainingPlayerId];
    if (current == null || staticData == null) {
      return;
    }
    final int targetSlot = (slot ?? current.equippedSlot).clamp(0, 4).toInt();
    final InventoryWeaponSlot? equipped = targetSlot < current.inventory.length
        ? current.inventory[targetSlot]
        : null;
    if (equipped == null) {
      return;
    }

    final List<InventoryWeaponSlot?> nextInventory =
        List<InventoryWeaponSlot?>.from(current.inventory);
    nextInventory[targetSlot] = null;

    final GroundItem dropped = _trainingGroundWeapon(
      equipped.weaponType,
      current.x + staticData.width * 0.5 + 12,
      current.y + staticData.height * 0.5 + 4,
      ((current.x * 0.013 + current.y * 0.017).abs() % 1),
      reserveAmmo: equipped.reserveAmmo,
      clipAmmo: equipped.clipAmmo,
    );

    final int nextEquippedSlot = nextInventory[targetSlot] == null
        ? _firstNonEmptySlot(nextInventory)
        : targetSlot;
    final InventoryWeaponSlot? nextEquipped = nextEquippedSlot >= 0
        ? nextInventory[nextEquippedSlot]
        : null;

    items = <GroundItem>[...items, dropped];
    _playerDynamicById = <String, _PlayerDynamicData>{
      ..._playerDynamicById,
      _trainingPlayerId: _copyDynamic(
        current,
        inventory: nextInventory,
        equippedSlot: nextEquippedSlot >= 0 ? nextEquippedSlot : 0,
        equippedWeapon: nextEquipped == null
            ? null
            : EquippedWeapon(
                type: nextEquipped.weaponType,
                label: nextEquipped.label,
                texturePath: nextEquipped.texturePath,
                clipAmmo: nextEquipped.clipAmmo,
                reserveAmmo: nextEquipped.reserveAmmo,
              ),
      ),
    };
    _rebuildPlayers();
    notifyListeners();
  }

  void _applyTrainingShootAt(double worldX, double worldY) {
    final _PlayerDynamicData? current = _playerDynamicById[_trainingPlayerId];
    final _PlayerStaticData? staticData = _playerStaticById[_trainingPlayerId];
    if (current == null || staticData == null) {
      return;
    }
    final int slot = current.equippedSlot.clamp(0, 4);
    final InventoryWeaponSlot? equipped =
        slot < current.inventory.length ? current.inventory[slot] : null;
    if (equipped == null || equipped.clipAmmo <= 0) {
      return;
    }
    if (_trainingReloadUntilSeconds != null) {
      return;
    }

    final _TrainingWeaponStats stats = _trainingWeaponStatsFor(equipped.weaponType);
    if (_trainingElapsedSeconds < _trainingNextShotSeconds) {
      return;
    }
    _trainingNextShotSeconds = _trainingElapsedSeconds + stats.fireInterval;

    final double fromX = current.x + staticData.width * 0.5;
    final double fromY = current.y + staticData.height * 0.5;
    final double dx = worldX - fromX;
    final double dy = worldY - fromY;
    final double len = math.sqrt(dx * dx + dy * dy);
    final double dirX = len <= 0.0001 ? 0 : dx / len;
    final double dirY = len <= 0.0001 ? -1 : dy / len;

    final int pellets = math.max(1, stats.pellets);
    for (int i = 0; i < pellets; i++) {
      final double spreadFactor = pellets <= 1 ? 0 : (i / (pellets - 1)) * 2 - 1;
      final double angleOffset = stats.spreadRadians * spreadFactor;
      final double baseAngle = math.atan2(dirY, dirX);
      final double shotAngle = baseAngle + angleOffset;
      final double shotDirX = math.cos(shotAngle);
      final double shotDirY = math.sin(shotAngle);
      _trainingProjectiles.add(
        _TrainingProjectileState(
          id: 'TP${_trainingProjectileSeq++}',
          x: fromX + shotDirX * 8,
          y: fromY + shotDirY * 8,
          vx: shotDirX * stats.projectileSpeed,
          vy: shotDirY * stats.projectileSpeed,
          remainingDistance: stats.range,
        ),
      );
    }

    final int updatedClip = (equipped.clipAmmo - 1).clamp(0, 9999);
    final InventoryWeaponSlot updatedSlot = InventoryWeaponSlot(
      kind: equipped.kind,
      weaponType: equipped.weaponType,
      label: equipped.label,
      texturePath: equipped.texturePath,
      clipAmmo: updatedClip,
      reserveAmmo: equipped.reserveAmmo,
      maxClipAmmo: equipped.maxClipAmmo,
    );
    final List<InventoryWeaponSlot?> nextInventory =
        List<InventoryWeaponSlot?>.from(current.inventory);
    nextInventory[slot] = updatedSlot;

    _playerDynamicById = <String, _PlayerDynamicData>{
      ..._playerDynamicById,
      _trainingPlayerId: _copyDynamic(
        current,
        inventory: nextInventory,
        equippedWeapon: EquippedWeapon(
          type: updatedSlot.weaponType,
          label: updatedSlot.label,
          texturePath: updatedSlot.texturePath,
          clipAmmo: updatedSlot.clipAmmo,
          reserveAmmo: updatedSlot.reserveAmmo,
        ),
      ),
    };
    _rebuildPlayers();
    notifyListeners();
  }

  void _applyTrainingReload() {
    final _PlayerDynamicData? current = _playerDynamicById[_trainingPlayerId];
    if (current == null) {
      return;
    }
    if (_trainingReloadUntilSeconds != null) {
      return;
    }
    final int slot = current.equippedSlot.clamp(0, 4);
    final InventoryWeaponSlot? equipped =
        slot < current.inventory.length ? current.inventory[slot] : null;
    if (equipped == null) {
      return;
    }
    if (equipped.clipAmmo >= equipped.maxClipAmmo || equipped.reserveAmmo <= 0) {
      return;
    }

    final _TrainingWeaponStats stats = _trainingWeaponStatsFor(equipped.weaponType);
    _trainingReloadUntilSeconds = _trainingElapsedSeconds + stats.reloadSeconds;
    _playerDynamicById = <String, _PlayerDynamicData>{
      ..._playerDynamicById,
      _trainingPlayerId: _copyDynamic(current, reloading: true),
    };
    _rebuildPlayers();
    notifyListeners();
  }

  void _completeTrainingReloadIfNeeded(_PlayerDynamicData current) {
    final double? reloadUntil = _trainingReloadUntilSeconds;
    if (reloadUntil == null || _trainingElapsedSeconds < reloadUntil) {
      return;
    }
    _trainingReloadUntilSeconds = null;

    final int slot = current.equippedSlot.clamp(0, 4);
    if (slot < 0 || slot >= current.inventory.length) {
      _playerDynamicById = <String, _PlayerDynamicData>{
        ..._playerDynamicById,
        _trainingPlayerId: _copyDynamic(current, reloading: false),
      };
      return;
    }
    final InventoryWeaponSlot? equipped = current.inventory[slot];
    if (equipped == null) {
      _playerDynamicById = <String, _PlayerDynamicData>{
        ..._playerDynamicById,
        _trainingPlayerId: _copyDynamic(current, reloading: false),
      };
      return;
    }

    final int needed = (equipped.maxClipAmmo - equipped.clipAmmo).clamp(0, equipped.maxClipAmmo);
    if (needed <= 0 || equipped.reserveAmmo <= 0) {
      _playerDynamicById = <String, _PlayerDynamicData>{
        ..._playerDynamicById,
        _trainingPlayerId: _copyDynamic(current, reloading: false),
      };
      return;
    }
    final int transfer = math.min(needed, equipped.reserveAmmo);

    final InventoryWeaponSlot updatedSlot = InventoryWeaponSlot(
      kind: equipped.kind,
      weaponType: equipped.weaponType,
      label: equipped.label,
      texturePath: equipped.texturePath,
      clipAmmo: equipped.clipAmmo + transfer,
      reserveAmmo: equipped.reserveAmmo - transfer,
      maxClipAmmo: equipped.maxClipAmmo,
    );
    final List<InventoryWeaponSlot?> nextInventory =
        List<InventoryWeaponSlot?>.from(current.inventory);
    nextInventory[slot] = updatedSlot;

    _playerDynamicById = <String, _PlayerDynamicData>{
      ..._playerDynamicById,
      _trainingPlayerId: _copyDynamic(
        current,
        inventory: nextInventory,
        equippedWeapon: EquippedWeapon(
          type: updatedSlot.weaponType,
          label: updatedSlot.label,
          texturePath: updatedSlot.texturePath,
          clipAmmo: updatedSlot.clipAmmo,
          reserveAmmo: updatedSlot.reserveAmmo,
        ),
        reloading: false,
      ),
    };
  }

  void _updateTrainingProjectiles(
    double delta, {
    required double worldWidth,
    required double worldHeight,
  }) {
    if (_trainingProjectiles.isEmpty) {
      projectiles = const <ProjectileSnapshot>[];
      return;
    }
    final List<_TrainingProjectileState> alive = <_TrainingProjectileState>[];
    for (final _TrainingProjectileState projectile in _trainingProjectiles) {
      final double stepX = projectile.vx * delta;
      final double stepY = projectile.vy * delta;
      final double traveled = math.sqrt(stepX * stepX + stepY * stepY);
      final double nx = projectile.x + stepX;
      final double ny = projectile.y + stepY;
      final double remaining = projectile.remainingDistance - traveled;
      if (remaining <= 0 || nx < 0 || ny < 0 || nx > worldWidth || ny > worldHeight) {
        continue;
      }
      alive.add(
        _TrainingProjectileState(
          id: projectile.id,
          x: nx,
          y: ny,
          vx: projectile.vx,
          vy: projectile.vy,
          remainingDistance: remaining,
        ),
      );
    }
    _trainingProjectiles
      ..clear()
      ..addAll(alive);
    projectiles = _trainingProjectiles
        .map(
          (_TrainingProjectileState state) => ProjectileSnapshot(
            id: state.id,
            ownerId: _trainingPlayerId,
            x: state.x,
            y: state.y,
            radius: 3,
          ),
        )
        .toList(growable: false);
  }

  GroundItem _trainingGroundWeapon(
    String weaponType,
    double x,
    double y,
    double floatPhase, {
    int? reserveAmmo,
    int? clipAmmo,
  }) {
    final InventoryWeaponSlot? slot = _trainingWeaponSlotForType(
      weaponType,
      reserveAmmo: reserveAmmo,
      clipAmmo: clipAmmo,
    );
    if (slot == null) {
      return GroundItem(
        id: 'TI${_trainingItemSeq++}',
        kind: 'weapon',
        weaponType: weaponType,
        texturePath: 'media/glock_2.png',
        x: x,
        y: y,
        width: 26,
        height: 14,
        amount: reserveAmmo ?? 0,
        floatPhase: floatPhase,
      );
    }
    return GroundItem(
      id: 'TI${_trainingItemSeq++}',
      kind: 'weapon',
      weaponType: slot.weaponType,
      texturePath: slot.texturePath,
      x: x,
      y: y,
      width: 26,
      height: 14,
      amount: slot.reserveAmmo,
      floatPhase: floatPhase,
    );
  }

  InventoryWeaponSlot? _trainingWeaponSlotForType(
    String weaponType, {
    int? reserveAmmo,
    int? clipAmmo,
  }) {
    switch (weaponType) {
      case 'glock':
        return InventoryWeaponSlot(
          kind: 'weapon',
          weaponType: 'glock',
          label: 'Glock',
          texturePath: 'media/glock_2.png',
          clipAmmo: clipAmmo ?? 12,
          reserveAmmo: reserveAmmo ?? 72,
          maxClipAmmo: 12,
        );
      case 'smg':
        return InventoryWeaponSlot(
          kind: 'weapon',
          weaponType: 'smg',
          label: 'SMG',
          texturePath: 'media/smg_2.png',
          clipAmmo: clipAmmo ?? 30,
          reserveAmmo: reserveAmmo ?? 120,
          maxClipAmmo: 30,
        );
      case 'rifle_asalto':
        return InventoryWeaponSlot(
          kind: 'weapon',
          weaponType: 'rifle_asalto',
          label: 'Rifle',
          texturePath: 'media/rifle_asalto_2.png',
          clipAmmo: clipAmmo ?? 25,
          reserveAmmo: reserveAmmo ?? 100,
          maxClipAmmo: 25,
        );
      case 'escopeta':
        return InventoryWeaponSlot(
          kind: 'weapon',
          weaponType: 'escopeta',
          label: 'Escopeta',
          texturePath: 'media/escopeta_2.png',
          clipAmmo: clipAmmo ?? 6,
          reserveAmmo: reserveAmmo ?? 36,
          maxClipAmmo: 6,
        );
      case 'awp':
        return InventoryWeaponSlot(
          kind: 'weapon',
          weaponType: 'awp',
          label: 'AWP',
          texturePath: 'media/awp_2.png',
          clipAmmo: clipAmmo ?? 5,
          reserveAmmo: reserveAmmo ?? 25,
          maxClipAmmo: 5,
        );
      default:
        return null;
    }
  }

  _TrainingWeaponStats _trainingWeaponStatsFor(String weaponType) {
    switch (weaponType) {
      case 'smg':
        return const _TrainingWeaponStats(
          projectileSpeed: 430,
          range: 540,
          fireInterval: 0.085,
          reloadSeconds: 1.6,
        );
      case 'rifle_asalto':
        return const _TrainingWeaponStats(
          projectileSpeed: 520,
          range: 740,
          fireInterval: 0.13,
          reloadSeconds: 1.9,
        );
      case 'escopeta':
        return const _TrainingWeaponStats(
          projectileSpeed: 360,
          range: 300,
          fireInterval: 0.78,
          pellets: 6,
          spreadRadians: 0.18,
          reloadSeconds: 2.2,
        );
      case 'awp':
        return const _TrainingWeaponStats(
          projectileSpeed: 760,
          range: 1040,
          fireInterval: 1.05,
          reloadSeconds: 2.8,
        );
      case 'glock':
      default:
        return const _TrainingWeaponStats(
          projectileSpeed: 380,
          range: 580,
          fireInterval: 0.24,
          reloadSeconds: 1.2,
        );
    }
  }

  bool _intersectsAnyBlockingRect(
    double x,
    double y,
    double width,
    double height,
    List<TrainingWorldRect> blockingRects,
  ) {
    for (final TrainingWorldRect rect in blockingRects) {
      if (_rectsOverlap(x, y, width, height, rect.x, rect.y, rect.width, rect.height)) {
        return true;
      }
    }
    return false;
  }

  double _speedMultiplierForPosition(
    double x,
    double y,
    double width,
    double height,
    List<TrainingSlowZone> slowZones,
  ) {
    if (slowZones.isEmpty) {
      return 1;
    }
    final double centerX = x + width * 0.5;
    final double centerY = y + height * 0.5;
    double multiplier = 1;
    for (final TrainingSlowZone zone in slowZones) {
      if (_pointInRect(centerX, centerY, zone.x, zone.y, zone.width, zone.height)) {
        multiplier = math.min(multiplier, zone.speedMultiplier.clamp(0.2, 1.0));
      }
    }
    return multiplier;
  }

  bool _pointInRect(
    double px,
    double py,
    double x,
    double y,
    double width,
    double height,
  ) {
    return px >= x && py >= y && px <= x + width && py <= y + height;
  }

  bool _rectsOverlap(
    double ax,
    double ay,
    double aw,
    double ah,
    double bx,
    double by,
    double bw,
    double bh,
  ) {
    return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
  }

  int _firstNonEmptySlot(List<InventoryWeaponSlot?> inventory) {
    for (int i = 0; i < inventory.length; i++) {
      if (inventory[i] != null) {
        return i;
      }
    }
    return -1;
  }

  void _applyTrainingSelectSlot(int slot) {
    final _PlayerDynamicData? current = _playerDynamicById[_trainingPlayerId];
    if (current == null) {
      return;
    }
    final int safeSlot = slot.clamp(0, 4).toInt();
    final InventoryWeaponSlot? selected = safeSlot < current.inventory.length
        ? current.inventory[safeSlot]
        : null;
    final EquippedWeapon? equipped = selected == null
        ? null
        : EquippedWeapon(
            type: selected.weaponType,
            label: selected.label,
            texturePath: selected.texturePath,
            clipAmmo: selected.clipAmmo,
            reserveAmmo: selected.reserveAmmo,
          );
    _playerDynamicById = <String, _PlayerDynamicData>{
      ..._playerDynamicById,
      _trainingPlayerId: _copyDynamic(
        current,
        equippedSlot: safeSlot,
        equippedWeapon: equipped,
      ),
    };
    _rebuildPlayers();
    notifyListeners();
  }

  _DirectionVector _directionVectorFor(String direction) {
    switch (direction) {
      case 'up':
        return const _DirectionVector(0, -1, 'up');
      case 'upLeft':
        return const _DirectionVector(-0.70710678, -0.70710678, 'upLeft');
      case 'left':
        return const _DirectionVector(-1, 0, 'left');
      case 'downLeft':
        return const _DirectionVector(-0.70710678, 0.70710678, 'downLeft');
      case 'down':
        return const _DirectionVector(0, 1, 'down');
      case 'downRight':
        return const _DirectionVector(0.70710678, 0.70710678, 'downRight');
      case 'right':
        return const _DirectionVector(1, 0, 'right');
      case 'upRight':
        return const _DirectionVector(0.70710678, -0.70710678, 'upRight');
      case 'none':
      default:
        return const _DirectionVector(0, 0, 'down');
    }
  }

  _PlayerDynamicData _copyDynamic(
    _PlayerDynamicData source, {
    double? x,
    double? y,
    String? direction,
    String? facing,
    bool? moving,
    bool? reloading,
    double? aimX,
    double? aimY,
    int? equippedSlot,
    List<InventoryWeaponSlot?>? inventory,
    EquippedWeapon? equippedWeapon,
  }) {
    return _PlayerDynamicData(
      id: source.id,
      x: x ?? source.x,
      y: y ?? source.y,
      score: source.score,
      gemsCollected: source.gemsCollected,
      kills: source.kills,
      deaths: source.deaths,
      placement: source.placement,
      alive: source.alive,
      health: source.health,
      shield: source.shield,
      maxHealth: source.maxHealth,
      maxShield: source.maxShield,
      recentlyHit: source.recentlyHit,
      aimX: aimX ?? source.aimX,
      aimY: aimY ?? source.aimY,
      equippedSlot: equippedSlot ?? source.equippedSlot,
      inventory: inventory ?? source.inventory,
      equippedWeapon: equippedWeapon ?? source.equippedWeapon,
      direction: direction ?? source.direction,
      facing: facing ?? source.facing,
      moving: moving ?? source.moving,
      reloading: reloading ?? source.reloading,
    );
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
    if (kDebugMode) {
      print('WebSocket tancat. Intentant reconnectar...');
    }
    isConnected = false;
    isConnecting = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (networkConfig.trainingMode) {
      return;
    }
    if (_intentionalDisconnect || _disposed) {
      return;
    }
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        print(
          "No es pot reconnectar al servidor després de $_maxReconnectAttempts intents.",
        );
      }
      return;
    }

    _reconnectAttempts++;
    if (kDebugMode) {
      print(
        "Intent de reconnexió #$_reconnectAttempts en ${_reconnectDelay.inSeconds} segons...",
      );
    }
    Future<void>.delayed(_reconnectDelay, () {
      if (_intentionalDisconnect || _disposed) {
        return;
      }
      _connectToWebSocket();
    });
  }

  void _sendMessage(Map<String, dynamic> payload) {
    if (networkConfig.trainingMode) {
      return;
    }
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

  Map<String, dynamic> _mapFromDynamic(Map<dynamic, dynamic> raw) {
    return raw.map(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );
  }
}
