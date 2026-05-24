import { altsia_to_html_with_rewriter, kodama_to_html, markdown_to_html } from 'altsia';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { altsiaTextRewriter, getVisitedTextLength, resetVisitedTextLength } from './visitor';
import { altsiaReadFile } from './extern-api';
import { renderJustKatex } from './katex';
import { ContextAPI } from './forester/context-api';
import { collectWorkspaceDocs, toDocId } from './forester/collect-docs';
import { PreviewWebviewHost } from './preview/webview-host';
import { Debouncer } from './utils/debouncer';

type WorkspaceDocsCache = {
  docsById: Map<string, string>;
  cachedDocs: ContextAPI['docs'] | undefined;
};

export class PreviewController implements vscode.Disposable {
  private static readonly previewDebounceMs = 120;
  private previewPanel: vscode.WebviewPanel | undefined;
  private previewDocumentUri: vscode.Uri | undefined;
  private previewDocumentType: 'altsia' | 'markdown' | 'plt' | undefined;
  private readonly mediaRoot: vscode.Uri;
  private readonly previewWebviewHost: PreviewWebviewHost;
  private readonly wordCountStatusBarItem: vscode.StatusBarItem;
  private readonly workspaceDocsCacheByKey = new Map<string, Promise<WorkspaceDocsCache>>();
  private readonly previewUpdateDebouncer = new Debouncer(PreviewController.previewDebounceMs);
  private readonly previewRefreshDebouncer = new Debouncer(PreviewController.previewDebounceMs);
  private previewRenderVersion = 0;
  private pendingPreviewDocument: vscode.TextDocument | undefined;

  constructor(
    extensionUri: vscode.Uri,
    private readonly getDisplayLanguage: () => string
  ) {
    this.mediaRoot = vscode.Uri.joinPath(extensionUri, 'media');
    this.previewWebviewHost = new PreviewWebviewHost(this.mediaRoot);
    this.wordCountStatusBarItem = vscode.window.createStatusBarItem(
      vscode.StatusBarAlignment.Right,
      100
    );
  }

  openPreviewToSide(): void {
    const activeEditor = vscode.window.activeTextEditor;
    if (!activeEditor || !this.isPreviewDocument(activeEditor.document)) {
      return;
    }

    if (!this.previewPanel) {
      this.previewPanel = vscode.window.createWebviewPanel(
        'altsiaPreview',
        'Altsia Preview',
        vscode.ViewColumn.Beside,
        {
          enableScripts: true,
          localResourceRoots: [this.mediaRoot],
        }
      );

      this.previewPanel.onDidDispose(() => {
        this.clearScheduledPreviewWork();
        this.previewPanel = undefined;
        this.previewDocumentUri = undefined;
        this.previewDocumentType = undefined;
        this.workspaceDocsCacheByKey.clear();
        this.wordCountStatusBarItem.hide();
        this.previewWebviewHost.reset();
      });
    } else {
      this.previewPanel.reveal(vscode.ViewColumn.Beside);
    }

    this.previewDocumentUri = activeEditor.document.uri;
    this.previewDocumentType = this.getDocumentType(activeEditor.document);
    this.clearScheduledPreviewWork();
    void this.updatePreview(activeEditor.document);
  }

  async refreshPreview(): Promise<void> {
    if (!this.previewPanel || !this.previewDocumentUri) {
      return;
    }

    const previewDocument = await vscode.workspace.openTextDocument(this.previewDocumentUri);
    await this.updatePreview(previewDocument);
  }

  handleDocumentChange(event: vscode.TextDocumentChangeEvent): void {
    if (!this.isPreviewDocument(event.document)) {
      return;
    }
    if (this.isAltDocument(event.document)) {
      void this.updateOpenedDocumentInCache(event.document);
    }

    if (!this.previewPanel || !this.previewDocumentUri) {
      return;
    }

    if (event.document.uri.toString() === this.previewDocumentUri.toString()) {
      this.previewDocumentType = this.getDocumentType(event.document);
      this.schedulePreviewUpdate(event.document);
      return;
    }

    if (this.previewDocumentType !== 'altsia') {
      return;
    }
    if (!this.isAltDocument(event.document)) {
      return;
    }

    if (!this.isSameWorkspace(event.document.uri, this.previewDocumentUri)) {
      return;
    }

    this.scheduleRefreshPreview();
  }

  handleDocumentOpen(document: vscode.TextDocument): void {
    if (!this.isAltDocument(document)) {
      return;
    }
    void this.updateOpenedDocumentInCache(document);
  }

