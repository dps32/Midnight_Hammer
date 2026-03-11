
'use strict';

const { loadMultiplayerLevel } = require('./multiplayerLevelData.js');

const WAITING_DURATION_MS = 60 * 1000;
const FINISHED_DURATION_MS = 10 * 1000;

const STORM_WAIT_MS = 60 * 1000;
const STORM_SHRINK_1_MS = 90 * 1000;
const STORM_SHRINK_2_MS = 90 * 1000;
const STORM_RADIUS_STAGE_1_FACTOR = 0.65;
const STORM_RADIUS_STAGE_2_FACTOR = 0.35;
const STORM_DAMAGE_STAGE_1 = 20;
const STORM_DAMAGE_STAGE_2 = 50;

const PLAYER_WIDTH = 20;
const PLAYER_HEIGHT = 20;
const PLAYER_SPEED = 150;
const PLAYER_REGEN_DELAY_MS = 2000;
const PLAYER_REGEN_PER_SECOND = 5;
const PLAYER_MAX_HEALTH = 400;

const DRONE_WIDTH = 16;
const DRONE_HEIGHT = 16;
const DRONE_SPEED = 180;
const DRONE_DURATION_MS = 5000;

const AIRSTRIKE_RADIUS = 140;
const AIRSTRIKE_WARNING_MS = 5000;

const GRENADE_SPEED = 220;
const GRENADE_RANGE = 260;
const GRENADE_FUSE_MS = 3000;

const PROJECTILE_STEP_DISTANCE = 6;
const WORLD_PADDING = 2;
const PICKUP_RADIUS = 16;
const MAX_NAME_LENGTH = 18;
const MAX_CONSUMABLE_SLOT = 9;
const MIN_CONSUMABLE_SLOT = 2;
const LOOT_SIZE = 14;

const WEAPONS = {
        pistol: {
                id: 'pistol',
                displayName: 'Pistol',
                kind: 'bullet',
                magazine: 10,
                fireIntervalMs: Math.round(0.35 * 1000),
                reloadMs: Math.round(1.2 * 1000),
                baseDamage: 40,
                spreadDeg: 1.5,
                projectileSpeed: 520,
                dropStart: 120,
                range: 520,
                minFactor: 0.45,
                projectileRadius: 3
        },
        smg: {
                id: 'smg',
                displayName: 'SMG',
                kind: 'bullet',
                magazine: 30,
                fireIntervalMs: Math.round(0.095 * 1000),
                reloadMs: Math.round(1.6 * 1000),
                baseDamage: 24,
                spreadDeg: 8,
                projectileSpeed: 520,
                dropStart: 90,
                range: 500,
                minFactor: 0.35,
                projectileRadius: 3
        },
        rifle: {
                id: 'rifle',
                displayName: 'Rifle',
                kind: 'bullet',
                magazine: 30,
                fireIntervalMs: Math.round(0.16 * 1000),
                reloadMs: Math.round(1.9 * 1000),
                baseDamage: 33,
                spreadDeg: 2.5,
                projectileSpeed: 520,
                dropStart: 180,
                range: 760,
                minFactor: 0.55,
                projectileRadius: 3
        },
        sniper: {
                id: 'sniper',
                displayName: 'Sniper',
                kind: 'bullet',
                magazine: 5,
                fireIntervalMs: Math.round(0.8 * 1000),
                reloadMs: Math.round(2.4 * 1000),
                baseDamage: 350,
                spreadDeg: 0,
                projectileSpeed: 520,
                dropStart: 700,
                range: 1400,
                minFactor: 0.85,
                projectileRadius: 3
        },
        rocket: {
                id: 'rocket',
                displayName: 'Rocket Launcher',
                kind: 'rocket',
                magazine: 1,
                fireIntervalMs: Math.round(1.0 * 1000),
                reloadMs: Math.round(2.8 * 1000),
                spreadDeg: 0,
                projectileSpeed: 260,
                range: 760,
                projectileRadius: 5,
                explosionInnerRadius: 24,
                explosionOuterRadius: 80,
                explosionInnerDamage: 400,
                explosionOuterDamage: 120
        }
};

const LOOT_SPAWN_COUNTS = {
        weapon: {
                smg: 18,
                rifle: 12,
                sniper: 6,
                rocket: 4
        },
        consumable: {
                grenade: 30,
                drone: 12,
                airstrike: 8
        }
};

const EXPLOSIVES = {
        grenade: {
                type: 'grenade',
                innerRadius: 28,
                outerRadius: 90,
                innerDamage: 300,
                outerDamage: 90
        },
        drone: {
                type: 'drone',
                innerRadius: 24,
                outerRadius: 85,
                innerDamage: 350,
                outerDamage: 105
        }
};

const DIRECTIONS = {
        none: { dx: 0, dy: 0 },
        up: { dx: 0, dy: -1 },
        upLeft: { dx: -0.70710677, dy: -0.70710677 },
        left: { dx: -1, dy: 0 },
        downLeft: { dx: -0.70710677, dy: 0.70710677 },
        down: { dx: 0, dy: 1 },
        downRight: { dx: 0.70710677, dy: 0.70710677 },
        right: { dx: 1, dy: 0 },
        upRight: { dx: 0.70710677, dy: -0.70710677 }
};

const LEVEL = loadMultiplayerLevel();

class GameLogic {
        constructor() {
                this.players = new Map();
                this.tickCounter = 0;
                this.nextJoinOrder = 0;
                this.nextEntityId = 1;
                this.initialStateDirty = true;

                this.phase = 'waiting';
                this.waitingEndsAt = null;
                this.returnToLobbyAt = null;
                this.winnerId = '';
                this.winnerName = '';

                this.projectiles = [];
                this.grenades = [];
                this.drones = [];
                this.loot = [];
                this.explosions = [];
                this.airstrikeWarnings = [];

                this.wallZones = this.buildWallZones();
                this.spawnCells = this.buildSpawnCells();
                this.storm = this.createInitialStorm();
        }

        addClient(id) {
                const now = Date.now();
                const player = this.createPlayer(id);

                if (this.phase === 'playing') {
                        player.alive = false;
                        player.spectator = true;
                        player.health = 0;
                        player.spectateIndex = 0;
                } else {
                        player.alive = false;
                        player.spectator = false;
                        player.health = PLAYER_MAX_HEALTH;
                }

                this.players.set(id, player);
                this.initialStateDirty = true;

                if (this.phase === 'waiting') {
                        this.refreshWaitingCountdown(now);
                }
                this.refreshSpectatorTargets();
                return player;
        }

        removeClient(id) {
                const now = Date.now();
                const player = this.players.get(id);
                if (player && this.phase === 'playing' && player.alive) {
                        this.eliminatePlayer(player, null, 'disconnect', now);
                }

                this.players.delete(id);
                this.initialStateDirty = true;

                if (this.players.size <= 0) {
                        this.resetMatch();
                        this.nextJoinOrder = 0;
                        return;
                }

                if (this.phase === 'waiting') {
                        this.refreshWaitingCountdown(now);
                }
                if (this.phase === 'playing') {
                        this.checkForMatchEnd(now);
                }
                this.refreshSpectatorTargets();
        }

