Every full-screen decision in the game is this one shell — there are no other modals.

```jsx
<Overlay title="The Forge">
  <OverlayText>The only currency is your scorecard. 9 boxes left.</OverlayText>
  <Button variant="overlay">{"Reshape a face — 1 box\nPull a die's weakest face up one pip."}</Button>
  <Button variant="overlay">Descend to floor 6</Button>
</Overlay>
```

Set `scrim={false}` to show the panel inside a card or specimen. Buttons are always `variant="overlay"` and stack full-width.
