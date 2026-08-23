import * as React from 'react';

/**
 * The centred modal shell used for the title screen, the forge, and the end of a run.
 * @dsGroup Game
 * @startingPoint section="Game" subtitle="Title, forge and run-over modal" viewport="700x340"
 */
export interface OverlayProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Uppercase title, e.g. 'THE FORGE'. */
  title: string;
  /** OverlayText paragraphs and overlay-variant Buttons. */
  children?: React.ReactNode;
  /** Render the darkening scrim behind the panel. Default true. */
  scrim?: boolean;
}
export interface OverlayTextProps extends React.HTMLAttributes<HTMLParagraphElement> {
  children?: React.ReactNode;
}
export declare function Overlay(props: OverlayProps): JSX.Element;
export declare function OverlayText(props: OverlayTextProps): JSX.Element;
