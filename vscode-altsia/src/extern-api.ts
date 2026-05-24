import * as fs from 'node:fs';
import * as path from 'node:path';
import * as vscode from 'vscode';

export function altsiaReadFile(document: vscode.TextDocument, relativePath: string): string {
  if (document.uri.scheme !== 'file') {
    throw new Error('altsiaReadFile only supports local file documents.');
  }

  const baseDirPath = path.dirname(document.uri.fsPath);
  const targetPath = path.resolve(baseDirPath, relativePath);
  return fs.readFileSync(targetPath, 'utf8');
}
