'use strict';

const { loadMultiplayerLevel } = require('./multiplayerLevelData.js');

// Lobby countdown length before the server switches the match from waiting to playing.
const WAITING_DURATION_MS = 60 * 1000;
// Safety fallback for dt calculation if the measured loop FPS is temporarily unavailable or zero.
const TARGET_FPS_FALLBACK = 60;
const PLAYER_WIDTH = 20;
const PLAYER_HEIGHT = 20;
const PLAYER_START_X = 32;
const PLAYER_START_Y = 32;
const PLAYER_START_STEP_X = 32;
const PLAYER_START_STEP_Y = 32;
const GEM_WIDTH = 15;
const GEM_HEIGHT = 15;
const MAX_INVENTORY_SLOTS = 5;
const PLAYER_MAX_HEALTH = 100;
const PLAYER_MAX_SHIELD = 100;
const DEFAULT_START_SHIELD = 30;
const PICKUP_RADIUS = 34;
const PROJECTILE_RADIUS = 3;
const PLAYER_FIRE_POINT_OFFSET = 8;
const PLAYER_MAX_COUNT = 64;

const MOVE_SPEED_PER_SECOND = 95;
const DIAGONAL_NORMALIZE = 0.70710677;
const NORMAL_ACCELERATION_PER_SECOND = 900;
const NORMAL_DECELERATION_PER_SECOND = 1200;
const ICE_ACCELERATION_PER_SECOND = 230;
const ICE_DECELERATION_PER_SECOND = 75;
const SAND_SPEED_MULTIPLIER = 0.48;
const MOVEMENT_DIRECTION_THRESHOLD = 2;
const VELOCITY_STOP_THRESHOLD = 0.5;
const MAX_COLLISION_SLIDE_ITERATIONS = 4;
const COLLISION_SWEEP_ITERATIONS = 12;
const COLLISION_TIME_BACKOFF = 0.001;
const COLLISION_PROBE_SPACING = 1.0;
const MOVEMENT_EPSILON = 0.0001;

const GEM_COUNTS = {
    blue: 500,
    green: 250,
    yellow: 100,
    purple: 50
};
const GEM_VALUES = {
    blue: 1,
    green: 2,
    yellow: 3,
    purple: 5
};

const ITEM_COUNTS = {
    health: 28,
    shield: 22
};

const WEAPON_CATALOG = {
    glock: {
        id: 'glock',
        label: 'Glock',
        damage: 16,
        fireRate: 3.6,
        projectileSpeed: 360,
        range: 560,
        spread: 0.04,
        pelletCount: 1,
        clipSize: 12,
        reserveAmmo: 72,
        texturePath: 'media/glock_2.png'
    },
    smg: {
        id: 'smg',
        label: 'SMG',
        damage: 10,
        fireRate: 9,
        projectileSpeed: 420,
        range: 520,
        spread: 0.07,
        pelletCount: 1,
        clipSize: 30,
        reserveAmmo: 120,
        texturePath: 'media/smg_2.png'
    },
    rifle_asalto: {
        id: 'rifle_asalto',
        label: 'Rifle',
        damage: 18,
        fireRate: 6,
        projectileSpeed: 480,
        range: 680,
        spread: 0.04,
        pelletCount: 1,
        clipSize: 25,
        reserveAmmo: 100,
        texturePath: 'media/rifle_asalto_2.png'
    },
    ak47: {
        id: 'ak47',
        label: 'AK47',
        damage: 24,
        fireRate: 4.2,
        projectileSpeed: 500,
        range: 760,
        spread: 0.03,
        pelletCount: 1,
        clipSize: 20,
        reserveAmmo: 80,
        texturePath: 'media/ak47_2.png'
    },
    escopeta: {
        id: 'escopeta',
        label: 'Escopeta',
        damage: 9,
        fireRate: 1.2,
        projectileSpeed: 340,
        range: 280,
        spread: 0.22,
        pelletCount: 6,
        clipSize: 6,
        reserveAmmo: 36,
        texturePath: 'media/escopeta_2.png'
    },
    awp: {
        id: 'awp',
        label: 'AWP',
        damage: 80,
        fireRate: 0.9,
        projectileSpeed: 720,
        range: 980,
        spread: 0.015,
        pelletCount: 1,
        clipSize: 5,
        reserveAmmo: 25,
        texturePath: 'media/awp_2.png'
    }
};

const WEAPON_SPAWN_TABLE = [
    'glock',
    'glock',
    'smg',
    'smg',
    'rifle_asalto',
    'rifle_asalto',
    'ak47',
    'escopeta',
    'awp'
];

const DIRECTIONS = {
    up: { dx: 0, dy: -1, facing: 'up' },
    upLeft: { dx: -DIAGONAL_NORMALIZE, dy: -DIAGONAL_NORMALIZE, facing: 'upLeft' },
    left: { dx: -1, dy: 0, facing: 'left' },
    downLeft: { dx: -DIAGONAL_NORMALIZE, dy: DIAGONAL_NORMALIZE, facing: 'downLeft' },
    down: { dx: 0, dy: 1, facing: 'down' },
    downRight: { dx: DIAGONAL_NORMALIZE, dy: DIAGONAL_NORMALIZE, facing: 'downRight' },
    right: { dx: 1, dy: 0, facing: 'right' },
    upRight: { dx: DIAGONAL_NORMALIZE, dy: -DIAGONAL_NORMALIZE, facing: 'upRight' },
    none: { dx: 0, dy: 0, facing: 'down' }
};

const LEVEL = loadMultiplayerLevel();
const PLAYER_TEMPLATE = findPlayerTemplate(LEVEL.sprites);
const GEM_TEMPLATE_BY_TYPE = buildGemTemplateMap(LEVEL.sprites);

class GameLogic {
    constructor() {
        this.players = new Map();
        this.tickCounter = 0;
        this.nextJoinOrder = 0;
        this.nextGemId = 0;
        this.nextItemId = 0;
        this.nextProjectileId = 0;
        this.phase = 'waiting';
        this.lobbyEndsAt = null;
        this.winnerId = '';
        this.gems = [];
        this.items = [];
        this.projectiles = [];
        this.initialStateDirty = true;

        this.layerRuntimeStates = LEVEL.layers.map((layer) => ({
            x: layer.x,
            y: layer.y
        }));
        this.zoneRuntimeStates = LEVEL.zones.map((zone) => ({
            x: zone.x,
            y: zone.y
        }));
        this.zonePreviousRuntimeStates = LEVEL.zones.map((zone) => ({
            x: zone.x,
            y: zone.y
        }));
        this.pathMotionTimeSeconds = 0;

        this.pathRuntimeById = new Map();
        for (const path of LEVEL.paths) {
            const runtime = createPathRuntime(path);
            if (runtime) {
                this.pathRuntimeById.set(path.id, runtime);
            }
        }

        this.pathBindingRuntimes = LEVEL.pathBindings
            .filter((binding) => binding.enabled)
            .map((binding) => {
                const pathRuntime = this.pathRuntimeById.get(binding.pathId);
                if (!pathRuntime) {
                    return null;
                }
                const initial = this.getInitialTargetPosition(binding.targetType, binding.targetIndex);
                if (!initial) {
                    return null;
                }
                return {
                    binding,
                    pathRuntime,
                    initialX: initial.x,
                    initialY: initial.y
                };
            })
            .filter(Boolean);

        this.wallZoneIndices = classifyZoneIndices(['mur', 'wall'], LEVEL.zones);
        this.iceZoneIndices = classifyZoneIndices(['ice', 'gel', 'hielo'], LEVEL.zones);
        this.sandZoneIndices = classifyZoneIndices(['sand', 'sorra', 'arena'], LEVEL.zones);
    }

