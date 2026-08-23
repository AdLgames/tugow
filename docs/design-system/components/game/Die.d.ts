import * as React from 'react';

/**
 * One of the eight named dice on the table. Clicking locks it for the entire floor.
 * @dsGroup Game
 * @startingPoint section="Game" subtitle="The eight named dice and their conditions" viewport="700x200"
 */
export interface DieProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** The die's name — Ash, Bramble, Cinder, Dovetail, Ember, Flint, Gallows, Hollow. */
  name: string;
  /** Showing face. 0 means not rolled yet this floor and renders as an em dash. */
  value?: number;
  /** Locked for the floor. Renders gold, disabled, tagged LOCKED. */
  locked?: boolean;
  /** Turned bitter in a scratched box: renders purple, tagged 'bitter'. */
  bitter?: boolean;
  /** Rolled the same face twice running — tagged 'again' for charms that read memory. */
  repeated?: boolean;
  /** Faces reshaped away from 1-6 by the Facet rule. */
  faceted?: boolean;
  /** Who holds the lock in a duel. 'adversary' washes the face red. */
  owner?: 'player' | 'adversary';
}
export declare function Die(props: DieProps): JSX.Element;
