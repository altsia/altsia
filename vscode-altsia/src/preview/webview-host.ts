import * as vscode from 'vscode';

type PreviewUpdateMessage = {
  type: 'update';
  html: string;
  bodyFontSize: number;
};

export type PreviewContent = {
  html: string;
  bodyFontSize: number;
};

export class PreviewWebviewHost {
  private isShellReady = false;

  constructor(private readonly mediaRoot: vscode.Uri) { }

  reset(): void {
    this.isShellReady = false;
  }

  async render(webview: vscode.Webview, content: PreviewContent): Promise<void> {
    if (!this.isShellReady) {
      this.initializeShell(webview, content);
      return;
    }
    const message: PreviewUpdateMessage = {
      type: 'update',
      html: content.html,
      bodyFontSize: content.bodyFontSize,
    };
    await webview.postMessage(message);
  }

  private initializeShell(webview: vscode.Webview, content: PreviewContent): void {
    const katexCssUri = webview.asWebviewUri(vscode.Uri.joinPath(this.mediaRoot, 'katex', 'katex.css'));
    const nonce = this.createNonce();
    webview.html = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${webview.cspSource} https: data:; style-src ${webview.cspSource} 'unsafe-inline'; font-src ${webview.cspSource} data:; script-src 'nonce-${nonce}';">
  <link rel="stylesheet" href="${katexCssUri}">
</head>
<body style="font-size: ${content.bodyFontSize}px;">
  <div id="preview-content">${content.html}</div>
  <script nonce="${nonce}">
    (() => {
      const contentRoot = document.getElementById('preview-content');
      if (!contentRoot) {
        return;
      }

      const sameNodeType = (left, right) => {
        if (left.nodeType !== right.nodeType) {
          return false;
        }
        if (left.nodeType !== Node.ELEMENT_NODE) {
          return true;
        }
        return left.tagName === right.tagName;
      };

      const patchChildren = (currentParent, nextChildren) => {
        const currentChildren = Array.from(currentParent.childNodes);
        const commonLength = Math.min(currentChildren.length, nextChildren.length);

        for (let index = 0; index < commonLength; index += 1) {
          patchNode(currentChildren[index], nextChildren[index]);
        }
        for (let index = commonLength; index < nextChildren.length; index += 1) {
          currentParent.appendChild(nextChildren[index].cloneNode(true));
        }
        for (let index = currentChildren.length - 1; index >= nextChildren.length; index -= 1) {
          currentChildren[index].remove();
        }
      };

      const patchNode = (currentNode, nextNode) => {
        if (!sameNodeType(currentNode, nextNode)) {
          currentNode.replaceWith(nextNode.cloneNode(true));
          return;
        }

        if (
          currentNode.nodeType === Node.TEXT_NODE ||
          currentNode.nodeType === Node.COMMENT_NODE
        ) {
          if (currentNode.nodeValue !== nextNode.nodeValue) {
            currentNode.nodeValue = nextNode.nodeValue;
          }
          return;
        }

        const currentElement = currentNode;
        const nextElement = nextNode;

        for (const { name } of Array.from(currentElement.attributes)) {
          if (!nextElement.hasAttribute(name)) {
            currentElement.removeAttribute(name);
          }
        }
        for (const { name, value } of Array.from(nextElement.attributes)) {
          if (currentElement.getAttribute(name) !== value) {
            currentElement.setAttribute(name, value);
          }
        }

        patchChildren(currentElement, Array.from(nextElement.childNodes));
      };

      const applyUpdate = (html, bodyFontSize) => {
        const template = document.createElement('template');
        template.innerHTML = html;
        patchChildren(contentRoot, Array.from(template.content.childNodes));
        document.body.style.fontSize = bodyFontSize + 'px';
      };

      window.addEventListener('message', (event) => {
        const message = event.data;
        if (!message || message.type !== 'update') {
          return;
        }
        applyUpdate(message.html, message.bodyFontSize);
      });
    })();
  </script>
</body>
</html>`;
    this.isShellReady = true;
  }

  private createNonce(): string {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let nonce = '';
    for (let index = 0; index < 32; index += 1) {
      nonce += alphabet.charAt(Math.floor(Math.random() * alphabet.length));
    }
    return nonce;
  }
}