    addClient(id) {
        if (this.players.size >= PLAYER_MAX_COUNT) {
            return null;
        }
        const spawn = this.getSpawnPosition(this.players.size);
        const player = {
            id,
            name: `Player ${this.players.size + 1}`,
            x: spawn.x,
            y: spawn.y,
            width: PLAYER_WIDTH,
            height: PLAYER_HEIGHT,
            direction: 'none',
            facing: 'down',
            moving: false,
            joinOrder: this.nextJoinOrder++,
            score: 0,
            gemsCollected: 0,
            kills: 0,
            deaths: 0,
            placement: 0,
            alive: true,
            health: PLAYER_MAX_HEALTH,
            shield: DEFAULT_START_SHIELD,
            maxHealth: PLAYER_MAX_HEALTH,
            maxShield: PLAYER_MAX_SHIELD,
            recentHitAtTick: -999999,
            velocityX: 0,
            velocityY: 0,
            aimX: spawn.x,
            aimY: spawn.y,
            nextFireAtSeconds: 0,
            inventory: createEmptyInventory(),
            equippedSlot: 0,
            trainingMode: false,
            animationId: PLAYER_TEMPLATE ? PLAYER_TEMPLATE.animationId : '',
            frameIndex: PLAYER_TEMPLATE ? resolveClipStartFrame(PLAYER_TEMPLATE.animationId) : 0,
            flipX: false,
            flipY: false
        };
        player.inventory[0] = createWeaponStack('glock');
        this.players.set(id, player);
        this.initialStateDirty = true;

        if (this.players.size === 1) {
            this.startWaitingRoom();
        } else if (this.phase === 'playing') {
            this.resetPlayerForMatch(player, this.players.size - 1);
        }

        return player;
    }

    removeClient(id) {
        const removed = this.players.get(id);
        if (removed) {
            this.dropInventoryForPlayer(removed);
        }
        this.players.delete(id);
        this.initialStateDirty = true;
        if (this.players.size <= 0) {
            this.resetMatch();
            this.nextJoinOrder = 0;
        }
    }

    handleMessage(id, msg) {
        try {
            const obj = JSON.parse(msg);
            if (!obj || !obj.type) {
                return false;
            }

            const player = this.players.get(id);
            if (!player) {
                return false;
            }

            switch (obj.type) {
            case 'register':
                {
                    const nextName = sanitizePlayerName(obj.playerName, player.name);
                    const wantsTraining = obj.trainingMode === true;
                    if (nextName !== player.name) {
                        player.name = nextName;
                        this.initialStateDirty = true;
                    }
                    if (wantsTraining !== player.trainingMode) {
                        player.trainingMode = wantsTraining;
                        this.initialStateDirty = true;
                    }
                    if (player.trainingMode && this.phase === 'waiting') {
                        this.startMatch();
                        return true;
                    }
                }
                break;
            case 'direction':
                player.direction = normalizeDirection(obj.value);
                if (player.direction !== 'none') {
                    player.facing = DIRECTIONS[player.direction].facing;
                }
                break;
            case 'aim':
                if (Number.isFinite(Number(obj.x)) && Number.isFinite(Number(obj.y))) {
                    player.aimX = Number(obj.x);
                    player.aimY = Number(obj.y);
                }
                break;
            case 'shoot':
                if (this.phase === 'playing') {
                    const aimX = Number.isFinite(Number(obj.x)) ? Number(obj.x) : player.aimX;
                    const aimY = Number.isFinite(Number(obj.y)) ? Number(obj.y) : player.aimY;
                    const shot = this.tryShoot(player, aimX, aimY);
                    if (shot) {
                        return true;
                    }
                }
                break;
            case 'pickup':
                if (this.phase === 'playing' && player.alive) {
                    const picked = this.tryPickupNearestItem(player);
                    if (picked) {
                        return true;
                    }
                }
                break;
            case 'dropWeapon':
                if (this.phase === 'playing' && player.alive) {
                    const slotIndex = clamp(Math.floor(Number(obj.slot) || player.equippedSlot), 0, MAX_INVENTORY_SLOTS - 1);
                    const dropped = this.tryDropWeapon(player, slotIndex);
                    if (dropped) {
                        return true;
                    }
                }
                break;
            case 'selectSlot':
                {
                    const slotIndex = clamp(Math.floor(Number(obj.slot) || 0), 0, MAX_INVENTORY_SLOTS - 1);
                    if (slotIndex !== player.equippedSlot) {
                        player.equippedSlot = slotIndex;
                        return true;
                    }
                }
                break;
            case 'restartMatch':
                if (this.phase === 'finished') {
                    this.restartToWaitingRoom();
                    return true;
                }
                break;
            default:
                break;
            }
        } catch (_) {
        }
        return false;
    }

    updateGame(fps) {
        if (this.players.size <= 0) {
            return;
        }

        const safeFps = Math.max(1, fps || TARGET_FPS_FALLBACK);
        const dtSeconds = 1 / safeFps;
        this.tickCounter = (this.tickCounter + 1) % 1000000;

        this.advanceEnvironment(dtSeconds);

        if (this.phase === 'waiting') {
            if (this.lobbyEndsAt == null) {
                this.startWaitingRoom();
            }
            if (this.lobbyEndsAt != null && Date.now() >= this.lobbyEndsAt) {
                this.startMatch();
            }
            return;
        }

        if (this.phase !== 'playing') {
            return;
        }

        for (const player of this.players.values()) {
            if (!player.alive) {
                player.moving = false;
                player.direction = 'none';
                continue;
            }
            this.applyMovingWallCarry(player);
            this.resolveWallPenetration(player);

            const direction = DIRECTIONS[player.direction] || DIRECTIONS.none;
            const onIce = this.playerOverlapsAnyZone(player, this.iceZoneIndices);
            const onSand = this.playerOverlapsAnyZone(player, this.sandZoneIndices);
            const speedMultiplier = onSand ? SAND_SPEED_MULTIPLIER : 1;
            const targetVelocityX = direction.dx * MOVE_SPEED_PER_SECOND * speedMultiplier;
            const targetVelocityY = direction.dy * MOVE_SPEED_PER_SECOND * speedMultiplier;
            const hasInput = player.direction !== 'none';
            const acceleration = onIce
                ? ICE_ACCELERATION_PER_SECOND
                : NORMAL_ACCELERATION_PER_SECOND;
            const deceleration = onIce
                ? ICE_DECELERATION_PER_SECOND
                : NORMAL_DECELERATION_PER_SECOND;
            const maxVelocityDelta = (hasInput ? acceleration : deceleration) * dtSeconds;

            player.velocityX = approach(player.velocityX, targetVelocityX, maxVelocityDelta);
            player.velocityY = approach(player.velocityY, targetVelocityY, maxVelocityDelta);
            if (Math.abs(player.velocityX) < VELOCITY_STOP_THRESHOLD) {
                player.velocityX = 0;
            }
            if (Math.abs(player.velocityY) < VELOCITY_STOP_THRESHOLD) {
                player.velocityY = 0;
            }

            const movingLeft = player.velocityX < -MOVEMENT_DIRECTION_THRESHOLD;
            const movingRight = player.velocityX > MOVEMENT_DIRECTION_THRESHOLD;
            const movingUp = player.velocityY < -MOVEMENT_DIRECTION_THRESHOLD;
            const movingDown = player.velocityY > MOVEMENT_DIRECTION_THRESHOLD;
            player.facing = resolveFacing(player.facing, movingUp, movingDown, movingLeft, movingRight);
            player.flipX = shouldFlipX(player.facing);
            player.animationId = resolvePlayerAnimationId(player.facing, player.moving);
            player.frameIndex = resolveAnimationFrame(player.animationId, this.tickCounter / safeFps);

            const previousX = player.x;
            const previousY = player.y;
            const dx = player.velocityX * dtSeconds;
            const dy = player.velocityY * dtSeconds;
            this.movePlayerWithWallCollisions(player, previousX, previousY, dx, dy);
            this.collectTouchedGems(player);
            this.consumeTouchingSupportItems(player);

            const hasDirectionalVelocity =
                Math.abs(player.velocityX) > MOVEMENT_DIRECTION_THRESHOLD ||
                Math.abs(player.velocityY) > MOVEMENT_DIRECTION_THRESHOLD;
            player.moving = hasInput && hasDirectionalVelocity;
        }

        this.updateProjectiles(dtSeconds, this.tickCounter / safeFps);

        const alivePlayers = Array.from(this.players.values()).filter((player) => player.alive);
        if (alivePlayers.length <= 1 && this.players.size > 1) {
            this.finishMatch();
        }
    }

