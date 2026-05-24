import * as vscode from 'vscode';
import { Docs } from './doc-entry';

export function toDocId(uri: vscode.Uri): string {
  return vscode.workspace.asRelativePath(uri, false).replace(/\\/g, '/');
}

async function readDocumentText(uri: vscode.Uri): Promise<string> {
  const openedDocument = vscode.workspace.textDocuments.find(
    (document) => document.uri.toString() === uri.toString()
  );
  if (openedDocument) {
    return openedDocument.getText();
  }

  const bytes = await vscode.workspace.fs.readFile(uri);
  return Buffer.from(bytes).toString('utf8');
}

export async function collectWorkspaceDocs(textDocument: vscode.TextDocument): Promise<Docs> {
  const workspaceFolder = vscode.workspace.getWorkspaceFolder(textDocument.uri);
  if (!workspaceFolder) {
    return [
      {
        id: toDocId(textDocument.uri),
        content: textDocument.getText(),
      },
    ];
  }

  const pattern = new vscode.RelativePattern(workspaceFolder, '**/*.alt');
  const altFileUris = await vscode.workspace.findFiles(pattern);
  altFileUris.sort((a, b) => a.toString().localeCompare(b.toString()));

  const docs = await Promise.all(
    altFileUris.map(async (uri) => ({
      id: toDocId(uri),
      content: await readDocumentText(uri),
    }))
  );

  return docs;
}
