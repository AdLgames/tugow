Use for every clickable thing outside the dice and the scorecard rows.

```jsx
<Button variant="action" onClick={roll}>Reroll (2 left)</Button>
<Button variant="overlay" onClick={take}>{"Pull another die into the pool — 2 boxes\nThe pool grows to 9."}</Button>
```

Notes: `variant="overlay"` keeps line breaks (`white-space: pre-line`) because the forge writes label + detail as one two-line string. Disabled buttons dim slightly but keep their tone — unaffordable forge offers stay readable.