        handleMessage(id, msg) {
                let obj;
                try {
                        obj = JSON.parse(msg);
                } catch (_) {
                        return false;
                }

                if (!obj || typeof obj.type !== 'string') {
                        return false;
                }

                const player = this.players.get(id);
                if (!player) {
                        return false;
                }

                const now = Date.now();
                switch (obj.type) {
                case 'register':
                        return this.handleRegister(player, obj);
                case 'input':
                        this.handleInput(player, obj);
                        return false;
                case 'action':
                        return this.handleAction(player, obj, now);
                case 'airstrikeTarget':
                        return this.handleAirstrikeTarget(player, obj, now);
                case 'restartMatch':
                        this.restartToWaitingRoom();
                        return true;
                default:
                        return false;
                }
        }

        handleRegister(player, obj) {
                const next = sanitizePlayerName(obj.playerName, player.name);
                if (next === player.name) {
                        return false;
                }
                player.name = next;
                this.initialStateDirty = true;
                return true;
        }

        handleInput(player, obj) {
                player.move = normalizeDirection(obj.move);
                player.firing = Boolean(obj.firing);

                const aimX = Number(obj.aimX);
                const aimY = Number(obj.aimY);
                if (Number.isFinite(aimX) && Number.isFinite(aimY)) {
                        player.aimX = clamp(aimX, 0, LEVEL.worldWidth);
                        player.aimY = clamp(aimY, 0, LEVEL.worldHeight);
                }
        }

        handleAction(player, obj, now) {
                const name = String(obj.name || '').trim();
                if (!name) {
                        return false;
                }

                switch (name) {
                case 'reload':
                        return this.startReload(player, now);
                case 'selectPrimary':
                        return Boolean(player.primaryWeapon);
                case 'dropPrimary':
                        return this.dropPrimaryWeapon(player);
                case 'useSlot':
                        return this.useConsumableSlot(player, obj.slot, now);
                case 'detonateDrone':
                        return this.detonateDroneForPlayer(player, now);
                case 'spectateNext':
                        return this.spectateNext(player);
                default:
                        return false;
                }
        }

        handleAirstrikeTarget(player, obj, now) {
                if (!player.alive || !player.pendingAirstrike) {
                        return false;
                }

                const x = Number(obj.x);
                const y = Number(obj.y);
                const targetX = Number.isFinite(x)
                        ? clamp(x, 0, LEVEL.worldWidth)
                        : player.x + player.width * 0.5;
                const targetY = Number.isFinite(y)
                        ? clamp(y, 0, LEVEL.worldHeight)
                        : player.y + player.height * 0.5;

                player.pendingAirstrike = false;
                this.airstrikeWarnings.push({
                        id: this.nextId('A'),
                        ownerId: player.id,
                        x: targetX,
                        y: targetY,
                        radius: AIRSTRIKE_RADIUS,
                        createdAt: now,
                        explodeAt: now + AIRSTRIKE_WARNING_MS
                });
                return true;
        }

        startReload(player, now) {
                if (!player.alive || !player.primaryWeapon) {
                        return false;
                }
                const weapon = WEAPONS[player.primaryWeapon];
                if (!weapon) {
                        return false;
                }
                if (player.reloadEndsAt > now) {
                        return false;
                }
                if (player.ammoInMag >= weapon.magazine) {
                        return false;
                }
                player.reloadEndsAt = now + weapon.reloadMs;
                player.firing = false;
                return true;
        }

        dropPrimaryWeapon(player) {
                if (!player.alive || !player.primaryWeapon) {
                        return false;
                }

                this.spawnWeaponLoot(
                        player.primaryWeapon,
                        player.x + player.width * 0.5,
                        player.y + player.height * 0.5
                );

                player.primaryWeapon = null;
                player.ammoInMag = 0;
                player.reloadEndsAt = 0;
                player.firing = false;
                return true;
        }

        useConsumableSlot(player, rawSlot, now) {
                if (!player.alive || player.pendingAirstrike || player.activeDroneId) {
                        return false;
                }

                const slot = Number(rawSlot);
                if (!Number.isFinite(slot)) {
                        return false;
                }
                const slotIndex = Math.floor(slot);
                if (slotIndex < MIN_CONSUMABLE_SLOT || slotIndex > MAX_CONSUMABLE_SLOT) {
                        return false;
                }

                const item = player.inventorySlots.get(slotIndex);
                if (!item || item.count <= 0) {
                        return false;
                }

                if (item.type === 'grenade') {
                        this.consumeInventorySlot(player, slotIndex, 1);
                        this.throwGrenade(player, now);
                        return true;
                }
                if (item.type === 'drone') {
                        this.consumeInventorySlot(player, slotIndex, 1);
                        this.deployDrone(player, now);
                        return true;
                }
                if (item.type === 'airstrike') {
                        this.consumeInventorySlot(player, slotIndex, 1);
                        player.pendingAirstrike = true;
                        player.firing = false;
                        return true;
                }
                return false;
        }

        consumeInventorySlot(player, slot, amount) {
                const entry = player.inventorySlots.get(slot);
                if (!entry) {
                        return;
                }
                entry.count = Math.max(0, entry.count - amount);
                if (entry.count <= 0) {
                        player.inventorySlots.delete(slot);
                        return;
                }
                player.inventorySlots.set(slot, entry);
        }

        deployDrone(player, now) {
                const x = player.x + (player.width - DRONE_WIDTH) * 0.5;
                const y = player.y + (player.height - DRONE_HEIGHT) * 0.5;
                const drone = {
                        id: this.nextId('D'),
                        ownerId: player.id,
                        x,
                        y,
                        width: DRONE_WIDTH,
                        height: DRONE_HEIGHT,
                        expiresAt: now + DRONE_DURATION_MS
                };
                this.drones.push(drone);
                player.activeDroneId = drone.id;
                player.move = 'none';
                player.firing = false;
        }

        detonateDroneForPlayer(player, now) {
                if (!player.activeDroneId) {
                        return false;
                }
                const index = this.drones.findIndex((drone) => drone.id === player.activeDroneId);
                if (index < 0) {
                        player.activeDroneId = '';
                        return false;
                }

                const drone = this.drones[index];
                this.drones.splice(index, 1);
                player.activeDroneId = '';

                const cx = drone.x + drone.width * 0.5;
                const cy = drone.y + drone.height * 0.5;
                this.spawnExplosionEvent('drone', cx, cy);
                this.applyRadialDamageLinear(
                        cx,
                        cy,
                        EXPLOSIVES.drone.innerRadius,
                        EXPLOSIVES.drone.outerRadius,
                        EXPLOSIVES.drone.innerDamage,
                        EXPLOSIVES.drone.outerDamage,
                        player.id,
                        'drone',
                        now
                );
                return true;
        }

        spectateNext(player) {
                if (!player.spectator) {
                        return false;
                }
                player.spectateIndex += 1;
                this.refreshSpectatorTargets();
                return true;
        }

