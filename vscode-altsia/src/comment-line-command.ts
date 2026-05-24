import * as vscode from 'vscode';

export function registerCommentLineCommand(): vscode.Disposable {
  return vscode.commands.registerTextEditorCommand('altsia.commentLine', async (editor) => {
    if (editor.document.languageId !== 'altsia') {
      await vscode.commands.executeCommand('editor.action.commentLine');
      return;
    }

    const targetLineNumbers = collectTargetLineNumbers(editor.selections);

    await editor.edit((editBuilder) => {
      for (const lineNumber of targetLineNumbers) {
        const line = editor.document.lineAt(lineNumber);
        const lineText = line.text;
        const leadingWhitespace = lineText.match(/^\s*/)?.[0] ?? '';
        const content = lineText.slice(leadingWhitespace.length);
        const toggledContent = toggleAltsiaLineComment(content);
        editBuilder.replace(line.range, `${leadingWhitespace}${toggledContent}`);
      }
    });
  });
}

function collectTargetLineNumbers(selections: readonly vscode.Selection[]): number[] {
  const lineNumbers = new Set<number>();

  for (const selection of selections) {
    if (selection.isEmpty) {
      lineNumbers.add(selection.active.line);
      continue;
    }

    const startLine = selection.start.line;
    const endLine =
      selection.end.character === 0
        ? Math.max(startLine, selection.end.line - 1)
        : selection.end.line;

    for (let lineNumber = startLine; lineNumber <= endLine; lineNumber += 1) {
      lineNumbers.add(lineNumber);
    }
  }

  return Array.from(lineNumbers).sort((a, b) => a - b);
}

function toggleAltsiaLineComment(content: string): string {
  const unwrapped = unwrapAltsiaLineComment(content);
  if (unwrapped !== undefined) {
    return unwrapped;
  }

  return `(% ${content})`;
}

function unwrapAltsiaLineComment(content: string): string | undefined {
  if (!content.startsWith('(%') || !content.endsWith(')')) {
    return undefined;
  }

  const inner = content.slice(2, -1);
  if (inner.startsWith(' ')) {
    return inner.slice(1);
  }

  return inner;
}
