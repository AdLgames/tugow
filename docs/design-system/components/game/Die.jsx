import React from 'react';

/* DieView — one die on the table, 92x104. Click locks it for the whole floor.
   Text is name / value / tags, exactly as die_view.gd composes it. Tint follows
   the die's condition: gold when locked, purple when bitter, ink otherwise.
   Locked dice are disabled but keep their tint (font_disabled_color is set to
   the same colour on purpose). */
export function Die({ name, value = 0, locked = false, bitter = false, repeated = false, faceted = false, owner = 'player', onClick, style, ...rest }) {
  const tags = [];
  if (locked) tags.push('LOCKED');
  if (bitter) tags.push('bitter');
  if (repeated) tags.push('again');
  if (faceted) tags.push('faceted');
  const tint = locked ? 'var(--tb-locked)' : bitter ? 'var(--tb-bitter)' : 'var(--tb-ink)';
  const disabled = locked || value === 0;
  return (
    <button
      {...rest}
      disabled={disabled}
      onClick={disabled ? undefined : onClick}
      title={name + ' — ' + (bitter ? 'bitter: refuses its lowest face.' : 'faces 1-6')}
      style={{
        width: 'var(--size-die-w)',
        height: 'var(--size-die-h)',
        display: 'grid',
        gridTemplateRows: 'auto 1fr auto',
        alignItems: 'center',
        gap: 'var(--space-2)',
        padding: 'var(--space-6)',
        background: locked ? 'var(--tb-locked-wash)' : owner === 'adversary' ? 'var(--tb-adversary-wash)' : 'var(--surface-raised)',
        border: '1px solid ' + (locked ? 'var(--tb-locked)' : bitter ? 'var(--tb-bitter)' : 'var(--tb-panel-edge)'),
        borderRadius: 'var(--radius-control)',
        color: tint,
        cursor: disabled ? 'default' : 'pointer',
        transition: 'border-color var(--motion-fast) linear, background var(--motion-fast) linear',
        ...style,
      }}
    >
      <span style={{ fontFamily: 'var(--font-display)', fontSize: 'var(--text-xs)', letterSpacing: 'var(--tracking-caps)', textTransform: 'uppercase', opacity: 0.9 }}>{name}</span>
      <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 'var(--text-die-value)', lineHeight: 1 }}>{value === 0 ? '—' : value}</span>
      <span style={{ fontFamily: 'var(--font-mono)', fontSize: '10px', letterSpacing: '.04em', color: locked ? 'var(--tb-locked)' : 'var(--tb-ink-dim)', minHeight: '12px' }}>{tags.join(' ')}</span>
    </button>
  );
}