        updateGame(fps) {
                if (this.players.size <= 0) {
                        return;
                }

                const now = Date.now();
                const safeFps = Math.max(1, Number.isFinite(fps) ? fps : 60);
                const dt = 1 / safeFps;
                this.tickCounter = (this.tickCounter + 1) % 1000000000;

                if (this.phase === 'waiting') {
                        this.refreshWaitingCountdown(now);
                        if (this.waitingEndsAt != null && now >= this.waitingEndsAt) {
                                this.startMatch(now);
                        }
                        this.updateExplosions(now);
                        this.refreshSpectatorTargets();
                        return;
                }

                if (this.phase === 'finished') {
                        if (this.returnToLobbyAt != null && now >= this.returnToLobbyAt) {
                                this.startWaitingRoom(now);
                        }
                        this.updateExplosions(now);
                        this.refreshSpectatorTargets();
                        return;
                }

                if (this.phase !== 'playing') {
                        return;
                }

                this.updateStorm(now);
                this.updateReloads(now);
                this.updatePlayerMovement(dt);
                this.handleWeaponFire(now);
                this.updateProjectiles(dt, now);
                this.updateGrenades(dt, now);
                this.updateDrones(dt, now);
                this.updateAirstrikes(now);
                this.updateExplosions(now);
                this.applyStormDamage(dt, now);
                this.applyHealthRegen(dt, now);
                this.collectLoot();
                this.refreshSpectatorTargets();
                this.checkForMatchEnd(now);
        }

        refreshWaitingCountdown(now) {
                if (this.players.size >= 2) {
                        if (this.waitingEndsAt == null) {
                                this.waitingEndsAt = now + WAITING_DURATION_MS;
                        }
                        return;
                }
                this.waitingEndsAt = null;
        }

        startWaitingRoom(now = Date.now()) {
                this.phase = 'waiting';
                this.winnerId = '';
                this.winnerName = '';
                this.returnToLobbyAt = null;
                this.waitingEndsAt = null;

                this.projectiles = [];
                this.grenades = [];
                this.drones = [];
                this.loot = [];
                this.airstrikeWarnings = [];
                this.explosions = [];
                this.storm = this.createInitialStorm();

                for (const player of this.players.values()) {
                        player.alive = false;
                        player.spectator = false;
                        player.health = PLAYER_MAX_HEALTH;
                        player.pendingAirstrike = false;
                        player.activeDroneId = '';
                        player.primaryWeapon = 'pistol';
                        player.ammoInMag = WEAPONS.pistol.magazine;
                        player.reloadEndsAt = 0;
                        player.firing = false;
                        player.move = 'none';
                        player.inventorySlots.clear();
                        const spawn = this.randomValidSpawn();
                        player.x = spawn.x;
                        player.y = spawn.y;
                        player.aimX = spawn.x + player.width * 0.5;
                        player.aimY = spawn.y + player.height * 0.5;
                }

                this.initialStateDirty = true;
                this.refreshWaitingCountdown(now);
                this.refreshSpectatorTargets();
        }

        startMatch(now) {
                this.phase = 'playing';
                this.waitingEndsAt = null;
                this.returnToLobbyAt = null;
                this.winnerId = '';
                this.winnerName = '';

                this.projectiles = [];
                this.grenades = [];
                this.drones = [];
                this.airstrikeWarnings = [];
                this.explosions = [];
                this.loot = [];

                this.storm = this.createInitialStorm();
                this.storm.stage = 'waiting';
                this.storm.stageStartedAt = now;
                this.storm.stageEndsAt = now + STORM_WAIT_MS;

                const orderedPlayers = Array.from(this.players.values()).sort((a, b) => a.joinOrder - b.joinOrder);
                const spawnPoints = this.generateSpawnPoints(orderedPlayers.length);

                for (let i = 0; i < orderedPlayers.length; i++) {
                        const player = orderedPlayers[i];
                        const spawn = spawnPoints[i] || this.randomValidSpawn();
                        player.alive = true;
                        player.spectator = false;
                        player.spectatingId = '';
                        player.spectateIndex = 0;
                        player.health = PLAYER_MAX_HEALTH;
                        player.lastDamageAt = 0;
                        player.primaryWeapon = 'pistol';
                        player.ammoInMag = WEAPONS.pistol.magazine;
                        player.reloadEndsAt = 0;
                        player.pendingAirstrike = false;
                        player.activeDroneId = '';
                        player.inventorySlots.clear();
                        player.firing = false;
                        player.move = 'none';
                        player.kills = 0;
                        player.deaths = 0;
                        player.x = spawn.x;
                        player.y = spawn.y;
                        player.aimX = spawn.x + player.width * 0.5;
                        player.aimY = spawn.y + player.height * 0.5;
                }

                this.spawnInitialLoot();
                this.refreshSpectatorTargets();
        }

        finishMatch(winner, now) {
                this.phase = 'finished';
                this.returnToLobbyAt = now + FINISHED_DURATION_MS;
                this.winnerId = winner ? winner.id : '';
                this.winnerName = winner ? winner.name : '';

                for (const player of this.players.values()) {
                        player.firing = false;
                        player.move = 'none';
                        player.pendingAirstrike = false;
                }
        }

        restartToWaitingRoom() {
                this.startWaitingRoom(Date.now());
        }

        resetMatch() {
                this.phase = 'waiting';
                this.waitingEndsAt = null;
                this.returnToLobbyAt = null;
                this.winnerId = '';
                this.winnerName = '';
                this.projectiles = [];
                this.grenades = [];
                this.drones = [];
                this.loot = [];
                this.airstrikeWarnings = [];
                this.explosions = [];
                this.storm = this.createInitialStorm();
                this.initialStateDirty = true;
        }

        updateStorm(now) {
                const storm = this.storm;
                if (storm.stage === 'waiting') {
                        storm.damagePerSecond = 0;
                        storm.radius = storm.initialRadius;
                        if (storm.stageEndsAt != null && now >= storm.stageEndsAt) {
                                storm.stage = 'shrink1';
                                storm.stageStartedAt = now;
                                storm.stageEndsAt = now + STORM_SHRINK_1_MS;
                                storm.damagePerSecond = STORM_DAMAGE_STAGE_1;
                        }
                        return;
                }

                if (storm.stage === 'shrink1') {
                        const t = normalizeProgress(now, storm.stageStartedAt, storm.stageEndsAt);
                        storm.radius = lerp(storm.initialRadius, storm.initialRadius * STORM_RADIUS_STAGE_1_FACTOR, t);
                        storm.damagePerSecond = STORM_DAMAGE_STAGE_1;
                        if (now >= storm.stageEndsAt) {
                                storm.stage = 'shrink2';
                                storm.stageStartedAt = now;
                                storm.stageEndsAt = now + STORM_SHRINK_2_MS;
                                storm.radius = storm.initialRadius * STORM_RADIUS_STAGE_1_FACTOR;
                                storm.damagePerSecond = STORM_DAMAGE_STAGE_2;
                        }
                        return;
                }

                if (storm.stage === 'shrink2') {
                        const t = normalizeProgress(now, storm.stageStartedAt, storm.stageEndsAt);
                        storm.radius = lerp(
                                storm.initialRadius * STORM_RADIUS_STAGE_1_FACTOR,
                                storm.initialRadius * STORM_RADIUS_STAGE_2_FACTOR,
                                t
                        );
                        storm.damagePerSecond = STORM_DAMAGE_STAGE_2;
                        if (now >= storm.stageEndsAt) {
                                storm.stage = 'final';
                                storm.stageStartedAt = now;
                                storm.stageEndsAt = null;
                                storm.radius = storm.initialRadius * STORM_RADIUS_STAGE_2_FACTOR;
                                storm.damagePerSecond = STORM_DAMAGE_STAGE_2;
                        }
                        return;
                }

                storm.stage = 'final';
                storm.radius = storm.initialRadius * STORM_RADIUS_STAGE_2_FACTOR;
                storm.damagePerSecond = STORM_DAMAGE_STAGE_2;
        }

