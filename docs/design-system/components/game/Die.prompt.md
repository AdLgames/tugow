A single die on the table; the whole locking verb lives here.

```jsx
<Die name="Ash" value={5} onClick={() => lock('ash')} />
<Die name="Gallows" value={2} bitter locked />
```

States: default (ink, clickable), locked (gold, disabled, gold wash), bitter (purple edge), `repeated` and `faceted` add tag text under the value. Value 0 means unrolled and is not clickable.
