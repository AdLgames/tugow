const { FloorScreen, TitleScreen, ForgeScreen, RunOverScreen } = window;

function App() {
  const [game, setGame] = React.useState(null);
  const [meta, setMeta] = React.useState({ runs: 0, deepest: 0, best: 0 });
  const push = (fn) => setGame((g) => { const next = { ...fn({ ...g }) }; return next; });

  const descend = () => {
    const g = window.TB.newRun();
    g.charms = [];
    setMeta((m) => ({ ...m, runs: m.runs + 1 }));
    setGame({ ...window.TB.beginFloor(g) });
  };

  const leaveForge = () => push((g) => window.TB.beginFloor(g));

  React.useEffect(() => {
    if (game && game.phase === 'over') {
      setMeta((m) => ({ runs: m.runs, deepest: Math.max(m.deepest, game.floor), best: Math.max(m.best, game.runTotal) }));
    }
  }, [game && game.phase]);

  return (
    <div style={{ position: 'relative', width: 'var(--size-viewport-w)', height: 'var(--size-viewport-h)', background: 'var(--surface-page)', overflow: 'hidden' }}>
      {game ? (
        <FloorScreen
          game={game}
          onRoll={() => push((g) => window.TB.rollTable(g, false))}
          onLock={(id) => push((g) => window.TB.lockDie(g, id))}
          onWrite={(box) => push((g) => window.TB.writeBox(g, box))}
        />
      ) : null}
      {!game ? <TitleScreen meta={meta} onDescend={descend} /> : null}
      {game && game.phase === 'forge' ? <ForgeScreen game={game} onOffer={(o) => push((g) => window.TB.applyForge(g, o))} onLeave={leaveForge} /> : null}
      {game && game.phase === 'over' ? <RunOverScreen game={game} onAgain={descend} /> : null}
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