        updateReloads(now) {
                for (const player of this.players.values()) {
                        if (!player.primaryWeapon) {
                                player.reloadEndsAt = 0;
                                continue;
                        }
                        if (player.reloadEndsAt > 0 && now >= player.reloadEndsAt) {
                                const weapon = WEAPONS[player.primaryWeapon];
                                if (weapon) {
                                        player.ammoInMag = weapon.magazine;
                                }
                                player.reloadEndsAt = 0;
                        }
                }
        }

        updatePlayerMovement(dt) {
                for (const player of this.players.values()) {
                        if (!player.alive) {
                                continue;
                        }
                        if (player.pendingAirstrike || player.activeDroneId) {
                                continue;
                        }
                        const dir = DIRECTIONS[player.move] || DIRECTIONS.none;
                        this.moveEntityWithWalls(player, dir.dx * PLAYER_SPEED * dt, dir.dy * PLAYER_SPEED * dt);
                }
        }

        handleWeaponFire(now) {
                for (const player of this.players.values()) {
                        if (!player.alive || !player.firing || player.pendingAirstrike || player.activeDroneId) {
                                continue;
                        }
                        this.tryFire(player, now);
                }
        }

        tryFire(player, now) {
                const weaponId = player.primaryWeapon;
                if (!weaponId) {
                        return;
                }
                const weapon = WEAPONS[weaponId];
                if (!weapon) {
                        return;
                }
                if (player.reloadEndsAt > now) {
                        return;
                }
                if (now - player.lastFireAt < weapon.fireIntervalMs) {
                        return;
                }
                if (player.ammoInMag <= 0) {
                        return;
                }

                const originX = player.x + player.width * 0.5;
                const originY = player.y + player.height * 0.5;
                let angle = Math.atan2(player.aimY - originY, player.aimX - originX);
                if (!Number.isFinite(angle)) {
                        angle = 0;
                }
                if (weapon.spreadDeg > 0) {
                        angle += (Math.random() * 2 - 1) * degToRad(weapon.spreadDeg);
                }

                player.lastFireAt = now;
                player.ammoInMag -= 1;

                this.projectiles.push({
                        id: this.nextId('P'),
                        kind: weapon.kind,
                        weaponId,
                        ownerId: player.id,
                        x: originX,
                        y: originY,
                        vx: Math.cos(angle) * weapon.projectileSpeed,
                        vy: Math.sin(angle) * weapon.projectileSpeed,
                        range: weapon.range,
                        travel: 0,
                        radius: weapon.projectileRadius || 3,
                        baseDamage: weapon.baseDamage || 0,
                        dropStart: weapon.dropStart || 0,
                        minFactor: weapon.minFactor || 1,
                        explosionInnerRadius: weapon.explosionInnerRadius || 0,
                        explosionOuterRadius: weapon.explosionOuterRadius || 0,
                        explosionInnerDamage: weapon.explosionInnerDamage || 0,
                        explosionOuterDamage: weapon.explosionOuterDamage || 0
                });
        }

        updateProjectiles(dt, now) {
                const next = [];
                for (const projectile of this.projectiles) {
                        let alive = true;
                        const speed = Math.sqrt(projectile.vx * projectile.vx + projectile.vy * projectile.vy);
                        const distance = speed * dt;
                        const steps = Math.max(1, Math.ceil(distance / PROJECTILE_STEP_DISTANCE));
                        const stepDt = dt / steps;

                        for (let step = 0; step < steps && alive; step++) {
                                const nx = projectile.x + projectile.vx * stepDt;
                                const ny = projectile.y + projectile.vy * stepDt;
                                projectile.travel += distanceBetween(projectile.x, projectile.y, nx, ny);
                                projectile.x = nx;
                                projectile.y = ny;

                                if (this.pointCollidesWall(projectile.x, projectile.y)) {
                                        if (projectile.kind === 'rocket') {
                                                this.explodeRocket(projectile, now);
                                        }
                                        alive = false;
                                        break;
                                }

                                const hit = this.findProjectileHitPlayer(projectile);
                                if (hit) {
                                        if (projectile.kind === 'rocket') {
                                                this.explodeRocket(projectile, now);
                                        } else {
                                                const damage = this.bulletDamageAtDistance(projectile);
                                                this.applyDamage(hit, damage, projectile.ownerId, projectile.weaponId, now);
                                        }
                                        alive = false;
                                        break;
                                }

                                if (projectile.travel >= projectile.range) {
                                        if (projectile.kind === 'rocket') {
                                                this.explodeRocket(projectile, now);
                                        }
                                        alive = false;
                                        break;
                                }
                        }

                        if (alive) {
                                next.push(projectile);
                        }
                }
                this.projectiles = next;
        }

        findProjectileHitPlayer(projectile) {
                for (const player of this.players.values()) {
                        if (!player.alive) {
                                continue;
                        }
                        if (projectile.kind === 'bullet' && player.id === projectile.ownerId) {
                                continue;
                        }
                        if (circleRectOverlap(projectile.x, projectile.y, projectile.radius, rectAt(player.x, player.y, player.width, player.height))) {
                                return player;
                        }
                }
                return null;
        }

        bulletDamageAtDistance(projectile) {
                if (projectile.baseDamage <= 0) {
                        return 0;
                }
                if (projectile.travel <= projectile.dropStart) {
                        return projectile.baseDamage;
                }
                const rangeAfterDrop = Math.max(1, projectile.range - projectile.dropStart);
                const t = clamp((projectile.travel - projectile.dropStart) / rangeAfterDrop, 0, 1);
                const factor = lerp(1, projectile.minFactor, t);
                return Math.max(1, Math.round(projectile.baseDamage * factor));
        }

        explodeRocket(projectile, now) {
                this.spawnExplosionEvent('rocket', projectile.x, projectile.y);
                this.applyRadialDamageLinear(
                        projectile.x,
                        projectile.y,
                        projectile.explosionInnerRadius,
                        projectile.explosionOuterRadius,
                        projectile.explosionInnerDamage,
                        projectile.explosionOuterDamage,
                        projectile.ownerId,
                        'rocket',
                        now
                );
        }