  handleDocumentClose(document: vscode.TextDocument): void {
    if (!this.isAltDocument(document)) {
      return;
    }
    void this.restoreClosedDocumentInCache(document);
  }

  handleActiveEditorChange(editor: vscode.TextEditor | undefined): void {
    if (!this.previewPanel || !editor || !this.isPreviewDocument(editor.document)) {
      return;
    }

    this.previewDocumentUri = editor.document.uri;
    this.previewDocumentType = this.getDocumentType(editor.document);
    this.clearScheduledPreviewWork();
    void this.updatePreview(editor.document);
  }

  dispose(): void {
    this.clearScheduledPreviewWork();
    this.previewPanel?.dispose();
    this.wordCountStatusBarItem.dispose();
  }

  private async updatePreview(textDocument: vscode.TextDocument): Promise<void> {
    if (!this.previewPanel) {
      return;
    }
    const renderVersion = ++this.previewRenderVersion;
    this.previewDocumentType = this.getDocumentType(textDocument);

    this.previewPanel.title = `Preview ${path.basename(textDocument.fileName)}`;
    const editorFontSize = vscode.workspace
      .getConfiguration('editor', textDocument.uri)
      .get<number>('fontSize', 14);
    const bodyFontSize = Number.isFinite(editorFontSize) ? editorFontSize : 14;

    const source = textDocument.getText();
    resetVisitedTextLength();

    const isMarkdown = this.isMarkdownDocument(textDocument);
    const isPlainAltsia = this.isPlainAltsiaDocument(textDocument);
    const contextApi = isMarkdown || isPlainAltsia
      ? { doc_workspace_path: '', docs: [] }
      : await this.getCachedContext(textDocument);
    if (!this.previewPanel) {
      return;
    }
    if (this.previewDocumentUri?.toString() !== textDocument.uri.toString()) {
      return;
    }
    if (renderVersion !== this.previewRenderVersion) {
      return;
    }

    const externApi = {
      read: (path: string) => altsiaReadFile(textDocument, path),
      katex_render: (tex: string) => renderJustKatex(tex, false),
      katex_display_render: (tex: string) => renderJustKatex(tex, true)
    };
    const html = isMarkdown
      ? markdown_to_html(
        source,
        contextApi,
        altsiaTextRewriter,
        externApi,
        this.getDisplayLanguage()
      )
      : isPlainAltsia
        ? altsia_to_html_with_rewriter(
          source,
          altsiaTextRewriter,
          externApi,
          this.getDisplayLanguage()
        )
        : kodama_to_html(
          source,
          contextApi,
          altsiaTextRewriter,
          externApi,
          this.getDisplayLanguage()
        );

    const visitedTextLength = getVisitedTextLength();
    this.wordCountStatusBarItem.text = `$(symbol-string) ${visitedTextLength} words`;
    this.wordCountStatusBarItem.tooltip = '[Altsia] word count';
    this.wordCountStatusBarItem.show();
    await this.previewWebviewHost.render(this.previewPanel.webview, {
      html,
      bodyFontSize,
    });
  }

  private schedulePreviewUpdate(textDocument: vscode.TextDocument): void {
    this.pendingPreviewDocument = textDocument;
    this.previewRefreshDebouncer.cancel();
    this.previewUpdateDebouncer.schedule(() => {
      const pendingDocument = this.pendingPreviewDocument;
      this.pendingPreviewDocument = undefined;
      if (!pendingDocument) {
        return;
      }
      void this.updatePreview(pendingDocument);
    });
  }

  private scheduleRefreshPreview(): void {
    this.pendingPreviewDocument = undefined;
    this.previewUpdateDebouncer.cancel();
    this.previewRefreshDebouncer.schedule(() => {
      void this.refreshPreview();
    });
  }

  private clearScheduledPreviewWork(): void {
    this.previewUpdateDebouncer.cancel();
    this.previewRefreshDebouncer.cancel();
    this.pendingPreviewDocument = undefined;
  }

  private getCachedContext(textDocument: vscode.TextDocument): Promise<ContextAPI> {
    return (async (): Promise<ContextAPI> => ({
      doc_workspace_path: toDocId(textDocument.uri),
      docs: await this.getWorkspaceDocs(textDocument),
    }))();
  }

