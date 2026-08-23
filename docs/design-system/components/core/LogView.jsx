import React from 'react';

/* RichTextLabel with scroll_following: the run's log, dim mono, newest last. */
export function LogView({ lines = [], style, ...rest }) {
  const ref = React.useRef(null);
  React.useEffect(() => { if (ref.current) ref.current.scrollTop = ref.current.scrollHeight; }, [lines.length]);
  return (
    <div
      {...rest}
      ref={ref}
      style={{
        fontFamily: 'var(--font-mono)',
        fontSize: 'var(--text-xs)',
        lineHeight: 'var(--leading-loose)',
        color: 'var(--tb-ink-dim)',
        overflowY: 'auto',
        display: 'flex',
        flexDirection: 'column',
        gap: '1px',
        ...style,
      }}
    >
      {lines.map((line, i) => (
        <div key={i} style={{ color: /^---/.test(line) ? 'var(--tb-ink)' : undefined }}>{line}</div>
      ))}
    </div>
  );
}
