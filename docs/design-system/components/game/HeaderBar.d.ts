import * as React from 'react';

/**
 * The top strip of the game screen: wordmark, floor, progress against the threshold, boxes remaining.
 * @dsGroup Game
 * @startingPoint section="Game" subtitle="Wordmark, floor, threshold meter, boxes left" viewport="700x120"
 */
export interface HeaderBarProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Current floor number, 1-12. */
  floor?: number;
  /** Score accumulated on this floor. */
  score?: number;
  /** This floor's threshold — 60 x 1.45^(floor-1). */
  threshold?: number;
  /** Open boxes remaining. Turns red at 4 or fewer. */
  boxesLeft?: number;
  /** Optional path to assets/logo.svg. */
  logo?: string;
}
export declare function HeaderBar(props: HeaderBarProps): JSX.Element;
