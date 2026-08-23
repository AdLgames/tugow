import * as React from 'react';

/**
 * The physical chit the Adversary slides onto the felt naming the box it will take next.
 * @dsGroup Game
 */
export interface DeclarationPlacardProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Box name, e.g. 'Sixes'. */
  box: string;
  /** The box's operation, verbatim from Scoring.BOX_RULES. */
  rule?: string;
  /** Who announced it, e.g. 'The Magpie'. */
  adversary?: string;
  /** Degrees of rotation, so repeat placements don't look stamped. Default -3. */
  tilt?: number;
}
export declare function DeclarationPlacard(props: DeclarationPlacardProps): JSX.Element;