    consumeSnapshotState() {
        if (!this.initialStateDirty) {
            return null;
        }
        this.initialStateDirty = false;
        return this.getSnapshotState();
    }

    getSnapshotState() {
        const players = Array.from(this.players.values()).sort(comparePlayers);
        return {
            level: LEVEL.levelName,
            players: players.map((player) => ({
                id: player.id,
                name: player.name,
                width: player.width,
                height: player.height,
                joinOrder: player.joinOrder
            })),
            gems: this.gems.map((gem) => ({
                id: gem.id,
                type: gem.type,
                x: round2(gem.x),
                y: round2(gem.y),
                width: gem.width,
                height: gem.height,
                value: gem.value
            }))
        };
    }

    getGameplayState() {
        const players = Array.from(this.players.values()).sort(comparePlayers);
        return {
            ...this.getGameplayStateBase(players),
            players: players.map((player) => ({
                ...this.serializeGameplayPlayer(player),
            })),
            gems: this.getVisibleGems(),
            items: this.getVisibleItems(),
            projectiles: this.getVisibleProjectiles(),
            ranking: this.getRanking(players)
        };
    }

    getGameplayStateForPlayer(playerId, options = {}) {
        const includeOtherPlayers = options.includeOtherPlayers !== false;
        const includeGems = options.includeGems !== false;
        const players = Array.from(this.players.values()).sort(comparePlayers);
        const selfPlayer = this.players.get(playerId);
        const state = {
            ...this.getGameplayStateBase(players),
            selfPlayer: selfPlayer ? this.serializeGameplayPlayer(selfPlayer) : null,
        };

        if (includeOtherPlayers) {
            state.otherPlayers = players
                .filter((player) => player.id !== playerId)
                .map((player) => this.serializeGameplayPlayer(player));
        }
        if (includeGems) {
            state.gems = this.getVisibleGems();
        }
        state.items = this.getVisibleItems();
        state.projectiles = this.getVisibleProjectiles();
        state.ranking = this.getRanking(players);

        return state;
    }

    getFullState() {
        return {
            ...this.getSnapshotState(),
            ...this.getGameplayState()
        };
    }

    getGameplayStateBase(players) {
        const countdownSeconds = this.phase === 'waiting' && this.lobbyEndsAt != null
            ? Math.max(0, Math.ceil((this.lobbyEndsAt - Date.now()) / 1000))
            : 0;
        const winner = this.winnerId ? this.players.get(this.winnerId) : players[0];

        return {
            tickCounter: this.tickCounter,
            phase: this.phase,
            countdownSeconds,
            alivePlayers: players.reduce((count, player) => count + (player.alive ? 1 : 0), 0),
            remainingGems: this.gems.reduce((count, gem) => count + (gem.visible ? 1 : 0), 0),
            winnerId: winner ? winner.id : '',
            winnerName: winner ? winner.name : '',
            layerTransforms: this.layerRuntimeStates.map((layer, index) => ({
                index,
                x: round2(layer.x),
                y: round2(layer.y)
            })),
            zoneTransforms: this.zoneRuntimeStates.map((zone, index) => ({
                index,
                x: round2(zone.x),
                y: round2(zone.y)
            }))
        };
    }

    serializeGameplayPlayer(player) {
        return {
            id: player.id,
            x: round2(player.x),
            y: round2(player.y),
            score: player.score,
            gemsCollected: player.gemsCollected,
            kills: player.kills,
            deaths: player.deaths,
            placement: player.placement,
            alive: player.alive,
            health: round2(player.health),
            shield: round2(player.shield),
            maxHealth: player.maxHealth,
            maxShield: player.maxShield,
            recentlyHit: this.tickCounter - player.recentHitAtTick <= 8,
            aimX: round2(player.aimX),
            aimY: round2(player.aimY),
            equippedSlot: player.equippedSlot,
            inventory: serializeInventory(player.inventory),
            equippedWeapon: this.getEquippedWeaponState(player),
            direction: player.direction,
            facing: player.facing,
            moving: player.moving,
        };
    }

    getVisibleGems() {
        return this.gems
            .filter((gem) => gem.visible)
            .map((gem) => ({
                id: gem.id,
                type: gem.type,
                x: round2(gem.x),
                y: round2(gem.y),
                width: gem.width,
                height: gem.height,
                value: gem.value
            }));
    }

    getVisibleItems() {
        return this.items
            .filter((item) => item.visible)
            .map((item) => ({
                id: item.id,
                kind: item.kind,
                weaponType: item.weaponType || '',
                x: round2(item.x),
                y: round2(item.y),
                width: item.width,
                height: item.height,
                amount: item.amount || 0,
                texturePath: item.texturePath || '',
                floatPhase: round2(item.floatPhase || 0)
            }));
    }

    getVisibleProjectiles() {
        return this.projectiles
            .filter((projectile) => projectile.visible)
            .map((projectile) => ({
                id: projectile.id,
                ownerId: projectile.ownerId,
                x: round2(projectile.x),
                y: round2(projectile.y),
                radius: projectile.radius
            }));
    }

    getRanking(players) {
        return players.map((player, index) => ({
            id: player.id,
            name: player.name,
            alive: player.alive,
            placement: player.placement > 0 ? player.placement : (player.alive ? 1 : index + 1),
            kills: player.kills,
            score: player.score
        }));
    }

    startWaitingRoom() {
        this.phase = 'waiting';
        this.winnerId = '';
        this.lobbyEndsAt = Date.now() + WAITING_DURATION_MS;
        this.initialStateDirty = true;
        this.resetEnvironmentRuntime();
        this.spawnGems();
        this.spawnItems();
        this.projectiles = [];
        this.positionPlayersForStart();
    }

    startMatch() {
        this.phase = 'playing';
        this.winnerId = '';
        this.lobbyEndsAt = null;
        this.resetEnvironmentRuntime();
        this.positionPlayersForStart();
    }

    finishMatch() {
        this.phase = 'finished';
        const players = Array.from(this.players.values()).sort(comparePlayers);
        const alivePlayers = players.filter((player) => player.alive);
        if (alivePlayers.length === 1) {
            alivePlayers[0].placement = 1;
            this.winnerId = alivePlayers[0].id;
        } else {
            this.winnerId = players.length > 0 ? players[0].id : '';
        }
    }

    restartToWaitingRoom() {
        if (this.players.size <= 0) {
            this.resetMatch();
            return;
        }
        this.startWaitingRoom();
    }

    resetMatch() {
        this.phase = 'waiting';
        this.lobbyEndsAt = null;
        this.winnerId = '';
        this.gems = [];
        this.items = [];
        this.projectiles = [];
        this.nextGemId = 0;
        this.nextItemId = 0;
        this.nextProjectileId = 0;
        this.initialStateDirty = true;
        this.resetEnvironmentRuntime();
    }

    resetEnvironmentRuntime() {
        this.pathMotionTimeSeconds = 0;
        this.layerRuntimeStates = LEVEL.layers.map((layer) => ({
            x: layer.x,
            y: layer.y
        }));
        this.zoneRuntimeStates = LEVEL.zones.map((zone) => ({
            x: zone.x,
            y: zone.y
        }));
        this.zonePreviousRuntimeStates = LEVEL.zones.map((zone) => ({
            x: zone.x,
            y: zone.y
        }));
    }