        throwGrenade(player, now) {
                const originX = player.x + player.width * 0.5;
                const originY = player.y + player.height * 0.5;
                const dx = player.aimX - originX;
                const dy = player.aimY - originY;
                const dist = Math.sqrt(dx * dx + dy * dy);
                const safeDist = dist <= 0.0001 ? 1 : dist;
                const scale = Math.min(1, GRENADE_RANGE / safeDist);
                const targetX = originX + dx * scale;
                const targetY = originY + dy * scale;
                this.grenades.push({
                        id: this.nextId('G'),
                        ownerId: player.id,
                        x: originX,
                        y: originY,
                        targetX,
                        targetY,
                        explodeAt: now + GRENADE_FUSE_MS
                });
        }

        updateGrenades(dt, now) {
                const next = [];
                for (const grenade of this.grenades) {
                        const toTargetX = grenade.targetX - grenade.x;
                        const toTargetY = grenade.targetY - grenade.y;
                        const remaining = Math.sqrt(toTargetX * toTargetX + toTargetY * toTargetY);
                        const step = GRENADE_SPEED * dt;
                        if (remaining > 0.001) {
                                if (step >= remaining) {
                                        grenade.x = grenade.targetX;
                                        grenade.y = grenade.targetY;
                                } else {
                                        grenade.x += (toTargetX / remaining) * step;
                                        grenade.y += (toTargetY / remaining) * step;
                                }
                        }

                        if (now >= grenade.explodeAt) {
                                this.spawnExplosionEvent('grenade', grenade.x, grenade.y);
                                this.applyRadialDamageLinear(
                                        grenade.x,
                                        grenade.y,
                                        EXPLOSIVES.grenade.innerRadius,
                                        EXPLOSIVES.grenade.outerRadius,
                                        EXPLOSIVES.grenade.innerDamage,
                                        EXPLOSIVES.grenade.outerDamage,
                                        grenade.ownerId,
                                        'grenade',
                                        now
                                );
                                continue;
                        }
                        next.push(grenade);
                }
                this.grenades = next;
        }

        updateDrones(dt, now) {
                const next = [];
                for (const drone of this.drones) {
                        const owner = this.players.get(drone.ownerId);
                        if (!owner || !owner.alive) {
                                if (owner) {
                                        owner.activeDroneId = '';
                                }
                                continue;
                        }

                        if (now >= drone.expiresAt) {
                                owner.activeDroneId = '';
                                const cx = drone.x + drone.width * 0.5;
                                const cy = drone.y + drone.height * 0.5;
                                this.spawnExplosionEvent('drone', cx, cy);
                                this.applyRadialDamageLinear(
                                        cx,
                                        cy,
                                        EXPLOSIVES.drone.innerRadius,
                                        EXPLOSIVES.drone.outerRadius,
                                        EXPLOSIVES.drone.innerDamage,
                                        EXPLOSIVES.drone.outerDamage,
                                        owner.id,
                                        'drone',
                                        now
                                );
                                continue;
                        }

                        const dir = DIRECTIONS[owner.move] || DIRECTIONS.none;
                        this.moveEntityWithWalls(drone, dir.dx * DRONE_SPEED * dt, dir.dy * DRONE_SPEED * dt);
                        next.push(drone);
                }
                this.drones = next;
        }

        updateAirstrikes(now) {
                const remaining = [];
                for (const warning of this.airstrikeWarnings) {
                        if (now < warning.explodeAt) {
                                remaining.push(warning);
                                continue;
                        }

                        this.spawnExplosionEvent('airstrike', warning.x, warning.y);
                        this.applyAirstrikeDamage(warning, now);
                }
                this.airstrikeWarnings = remaining;
        }

        applyAirstrikeDamage(warning, now) {
                const inner = warning.radius * 0.5;
                const outer = warning.radius;
                for (const player of this.players.values()) {
                        if (!player.alive) {
                                continue;
                        }
                        const cx = player.x + player.width * 0.5;
                        const cy = player.y + player.height * 0.5;
                        const dist = distanceBetween(cx, cy, warning.x, warning.y);
                        if (dist > outer) {
                                continue;
                        }
                        this.applyDamage(player, dist <= inner ? 400 : 300, warning.ownerId, 'airstrike', now);
                }
        }

        applyStormDamage(dt, now) {
                if (this.storm.damagePerSecond <= 0) {
                        return;
                }
                for (const player of this.players.values()) {
                        if (!player.alive) {
                                continue;
                        }
                        const cx = player.x + player.width * 0.5;
                        const cy = player.y + player.height * 0.5;
                        const dist = distanceBetween(cx, cy, this.storm.centerX, this.storm.centerY);
                        if (dist <= this.storm.radius) {
                                continue;
                        }
                        this.applyDamage(player, this.storm.damagePerSecond * dt, null, 'storm', now);
                }
        }

        applyHealthRegen(dt, now) {
                for (const player of this.players.values()) {
                        if (!player.alive) {
                                continue;
                        }
                        if (player.health >= PLAYER_MAX_HEALTH) {
                                continue;
                        }
                        if (now - player.lastDamageAt < PLAYER_REGEN_DELAY_MS) {
                                continue;
                        }
                        player.health = Math.min(PLAYER_MAX_HEALTH, player.health + PLAYER_REGEN_PER_SECOND * dt);
                }
        }

        collectLoot() {
                if (this.loot.length <= 0) {
                        return;
                }
                const remaining = [];
                for (const loot of this.loot) {
                        let picked = false;
                        for (const player of this.players.values()) {
                                if (!player.alive) {
                                        continue;
                                }
                                if (!this.playerCanPickLoot(player, loot)) {
                                        continue;
                                }

                                if (loot.kind === 'weapon') {
                                        if (player.primaryWeapon) {
                                                continue;
                                        }
                                        player.primaryWeapon = loot.weaponId;
                                        const weapon = WEAPONS[loot.weaponId];
                                        player.ammoInMag = weapon ? weapon.magazine : 0;
                                        player.reloadEndsAt = 0;
                                        picked = true;
                                        break;
                                }

                                if (loot.kind === 'consumable') {
                                        if (!this.addConsumable(player, loot.consumableType, 1)) {
                                                continue;
                                        }
                                        picked = true;
                                        break;
                                }
                        }
                        if (!picked) {
                                remaining.push(loot);
                        }
                }
                this.loot = remaining;
        }

        playerCanPickLoot(player, loot) {
                const cx = player.x + player.width * 0.5;
                const cy = player.y + player.height * 0.5;
                return distanceBetween(cx, cy, loot.x, loot.y) <= PICKUP_RADIUS;
        }

        addConsumable(player, type, amount) {
                for (const [slot, entry] of player.inventorySlots.entries()) {
                        if (entry.type === type) {
                                entry.count += amount;
                                player.inventorySlots.set(slot, entry);
                                return true;
                        }
                }
                for (let slot = MIN_CONSUMABLE_SLOT; slot <= MAX_CONSUMABLE_SLOT; slot++) {
                        if (!player.inventorySlots.has(slot)) {
                                player.inventorySlots.set(slot, { type, count: amount });
                                return true;
                        }
                }
                return false;
        }

