import { renderKatexText, resetKatexMacros } from "./katex";

let visitedTextLength = 0;

export function altsiaTextRewriter(text: string): string {
  visitedTextLength += text.length;
  return renderKatexText(text)
}

export function resetVisitedTextLength(): void {
  visitedTextLength = 0;
  resetKatexMacros();
}

export function getVisitedTextLength(): number {
  return visitedTextLength;
}