    advanceEnvironment(dtSeconds) {
        for (let i = 0; i < this.zoneRuntimeStates.length; i++) {
            this.zonePreviousRuntimeStates[i].x = this.zoneRuntimeStates[i].x;
            this.zonePreviousRuntimeStates[i].y = this.zoneRuntimeStates[i].y;
        }

        this.pathMotionTimeSeconds += dtSeconds;
        for (const runtime of this.pathBindingRuntimes) {
            const progress = pathProgressAtTime(
                runtime.binding.behavior,
                runtime.binding.durationSeconds,
                this.pathMotionTimeSeconds
            );
            const sample = samplePathAtProgress(runtime.pathRuntime, progress);
            const targetX = runtime.binding.relativeToInitialPosition
                ? runtime.initialX + (sample.x - runtime.pathRuntime.firstPointX)
                : sample.x;
            const targetY = runtime.binding.relativeToInitialPosition
                ? runtime.initialY + (sample.y - runtime.pathRuntime.firstPointY)
                : sample.y;
            this.applyPathTarget(runtime.binding.targetType, runtime.binding.targetIndex, targetX, targetY);
        }
    }

    applyPathTarget(targetType, targetIndex, x, y) {
        if (targetType === 'layer' && this.layerRuntimeStates[targetIndex]) {
            this.layerRuntimeStates[targetIndex].x = x;
            this.layerRuntimeStates[targetIndex].y = y;
            return;
        }
        if (targetType === 'zone' && this.zoneRuntimeStates[targetIndex]) {
            this.zoneRuntimeStates[targetIndex].x = x;
            this.zoneRuntimeStates[targetIndex].y = y;
        }
    }

    getInitialTargetPosition(targetType, targetIndex) {
        if (targetType === 'layer' && LEVEL.layers[targetIndex]) {
            return { x: LEVEL.layers[targetIndex].x, y: LEVEL.layers[targetIndex].y };
        }
        if (targetType === 'zone' && LEVEL.zones[targetIndex]) {
            return { x: LEVEL.zones[targetIndex].x, y: LEVEL.zones[targetIndex].y };
        }
        return null;
    }

    positionPlayersForStart() {
        const players = Array.from(this.players.values()).sort((a, b) => a.joinOrder - b.joinOrder);
        players.forEach((player, index) => {
            this.resetPlayerForMatch(player, index);
        });
    }

    resetPlayerForMatch(player, index) {
        const spawn = this.getSpawnPosition(index);
        player.x = spawn.x;
        player.y = spawn.y;
        player.direction = 'none';
        player.facing = 'down';
        player.moving = false;
        player.velocityX = 0;
        player.velocityY = 0;
        player.score = 0;
        player.gemsCollected = 0;
        player.kills = 0;
        player.placement = 0;
        player.alive = true;
        player.health = PLAYER_MAX_HEALTH;
        player.shield = DEFAULT_START_SHIELD;
        player.maxHealth = PLAYER_MAX_HEALTH;
        player.maxShield = PLAYER_MAX_SHIELD;
        player.recentHitAtTick = -999999;
        player.nextFireAtSeconds = 0;
        player.aimX = player.x + player.width * 0.5;
        player.aimY = player.y + player.height * 0.5;
        player.inventory = createEmptyInventory();
        player.inventory[0] = createWeaponStack('glock');
        player.equippedSlot = 0;
        player.animationId = PLAYER_TEMPLATE ? PLAYER_TEMPLATE.animationId : '';
        player.frameIndex = PLAYER_TEMPLATE ? resolveClipStartFrame(PLAYER_TEMPLATE.animationId) : 0;
        player.flipX = false;
        player.flipY = false;
        this.resolveWallPenetration(player);
    }

    getSpawnPosition(index) {
        const maxRows = Math.max(
            1,
            Math.floor((LEVEL.worldHeight - PLAYER_START_Y - PLAYER_HEIGHT) / PLAYER_START_STEP_Y) + 1
        );
        const maxColumns = Math.max(
            1,
            Math.floor((LEVEL.worldWidth * 0.25 - PLAYER_START_X - PLAYER_WIDTH) / PLAYER_START_STEP_X) + 1
        );
        const row = index % maxRows;
        const column = Math.floor(index / maxRows) % maxColumns;
        return {
            x: PLAYER_START_X + column * PLAYER_START_STEP_X,
            y: PLAYER_START_Y + row * PLAYER_START_STEP_Y
        };
    }

    movePlayerWithWallCollisions(player, previousX, previousY, deltaX, deltaY) {
        let currentX = previousX;
        let currentY = previousY;
        let remainingX = deltaX;
        let remainingY = deltaY;

        for (let i = 0; i < MAX_COLLISION_SLIDE_ITERATIONS; i++) {
            if (Math.abs(remainingX) <= MOVEMENT_EPSILON &&
                Math.abs(remainingY) <= MOVEMENT_EPSILON) {
                break;
            }

            const targetX = currentX + remainingX;
            const targetY = currentY + remainingY;
            if (!this.wouldCollideBlocked(player, targetX, targetY)) {
                currentX = targetX;
                currentY = targetY;
                break;
            }

            const hitT = this.findCollisionTimeOnSegment(player, currentX, currentY, remainingX, remainingY);
            const safeT = clamp(hitT - COLLISION_TIME_BACKOFF, 0, 1);
            const probeT = clamp(hitT + COLLISION_TIME_BACKOFF, 0, 1);

            const segmentStartX = currentX;
            const segmentStartY = currentY;
            currentX = segmentStartX + remainingX * safeT;
            currentY = segmentStartY + remainingY * safeT;

            const probeX = segmentStartX + remainingX * probeT;
            const probeY = segmentStartY + remainingY * probeT;
            const normal = this.estimateCollisionNormalAt(player, probeX, probeY, remainingX, remainingY);

            const remainingScale = Math.max(0, 1 - safeT);
            let slideX = remainingX * remainingScale;
            let slideY = remainingY * remainingScale;
            const intoWall = slideX * normal.x + slideY * normal.y;
            if (intoWall < 0) {
                slideX -= intoWall * normal.x;
                slideY -= intoWall * normal.y;
            }

            remainingX = slideX;
            remainingY = slideY;
        }

        player.x = currentX;
        player.y = currentY;
        if (this.wouldCollideBlocked(player, player.x, player.y)) {
            player.x = previousX;
            player.y = previousY;
            this.resolveWallPenetration(player);
        }
    }

    resolveWallPenetration(player) {
        if (!this.wouldCollideBlocked(player, player.x, player.y)) {
            return;
        }

        for (const zoneIndex of this.wallZoneIndices) {
            if (!this.collidesWithZoneAt(player, zoneIndex, player.x, player.y)) {
                continue;
            }

            const zoneRect = this.zoneRectAtIndex(zoneIndex);
            const playerRect = rectAt(player.x, player.y, player.width, player.height);

            const penLeft = playerRect.right - zoneRect.left;
            const penRight = zoneRect.right - playerRect.left;
            const penTop = playerRect.bottom - zoneRect.top;
            const penBottom = zoneRect.bottom - playerRect.top;

            let minPen = penLeft;
            let pushX = -penLeft;
            let pushY = 0;

            if (penRight < minPen) {
                minPen = penRight;
                pushX = penRight;
                pushY = 0;
            }
            if (penTop < minPen) {
                minPen = penTop;
                pushX = 0;
                pushY = -penTop;
            }
            if (penBottom < minPen) {
                minPen = penBottom;
                pushX = 0;
                pushY = penBottom;
            }

            player.x += pushX;
            player.y += pushY;
            player.x = clamp(player.x, 0, Math.max(0, LEVEL.worldWidth - player.width));
            player.y = clamp(player.y, 0, Math.max(0, LEVEL.worldHeight - player.height));

            if (!this.wouldCollideBlocked(player, player.x, player.y)) {
                return;
            }
        }
    }

