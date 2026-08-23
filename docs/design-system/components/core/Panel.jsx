import React from 'react';

/* PanelContainer + ThemeColors.panel_style(). 1px edge, 4px corners,
   10px side / 8px vertical content margins. The edge colour is the only knob. */
export function Panel({ edge = 'default', pad = true, as: Tag = 'div', style, children, ...rest }) {
  const edges = {
    default: 'var(--tb-panel-edge)',
    adversary: 'var(--tb-adversary)',
    ink: 'var(--tb-ink)',
    player: 'var(--tb-player)',
    locked: 'var(--tb-locked)',
  };
  return (
    <Tag
      {...rest}
      style={{
        background: 'var(--tb-panel)',
        border: '1px solid ' + (edges[edge] || edge),
        borderRadius: 'var(--radius-panel)',
        padding: pad ? 'var(--panel-pad-y) var(--panel-pad-x)' : 0,
        color: 'var(--text-body)',
        ...style,
      }}
    >
      {children}
    </Tag>
  );
}
