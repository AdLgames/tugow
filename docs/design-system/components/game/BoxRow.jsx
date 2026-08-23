import React from 'react';

/* One row of the thirteen. Open rows show a live preview or 'scratch'; spent
   rows show the state tag and the points, tinted by who owns them. A declared
   box is marked '>' and turns declared-orange for exactly one turn. */
export function BoxRow({ name, rule, state = 'open', points = 0, preview = null, declared = false, disabled = false, onClick, style, ...rest }) {
  const tones = { open: 'var(--tb-open)', player: 'var(--tb-player)', adversary: 'var(--tb-adversary)', burned: 'var(--tb-burned)' };
  const tone = declared && state === 'open' ? 'var(--tb-declared)' : tones[state];
  const tags = { open: 'open', player: 'you', adversary: 'them', burned: 'burned' };
  const open = state === 'open';
  const clickable = open && !disabled;
  return (
    <button
      {...rest}
      disabled={!clickable}
      onClick={clickable ? onClick : undefined}
      style={{
        display: 'grid',
        gridTemplateColumns: '10px minmax(0,var(--size-box-label-w)) var(--size-box-value-w)',
        alignItems: 'center',
        gap: 'var(--space-6)',
        width: '100%',
        minHeight: 'var(--size-box-row-h)',
        padding: '0 var(--space-6)',
        textAlign: 'left',
        background: declared && open ? 'var(--tb-declared-wash)' : state === 'adversary' ? 'var(--tb-adversary-wash)' : 'transparent',
        border: '1px solid ' + (declared && open ? 'var(--tb-declared)' : 'transparent'),
        borderRadius: 'var(--radius-control)',
        color: tone,
        cursor: clickable ? 'pointer' : 'default',
        transition: 'background var(--motion-fast) linear',
        ...style,
      }}
    >
      <span style={{ fontFamily: 'var(--font-mono)', color: 'var(--tb-declared)' }}>{declared && open ? '>' : ''}</span>
      <span style={{ display: 'flex', alignItems: 'baseline', gap: 'var(--space-6)', minWidth: 0 }}>
        <span style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--text-sm)', letterSpacing: 'var(--tracking-caps)', textTransform: 'uppercase', whiteSpace: 'nowrap' }}>{name}</span>
        <span style={{ fontFamily: 'var(--font-body)', fontSize: 'var(--text-xs)', color: open ? 'var(--tb-ink-dim)' : 'inherit', opacity: open ? 1 : 0.7, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{rule}</span>
      </span>
      <span style={{ fontFamily: 'var(--font-mono)', fontSize: 'var(--text-sm)', fontVariantNumeric: 'tabular-nums', textAlign: 'right', color: open ? (preview ? 'var(--tb-ink)' : 'var(--tb-burned)') : tone }}>
        {open ? (preview ? preview : 'scratch') : tags[state] + ' ' + points}
      </span>
    </button>
  );
}
