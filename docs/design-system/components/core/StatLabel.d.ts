import * as React from 'react';

/**
 * Dim monospaced readout for header stats: floor, score / threshold, boxes left.
 * @dsGroup Core
 */
export interface StatLabelProps extends React.HTMLAttributes<HTMLSpanElement> {
  /** Text colour. Defaults to --tb-ink-dim. */
  tone?: string;
  children?: React.ReactNode;
}
export declare function StatLabel(props: StatLabelProps): JSX.Element;
