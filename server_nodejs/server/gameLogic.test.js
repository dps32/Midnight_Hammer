'use strict';

const assert = require('node:assert/strict');
const GameLogic = require('./gameLogic.js');

function runTest(name, fn) {
        try {
                fn();
                console.log(`[PASS] ${name}`);
        } catch (error) {
                console.error(`[FAIL] ${name}`);
                console.error(error);
                process.exitCode = 1;
        }
}

function forceStartMatch(game) {
        game.waitingEndsAt = Date.now() - 1;
        game.updateGame(60);
        assert.equal(game.phase, 'playing');
}

runTest('waiting -> playing starts with 2 players', () => {
        const game = new GameLogic();
        game.addClient('P1');
        game.addClient('P2');
        assert.equal(game.phase, 'waiting');
        assert.notEqual(game.waitingEndsAt, null);

        forceStartMatch(game);
        const state = game.getGameplayState();
        assert.equal(state.phase, 'playing');
        assert.equal(state.aliveCount, 2);
});

runTest('joining during playing enters as spectator', () => {
        const game = new GameLogic();
        game.addClient('P1');
        game.addClient('P2');
        forceStartMatch(game);

        game.addClient('P3');
        const late = game.players.get('P3');
        assert.ok(late);
        assert.equal(late.alive, false);
        assert.equal(late.spectator, true);
});

runTest('disconnecting alive player during match can end game', () => {
        const game = new GameLogic();
        game.addClient('P1');
        game.addClient('P2');
        forceStartMatch(game);

        game.removeClient('P1');
        assert.equal(game.phase, 'finished');
        assert.equal(game.winnerId, 'P2');
});

runTest('dropPrimary leaves player unarmed and creates weapon loot', () => {
        const game = new GameLogic();
        game.addClient('P1');
        game.addClient('P2');
        forceStartMatch(game);

        const beforeLoot = game.loot.length;
        const changed = game.handleMessage(
                'P1',
                JSON.stringify({ type: 'action', name: 'dropPrimary' })
        );
        const player = game.players.get('P1');

        assert.equal(changed, true);
        assert.ok(player);
        assert.equal(player.primaryWeapon, null);
        assert.equal(game.loot.length, beforeLoot + 1);
        assert.equal(game.loot.at(-1).kind, 'weapon');
});

runTest('consumables stack and occupy first free slot 2..9', () => {
        const game = new GameLogic();
        game.addClient('P1');
        game.addClient('P2');
        forceStartMatch(game);

        const player = game.players.get('P1');
        assert.ok(player);

        assert.equal(game.addConsumable(player, 'grenade', 1), true);
        assert.equal(game.addConsumable(player, 'grenade', 2), true);
        assert.equal(game.addConsumable(player, 'drone', 1), true);

        const inv = Array.from(player.inventorySlots.entries()).sort((a, b) => a[0] - b[0]);
        assert.equal(inv[0][0], 2);
        assert.equal(inv[0][1].type, 'grenade');
        assert.equal(inv[0][1].count, 3);
        assert.equal(inv[1][0], 3);
        assert.equal(inv[1][1].type, 'drone');
});
