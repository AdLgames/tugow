import * as React from 'react';

/**
 * The thirteen-box scorecard — the game's health bar, shared with the Adversary during a duel.
 * @dsGroup Game
 * @startingPoint section="Game" subtitle="Thirteen boxes, colour-coded by who spent them" viewport="700x400"
 */
export interface ScorecardProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Box definitions. Defaults to the export BOXES — the thirteen operators in source order. */
  boxes?: { name: string; rule: string }[];
  /** Per-box ownership, 13 entries. */
  states?: ('open' | 'player' | 'adversary' | 'burned')[];
  /** Per-box points for spent boxes. */
  points?: number[];
  /** Per-box live preview for the current table. */
  previews?: (number | null)[];
  /** Index of the box the Adversary announced, or -1. */
  declared?: number;
  /** Disable writing (not the player's turn). */
  disabled?: boolean;
  /** Called with the box index when the player writes. */
  onWrite?: (box: number) => void;
}
export declare const BOXES: { name: string; rule: string }[];
export declare function Scorecard(props: ScorecardProps): JSX.Element;