  private async getWorkspaceDocs(textDocument: vscode.TextDocument): Promise<ContextAPI['docs']> {
    const workspaceDocsCache = await this.getOrCreateWorkspaceDocsCache(textDocument);
    if (workspaceDocsCache.cachedDocs) {
      return workspaceDocsCache.cachedDocs;
    }

    workspaceDocsCache.cachedDocs = Array.from(workspaceDocsCache.docsById.entries())
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([id, content]) => ({ id, content }));
    return workspaceDocsCache.cachedDocs;
  }

  private getOrCreateWorkspaceDocsCache(
    textDocument: vscode.TextDocument
  ): Promise<WorkspaceDocsCache> {
    const cacheKey = this.getWorkspaceCacheKey(textDocument.uri);
    const existingCachePromise = this.workspaceDocsCacheByKey.get(cacheKey);
    if (existingCachePromise) {
      return existingCachePromise;
    }

    const cachePromise = (async (): Promise<WorkspaceDocsCache> => {
      const docs = await collectWorkspaceDocs(textDocument);
      const docsById = new Map(docs.map((docEntry) => [docEntry.id, docEntry.content]));
      return {
        docsById,
        cachedDocs: undefined,
      };
    })();

    this.workspaceDocsCacheByKey.set(cacheKey, cachePromise);
    return cachePromise;
  }

  private async updateOpenedDocumentInCache(document: vscode.TextDocument): Promise<void> {
    const cachePromise = this.workspaceDocsCacheByKey.get(this.getWorkspaceCacheKey(document.uri));
    if (!cachePromise) {
      return;
    }

    const workspaceDocsCache = await cachePromise;
    const docId = toDocId(document.uri);
    const content = document.getText();
    if (workspaceDocsCache.docsById.get(docId) === content) {
      return;
    }

    workspaceDocsCache.docsById.set(docId, content);
    workspaceDocsCache.cachedDocs = undefined;
  }

  private async restoreClosedDocumentInCache(document: vscode.TextDocument): Promise<void> {
    const cachePromise = this.workspaceDocsCacheByKey.get(this.getWorkspaceCacheKey(document.uri));
    if (!cachePromise) {
      return;
    }

    const workspaceDocsCache = await cachePromise;
    const docId = toDocId(document.uri);

    if (document.uri.scheme !== 'file') {
      if (workspaceDocsCache.docsById.delete(docId)) {
        workspaceDocsCache.cachedDocs = undefined;
      }
      return;
    }

    try {
      const bytes = await vscode.workspace.fs.readFile(document.uri);
      const diskContent = Buffer.from(bytes).toString('utf8');
      if (workspaceDocsCache.docsById.get(docId) !== diskContent) {
        workspaceDocsCache.docsById.set(docId, diskContent);
        workspaceDocsCache.cachedDocs = undefined;
      }
    } catch {
      if (workspaceDocsCache.docsById.delete(docId)) {
        workspaceDocsCache.cachedDocs = undefined;
      }
    }
  }

  private getWorkspaceCacheKey(uri: vscode.Uri): string {
    const workspaceFolder = vscode.workspace.getWorkspaceFolder(uri);
    if (!workspaceFolder) {
      return `document:${uri.toString()}`;
    }
    return `workspace:${workspaceFolder.uri.toString()}`;
  }

  private isSameWorkspace(leftUri: vscode.Uri, rightUri: vscode.Uri): boolean {
    const leftWorkspaceFolder = vscode.workspace.getWorkspaceFolder(leftUri);
    const rightWorkspaceFolder = vscode.workspace.getWorkspaceFolder(rightUri);
    if (!leftWorkspaceFolder || !rightWorkspaceFolder) {
      return false;
    }
    return leftWorkspaceFolder.uri.toString() === rightWorkspaceFolder.uri.toString();
  }

  private isAltDocument(document: vscode.TextDocument): boolean {
    return document.languageId === 'altsia' || document.fileName.endsWith('.alt');
  }

  private isPlainAltsiaDocument(document: vscode.TextDocument): boolean {
    return document.fileName.endsWith('.plt');
  }

  private isMarkdownDocument(document: vscode.TextDocument): boolean {
    return document.languageId === 'markdown' || document.fileName.endsWith('.md');
  }

  private isPreviewDocument(document: vscode.TextDocument): boolean {
    return this.isAltDocument(document) || this.isPlainAltsiaDocument(document) || this.isMarkdownDocument(document);
  }

  private getDocumentType(document: vscode.TextDocument): 'altsia' | 'markdown' | 'plt' | undefined {
    if (this.isAltDocument(document)) {
      return 'altsia';
    }
    if (this.isPlainAltsiaDocument(document)) {
      return 'plt';
    }
    if (this.isMarkdownDocument(document)) {
      return 'markdown';
    }
    return undefined;
  }
}
