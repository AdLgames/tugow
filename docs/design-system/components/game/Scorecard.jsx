import React from 'react';
import { BoxRow } from './BoxRow.jsx';

/* THE CARD. Thirteen rows, 2px apart, in a panel. The card is the health bar,
   so it never resets between floors. */
export const BOXES = [
  { name: 'Aces', rule: 'Sum of 1s x 1' },
  { name: 'Twos', rule: 'Sum of 2s x 2' },
  { name: 'Threes', rule: 'Sum of 3s x 3' },
  { name: 'Fours', rule: 'Sum of 4s x 4' },
  { name: 'Fives', rule: 'Sum of 5s x 5' },
  { name: 'Sixes', rule: 'Sum of 6s x 6' },
  { name: 'Three of a Kind', rule: 'Sum of all five x 3' },
  { name: 'Four of a Kind', rule: 'Quad face cubed x 5' },
  { name: 'Full House', rule: 'Triple x pair x 10' },
  { name: 'Small Straight', rule: 'Span (max 4) x highest x 5' },
  { name: 'Large Straight', rule: 'Product of all five' },
  { name: 'Yahtzee', rule: 'Face to the fourth x 2' },
  { name: 'Chance', rule: 'Sum, doubled per 6' },
];

export function Scorecard({ boxes = BOXES, states = [], points = [], previews = [], declared = -1, disabled = false, onWrite, style, ...rest }) {
  return (
    <div
      {...rest}
      style={{
        background: 'var(--tb-panel)',
        border: '1px solid var(--tb-panel-edge)',
        borderRadius: 'var(--radius-panel)',
        padding: 'var(--panel-pad-y) var(--panel-pad-x)',
        minWidth: 'var(--size-card-col)',
        display: 'flex',
        flexDirection: 'column',
        gap: 'var(--space-2)',
        ...style,
      }}
    >
      <div className="tb-heading" style={{ marginBottom: 'var(--space-6)' }}>The Card</div>
      {boxes.map((b, i) => (
        <BoxRow
          key={b.name}
          name={b.name}
          rule={b.rule}
          state={states[i] || 'open'}
          points={points[i] || 0}
          preview={previews[i] ?? null}
          declared={i === declared}
          disabled={disabled}
          onClick={onWrite ? () => onWrite(i) : undefined}
        />
      ))}
    </div>
  );
}
