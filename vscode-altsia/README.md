
# <img src="./images/altsia.png" title="altsia" width=100 /> VS Code Extension

Visual Studio Code extension for the Altsia

## Development install

This extension depends on the `altsia` package via `file:` dependency in development mode.

### 1. Build `altsia` from source

```bash
git clone https://github.com/altsia/altsia
cd altsia
moon build --release
```

### 2. Create `package.json`

Create `_build/js/release/build/package.json` with:

```json
{
  "name": "altsia",
  "version": "0.1.5", // edit it
  "description": "An experimental markup language that respects document calculus. ",
  "main": "altsia.js",
  "types": "altsia.d.ts",
  "keywords": [
    "altsia"
  ],
  "homepage": "https://altsia.github.io/altsia/",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/altsia/altsia.git"
  },
  "author": "altsia",
  "license": "GPL-3.0",
  "dependencies": {}
}
```

### 3. Configure `file:` dependency in this extension

```bash
cd /path/to/vscode-altsia
npm pkg set dependencies.altsia="file:../altsia/_build/js/release/build"
npm install
npm run copy:katex
```

### 4. Build and run extension development host

```bash
npm run compile
```

In VS Code, run the launch config: `Run Altsia Preview Extension` (or press `F5`).
