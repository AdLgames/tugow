import React from 'react';

/* _stat_label(): a dim mono readout in the header row. */
export function StatLabel({ children, tone = 'var(--tb-ink-dim)', style, ...rest }) {
  return (
    <span
      {...rest}
      style={{
        fontFamily: 'var(--font-mono)',
        fontSize: 'var(--text-sm)',
        fontVariantNumeric: 'tabular-nums',
        color: tone,
        whiteSpace: 'nowrap',
        ...style,
      }}
    >
      {children}
    </span>
  );
}
