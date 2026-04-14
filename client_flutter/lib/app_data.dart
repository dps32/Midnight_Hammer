import 'dart:convert';

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
                (dynamic key, dynamic data) =>
                    MapEntry(key.toString(), data),
              ),
            );
          })
          .toList(growable: false)),
      equippedWeapon: json['equippedWeapon'] is Map
          ? EquippedWeapon.fromJson(
              (json['equippedWeapon'] as Map).map(
                (dynamic key, dynamic value) =>
                    MapEntry(key.toString(), value),
              ),
            )
          : null,
      direction: (json['direction'] as String? ?? 'none').trim(),
      facing: (json['facing'] as String? ?? 'down').trim(),
      moving: json['moving'] as bool? ?? false,
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
  });
}

class AppData extends ChangeNotifier {
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
    _connectToWebSocket();
  }

  void updateMovementDirection(String direction) {
    final String normalized = _normalizeDirection(direction);
    if (_lastDirection == normalized) {
      return;
    }
    _lastDirection = normalized;
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
        final Map<String, dynamic> gameState =
            rawGameState is Map ? _mapFromDynamic(rawGameState) : {};
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
        ..addAll(<String, _PlayerDynamicData>{
          for (final Map rawPlayer
              in (state['players'] as List<dynamic>? ?? const <dynamic>[])
                  .whereType<Map>())
            (_mapFromDynamic(rawPlayer)['id'] as String? ?? '').trim():
                _dynamicPlayerFromJson(_mapFromDynamic(rawPlayer)),
        }..remove(''));
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
    );
  }

  void _rebuildPlayers() {
    final Set<String> ids = <String>{
      ..._playerStaticById.keys,
      ..._playerDynamicById.keys,
    };
    players = ids.map((String id) {
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
        joinOrder: staticData?.joinOrder ?? 0,
      );
    }).toList(growable: false);
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
    _sendMessage(<String, dynamic>{'type': 'aim', 'x': worldX, 'y': worldY});
  }

  void shootAt(double worldX, double worldY) {
    _sendMessage(<String, dynamic>{'type': 'shoot', 'x': worldX, 'y': worldY});
  }

  void pickupNearestItem() {
    _sendMessage(<String, dynamic>{'type': 'pickup'});
  }

  void dropWeapon({int? slot}) {
    _sendMessage(<String, dynamic>{
      'type': 'dropWeapon',
      'slot': ?slot,
    });
  }

  void selectSlot(int slot) {
    _sendMessage(<String, dynamic>{'type': 'selectSlot', 'slot': slot});
  }

  void _registerPlayer() {
    _sendMessage(<String, dynamic>{
      'type': 'register',
      'playerName': playerName,
      'trainingMode': networkConfig.trainingMode,
    });
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
