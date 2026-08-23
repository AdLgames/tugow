Flat bordered surface used for every region of the interface — header, scorecard, table, side column, overlay.

```jsx
<Panel edge="adversary">
  <h3 className="tb-heading" style={{ color: 'var(--tb-adversary)' }}>THE MAGPIE</h3>
</Panel>
```

Variants: `edge` picks the border colour — `default` for neutral regions, `adversary` for the duel panel, `ink` for the modal overlay. Never add a drop shadow; the game has none.
