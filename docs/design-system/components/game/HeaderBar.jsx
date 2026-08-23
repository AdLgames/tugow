import React from 'react';
import { StatLabel } from '../core/StatLabel.jsx';
import { ThresholdBar } from '../core/ThresholdBar.jsx';

/* The header strip: wordmark, floor, score / threshold, the meter, boxes left. */
export function HeaderBar({ floor = 1, score = 0, threshold = 60, boxesLeft = 13, logo = null, style, ...rest }) {
  return (
    <div
      {...rest}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 'var(--space-20)',
        background: 'var(--tb-panel)',
        border: '1px solid var(--tb-panel-edge)',
        borderRadius: 'var(--radius-panel)',
        padding: 'var(--panel-pad-y) var(--panel-pad-x)',
        ...style,
      }}
    >
      {logo ? <img src={logo} alt="" width="24" height="24" style={{ display: 'block' }} /> : null}
      <span style={{ fontFamily: 'var(--font-display)', fontWeight: 'var(--weight-display-heavy)', fontSize: 'var(--text-title)', letterSpacing: 'var(--tracking-display)', textTransform: 'uppercase', color: 'var(--tb-ink)', whiteSpace: 'nowrap' }}>Thirteen Boxes</span>
      <StatLabel>Floor {floor}</StatLabel>
      <StatLabel>{score} / {threshold}</StatLabel>
      <ThresholdBar value={score} max={threshold} style={{ flex: 1 }} />
      <StatLabel tone={boxesLeft <= 4 ? 'var(--tb-adversary)' : undefined}>{boxesLeft} boxes left</StatLabel>
    </div>
  );
}