    applyMovingWallCarry(player) {
        let bestDeltaMagnitudeSq = 0;
        let carryX = 0;
        let carryY = 0;

        for (const zoneIndex of this.wallZoneIndices) {
            if (!this.collidesWithZoneAt(player, zoneIndex, player.x, player.y)) {
                continue;
            }

            const deltaX = this.zoneDeltaX(zoneIndex);
            const deltaY = this.zoneDeltaY(zoneIndex);
            if (Math.abs(deltaX) <= MOVEMENT_EPSILON &&
                Math.abs(deltaY) <= MOVEMENT_EPSILON) {
                continue;
            }

            const candidateX = clamp(
                player.x + deltaX,
                0,
                Math.max(0, LEVEL.worldWidth - player.width)
            );
            const candidateY = clamp(
                player.y + deltaY,
                0,
                Math.max(0, LEVEL.worldHeight - player.height)
            );

            const stillCollides = this.collidesWithZoneAt(player, zoneIndex, candidateX, candidateY);
            if (stillCollides) {
                continue;
            }

            const deltaMagnitudeSq = deltaX * deltaX + deltaY * deltaY;
            if (deltaMagnitudeSq > bestDeltaMagnitudeSq) {
                bestDeltaMagnitudeSq = deltaMagnitudeSq;
                carryX = candidateX - player.x;
                carryY = candidateY - player.y;
            }
        }

        if (bestDeltaMagnitudeSq > 0) {
            player.x += carryX;
            player.y += carryY;
        }
    }

    findCollisionTimeOnSegment(player, startX, startY, deltaX, deltaY) {
        if (this.wouldCollideBlocked(player, startX, startY)) {
            return 0;
        }
        const distance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
        if (distance <= MOVEMENT_EPSILON) {
            return 1;
        }

        const probeCount = Math.max(1, Math.ceil(distance / COLLISION_PROBE_SPACING));
        let low = 0;
        let high = 1;
        let hasCollision = false;
        for (let i = 1; i <= probeCount; i++) {
            const t = i / probeCount;
            const sampleX = startX + deltaX * t;
            const sampleY = startY + deltaY * t;
            if (this.wouldCollideBlocked(player, sampleX, sampleY)) {
                high = t;
                hasCollision = true;
                break;
            }
            low = t;
        }

        if (!hasCollision) {
            return 1;
        }

        for (let i = 0; i < COLLISION_SWEEP_ITERATIONS; i++) {
            const mid = (low + high) * 0.5;
            const midX = startX + deltaX * mid;
            const midY = startY + deltaY * mid;
            if (this.wouldCollideBlocked(player, midX, midY)) {
                high = mid;
            } else {
                low = mid;
            }
        }
        return high;
    }

    estimateCollisionNormalAt(player, x, y, movementX, movementY) {
        const playerRect = rectAt(x, y, player.width, player.height);
        let bestScore = Number.POSITIVE_INFINITY;
        let bestNormalX = 0;
        let bestNormalY = 0;

        for (const zoneIndex of this.wallZoneIndices) {
            if (!this.collidesWithZoneAt(player, zoneIndex, x, y)) {
                continue;
            }

            const zoneRect = this.zoneRectAtIndex(zoneIndex);
            const relativeX = movementX - this.zoneDeltaX(zoneIndex);
            const relativeY = movementY - this.zoneDeltaY(zoneIndex);
            const relativeSpeedSq = relativeX * relativeX + relativeY * relativeY;
            const hasRelativeMotion = relativeSpeedSq > MOVEMENT_EPSILON * MOVEMENT_EPSILON;

            const consider = (penetration, normalX, normalY) => {
                if (!Number.isFinite(penetration) || penetration <= MOVEMENT_EPSILON) {
                    return;
                }
                let score = penetration;
                if (hasRelativeMotion) {
                    const relativeDot = relativeX * normalX + relativeY * normalY;
                    if (relativeDot >= 0) {
                        score += 1000000;
                    }
                }
                if (score < bestScore) {
                    bestScore = score;
                    bestNormalX = normalX;
                    bestNormalY = normalY;
                }
            };

            consider(playerRect.right - zoneRect.left, -1, 0);
            consider(zoneRect.right - playerRect.left, 1, 0);
            consider(playerRect.bottom - zoneRect.top, 0, -1);
            consider(zoneRect.bottom - playerRect.top, 0, 1);
        }

        if (Number.isFinite(bestScore)) {
            return { x: bestNormalX, y: bestNormalY };
        }

        const moveLen = Math.sqrt(movementX * movementX + movementY * movementY);
        if (moveLen > MOVEMENT_EPSILON) {
            return { x: -movementX / moveLen, y: -movementY / moveLen };
        }
        return { x: 0, y: -1 };
    }

    collectTouchedGems(player) {
        for (const gem of this.gems) {
            if (!gem.visible) {
                continue;
            }
            if (rectsOverlap(
                this.playerCollisionRect(player),
                this.gemCollisionRect(gem)
            )) {
                player.score += gem.value;
                player.gemsCollected += 1;
                gem.visible = false;
            }
        }
    }

    spawnGems() {
        this.gems = [];
        this.nextGemId = 0;
        this.initialStateDirty = true;

        const shuffledCells = shuffle(LEVEL.gemCells.slice());
        const spawnQueue = [];
        Object.entries(GEM_COUNTS).forEach(([type, count]) => {
            for (let i = 0; i < count; i++) {
                spawnQueue.push(type);
            }
        });

        for (let i = 0; i < spawnQueue.length && i < shuffledCells.length; i++) {
            const type = spawnQueue[i];
            const cell = shuffledCells[i];
            this.gems.push({
                id: `G${String(this.nextGemId++).padStart(3, '0')}`,
                type,
                x: cell.x,
                y: cell.y,
                width: GEM_WIDTH,
                height: GEM_HEIGHT,
                value: GEM_VALUES[type] || 1,
                visible: true
            });
        }
    }

    playerOverlapsAnyZone(player, zoneIndices) {
        for (const zoneIndex of zoneIndices) {
            if (this.collidesWithZoneAt(player, zoneIndex, player.x, player.y)) {
                return true;
            }
        }
        return false;
    }

    collidesWithZoneAt(player, zoneIndex, x, y) {
        const zoneRect = this.zoneRectAtIndex(zoneIndex);
        for (const hitBoxRect of this.playerHitBoxRectsAt(player, x, y)) {
            if (rectsOverlap(hitBoxRect, zoneRect)) {
                return true;
            }
        }
        return false;
    }

    wouldCollideBlocked(player, x, y) {
        for (const zoneIndex of this.wallZoneIndices) {
            const zoneRect = this.zoneRectAtIndex(zoneIndex);
            for (const hitBoxRect of this.playerHitBoxRectsAt(player, x, y)) {
                if (rectsOverlap(hitBoxRect, zoneRect)) {
                    return true;
                }
            }
        }
        return false;
    }

    zoneRectAtIndex(zoneIndex) {
        const zone = LEVEL.zones[zoneIndex];
        const runtime = this.zoneRuntimeStates[zoneIndex] || zone;
        return rectAt(runtime.x, runtime.y, zone.width, zone.height);
    }

    zoneDeltaX(zoneIndex) {
        const current = this.zoneRuntimeStates[zoneIndex];
        const previous = this.zonePreviousRuntimeStates[zoneIndex];
        if (!current || !previous) {
            return 0;
        }
        return current.x - previous.x;
    }

    zoneDeltaY(zoneIndex) {
        const current = this.zoneRuntimeStates[zoneIndex];
        const previous = this.zonePreviousRuntimeStates[zoneIndex];
        if (!current || !previous) {
            return 0;
        }
        return current.y - previous.y;
    }

    playerCollisionRect(player) {
        const hitBoxes = this.playerHitBoxRectsAt(player, player.x, player.y);
        return unionRects(hitBoxes, rectAt(player.x, player.y, player.width, player.height));
    }

    playerHitBoxRectsAt(player, x, y) {
        const clip = LEVEL.animationClips.get(player.animationId);
        const hitBoxes = activeHitBoxesForClip(clip, player.frameIndex);
        if (!hitBoxes || hitBoxes.length <= 0) {
            return [rectAt(x, y, player.width, player.height)];
        }
        return hitBoxes.map((hitBox) =>
            hitBoxRectAt(x, y, player.width, player.height, hitBox, player.flipX, player.flipY)
        );
    }

