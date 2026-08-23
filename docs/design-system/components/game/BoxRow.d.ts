import * as React from 'react';

/**
 * One of the thirteen boxes: name, operation, and either a live preview or the spent result.
 * @dsGroup Game
 */
export interface BoxRowProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** Box name, e.g. 'Four of a Kind'. */
  name: string;
  /** The operation, verbatim from Scoring.BOX_RULES, e.g. 'Quad face cubed x 5'. */
  rule: string;
  /** Who holds it. 'burned' is the Furnace or the forge. */
  state?: 'open' | 'player' | 'adversary' | 'burned';
  /** Points written into a spent box. */
  points?: number;
  /** Live score for the current table. 0 or null renders 'scratch'. */
  preview?: number | null;
  /** The Adversary has announced this box: marker, orange tint, one turn to respond. */
  declared?: boolean;
  /** Not the player's turn — open rows stay tinted but unclickable. */
  disabled?: boolean;
}
export declare function BoxRow(props: BoxRowProps): JSX.Element;
