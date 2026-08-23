Shows floor score against the floor's threshold. Always paired with a `StatLabel` reading `score / threshold`.

```jsx
<ThresholdBar value={265} max={385} />
```

Never show a percentage inside it — the source sets `show_percentage = false`.
