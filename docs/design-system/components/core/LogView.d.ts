import * as React from 'react';

/**
 * The run log — dim monospaced lines, newest last, auto-scrolled to the bottom.
 * @dsGroup Core
 */
export interface LogViewProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Log lines in emission order. Floor separators ('--- Floor 3 ...') brighten to ink. */
  lines?: string[];
}
export declare function LogView(props: LogViewProps): JSX.Element;