    gemCollisionRect(gem) {
        const template = GEM_TEMPLATE_BY_TYPE.get(gem.type);
        const clip = template ? LEVEL.animationClips.get(template.animationId) : null;
        const frameIndex = resolveAnimationFrame(template ? template.animationId : '', this.tickCounter / TARGET_FPS_FALLBACK);
        const hitBoxes = activeHitBoxesForClip(clip, frameIndex);
        if (!hitBoxes || hitBoxes.length <= 0) {
            return rectAt(gem.x, gem.y, gem.width, gem.height);
        }
        const rects = hitBoxes.map((hitBox) =>
            hitBoxRectAt(gem.x, gem.y, gem.width, gem.height, hitBox, false, false)
        );
        return unionRects(rects, rectAt(gem.x, gem.y, gem.width, gem.height));
    }

    spawnItems() {
        this.items = [];
        this.nextItemId = 0;
        const cells = shuffle(LEVEL.gemCells.slice());
        if (cells.length <= 0) {
            return;
        }

        const weaponCount = Math.max(10, Math.floor(cells.length * 0.08));
        for (let i = 0; i < weaponCount && i < cells.length; i++) {
            const weaponType = WEAPON_SPAWN_TABLE[i % WEAPON_SPAWN_TABLE.length];
            const item = this.createWeaponItem(weaponType, cells[i].x, cells[i].y);
            if (item) {
                this.items.push(item);
            }
        }

        const supportCells = cells.slice(weaponCount);
        let cursor = 0;
        for (let i = 0; i < ITEM_COUNTS.health && cursor < supportCells.length; i++, cursor++) {
            this.items.push(this.createSupportItem('health', supportCells[cursor].x, supportCells[cursor].y, 40));
        }
        for (let i = 0; i < ITEM_COUNTS.shield && cursor < supportCells.length; i++, cursor++) {
            this.items.push(this.createSupportItem('shield', supportCells[cursor].x, supportCells[cursor].y, 35));
        }
    }

    createWeaponItem(weaponType, x, y, stack) {
        const config = WEAPON_CATALOG[weaponType];
        if (!config) {
            return null;
        }
        const ammoStack = stack || createWeaponStack(weaponType);
        return {
            id: `I${String(this.nextItemId++).padStart(4, '0')}`,
            kind: 'weapon',
            weaponType,
            x,
            y,
            width: 26,
            height: 14,
            amount: ammoStack.reserveAmmo,
            clipAmmo: ammoStack.clipAmmo,
            maxClipAmmo: ammoStack.maxClipAmmo,
            texturePath: config.texturePath,
            floatPhase: Math.random() * Math.PI * 2,
            visible: true
        };
    }

    createSupportItem(kind, x, y, amount) {
        return {
            id: `I${String(this.nextItemId++).padStart(4, '0')}`,
            kind,
            weaponType: '',
            x,
            y,
            width: 16,
            height: 16,
            amount,
            texturePath: kind === 'shield' ? 'media/gem.png' : 'media/DragonDeath.png',
            floatPhase: Math.random() * Math.PI * 2,
            visible: true
        };
    }

    consumeTouchingSupportItems(player) {
        const playerRect = this.playerCollisionRect(player);
        for (const item of this.items) {
            if (!item.visible || item.kind === 'weapon') {
                continue;
            }
            if (!rectsOverlap(playerRect, rectAt(item.x, item.y, item.width, item.height))) {
                continue;
            }
            if (item.kind === 'health') {
                if (player.health >= player.maxHealth) {
                    continue;
                }
                player.health = clamp(player.health + item.amount, 0, player.maxHealth);
            } else if (item.kind === 'shield') {
                if (player.shield >= player.maxShield) {
                    continue;
                }
                player.shield = clamp(player.shield + item.amount, 0, player.maxShield);
            }
            item.visible = false;
        }
    }

    tryPickupNearestItem(player) {
        let nearest = null;
        let nearestDistanceSq = Number.POSITIVE_INFINITY;
        const playerCenterX = player.x + player.width * 0.5;
        const playerCenterY = player.y + player.height * 0.5;

        for (const item of this.items) {
            if (!item.visible || item.kind !== 'weapon') {
                continue;
            }
            const centerX = item.x + item.width * 0.5;
            const centerY = item.y + item.height * 0.5;
            const dx = centerX - playerCenterX;
            const dy = centerY - playerCenterY;
            const distanceSq = dx * dx + dy * dy;
            if (distanceSq > PICKUP_RADIUS * PICKUP_RADIUS) {
                continue;
            }
            if (distanceSq < nearestDistanceSq) {
                nearest = item;
                nearestDistanceSq = distanceSq;
            }
        }

        if (!nearest) {
            return false;
        }

        const slot = findFirstFreeSlot(player.inventory);
        const slotIndex = slot >= 0 ? slot : player.equippedSlot;
        if (slotIndex < 0 || slotIndex >= player.inventory.length) {
            return false;
        }
        player.inventory[slotIndex] = {
            kind: 'weapon',
            weaponType: nearest.weaponType,
            clipAmmo: nearest.clipAmmo,
            reserveAmmo: nearest.amount,
            maxClipAmmo: nearest.maxClipAmmo
        };
        player.equippedSlot = slotIndex;
        nearest.visible = false;
        return true;
    }

    tryDropWeapon(player, slotIndex) {
        const stack = player.inventory[slotIndex];
        if (!stack || stack.kind !== 'weapon') {
            return false;
        }

        const dropX = clamp(player.x + player.width * 0.5 - 12, 0, Math.max(0, LEVEL.worldWidth - 24));
        const dropY = clamp(player.y + player.height * 0.5 - 8, 0, Math.max(0, LEVEL.worldHeight - 16));
        const item = this.createWeaponItem(stack.weaponType, dropX, dropY, stack);
        if (item) {
            this.items.push(item);
        }
        player.inventory[slotIndex] = null;
        if (player.equippedSlot === slotIndex) {
            player.equippedSlot = Math.max(0, findFirstFilledSlot(player.inventory));
        }
        return true;
    }

    getEquippedWeaponState(player) {
        const stack = player.inventory[player.equippedSlot];
        if (!stack || stack.kind !== 'weapon') {
            return null;
        }
        const config = WEAPON_CATALOG[stack.weaponType];
        if (!config) {
            return null;
        }
        return {
            type: config.id,
            label: config.label,
            clipAmmo: stack.clipAmmo,
            reserveAmmo: stack.reserveAmmo,
            texturePath: config.texturePath,
            fireRate: config.fireRate
        };
    }

    tryShoot(player, aimX, aimY) {
        if (!player.alive) {
            return false;
        }
        const stack = player.inventory[player.equippedSlot];
        if (!stack || stack.kind !== 'weapon') {
            return false;
        }
        const config = WEAPON_CATALOG[stack.weaponType];
        if (!config || stack.clipAmmo <= 0) {
            return false;
        }

        const nowSeconds = this.tickCounter / TARGET_FPS_FALLBACK;
        if (nowSeconds < player.nextFireAtSeconds) {
            return false;
        }
        player.nextFireAtSeconds = nowSeconds + (1 / Math.max(0.2, config.fireRate));

        const originX = player.x + player.width * 0.5;
        const originY = player.y + player.height * 0.5;
        const baseDx = aimX - originX;
        const baseDy = aimY - originY;
        const baseLength = Math.sqrt(baseDx * baseDx + baseDy * baseDy);
        let dirX = baseDx;
        let dirY = baseDy;
        if (baseLength <= 0.001) {
            const fallback = directionVectorForFacing(player.facing);
            dirX = fallback.x;
            dirY = fallback.y;
        }
        const normalized = normalizeVector(dirX, dirY);
        player.aimX = originX + normalized.x * 100;
        player.aimY = originY + normalized.y * 100;

        stack.clipAmmo = Math.max(0, stack.clipAmmo - 1);
        const pellets = Math.max(1, config.pelletCount || 1);
        for (let i = 0; i < pellets; i++) {
            const spread = config.spread || 0;
            const spreadAngle = randomInRange(-spread, spread);
            const spreadVector = rotateVector(normalized.x, normalized.y, spreadAngle);
            this.projectiles.push({
                id: `P${String(this.nextProjectileId++).padStart(5, '0')}`,
                ownerId: player.id,
                x: originX + spreadVector.x * PLAYER_FIRE_POINT_OFFSET,
                y: originY + spreadVector.y * PLAYER_FIRE_POINT_OFFSET,
                vx: spreadVector.x * config.projectileSpeed,
                vy: spreadVector.y * config.projectileSpeed,
                damage: config.damage,
                rangeLeft: config.range,
                radius: PROJECTILE_RADIUS,
                visible: true
            });
        }

        if (stack.clipAmmo <= 0 && stack.reserveAmmo > 0) {
            const refill = Math.min(stack.maxClipAmmo, stack.reserveAmmo);
            stack.clipAmmo += refill;
            stack.reserveAmmo -= refill;
        }

        return true;
    }

