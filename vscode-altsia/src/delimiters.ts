/* eslint no-constant-condition:0 */

export interface Delimiter {
  left: string;
  right: string;
  display: boolean;
}

export interface TextSplitItem {
  type: "text";
  data: string;
}

export interface MathSplitItem {
  type: "math";
  data: string;
  rawData: string;
  display: boolean;
}

export type SplitItem = TextSplitItem | MathSplitItem;

const findEndOfMath = (
  delimiter: string,
  text: string,
  startIndex: number
): number => {
  // Adapted from
  // https://github.com/Khan/perseus/blob/master/src/perseus-markdown.jsx
  let index = startIndex;
  let braceLevel = 0;

  const delimLength = delimiter.length;

  while (index < text.length) {
    const character = text[index];

    if (
      braceLevel <= 0 &&
      text.slice(index, index + delimLength) === delimiter
    ) {
      return index;
    } else if (character === "\\") {
      index++;
    } else if (character === "{") {
      braceLevel++;
    } else if (character === "}") {
      braceLevel--;
    }

    index++;
  }

  return -1;
};

const escapeRegex = (value: string): string => {
  return value.replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&");
};

const amsRegex = /^\\begin{/;

const splitAtDelimiters = (
  text: string,
  delimiters: Delimiter[]
): SplitItem[] => {
  let index: number;
  const data: SplitItem[] = [];

  const regexLeft = new RegExp(
    "(" + delimiters.map((delimiter) => escapeRegex(delimiter.left)).join("|") + ")"
  );

  while (true) {
    index = text.search(regexLeft);
    if (index === -1) {
      break;
    }
    if (index > 0) {
      data.push({
        type: "text",
        data: text.slice(0, index),
      });
      text = text.slice(index); // now text starts with delimiter
    }
    // ... so this always succeeds:
    const delimiterIndex = delimiters.findIndex((delimiter) =>
      text.startsWith(delimiter.left)
    );
    if (delimiterIndex === -1) {
      break;
    }
    const currentDelimiter = delimiters[delimiterIndex];
    index = findEndOfMath(
      currentDelimiter.right,
      text,
      currentDelimiter.left.length
    );
    if (index === -1) {
      break;
    }
    const rawData = text.slice(0, index + currentDelimiter.right.length);
    const math = amsRegex.test(rawData)
      ? rawData
      : text.slice(currentDelimiter.left.length, index);
    data.push({
      type: "math",
      data: math,
      rawData,
      display: currentDelimiter.display,
    });
    text = text.slice(index + currentDelimiter.right.length);
  }

  if (text !== "") {
    data.push({
      type: "text",
      data: text,
    });
  }

  return data;
};

export default splitAtDelimiters;
