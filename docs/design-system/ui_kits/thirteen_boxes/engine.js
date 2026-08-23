/* Thirteen Boxes — cosmetic recreation of the run loop.
   Scoring mirrors scripts/core/scoring.gd on the committed TEMPERED curve;
   floors, thresholds, duel floors and reclaim mirror scripts/autoload/balance.gd.
   Simplified: no charms engine, no facets, one adversary behaviour per roster entry. */
window.TB = (function () {
  const BOXES = [
    ['Aces', 'Sum of 1s x 1'], ['Twos', 'Sum of 2s x 2'], ['Threes', 'Sum of 3s x 3'],
    ['Fours', 'Sum of 4s x 4'], ['Fives', 'Sum of 5s x 5'], ['Sixes', 'Sum of 6s x 6'],
    ['Three of a Kind', 'Sum of all five x 3'], ['Four of a Kind', 'Quad face cubed x 5'],
    ['Full House', 'Triple x pair x 10'], ['Small Straight', 'Span (max 4) x highest x 5'],
    ['Large Straight', 'Product of all five'], ['Yahtzee', 'Face to the fourth x 2'],
    ['Chance', 'Sum, doubled per 6'],
  ].map(([name, rule]) => ({ name, rule }));

  const DIE_NAMES = ['Ash', 'Bramble', 'Cinder', 'Dovetail', 'Ember', 'Flint', 'Gallows', 'Hollow'];

  const ROSTER = {
    3: { name: 'The Auditor', blurb: 'Claims only upper-section boxes, methodically, low to high. Slow and honest. Brutal if ignored.' },
    5: { name: 'The Magpie', blurb: 'Always targets whichever box you are building toward. Reads your locks. Punishes telegraphing.' },
    7: { name: 'The Twin', blurb: 'Rolls whatever you rolled last turn. Beat it by playing badly.' },
    9: { name: 'The Magpie', blurb: 'Always targets whichever box you are building toward. Reads your locks. Punishes telegraphing.' },
    10: { name: 'The Furnace', blurb: 'Does not claim boxes. Burns one per turn, unscored, gone. Pure clock. Cannot be denied, only outrun.' },
    11: { name: 'The Twin', blurb: 'Rolls whatever you rolled last turn. Beat it by playing badly.' },
    12: { name: 'The Debtor', blurb: 'Scores into boxes you have already filled, overwriting them. Your best score is never safe.' },
  };

  const counts = (v) => v.reduce((m, x) => (m[x] = (m[x] || 0) + 1, m), {});
  const sum = (v) => v.reduce((a, b) => a + b, 0);
  const product = (v) => v.reduce((a, b) => a * b, 1);
  const faceWithAtLeast = (c, n) => Math.max(0, ...Object.keys(c).filter((f) => c[f] >= n).map(Number));

  function longestRun(c) {
    const faces = Object.keys(c).map(Number).sort((a, b) => a - b);
    let best = [], cur = [];
    for (const f of faces) {
      cur = cur.length && f === cur[cur.length - 1] + 1 ? cur.concat(f) : [f];
      if (cur.length > best.length) best = cur.slice();
    }
    return best;
  }

  function score(box, values) {
    if (!values.length) return 0;
    const c = counts(values);
    if (box <= 5) { const face = box + 1; return (c[face] || 0) * face * face; }
    if (box === 6) return Math.max(0, ...Object.values(c)) < 3 ? 0 : sum(values) * 3;
    if (box === 7) { const q = faceWithAtLeast(c, 4); return q ? Math.pow(q, 3) * 5 : 0; }
    if (box === 8) {
      const faces = Object.keys(c).map(Number).sort((a, b) => b - a);
      const triple = faces.find((f) => c[f] >= 3);
      if (!triple) return 0;
      let pair = Math.max(0, ...faces.filter((f) => f !== triple && c[f] >= 2));
      if (!pair && c[triple] >= 5) pair = triple;
      return pair ? triple * pair * 10 : 0;
    }
    if (box === 9) { const r = longestRun(c); return r.length < 4 ? 0 : Math.min(r.length, 4) * r[r.length - 1] * 5; }
    if (box === 10) return longestRun(c).length < 5 ? 0 : product(values);
    if (box === 11) { const f = faceWithAtLeast(c, 5); return f ? Math.pow(f, 4) * 2 : 0; }
    if (box === 12) return values.filter((v) => v === 6).reduce((t) => t * 2, sum(values));
    return 0;
  }

  const threshold = (n) => Math.round(60 * Math.pow(1.45, n - 1));
  const isDuelFloor = (n) => [3, 5, 7, 9, 10, 11, 12].includes(n);

  function newRun() {
    return {
      floor: 0, thresholdValue: 0, floorScore: 0, turn: 0, rerolls: 2,
      dice: DIE_NAMES.map((name, id) => ({ id, name, value: 0, locked: false, bitter: false, repeated: false, owner: 'player' })),
      table: [], states: BOXES.map(() => 'open'), points: BOXES.map(() => 0),
      spendOrder: [], runTotal: 0, adversary: null, declared: -1, adversaryScore: 0,
      phase: 'floor', log: ['Thirteen boxes. Spend them carefully.'], lastValues: [],
    };
  }

  const openBoxes = (g) => g.states.reduce((a, s, i) => (s === 'open' ? a.concat(i) : a), []);
  const openCount = (g) => openBoxes(g).length;
  const adversaryCount = (g) => g.states.filter((s) => s === 'adversary').length;

  function logLine(g, line) { g.log = g.log.concat(line).slice(-200); }

  function beginFloor(g) {
    g.floor += 1;
    g.thresholdValue = threshold(g.floor);
    g.floorScore = 0; g.turn = 0; g.declared = -1; g.adversaryScore = 0;
    g.dice.forEach((d) => { d.locked = false; d.value = 0; d.repeated = false; d.owner = 'player'; });
    g.adversary = isDuelFloor(g.floor) ? ROSTER[g.floor] || ROSTER[12] : null;
    logLine(g, '--- Floor ' + g.floor + ' — threshold ' + g.thresholdValue + ' ---');
    if (g.adversary) {
      logLine(g, g.adversary.name + ' steps up to the card. ' + g.adversary.blurb);
      declare(g);
    }
    g.phase = 'floor';
    beginTurn(g);
    return g;
  }

  function beginTurn(g) {
    g.turn += 1; g.rerolls = 2;
    const locked = g.dice.filter((d) => d.locked && d.owner === 'player');
    const free = g.dice.filter((d) => !d.locked).sort(() => Math.random() - 0.5);
    g.table = locked.concat(free.slice(0, Math.max(0, 5 - locked.length))).map((d) => d.id);
    rollTable(g, true);
  }

  function rollTable(g, first) {
    if (!first) { if (g.rerolls <= 0) return g; g.rerolls -= 1; }
    g.table.forEach((id) => {
      const d = g.dice[id];
      if (d.locked) return;
      let v = 1 + Math.floor(Math.random() * 6);
      if (d.bitter) { const a = 1 + Math.floor(Math.random() * 6); v = Math.max(v, a); if (v === 1) v = 2; }
      d.repeated = v === d.value && d.value !== 0;
      d.value = v;
    });
    logLine(g, 'Roll: ' + g.table.map((id) => g.dice[id].name + ': ' + g.dice[id].value + (g.dice[id].locked ? ' (locked)' : '')).join(' | '));
    return g;
  }

  function lockDie(g, id) {
    const d = g.dice[id];
    if (d.locked || d.value === 0) return g;
    d.locked = true; d.owner = 'player';
    logLine(g, 'Locked ' + d.name + ' on ' + d.value + ' for the floor.');
    return g;
  }

  const tableValues = (g) => g.table.map((id) => g.dice[id].value);
  const previews = (g) => g.states.map((s, i) => (s === 'open' ? score(i, tableValues(g)) : null));

  function writeBox(g, box) {
    if (g.states[box] !== 'open') return g;
    const values = tableValues(g);
    const value = score(box, values);
    const denied = g.declared === box;
    g.lastValues = values.slice();
    g.states[box] = 'player'; g.points[box] = value;
    g.spendOrder.push(box); g.runTotal += value; g.floorScore += value;
    if (denied) logLine(g, 'Denied: You took ' + BOXES[box].name + ' out of ' + g.adversary.name + "'s hands.");
    if (value === 0) {
      logLine(g, 'Scratched ' + BOXES[box].name + '. A hole for the rest of the run.');
      g.table.forEach((id) => { const d = g.dice[id]; if (d.locked && !d.bitter) { d.bitter = true; logLine(g, d.name + ' turns bitter.'); } });
    } else {
      logLine(g, BOXES[box].name + ' for ' + value + '. (floor ' + g.floorScore + '/' + g.thresholdValue + ')');
    }
    return afterPlayerTurn(g);
  }

  function afterPlayerTurn(g) {
    if (g.floorScore >= g.thresholdValue) return clearFloor(g);
    if (!openCount(g)) return endRun(g, false, 'The card is full on floor ' + g.floor + '.');
    if (g.adversary) {
      adversaryTurn(g);
      if (g.phase === 'over') return g;
      if (!openCount(g)) return endRun(g, false, 'The card is full on floor ' + g.floor + '.');
    }
    beginTurn(g);
    return g;
  }

  function declare(g) {
    const options = openBoxes(g);
    if (!options.length) { g.declared = -1; return; }
    if (g.adversary.name === 'The Auditor') g.declared = options.find((b) => b <= 5) ?? options[0];
    else if (g.adversary.name === 'The Magpie') {
      const read = g.dice.filter((d) => d.locked).map((d) => d.value).concat(g.lastValues).slice(0, 5);
      g.declared = options.reduce((best, b) => (score(b, read) > score(best, read) ? b : best), options[0]);
    } else g.declared = options.reduce((best, b) => (b > best ? b : best), options[0]);
    logLine(g, g.adversary.name + ' announces: ' + BOXES[g.declared].name + '.');
  }

  function adversaryTurn(g) {
    const box = g.states[g.declared] === 'open' ? g.declared : openBoxes(g)[0];
    if (box === undefined) return;
    if (g.adversary.name === 'The Furnace') {
      g.states[box] = 'burned'; g.points[box] = 0;
      logLine(g, 'The Furnace burns ' + BOXES[box].name + ' to ash.');
    } else {
      const values = Array.from({ length: 5 }, () => 1 + Math.floor(Math.random() * 6));
      const value = score(box, values);
      g.states[box] = 'adversary'; g.points[box] = value; g.adversaryScore += value;
      logLine(g, g.adversary.name + ' takes ' + BOXES[box].name + ' with [' + values.join(', ') + '] for ' + value + '.');
    }
    if (adversaryCount(g) >= 7) return endRun(g, false, g.adversary.name + ' claimed seven boxes. It takes the card.');
    declare(g);
  }

  function clearFloor(g) {
    if (g.adversary) {
      if (g.floorScore > g.adversaryScore) {
        let back = 0;
        for (let i = g.spendOrder.length - 1; i >= 0 && back < 3; i -= 1) {
          const b = g.spendOrder[i];
          if (g.states[b] === 'player') { g.states[b] = 'open'; g.spendOrder.splice(i, 1); back += 1; }
        }
        logLine(g, 'You out-scored ' + g.adversary.name + ', ' + g.floorScore + ' to ' + g.adversaryScore + '. ' + back + ' boxes come back.');
      } else {
        logLine(g, g.adversary.name + ' out-scored you, ' + g.adversaryScore + ' to ' + g.floorScore + '. The burned boxes stay burned.');
      }
    }
    logLine(g, 'Floor ' + g.floor + ' cleared in ' + g.turn + ' turns. ' + openCount(g) + ' boxes left.');
    if (g.floor >= 12) return endRun(g, true, 'Twelve floors down with ' + openCount(g) + ' boxes to spare.');
    g.phase = 'forge';
    return g;
  }

  function endRun(g, won, reason) {
    g.phase = 'over'; g.won = won; g.reason = reason;
    logLine(g, reason);
    logLine(g, 'Run total: ' + g.runTotal + ' over ' + g.floor + ' floors.');
    return g;
  }

  const FORGE = [
    { id: 'reshape_face', label: 'Reshape a face', detail: "Pull a die's weakest face up one pip.", cost: 1 },
    { id: 'ninth_die', label: 'Pull another die into the pool', detail: 'The pool grows to 9.', cost: 2 },
    { id: 'cleanse_bitter', label: 'Cleanse a bitter die', detail: 'It rolls honestly again.', cost: 1 },
    { id: 'overwrite_box', label: 'Overwrite a box you hate', detail: 'Reopen a box you already filled; its points leave the run total.', cost: 1 },
    { id: 'take_charm', label: 'Take the charm: Grudge', detail: 'A die that rolls a 1 is furious next turn: +2 to every face.', cost: 1 },
  ];

  function applyForge(g, offer) {
    const open = openBoxes(g);
    if (open.length - offer.cost < 1) return g;
    for (let i = 0; i < offer.cost; i += 1) {
      const box = open[open.length - 1 - i];
      g.states[box] = 'burned';
      logLine(g, 'Forge takes ' + BOXES[box].name + '. ' + (openCount(g)) + ' boxes left.');
    }
    if (offer.id === 'ninth_die') {
      g.dice.push({ id: g.dice.length, name: 'Ivory', value: 0, locked: false, bitter: false, repeated: false, owner: 'player' });
      logLine(g, 'Forge: Ivory joins the pool (' + g.dice.length + ' dice).');
    }
    if (offer.id === 'cleanse_bitter') { const d = g.dice.find((x) => x.bitter); if (d) { d.bitter = false; logLine(g, 'Forge: ' + d.name + ' is cleansed.'); } }
    if (offer.id === 'take_charm') logLine(g, 'Charm taken: Grudge — a die that rolls a 1 is furious next turn: +2 to every face.');
    if (offer.id === 'reshape_face') logLine(g, 'Forge: Ash reshaped to [2, 2, 3, 4, 5, 6].');
    return g;
  }

  return { BOXES, DIE_NAMES, ROSTER, FORGE, score, threshold, isDuelFloor, newRun, beginFloor, beginTurn, rollTable, lockDie, writeBox, previews, tableValues, openCount, adversaryCount, applyForge, openBoxes };
})();