    updateProjectiles(dtSeconds) {
        if (this.projectiles.length <= 0) {
            return;
        }

        for (const projectile of this.projectiles) {
            if (!projectile.visible) {
                continue;
            }
            const dx = projectile.vx * dtSeconds;
            const dy = projectile.vy * dtSeconds;
            projectile.x += dx;
            projectile.y += dy;
            projectile.rangeLeft -= Math.sqrt(dx * dx + dy * dy);

            if (projectile.rangeLeft <= 0 ||
                projectile.x < 0 || projectile.y < 0 ||
                projectile.x > LEVEL.worldWidth || projectile.y > LEVEL.worldHeight ||
                this.pointBlockedByWalls(projectile.x, projectile.y)) {
                projectile.visible = false;
                continue;
            }

            const owner = this.players.get(projectile.ownerId);
            if (!owner || !owner.alive) {
                projectile.visible = false;
                continue;
            }

            for (const target of this.players.values()) {
                if (!target.alive || target.id === projectile.ownerId) {
                    continue;
                }
                const hitRect = this.playerCollisionRect(target);
                if (!pointInsideRect(projectile.x, projectile.y, hitRect)) {
                    continue;
                }
                this.applyDamage(owner, target, projectile.damage);
                projectile.visible = false;
                break;
            }
        }

        this.projectiles = this.projectiles.filter((projectile) => projectile.visible);
    }

    pointBlockedByWalls(x, y) {
        for (const zoneIndex of this.wallZoneIndices) {
            const zoneRect = this.zoneRectAtIndex(zoneIndex);
            if (x >= zoneRect.left && x <= zoneRect.right && y >= zoneRect.top && y <= zoneRect.bottom) {
                return true;
            }
        }
        return false;
    }

    applyDamage(attacker, target, amount) {
        let damage = Math.max(0, Number(amount) || 0);
        if (damage <= 0 || !target.alive) {
            return;
        }

        const shieldDamage = Math.min(target.shield, damage);
        target.shield -= shieldDamage;
        damage -= shieldDamage;

        if (damage > 0) {
            target.health = Math.max(0, target.health - damage);
        }
        target.recentHitAtTick = this.tickCounter;

        if (target.health <= 0 && target.alive) {
            target.alive = false;
            target.deaths += 1;
            target.direction = 'none';
            target.moving = false;
            target.velocityX = 0;
            target.velocityY = 0;
            target.placement = Math.max(2, Array.from(this.players.values()).filter((player) => player.alive).length + 1);
            attacker.kills += 1;
            attacker.score += 25;
            this.dropInventoryForPlayer(target);
        }
    }

    dropInventoryForPlayer(player) {
        for (let i = 0; i < player.inventory.length; i++) {
            const stack = player.inventory[i];
            if (!stack || stack.kind !== 'weapon') {
                continue;
            }
            const jitter = randomInRange(-8, 8);
            const dropX = clamp(player.x + player.width * 0.5 + jitter, 0, Math.max(0, LEVEL.worldWidth - 24));
            const dropY = clamp(player.y + player.height * 0.5 - jitter, 0, Math.max(0, LEVEL.worldHeight - 16));
            const item = this.createWeaponItem(stack.weaponType, dropX, dropY, stack);
            if (item) {
                this.items.push(item);
            }
            player.inventory[i] = null;
        }
    }
}

function createPathRuntime(path) {
    if (!path || !Array.isArray(path.points) || path.points.length < 2) {
        return null;
    }

    const segments = [];
    let totalLength = 0;
    for (let i = 1; i < path.points.length; i++) {
        const a = path.points[i - 1];
        const b = path.points[i];
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const length = Math.sqrt(dx * dx + dy * dy);
        if (length <= 0) {
            continue;
        }
        segments.push({
            ax: a.x,
            ay: a.y,
            bx: b.x,
            by: b.y,
            length,
            startLength: totalLength,
            endLength: totalLength + length
        });
        totalLength += length;
    }

    if (segments.length <= 0 || totalLength <= 0) {
        return null;
    }

    return {
        firstPointX: path.points[0].x,
        firstPointY: path.points[0].y,
        totalLength,
        segments
    };
}

function samplePathAtProgress(pathRuntime, progress) {
    if (!pathRuntime) {
        return { x: 0, y: 0 };
    }

    const clamped = clamp(progress, 0, 1);
    const targetLength = clamped * pathRuntime.totalLength;
    for (const segment of pathRuntime.segments) {
        if (targetLength <= segment.endLength) {
            const localLength = targetLength - segment.startLength;
            const alpha = segment.length <= 0 ? 0 : localLength / segment.length;
            return {
                x: lerp(segment.ax, segment.bx, alpha),
                y: lerp(segment.ay, segment.by, alpha)
            };
        }
    }

    const last = pathRuntime.segments[pathRuntime.segments.length - 1];
    return { x: last.bx, y: last.by };
}

function pathProgressAtTime(behavior, durationSeconds, timeSeconds) {
    if (!Number.isFinite(durationSeconds) || durationSeconds <= 0) {
        return 0;
    }

    const t = Math.max(0, timeSeconds);
    const normalizedBehavior = String(behavior || '').trim().toLowerCase();
    if (normalizedBehavior === 'ping_pong' || normalizedBehavior === 'pingpong') {
        const cycle = durationSeconds * 2;
        const cycleTime = t % cycle;
        if (cycleTime <= durationSeconds) {
            return cycleTime / durationSeconds;
        }
        return 1 - ((cycleTime - durationSeconds) / durationSeconds);
    }
    if (normalizedBehavior === 'once') {
        return clamp(t / durationSeconds, 0, 1);
    }
    return (t % durationSeconds) / durationSeconds;
}

function classifyZoneIndices(tokens, zones) {
    const indices = [];
    for (let i = 0; i < zones.length; i++) {
        const zone = zones[i];
        const type = normalize(zone.type);
        const name = normalize(zone.name);
        if (containsAny(type, tokens) || containsAny(name, tokens)) {
            indices.push(i);
        }
    }
    return indices;
}

function resolveFacing(previousFacing, up, down, left, right) {
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
    return previousFacing || 'down';
}

function comparePlayers(a, b) {
    if (a.alive !== b.alive) {
        return a.alive ? -1 : 1;
    }
    if (a.alive && b.alive && b.kills !== a.kills) {
        return b.kills - a.kills;
    }
    if (!a.alive && !b.alive && a.placement !== b.placement) {
        return a.placement - b.placement;
    }
    if (b.score !== a.score) {
        return b.score - a.score;
    }
    if (b.gemsCollected !== a.gemsCollected) {
        return b.gemsCollected - a.gemsCollected;
    }
    return a.joinOrder - b.joinOrder;
}

function sanitizePlayerName(value, fallback) {
    const name = String(value || '').replace(/\s+/g, ' ').trim();
    if (!name) {
        return fallback;
    }
    return name.substring(0, 18);
}

function findPlayerTemplate(sprites) {
    for (const sprite of sprites) {
        const type = normalize(sprite.type);
        const name = normalize(sprite.name);
        if (containsAny(type, ['player', 'hero', 'heroi', 'foxy']) ||
            containsAny(name, ['player', 'hero', 'heroi', 'foxy'])) {
            return sprite;
        }
    }
    return sprites[0] || null;
}

