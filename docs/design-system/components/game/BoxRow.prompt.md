A single scorecard line. Use inside `Scorecard`, not standalone.

```jsx
<BoxRow name="Sixes" rule="Sum of 6s x 6" preview={108} onClick={write} />
<BoxRow name="Yahtzee" rule="Face to the fourth x 2" state="adversary" points={512} />
<BoxRow name="Chance" rule="Sum, doubled per 6" declared preview={96} />
```

An open row with no preview reads `scratch` in burned grey — writing it is a sacrifice, not an error.
