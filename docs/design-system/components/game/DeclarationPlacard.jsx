import React from 'react';

/* The chit the Adversary slides onto the felt when it announces its target box.
   Physical object, not a corner label: the announcement is the tactical layer, so it
   sits on the table where the dice are. 320x180. */
export function DeclarationPlacard({ box, rule, adversary, tilt = -3, style, ...rest }) {
  return (
    <div
      {...rest}
      style={{
        position: 'relative',
        width: 320,
        height: 180,
        transform: 'rotate(' + tilt + 'deg)',
        borderRadius: 4,
        padding: '16px 18px',
        display: 'flex',
        flexDirection: 'column',
        gap: 6,
        background: 'linear-gradient(168deg,#e2d3b0,#c4b48f 62%,#a3937158)',
        boxShadow: 'inset 0 2px 0 #fff8, inset 0 -10px 22px #2b201366, 0 18px 30px #000000b3, 0 0 0 1px #00000073',
        color: '#191420',
        fontFamily: 'var(--font-body)',
      }}
    >
      <div style={{ position: 'absolute', inset: 6, border: '1px solid #8e2f2259', borderRadius: 2, pointerEvents: 'none' }} />
      <div style={{ fontFamily: 'var(--font-mono)', fontSize: 11, letterSpacing: '.14em', textTransform: 'uppercase', color: '#8e2f22' }}>
        {adversary ? adversary + ' announces' : 'Announced'}
      </div>
      <div style={{ fontFamily: 'var(--font-display)', fontWeight: 900, fontSize: 26, letterSpacing: '.08em', textTransform: 'uppercase', lineHeight: 1.05, color: '#241c14' }}>
        {box}
      </div>
      <div style={{ fontSize: 13, color: '#191420b3' }}>{rule}</div>
      <div style={{ marginTop: 'auto', fontFamily: 'var(--font-mono)', fontSize: 11, color: '#191420a6' }}>
        One turn to deny it.
      </div>
    </div>
  );
}
