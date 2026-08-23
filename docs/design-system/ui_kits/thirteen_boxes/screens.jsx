const { Panel, Button, StatLabel, LogView, Die, Scorecard, AdversaryPanel, Overlay, OverlayText, HeaderBar } = window.ThirteenBoxesDesignSystem_2f8d07;

/* THE TABLE — dice centred, Roll under them, hint under that. Two spacers
   above and below keep the row vertically centred exactly as main.gd does. */
function TablePanel({ game, onRoll, onLock }) {
  const hint = game.adversary && game.declared >= 0
    ? 'Deny it by taking ' + window.TB.BOXES[game.declared].name + ' yourself, or outpace it — you need ' + Math.max(0, game.thresholdValue - game.floorScore) + ' more.'
    : 'Writing a box ends the turn and spends it for the rest of the run. ' + Math.max(0, game.thresholdValue - game.floorScore) + ' more to clear.';
  return (
    <Panel style={{ flex: '1.4 1 0', display: 'flex', flexDirection: 'column', gap: 'var(--space-10)' }}>
      <div className="tb-heading">The Table — click a die to lock it for the floor</div>
      <div style={{ flex: 1 }} />
      <div style={{ display: 'flex', gap: 'var(--space-8)', justifyContent: 'center' }}>
        {game.table.map((id) => {
          const d = game.dice[id];
          return <Die key={id} name={d.name} value={d.value} locked={d.locked} bitter={d.bitter} repeated={d.repeated} owner={d.owner} onClick={() => onLock(id)} />;
        })}
      </div>
      <div style={{ display: 'flex', justifyContent: 'center', gap: 'var(--space-12)' }}>
        <Button variant="action" disabled={game.rerolls <= 0} onClick={onRoll}>
          {game.rerolls > 0 ? 'Reroll (' + game.rerolls + ' left)' : 'No rerolls'}
        </Button>
      </div>
      <p style={{ minHeight: 44, textAlign: 'center', fontSize: 'var(--text-sm)', color: 'var(--tb-ink-dim)', textWrap: 'pretty' }}>{hint}</p>
      <div style={{ flex: 1 }} />
    </Panel>
  );
}

/* The side column: adversary, charms, log. */
function SideColumn({ game }) {
  return (
    <div style={{ flex: '0.85 1 0', minWidth: 'var(--size-side-col)', display: 'flex', flexDirection: 'column', gap: 'var(--space-10)' }}>
      <AdversaryPanel
        name={game.adversary ? game.adversary.name : undefined}
        blurb={game.adversary ? game.adversary.blurb : undefined}
        announced={game.declared >= 0 ? window.TB.BOXES[game.declared].name : 'nothing'}
        score={game.adversaryScore}
        boxesTaken={window.TB.adversaryCount(game)}
      />
      <Panel>
        <div style={{ fontSize: 'var(--text-xs)', color: 'var(--tb-ink-dim)' }}>Charms: {game.charms && game.charms.length ? game.charms.join(', ') : 'none yet'}</div>
      </Panel>
      <Panel style={{ flex: 1, minHeight: 0, display: 'flex' }}>
        <LogView lines={game.log} style={{ flex: 1 }} />
      </Panel>
    </div>
  );
}

function FloorScreen({ game, onRoll, onLock, onWrite }) {
  return (
    <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', gap: 'var(--space-10)', padding: 'var(--screen-pad-y) var(--screen-pad-x)' }}>
      <HeaderBar floor={game.floor} score={game.floorScore} threshold={game.thresholdValue} boxesLeft={window.TB.openCount(game)} logo="../../assets/logo.svg" />
      <div style={{ flex: 1, minHeight: 0, display: 'flex', gap: 'var(--space-12)' }}>
        <Scorecard
          style={{ flex: '0.95 1 0', overflow: 'hidden' }}
          states={game.states}
          points={game.points}
          previews={window.TB.previews(game)}
          declared={game.declared}
          disabled={game.phase !== 'floor'}
          onWrite={onWrite}
        />
        <TablePanel game={game} onRoll={onRoll} onLock={onLock} />
        <SideColumn game={game} />
      </div>
    </div>
  );
}

function TitleScreen({ meta, onDescend }) {
  return (
    <Overlay title="Thirteen Boxes">
      <OverlayText>A dice roguelike where the scorecard is your health bar.</OverlayText>
      <OverlayText>Thirteen boxes. Every turn spends one, permanently, for the rest of the run. Clear a floor fast and you carry the rest forward.</OverlayText>
      <OverlayText>Locked is locked for the whole floor, not the turn.</OverlayText>
      <StatLabel>Runs: {meta.runs}   Deepest floor: {meta.deepest}   Best total: {meta.best}</StatLabel>
      <Button variant="overlay" onClick={onDescend}>Descend</Button>
    </Overlay>
  );
}

function ForgeScreen({ game, onOffer, onLeave }) {
  const open = window.TB.openCount(game);
  return (
    <Overlay title="The Forge">
      <OverlayText>The only currency is your scorecard. {open} boxes left.</OverlayText>
      {window.TB.FORGE.map((offer) => (
        <Button key={offer.id} variant="overlay" disabled={open - offer.cost < 1} onClick={() => onOffer(offer)}>
          {offer.label + ' — ' + offer.cost + (offer.cost === 1 ? ' box' : ' boxes') + '\n' + offer.detail}
        </Button>
      ))}
      <Button variant="overlay" onClick={onLeave}>Descend to floor {game.floor + 1}</Button>
    </Overlay>
  );
}

function RunOverScreen({ game, onAgain }) {
  return (
    <Overlay title={game.won ? 'You walked out.' : 'The run ends.'}>
      <OverlayText>{game.reason}</OverlayText>
      <StatLabel>Run total: {game.runTotal}   Floors: {game.floor}</StatLabel>
      <Button variant="overlay" onClick={onAgain}>Again</Button>
    </Overlay>
  );
}

Object.assign(window, { TablePanel, SideColumn, FloorScreen, TitleScreen, ForgeScreen, RunOverScreen });
