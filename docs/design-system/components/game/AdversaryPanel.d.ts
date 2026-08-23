import * as React from 'react';

/**
 * The duel readout: who is writing on your card, what it announced, and how close it is to taking the card.
 * @dsGroup Game
 */
export interface AdversaryPanelProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Display name, e.g. 'The Magpie'. Omit for 'No adversary on this floor.' */
  name?: string;
  /** The roster blurb, verbatim. */
  blurb?: string;
  /** Box it announced this turn, or 'nothing'. */
  announced?: string;
  /** Its duel score so far. */
  score?: number;
  /** Boxes it has claimed. */
  boxesTaken?: number;
  /** Boxes it needs to take the card. Default 7. */
  boxLimit?: number;
}
export declare function AdversaryPanel(props: AdversaryPanelProps): JSX.Element;
