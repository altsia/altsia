
import { KatexOptions, renderToString } from "katex"
import splitAtDelimiters, { Delimiter } from "./delimiters";

const delimiters: Delimiter[] = [
  { left: '$$', right: '$$', display: true },
  { left: '$', right: '$', display: false },
]
const baseOptions: KatexOptions = {
  throwOnError: true,
  trust: true,
  globalGroup: true,
};
let sharedMacros: NonNullable<KatexOptions['macros']> = {};

export function resetKatexMacros(): void {
  sharedMacros = {};
}

export const renderKatexText = (text: string): string => {
  const splitItems = splitAtDelimiters(text, delimiters)
  return splitItems.map((item) => {
    if (item.type === "math") {
      return renderToString(item.data, {
        ...baseOptions,
        displayMode: item.display,
        macros: sharedMacros,
      })
    } else {
      return item.data
    }
  }).join("")
}

export const renderJustKatex = (tex: string, displayMode: boolean): string => {
  return renderToString(tex, {
    ...baseOptions,
    displayMode,
    macros: sharedMacros,
  })
}