        applyDamage(player, rawDamage, sourceId, reason, now) {
                if (!player.alive) {
                        return;
                }
                const damage = Math.max(0, Number(rawDamage) || 0);
                if (damage <= 0) {
                        return;
                }
                player.health -= damage;
                player.lastDamageAt = now;
                if (player.health > 0) {
                        return;
                }
                this.eliminatePlayer(player, sourceId, reason, now);
        }

        eliminatePlayer(player, sourceId, reason, now) {
                if (!player.alive) {
                        return;
                }

                player.alive = false;
                player.spectator = true;
                player.health = 0;
                player.firing = false;
                player.move = 'none';
                player.pendingAirstrike = false;
                player.reloadEndsAt = 0;

                if (player.activeDroneId) {
                        this.removeDroneById(player.activeDroneId);
                        player.activeDroneId = '';
                }

                this.dropLootOnDeath(player);
                player.deaths += 1;

                if (sourceId && sourceId !== player.id) {
                        const killer = this.players.get(sourceId);
                        if (killer) {
                                killer.kills += 1;
                        }
                }

                this.refreshSpectatorTargets();
                this.checkForMatchEnd(now);
        }

        dropLootOnDeath(player) {
                const dropX = player.x + player.width * 0.5;
                const dropY = player.y + player.height * 0.5;

                if (player.primaryWeapon) {
                        this.spawnWeaponLoot(player.primaryWeapon, dropX, dropY);
                        player.primaryWeapon = null;
                        player.ammoInMag = 0;
                }

                for (const entry of player.inventorySlots.values()) {
                        for (let i = 0; i < entry.count; i++) {
                                this.spawnConsumableLoot(entry.type, dropX + randomRange(-10, 10), dropY + randomRange(-10, 10));
                        }
                }
                player.inventorySlots.clear();
        }

        spawnExplosionEvent(type, x, y) {
                this.explosions.push({
                        id: this.nextId('X'),
                        type,
                        x,
                        y,
                        expiresAt: Date.now() + 450
                });
        }

        updateExplosions(now) {
                this.explosions = this.explosions.filter((explosion) => explosion.expiresAt > now);
        }

        applyRadialDamageLinear(x, y, innerRadius, outerRadius, innerDamage, outerDamage, sourceId, reason, now) {
                const safeInner = Math.max(0, innerRadius);
                const safeOuter = Math.max(safeInner + 0.001, outerRadius);
                for (const player of this.players.values()) {
                        if (!player.alive) {
                                continue;
                        }
                        const cx = player.x + player.width * 0.5;
                        const cy = player.y + player.height * 0.5;
                        const dist = distanceBetween(cx, cy, x, y);
                        if (dist > safeOuter) {
                                continue;
                        }

                        let damage;
                        if (dist <= safeInner) {
                                damage = innerDamage;
                        } else {
                                const t = (dist - safeInner) / (safeOuter - safeInner);
                                damage = lerp(innerDamage, outerDamage, t);
                        }
                        this.applyDamage(player, damage, sourceId, reason, now);
                }
        }

        removeDroneById(droneId) {
                const index = this.drones.findIndex((drone) => drone.id === droneId);
                if (index >= 0) {
                        this.drones.splice(index, 1);
                }
        }

        checkForMatchEnd(now) {
                if (this.phase !== 'playing') {
                        return;
                }
                const alivePlayers = Array.from(this.players.values()).filter((player) => player.alive);
                if (alivePlayers.length > 1) {
                        return;
                }
                this.finishMatch(alivePlayers[0] || null, now);
        }

        refreshSpectatorTargets() {
                const alivePlayers = Array.from(this.players.values())
                        .filter((player) => player.alive)
                        .sort((a, b) => a.joinOrder - b.joinOrder);

                for (const player of this.players.values()) {
                        if (!player.spectator) {
                                player.spectatingId = '';
                                continue;
                        }
                        if (alivePlayers.length <= 0) {
                                player.spectatingId = '';
                                player.spectateIndex = 0;
                                continue;
                        }
                        const index = positiveMod(player.spectateIndex, alivePlayers.length);
                        player.spectateIndex = index;
                        player.spectatingId = alivePlayers[index].id;
                }
        }

        generateSpawnPoints(count) {
                if (count <= 0) {
                        return [];
                }
                const candidates = shuffle(this.spawnCells.slice());
                const result = [];

                for (const candidate of candidates) {
                        if (result.length >= count) {
                                break;
                        }
                        if (this.rectCollidesWall(candidate.x, candidate.y, PLAYER_WIDTH, PLAYER_HEIGHT)) {
                                continue;
                        }
                        let overlaps = false;
                        for (const picked of result) {
                                const dx = (picked.x + PLAYER_WIDTH * 0.5) - (candidate.x + PLAYER_WIDTH * 0.5);
                                const dy = (picked.y + PLAYER_HEIGHT * 0.5) - (candidate.y + PLAYER_HEIGHT * 0.5);
                                if (dx * dx + dy * dy < 30 * 30) {
                                        overlaps = true;
                                        break;
                                }
                        }
                        if (!overlaps) {
                                result.push(candidate);
                        }
                }

                while (result.length < count) {
                        result.push(this.randomValidSpawn());
                }
                return result;
        }

        randomValidSpawn() {
                if (this.spawnCells.length > 0) {
                        const attempts = Math.min(200, this.spawnCells.length * 2);
                        for (let i = 0; i < attempts; i++) {
                                const idx = Math.floor(Math.random() * this.spawnCells.length);
                                const candidate = this.spawnCells[idx];
                                if (candidate && !this.rectCollidesWall(candidate.x, candidate.y, PLAYER_WIDTH, PLAYER_HEIGHT)) {
                                        return { x: candidate.x, y: candidate.y };
                                }
                        }
                }

                for (let i = 0; i < 300; i++) {
                        const x = randomRange(0, Math.max(0, LEVEL.worldWidth - PLAYER_WIDTH));
                        const y = randomRange(0, Math.max(0, LEVEL.worldHeight - PLAYER_HEIGHT));
                        if (!this.rectCollidesWall(x, y, PLAYER_WIDTH, PLAYER_HEIGHT)) {
                                return { x, y };
                        }
                }

                return {
                        x: clamp(LEVEL.worldWidth * 0.5 - PLAYER_WIDTH * 0.5, 0, Math.max(0, LEVEL.worldWidth - PLAYER_WIDTH)),
                        y: clamp(LEVEL.worldHeight * 0.5 - PLAYER_HEIGHT * 0.5, 0, Math.max(0, LEVEL.worldHeight - PLAYER_HEIGHT))
                };
        }

