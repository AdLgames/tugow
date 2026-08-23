import * as React from 'react';

/**
 * The game's button in its three real shapes: the Roll action, an overlay list row, a scorecard row.
 * @dsGroup Core
 */
export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** 'action' = 200x42 Roll button, 'overlay' = 34px full-width list row, 'row' = scorecard box row. */
  variant?: 'action' | 'overlay' | 'row';
  /** Text colour override — box rows are tinted by card state. */
  tone?: string;
  children?: React.ReactNode;
}
export declare function Button(props: ButtonProps): JSX.Element;
