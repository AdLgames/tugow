import React from 'react';

/* The centred modal: title, dim body text, a stack of overlay buttons. Ink edge,
   560px minimum, 10px separation. Title, forge, and run-over all use this one shell. */
export function Overlay({ title, children, scrim = true, style, ...rest }) {
  const panel = (
    <div
      {...rest}
      style={{
        minWidth: 'var(--size-overlay-w)',
        maxWidth: 640,
        background: 'var(--tb-panel)',
        border: '1px solid var(--tb-ink)',
        borderRadius: 'var(--radius-panel)',
        padding: 'var(--panel-pad-y) var(--panel-pad-x)',
        display: 'flex',
        flexDirection: 'column',
        gap: 'var(--space-10)',
        boxShadow: 'var(--shadow-overlay)',
        ...style,
      }}
    >
      <div style={{ fontFamily: 'var(--font-display)', fontWeight: 'var(--weight-display-heavy)', fontSize: 'var(--text-overlay-title)', letterSpacing: 'var(--tracking-display)', textTransform: 'uppercase', color: 'var(--tb-ink)' }}>{title}</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-6)' }}>{children}</div>
    </div>
  );
  if (!scrim) return panel;
  return (
    <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', background: 'var(--tb-scrim)', padding: 'var(--space-20)' }}>{panel}</div>
  );
}

/* The dim paragraph the overlay is mostly made of. */
export function OverlayText({ children, style, ...rest }) {
  return (
    <p {...rest} style={{ fontFamily: 'var(--font-body)', fontSize: 'var(--text-sm)', lineHeight: 'var(--leading-normal)', color: 'var(--tb-ink-dim)', ...style }}>{children}</p>
  );
}