        spawnInitialLoot() {
                const candidates = shuffle(this.spawnCells.slice());
                let index = 0;

                const takeCell = () => {
                        while (index < candidates.length) {
                                const cell = candidates[index++];
                                if (!cell) {
                                        continue;
                                }
                                if (this.rectCollidesWall(cell.x - LOOT_SIZE * 0.5, cell.y - LOOT_SIZE * 0.5, LOOT_SIZE, LOOT_SIZE)) {
                                        continue;
                                }
                                return cell;
                        }
                        return null;
                };

                for (const [weaponId, count] of Object.entries(LOOT_SPAWN_COUNTS.weapon)) {
                        for (let i = 0; i < count; i++) {
                                const cell = takeCell();
                                if (!cell) {
                                        break;
                                }
                                this.spawnWeaponLoot(weaponId, cell.x + LOOT_SIZE * 0.5, cell.y + LOOT_SIZE * 0.5);
                        }
                }

                for (const [type, count] of Object.entries(LOOT_SPAWN_COUNTS.consumable)) {
                        for (let i = 0; i < count; i++) {
                                const cell = takeCell();
                                if (!cell) {
                                        break;
                                }
                                this.spawnConsumableLoot(type, cell.x + LOOT_SIZE * 0.5, cell.y + LOOT_SIZE * 0.5);
                        }
                }
        }

        spawnWeaponLoot(weaponId, x, y) {
                if (!WEAPONS[weaponId]) {
                        return;
                }
                this.loot.push({
                        id: this.nextId('L'),
                        kind: 'weapon',
                        weaponId,
                        x: clamp(x, WORLD_PADDING, LEVEL.worldWidth - WORLD_PADDING),
                        y: clamp(y, WORLD_PADDING, LEVEL.worldHeight - WORLD_PADDING)
                });
        }

        spawnConsumableLoot(type, x, y) {
                if (type !== 'grenade' && type !== 'drone' && type !== 'airstrike') {
                        return;
                }
                this.loot.push({
                        id: this.nextId('L'),
                        kind: 'consumable',
                        consumableType: type,
                        x: clamp(x, WORLD_PADDING, LEVEL.worldWidth - WORLD_PADDING),
                        y: clamp(y, WORLD_PADDING, LEVEL.worldHeight - WORLD_PADDING)
                });
        }

        moveEntityWithWalls(entity, dx, dy) {
                if (!Number.isFinite(dx) || !Number.isFinite(dy)) {
                        return;
                }

                if (Math.abs(dx) > 0) {
                        const targetX = clamp(entity.x + dx, 0, Math.max(0, LEVEL.worldWidth - entity.width));
                        if (!this.rectCollidesWall(targetX, entity.y, entity.width, entity.height)) {
                                entity.x = targetX;
                        }
                }

                if (Math.abs(dy) > 0) {
                        const targetY = clamp(entity.y + dy, 0, Math.max(0, LEVEL.worldHeight - entity.height));
                        if (!this.rectCollidesWall(entity.x, targetY, entity.width, entity.height)) {
                                entity.y = targetY;
                        }
                }

                entity.x = clamp(entity.x, 0, Math.max(0, LEVEL.worldWidth - entity.width));
                entity.y = clamp(entity.y, 0, Math.max(0, LEVEL.worldHeight - entity.height));
        }

        rectCollidesWall(x, y, width, height) {
                const rect = rectAt(x, y, width, height);
                for (const wall of this.wallZones) {
                        if (rectsOverlap(rect, wall)) {
                                return true;
                        }
                }
                return false;
        }

        pointCollidesWall(x, y) {
                for (const wall of this.wallZones) {
                        if (x >= wall.left && x <= wall.right && y >= wall.top && y <= wall.bottom) {
                                return true;
                        }
                }
                return false;
        }

        buildWallZones() {
                const zones = [];
                for (const zone of LEVEL.zones) {
                        const type = normalize(zone.type);
                        const name = normalize(zone.name);
                        if (!type.includes('wall') && !name.includes('wall') && !type.includes('mur') && !name.includes('mur')) {
                                continue;
                        }
                        zones.push(rectAt(zone.x, zone.y, zone.width, zone.height));
                }
                return zones;
        }

        buildSpawnCells() {
                const cells = [];
                if (Array.isArray(LEVEL.gemCells) && LEVEL.gemCells.length > 0) {
                        for (const cell of LEVEL.gemCells) {
                                cells.push({
                                        x: clamp(cell.x, 0, Math.max(0, LEVEL.worldWidth - PLAYER_WIDTH)),
                                        y: clamp(cell.y, 0, Math.max(0, LEVEL.worldHeight - PLAYER_HEIGHT))
                                });
                        }
                        return uniqueCells(cells);
                }

                const step = 24;
                for (let y = step; y < LEVEL.worldHeight - step; y += step) {
                        for (let x = step; x < LEVEL.worldWidth - step; x += step) {
                                cells.push({
                                        x: clamp(x, 0, Math.max(0, LEVEL.worldWidth - PLAYER_WIDTH)),
                                        y: clamp(y, 0, Math.max(0, LEVEL.worldHeight - PLAYER_HEIGHT))
                                });
                        }
                }
                return uniqueCells(cells);
        }

        createInitialStorm() {
                const initialRadius = Math.min(LEVEL.worldWidth, LEVEL.worldHeight) * 0.5;
                return {
                        stage: 'waiting',
                        centerX: LEVEL.worldWidth * 0.5,
                        centerY: LEVEL.worldHeight * 0.5,
                        initialRadius,
                        radius: initialRadius,
                        damagePerSecond: 0,
                        stageStartedAt: 0,
                        stageEndsAt: 0
                };
        }

        createPlayer(id) {
                const spawn = this.randomValidSpawn();
                return {
                        id,
                        name: `Player ${this.players.size + 1}`,
                        joinOrder: this.nextJoinOrder++,
                        x: spawn.x,
                        y: spawn.y,
                        width: PLAYER_WIDTH,
                        height: PLAYER_HEIGHT,
                        move: 'none',
                        aimX: spawn.x + PLAYER_WIDTH * 0.5,
                        aimY: spawn.y + PLAYER_HEIGHT * 0.5,
                        firing: false,
                        lastFireAt: 0,
                        reloadEndsAt: 0,
                        alive: false,
                        spectator: false,
                        spectateIndex: 0,
                        spectatingId: '',
                        health: PLAYER_MAX_HEALTH,
                        lastDamageAt: 0,
                        primaryWeapon: 'pistol',
                        ammoInMag: WEAPONS.pistol.magazine,
                        pendingAirstrike: false,
                        activeDroneId: '',
                        inventorySlots: new Map(),
                        kills: 0,
                        deaths: 0
                };
        }

        nextId(prefix) {
                const value = this.nextEntityId++;
                return `${prefix}${String(value).padStart(6, '0')}`;
        }

        consumeInitialState() {
                if (!this.initialStateDirty) {
                        return null;
                }
                this.initialStateDirty = false;
                return this.getInitialState();
        }

        getInitialState() {
                return {
                        level: LEVEL.levelName,
                        worldWidth: round2(LEVEL.worldWidth),
                        worldHeight: round2(LEVEL.worldHeight),
                        wallZones: this.wallZones.map((wall) => ({
                                x: round2(wall.left),
                                y: round2(wall.top),
                                width: round2(wall.width),
                                height: round2(wall.height)
                        })),
                        players: Array.from(this.players.values())
                                .sort((a, b) => a.joinOrder - b.joinOrder)
                                .map((player) => ({
                                        id: player.id,
                                        name: player.name,
                                        joinOrder: player.joinOrder,
                                        width: player.width,
                                        height: player.height
                                }))
                };
        }

