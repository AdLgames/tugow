import * as React from 'react';

/**
 * The floor threshold meter — 140x18, no percentage label.
 * @dsGroup Core
 */
export interface ThresholdBarProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Current floor score. */
  value?: number;
  /** The floor's threshold. */
  max?: number;
  /** Fill colour. Default --tb-ink. */
  tone?: string;
}
export declare function ThresholdBar(props: ThresholdBarProps): JSX.Element;
