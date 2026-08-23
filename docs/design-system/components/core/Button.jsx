import React from 'react';

/* Godot Buttons, as the game configures them. Three shapes exist in the source:
   'action' (Roll — 200x42, centred), 'overlay' (34px tall, left-aligned, wraps),
   and 'row' (the scorecard box rows). Disabled keeps its font colour rather than
   fading — main.gd sets font_disabled_color to the same value on purpose. */
export function Button({ variant = 'action', tone, disabled, style, children, ...rest }) {
  const base = {
    fontFamily: 'var(--font-display)',
    fontWeight: 'var(--weight-display)',
    letterSpacing: 'var(--tracking-caps)',
    fontSize: 'var(--text-base)',
    background: 'var(--surface-raised)',
    color: tone || 'var(--tb-ink)',
    border: '1px solid var(--tb-panel-edge)',
    borderRadius: 'var(--radius-control)',
    cursor: disabled ? 'default' : 'pointer',
    opacity: disabled ? 0.7 : 1,
    transition: 'background var(--motion-fast) linear, border-color var(--motion-fast) linear',
  };
  const shapes = {
    action: { minWidth: 'var(--size-roll-btn-w)', height: 'var(--size-roll-btn-h)', textTransform: 'uppercase', padding: '0 var(--space-16)' },
    overlay: { fontFamily: 'var(--font-body)', fontWeight: 'var(--weight-body-strong)', minHeight: 'var(--size-overlay-btn-h)', width: '100%', textAlign: 'left', padding: 'var(--space-6) var(--space-10)', whiteSpace: 'pre-line', letterSpacing: 'var(--tracking-normal)' },
    row: { fontFamily: 'var(--font-body)', minHeight: 'var(--size-box-row-h)', width: '100%', textAlign: 'left', padding: '0 var(--space-6)', letterSpacing: 'var(--tracking-normal)' },
  };
  return (
    <button
      {...rest}
      disabled={disabled}
      data-tb-button={variant}
      style={{ ...base, ...shapes[variant], ...style }}
    >
      {children}
    </button>
  );
}
