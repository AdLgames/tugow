import React from 'react';

/* ProgressBar, 140x18, no percentage text. Fills with ink; the game never
   colours it by success — the numbers beside it carry that. */
export function ThresholdBar({ value = 0, max = 1, tone = 'var(--tb-ink)', style, ...rest }) {
  const pct = Math.max(0, Math.min(1, value / Math.max(1, max))) * 100;
  return (
    <div
      {...rest}
      role="progressbar"
      aria-valuenow={value}
      aria-valuemax={max}
      style={{
        minWidth: 'var(--size-progress-w)',
        height: 'var(--size-progress-h)',
        background: 'var(--tb-background)',
        border: '1px solid var(--tb-panel-edge)',
        borderRadius: 'var(--radius-control)',
        overflow: 'hidden',
        ...style,
      }}
    >
      <div style={{ width: pct + '%', height: '100%', background: tone, transition: 'width var(--motion-base) linear' }} />
    </div>
  );
}