function buildGemTemplateMap(sprites) {
    const map = new Map();
    for (const sprite of sprites) {
        const type = normalize(sprite.type);
        if (type.includes('gem purple')) {
            map.set('purple', sprite);
        } else if (type.includes('gem yellow')) {
            map.set('yellow', sprite);
        } else if (type.includes('gem green')) {
            map.set('green', sprite);
        } else if (type.includes('gem blue')) {
            map.set('blue', sprite);
        }
    }
    return map;
}

function resolvePlayerAnimationId(facing, moving) {
    const animationName = resolvePlayerAnimationName(facing, moving);
    for (const clip of LEVEL.animationClips.values()) {
        if (normalize(clip.name) === normalize(animationName)) {
            return clip.id;
        }
    }
    return PLAYER_TEMPLATE ? PLAYER_TEMPLATE.animationId : '';
}

function resolvePlayerAnimationName(facing, moving) {
    switch (facing) {
    case 'left':
        return moving ? 'Character  Walk Right' : 'Character Idle Right';
    case 'upLeft':
        return moving ? 'Character  Walk Up-Right' : 'Character Idle Up-Right';
    case 'downLeft':
        return moving ? 'Character  Walk Down-Right' : 'Character Idle Down-Right';
    case 'right':
        return moving ? 'Character  Walk Right' : 'Character Idle Right';
    case 'upRight':
        return moving ? 'Character  Walk Up-Right' : 'Character Idle Up-Right';
    case 'up':
        return moving ? 'Character  Walk Up' : 'Character Idle Up';
    case 'downRight':
        return moving ? 'Character  Walk Down-Right' : 'Character Idle Down-Right';
    case 'down':
    default:
        return moving ? 'Character  Walk Down' : 'Character Idle Down';
    }
}

function shouldFlipX(facing) {
    return facing === 'left' || facing === 'upLeft' || facing === 'downLeft';
}

function resolveAnimationFrame(animationId, elapsedSeconds) {
    const clip = LEVEL.animationClips.get(animationId);
    if (!clip) {
        return 0;
    }
    const start = Math.max(0, clip.startFrame);
    const end = Math.max(start, clip.endFrame);
    const span = Math.max(1, end - start + 1);
    const ticks = Math.floor(Math.max(0, elapsedSeconds) * clip.fps);
    const offset = clip.loop ? positiveMod(ticks, span) : Math.min(ticks, span - 1);
    return start + offset;
}

function resolveClipStartFrame(animationId) {
    const clip = LEVEL.animationClips.get(animationId);
    return clip ? Math.max(0, clip.startFrame) : 0;
}

function activeHitBoxesForClip(clip, frameIndex) {
    if (!clip) {
        return null;
    }
    const frameRig = clip.frameRigs.get(frameIndex);
    if (frameRig && frameRig.hitBoxes.length > 0) {
        return frameRig.hitBoxes;
    }
    if (clip.hitBoxes.length > 0) {
        return clip.hitBoxes;
    }
    return null;
}

function hitBoxRectAt(x, y, width, height, hitBox, flipX, flipY) {
    let normalizedX = hitBox.x;
    let normalizedY = hitBox.y;
    if (flipX) {
        normalizedX = 1 - hitBox.x - hitBox.width;
    }
    if (flipY) {
        normalizedY = 1 - hitBox.y - hitBox.height;
    }
    return rectAt(
        x + normalizedX * width,
        y + normalizedY * height,
        hitBox.width * width,
        hitBox.height * height
    );
}

function unionRects(rects, fallback) {
    if (!rects || rects.length <= 0) {
        return fallback;
    }
    let minLeft = Number.POSITIVE_INFINITY;
    let minTop = Number.POSITIVE_INFINITY;
    let maxRight = Number.NEGATIVE_INFINITY;
    let maxBottom = Number.NEGATIVE_INFINITY;
    for (const rect of rects) {
        minLeft = Math.min(minLeft, rect.left);
        minTop = Math.min(minTop, rect.top);
        maxRight = Math.max(maxRight, rect.right);
        maxBottom = Math.max(maxBottom, rect.bottom);
    }
    if (!Number.isFinite(minLeft) || !Number.isFinite(minTop) ||
        !Number.isFinite(maxRight) || !Number.isFinite(maxBottom)) {
        return fallback;
    }
    return rectAt(minLeft, minTop, maxRight - minLeft, maxBottom - minTop);
}

function positiveMod(value, divisor) {
    const mod = value % divisor;
    return mod < 0 ? mod + divisor : mod;
}

function normalizeDirection(value) {
    const direction = String(value || '').trim();
    return Object.prototype.hasOwnProperty.call(DIRECTIONS, direction)
        ? direction
        : 'none';
}

function rectAt(x, y, width, height) {
    return {
        left: x,
        top: y,
        right: x + width,
        bottom: y + height,
        width,
        height
    };
}

function rectsOverlap(a, b) {
    return a.left < b.right &&
        a.right > b.left &&
        a.top < b.bottom &&
        a.bottom > b.top;
}

function approach(current, target, maxDelta) {
    if (current < target) {
        return Math.min(current + maxDelta, target);
    }
    if (current > target) {
        return Math.max(current - maxDelta, target);
    }
    return target;
}

function containsAny(value, needles) {
    for (const needle of needles) {
        if (needle && value.includes(needle)) {
            return true;
        }
    }
    return false;
}

function normalize(value) {
    return String(value || '').trim().toLowerCase();
}

function clamp(value, min, max) {
    return Math.max(min, Math.min(max, value));
}

function lerp(from, to, alpha) {
    return from + (to - from) * alpha;
}

function round2(value) {
    return Math.round(value * 100) / 100;
}

function shuffle(values) {
    for (let i = values.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        const temp = values[i];
        values[i] = values[j];
        values[j] = temp;
    }
    return values;
}

function createEmptyInventory() {
    return Array.from({ length: MAX_INVENTORY_SLOTS }, () => null);
}

function createWeaponStack(weaponType) {
    const config = WEAPON_CATALOG[weaponType] || WEAPON_CATALOG.glock;
    return {
        kind: 'weapon',
        weaponType: config.id,
        clipAmmo: config.clipSize,
        reserveAmmo: config.reserveAmmo,
        maxClipAmmo: config.clipSize
    };
}

function serializeInventory(inventory) {
    return inventory.map((entry) => {
        if (!entry) {
            return null;
        }
        if (entry.kind !== 'weapon') {
            return null;
        }
        const config = WEAPON_CATALOG[entry.weaponType];
        return {
            kind: 'weapon',
            weaponType: entry.weaponType,
            clipAmmo: entry.clipAmmo,
            reserveAmmo: entry.reserveAmmo,
            maxClipAmmo: entry.maxClipAmmo,
            label: config ? config.label : entry.weaponType,
            texturePath: config ? config.texturePath : ''
        };
    });
}

function findFirstFreeSlot(inventory) {
    for (let i = 0; i < inventory.length; i++) {
        if (!inventory[i]) {
            return i;
        }
    }
    return -1;
}

function findFirstFilledSlot(inventory) {
    for (let i = 0; i < inventory.length; i++) {
        if (inventory[i]) {
            return i;
        }
    }
    return 0;
}

function directionVectorForFacing(facing) {
    const normalized = DIRECTIONS[facing] || DIRECTIONS.down;
    return normalizeVector(normalized.dx, normalized.dy);
}

function normalizeVector(x, y) {
    const length = Math.sqrt(x * x + y * y);
    if (length <= 0.000001) {
        return { x: 0, y: 1 };
    }
    return { x: x / length, y: y / length };
}

function rotateVector(x, y, radians) {
    const cos = Math.cos(radians);
    const sin = Math.sin(radians);
    return {
        x: x * cos - y * sin,
        y: x * sin + y * cos
    };
}

function randomInRange(min, max) {
    return min + Math.random() * (max - min);
}

function pointInsideRect(x, y, rect) {
    return x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom;
}

module.exports = GameLogic;
