import * as React from 'react';

/**
 * The one container in the game: a flat panel with a 1px coloured edge and 4px corners.
 * @dsGroup Core
 */
export interface PanelProps extends React.HTMLAttributes<HTMLElement> {
  /** Border colour. Semantic names map to palette states; any CSS colour also works. */
  edge?: 'default' | 'adversary' | 'ink' | 'player' | 'locked' | string;
  /** Apply panel_style content margins (10px / 8px). Default true. */
  pad?: boolean;
  /** Element to render. Default 'div'. */
  as?: keyof JSX.IntrinsicElements;
  children?: React.ReactNode;
}
export declare function Panel(props: PanelProps): JSX.Element;
