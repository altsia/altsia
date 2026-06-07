"use strict";

const cp = require("child_process");
const path = require("path");
const vscode = require("vscode");

const LANGUAGE_ID = "altsia";
const PREVIEW_COMMAND = "altsia.preview";
const REFRESH_COMMAND = "altsia.preview.refresh";

class PreviewController {
  constructor(context) {
    this.context = context;
    this.panel = undefined;
    this.entry = undefined;
    this.refreshTimer = undefined;
  }

  async open(resource) {
    const document = await this.documentForResource(resource);
    if (!document) {
      vscode.window.showWarningMessage("Open an Altsia file before previewing.");
      return;
    }
    this.entry = document.uri;
    if (!this.panel) {
      this.panel = vscode.window.createWebviewPanel(
        "altsiaPreview",
        "Altsia Preview",
        vscode.ViewColumn.Beside,
        {
          enableScripts: true,
          retainContextWhenHidden: true,
          localResourceRoots: this.localResourceRoots(document.uri),
        },
      );
      this.panel.onDidDispose(() => {
        this.panel = undefined;
        this.entry = undefined;
      }, undefined, this.context.subscriptions);
      this.panel.webview.onDidReceiveMessage(message => {
        if (message && message.command === "refresh") {
          this.refresh();
        }
      }, undefined, this.context.subscriptions);
    }
    await this.refresh();
  }

  async refresh() {
    if (!this.panel || !this.entry) {
      await this.open();
      return;
    }
    const document = await vscode.workspace.openTextDocument(this.entry);
    await this.saveBeforeRefresh(document);
    this.panel.title = "Preview " + path.basename(this.entry.fsPath);
    this.panel.webview.html = this.loadingHtml(this.panel.webview);
    try {
      const html = await renderPreview(this.entry.fsPath);
      this.panel.webview.html = this.previewHtml(this.panel.webview, html);
    } catch (error) {
      this.panel.webview.html = this.errorHtml(
        this.panel.webview,
        error instanceof Error ? error.message : String(error),
      );
    }
  }

  scheduleRefresh(uri) {
    if (!this.panel || !this.entry || uri.toString() !== this.entry.toString()) {
      return;
    }
    if (this.refreshTimer) {
      clearTimeout(this.refreshTimer);
    }
    this.refreshTimer = setTimeout(() => {
      this.refreshTimer = undefined;
      this.refresh();
    }, 150);
  }

  async documentForResource(resource) {
    if (resource && resource.scheme === "file") {
      const document = await vscode.workspace.openTextDocument(resource);
      return isAltsiaDocument(document) ? document : undefined;
    }
    const editor = vscode.window.activeTextEditor;
    if (editor && isAltsiaDocument(editor.document)) {
      return editor.document;
    }
    return undefined;
  }

  async saveBeforeRefresh(document) {
    const config = vscode.workspace.getConfiguration("altsia.preview");
    if (config.get("autoSaveBeforeRefresh", true) && document.isDirty) {
      await document.save();
    }
  }

  localResourceRoots(uri) {
    const roots = [];
    const workspaceFolder = vscode.workspace.getWorkspaceFolder(uri);
    if (workspaceFolder) {
      roots.push(workspaceFolder.uri);
    }
    roots.push(vscode.Uri.file(path.dirname(uri.fsPath)));
    return roots;
  }

  previewHtml(webview, body) {
    const nonce = nonceValue();
    const csp = [
      "default-src 'none'",
      "img-src " + webview.cspSource + " data:",
      "style-src " + webview.cspSource + " 'unsafe-inline'",
      "script-src 'nonce-" + nonce + "'",
    ].join("; ");
    return [
      "<!doctype html>",
      '<html lang="en">',
      "<head>",
      '<meta charset="utf-8">',
      '<meta http-equiv="Content-Security-Policy" content="' + escapeAttr(csp) + '">',
      '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
      "<style>",
      previewStyle(),
      "</style>",
      "</head>",
      "<body>",
      '<main class="altsia-preview">',
      body,
      "</main>",
      '<script nonce="' + nonce + '">',
      previewScript(),
      "</script>",
      "</body>",
      "</html>",
    ].join("");
  }

  loadingHtml(webview) {
    return this.messageHtml(webview, "Rendering preview...");
  }

  errorHtml(webview, message) {
    return this.messageHtml(webview, escapeHtml(message), true);
  }

