import { altsia_normalize, altsia_normalize_range } from 'altsia';
import * as vscode from 'vscode';

export function registerNormalizeCommand(
  getDisplayLanguage: () => string,
  getNormalizeMaxWidth: () => number | undefined
): vscode.Disposable {
  return vscode.commands.registerTextEditorCommand('altsia.normalize', async (editor) => {
    if (editor.document.languageId !== 'altsia') {
      void vscode.window.showWarningMessage('Altsia normalize only supports .alt documents.');
      return;
    }

    const source = editor.document.getText();

    try {
      const normalized = altsia_normalize(
        source,
        getDisplayLanguage(),
        getNormalizeMaxWidth()
      );
      if (normalized === source) {
        return;
      }

      const wholeDocumentRange = new vscode.Range(
        editor.document.positionAt(0),
        editor.document.positionAt(source.length)
      );

      await editor.edit((editBuilder) => {
        editBuilder.replace(wholeDocumentRange, normalized);
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      void vscode.window.showErrorMessage(`Altsia normalize failed: ${message}`);
    }
  });
}

export function registerNormalizeRangeFormattingProvider(
  getDisplayLanguage: () => string,
  getNormalizeMaxWidth: () => number | undefined
): vscode.Disposable {
  return vscode.languages.registerDocumentRangeFormattingEditProvider(
    { language: 'altsia' },
    {
      provideDocumentRangeFormattingEdits(
        document: vscode.TextDocument,
        range: vscode.Range
      ): vscode.TextEdit[] {
        try {
          const source = document.getText();
          const startOffset = document.offsetAt(range.start);
          const endOffset = document.offsetAt(range.end);
          const normalized = altsia_normalize_range(
            source,
            startOffset,
            endOffset,
            getDisplayLanguage(),
            getNormalizeMaxWidth()
          );

          if (normalized === source) {
            return [];
          }

          const wholeDocumentRange = new vscode.Range(
            document.positionAt(0),
            document.positionAt(source.length)
          );

          return [vscode.TextEdit.replace(wholeDocumentRange, normalized)];
        } catch (error) {
          const message = error instanceof Error ? error.message : String(error);
          void vscode.window.showErrorMessage(`Altsia format selection failed: ${message}`);
          return [];
        }
      },
    }
  );
}
