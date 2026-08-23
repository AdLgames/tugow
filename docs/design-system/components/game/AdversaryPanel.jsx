import React from 'react';
import { Panel } from '../core/Panel.jsx';

/* The duel panel: red-edged, name in adversary red, blurb dim, status in ink.
   It announces its target box before rolling — that line is the whole fight. */
export function AdversaryPanel({ name, blurb, announced = 'nothing', score = 0, boxesTaken = 0, boxLimit = 7, style, ...rest }) {
  if (!name) {
    return (
      <Panel {...rest} style={style}>
        <div style={{ fontFamily: 'var(--font-display)', letterSpacing: 'var(--tracking-caps)', color: 'var(--tb-adversary)', fontSize: 'var(--text-sm)' }}>No adversary on this floor.</div>
      </Panel>
    );
  }
  return (
    <Panel {...rest} edge="adversary" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-6)', ...style }}>
      <div style={{ fontFamily: 'var(--font-display)', fontWeight: 'var(--weight-display-heavy)', letterSpacing: 'var(--tracking-display)', textTransform: 'uppercase', color: 'var(--tb-adversary)', fontSize: 'var(--text-lg)' }}>{name}</div>
      <div style={{ fontFamily: 'var(--font-body)', fontSize: 'var(--text-xs)', lineHeight: 'var(--leading-normal)', color: 'var(--tb-ink-dim)' }}>{blurb}</div>
      <div style={{ fontFamily: 'var(--font-mono)', fontSize: 'var(--text-xs)', lineHeight: 'var(--leading-loose)', color: 'var(--tb-ink)' }}>
        <div>Announced: <span style={{ color: 'var(--tb-declared)' }}>{announced}</span></div>
        <div>Its score: {score}   Boxes taken: {boxesTaken}/{boxLimit}</div>
      </div>
    </Panel>
  );
}