  messageHtml(webview, message, isError = false) {
    const nonce = nonceValue();
    const csp = [
      "default-src 'none'",
      "style-src " + webview.cspSource + " 'unsafe-inline'",
      "script-src 'nonce-" + nonce + "'",
    ].join("; ");
    const className = isError ? "message error" : "message";
    return [
      "<!doctype html>",
      '<html lang="en">',
      "<head>",
      '<meta charset="utf-8">',
      '<meta http-equiv="Content-Security-Policy" content="' + escapeAttr(csp) + '">',
      "<style>",
      previewStyle(),
      "</style>",
      "</head>",
      "<body>",
      '<main class="' + className + '">',
      isError ? "<pre>" + message + "</pre>" : "<p>" + message + "</p>",
      '<button id="refresh">Refresh</button>',
      "</main>",
      '<script nonce="' + nonce + '">',
      "const vscode = acquireVsCodeApi();",
      "document.getElementById('refresh')?.addEventListener('click', () => vscode.postMessage({command: 'refresh'}));",
      "</script>",
      "</body>",
      "</html>",
    ].join("");
  }
}

function activate(context) {
  const controller = new PreviewController(context);
  context.subscriptions.push(
    vscode.commands.registerCommand(PREVIEW_COMMAND, resource => controller.open(resource)),
    vscode.commands.registerCommand(REFRESH_COMMAND, () => controller.refresh()),
    vscode.workspace.onDidSaveTextDocument(document => {
      if (isAltsiaDocument(document)) {
        controller.scheduleRefresh(document.uri);
      }
    }),
    vscode.window.onDidChangeActiveTextEditor(editor => {
      if (editor && isAltsiaDocument(editor.document)) {
        controller.scheduleRefresh(editor.document.uri);
      }
    }),
  );
}

function deactivate() {}

function isAltsiaDocument(document) {
  return document.languageId === LANGUAGE_ID || /\.(alt|altsia)$/.test(document.fileName);
}

function renderPreview(entryPath) {
  const config = vscode.workspace.getConfiguration("altsia.preview");
  const command = config.get("command", "alt");
  const extraArgs = config.get("commandArgs", []);
  const args = extraArgs.concat(["preview", entryPath]);
  return new Promise((resolve, reject) => {
    cp.execFile(command, args, {
      cwd: path.dirname(entryPath),
      maxBuffer: 16 * 1024 * 1024,
    }, (error, stdout, stderr) => {
      if (error) {
        reject(new Error(commandFailureMessage(command, args, error, stderr)));
        return;
      }
      if (stderr.trim() !== "") {
        reject(new Error(stderr.trim()));
        return;
      }
      resolve(stdout);
    });
  });
}

function commandFailureMessage(command, args, error, stderr) {
  const detail = stderr.trim() || error.message;
  return [
    "Unable to run Altsia preview command.",
    "",
    "Command: " + [command].concat(args).join(" "),
    "",
    detail,
    "",
    "Set `altsia.preview.command` to the `alt` executable path if it is not on PATH.",
  ].join("\n");
}

function previewStyle() {
  return [
    "body {",
    "  margin: 0;",
    "  color: var(--vscode-editor-foreground);",
    "  background: var(--vscode-editor-background);",
    "  font-family: var(--vscode-font-family);",
    "  line-height: 1.55;",
    "}",
    ".altsia-preview {",
    "  max-width: 820px;",
    "  margin: 0 auto;",
    "  padding: 28px 32px 48px;",
    "}",
    ".altsia-preview img { max-width: 100%; }",
    ".altsia-preview pre, .altsia-preview code {",
    "  font-family: var(--vscode-editor-font-family);",
    "}",
    ".altsia-preview pre {",
    "  overflow-x: auto;",
    "  padding: 12px;",
    "  background: var(--vscode-textCodeBlock-background);",
    "}",
    ".altsia-preview a { color: var(--vscode-textLink-foreground); }",
    ".message { padding: 24px; }",
    ".message.error pre {",
    "  white-space: pre-wrap;",
    "  color: var(--vscode-errorForeground);",
    "}",
    "button {",
    "  color: var(--vscode-button-foreground);",
    "  background: var(--vscode-button-background);",
    "  border: 0;",
    "  padding: 6px 12px;",
    "  cursor: pointer;",
    "}",
    "button:hover { background: var(--vscode-button-hoverBackground); }",
  ].join("\n");
}

function previewScript() {
  return [
    "const vscode = acquireVsCodeApi();",
    "document.addEventListener('click', event => {",
    "  const link = event.target.closest('a');",
    "  if (!link || !link.getAttribute('data-missing-target')) return;",
    "  event.preventDefault();",
    "});",
  ].join("\n");
}

function nonceValue() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let value = "";
  for (let i = 0; i < 32; i += 1) {
    value += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return value;
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function escapeAttr(value) {
  return escapeHtml(value).replace(/"/g, "&quot;");
}

module.exports = {
  activate,
  deactivate,
};