        getGameplayState() {
                const now = Date.now();
                const countdownSeconds = this.phase === 'waiting' && this.waitingEndsAt != null
                        ? Math.max(0, Math.ceil((this.waitingEndsAt - now) / 1000))
                        : 0;
                const returnToLobbySeconds = this.phase === 'finished' && this.returnToLobbyAt != null
                        ? Math.max(0, Math.ceil((this.returnToLobbyAt - now) / 1000))
                        : 0;
                const stormSecondsToNextStage = this.storm.stageEndsAt
                        ? Math.max(0, Math.ceil((this.storm.stageEndsAt - now) / 1000))
                        : 0;

                return {
                        tickCounter: this.tickCounter,
                        level: LEVEL.levelName,
                        worldWidth: round2(LEVEL.worldWidth),
                        worldHeight: round2(LEVEL.worldHeight),
                        phase: this.phase,
                        countdownSeconds,
                        returnToLobbySeconds,
                        winnerId: this.winnerId,
                        winnerName: this.winnerName,
                        aliveCount: Array.from(this.players.values()).filter((player) => player.alive).length,
                        storm: {
                                stage: this.storm.stage,
                                centerX: round2(this.storm.centerX),
                                centerY: round2(this.storm.centerY),
                                radius: round2(this.storm.radius),
                                damagePerSecond: round2(this.storm.damagePerSecond),
                                secondsToNextStage: stormSecondsToNextStage
                        },
                        players: Array.from(this.players.values())
                                .sort((a, b) => a.joinOrder - b.joinOrder)
                                .map((player) => this.serializePlayer(player, now)),
                        projectiles: this.projectiles.map((projectile) => ({
                                id: projectile.id,
                                kind: projectile.kind,
                                weaponId: projectile.weaponId,
                                x: round2(projectile.x),
                                y: round2(projectile.y)
                        })),
                        grenades: this.grenades.map((grenade) => ({
                                id: grenade.id,
                                x: round2(grenade.x),
                                y: round2(grenade.y),
                                ownerId: grenade.ownerId,
                                secondsToExplode: Math.max(0, round2((grenade.explodeAt - now) / 1000))
                        })),
                        drones: this.drones.map((drone) => ({
                                id: drone.id,
                                ownerId: drone.ownerId,
                                x: round2(drone.x),
                                y: round2(drone.y),
                                width: drone.width,
                                height: drone.height,
                                secondsRemaining: Math.max(0, round2((drone.expiresAt - now) / 1000))
                        })),
                        loot: this.loot.map((item) => ({
                                id: item.id,
                                kind: item.kind,
                                weaponId: item.weaponId || '',
                                consumableType: item.consumableType || '',
                                x: round2(item.x),
                                y: round2(item.y)
                        })),
                        explosions: this.explosions.map((explosion) => ({
                                id: explosion.id,
                                type: explosion.type,
                                x: round2(explosion.x),
                                y: round2(explosion.y),
                                ttlMs: Math.max(0, Math.round(explosion.expiresAt - now))
                        })),
                        airstrikeWarnings: this.airstrikeWarnings.map((warning) => ({
                                id: warning.id,
                                ownerId: warning.ownerId,
                                x: round2(warning.x),
                                y: round2(warning.y),
                                radius: warning.radius,
                                secondsToImpact: Math.max(0, round2((warning.explodeAt - now) / 1000))
                        }))
                };
        }

        serializePlayer(player, now) {
                const weapon = player.primaryWeapon ? WEAPONS[player.primaryWeapon] : null;
                return {
                        id: player.id,
                        name: player.name,
                        joinOrder: player.joinOrder,
                        x: round2(player.x),
                        y: round2(player.y),
                        width: player.width,
                        height: player.height,
                        move: player.move,
                        aimX: round2(player.aimX),
                        aimY: round2(player.aimY),
                        alive: player.alive,
                        spectator: player.spectator,
                        spectatingId: player.spectatingId,
                        health: round2(player.health),
                        maxHealth: PLAYER_MAX_HEALTH,
                        primaryWeapon: player.primaryWeapon || '',
                        ammoInMag: player.ammoInMag,
                        ammoCapacity: weapon ? weapon.magazine : 0,
                        reloading: player.reloadEndsAt > now,
                        reloadRemainingMs: Math.max(0, Math.round(player.reloadEndsAt - now)),
                        pendingAirstrike: player.pendingAirstrike,
                        activeDroneId: player.activeDroneId,
                        kills: player.kills,
                        deaths: player.deaths,
                        inventorySlots: Array.from(player.inventorySlots.entries())
                                .sort((a, b) => a[0] - b[0])
                                .map(([slot, entry]) => ({
                                        slot,
                                        type: entry.type,
                                        count: entry.count
                                }))
                };
        }

        getFullState() {
                return {
                        ...this.getInitialState(),
                        ...this.getGameplayState()
                };
        }
}

function normalizeProgress(now, from, to) {
        const duration = Math.max(1, to - from);
        return clamp((now - from) / duration, 0, 1);
}

function sanitizePlayerName(value, fallback) {
        const cleaned = String(value || '').replace(/\s+/g, ' ').trim();
        if (!cleaned) {
                return fallback;
        }
        return cleaned.slice(0, MAX_NAME_LENGTH);
}

function normalizeDirection(value) {
        const move = String(value || '').trim();
        if (Object.prototype.hasOwnProperty.call(DIRECTIONS, move)) {
                return move;
        }
        return 'none';
}

function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
}

function round2(value) {
        return Math.round(value * 100) / 100;
}

function lerp(from, to, alpha) {
        return from + (to - from) * alpha;
}

function degToRad(deg) {
        return (deg * Math.PI) / 180;
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

function circleRectOverlap(cx, cy, radius, rect) {
        const nearestX = clamp(cx, rect.left, rect.right);
        const nearestY = clamp(cy, rect.top, rect.bottom);
        const dx = cx - nearestX;
        const dy = cy - nearestY;
        return (dx * dx + dy * dy) <= radius * radius;
}

function distanceBetween(x1, y1, x2, y2) {
        const dx = x2 - x1;
        const dy = y2 - y1;
        return Math.sqrt(dx * dx + dy * dy);
}

function normalize(value) {
        return String(value || '').trim().toLowerCase();
}

function randomRange(min, max) {
        return min + Math.random() * (max - min);
}

function shuffle(array) {
        for (let i = array.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                const temp = array[i];
                array[i] = array[j];
                array[j] = temp;
        }
        return array;
}

function uniqueCells(cells) {
        const map = new Map();
        for (const cell of cells) {
                const key = `${Math.round(cell.x)}:${Math.round(cell.y)}`;
                if (!map.has(key)) {
                        map.set(key, { x: cell.x, y: cell.y });
                }
        }
        return Array.from(map.values());
}

function positiveMod(value, divisor) {
        if (divisor <= 0) {
                return 0;
        }
        const mod = value % divisor;
        return mod < 0 ? mod + divisor : mod;
}

module.exports = GameLogic;
